# Runs Edge in Chrome from a normal local copy. Flutter cannot reliably build
# from this OneDrive-backed checkout because cloud placeholder files fail its
# writability checks; source changes still remain in this checkout.
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $MyInvocation.MyCommand.Path

# The stable port is intentional: it preserves Chrome's Web Bluetooth grant
# and the local app database across launches. A second double-click should use
# the preview already serving there, not fail with Windows' "address already
# in use" error. Only do this for the normal run path — tests and builds do
# not start a browser server.
$normalLaunch = $FlutterArgs.Count -eq 0
if ($normalLaunch) {
  $existing = Get-NetTCPConnection -LocalPort 65429 -State Listen -ErrorAction SilentlyContinue
  if ($existing) {
    try {
      $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:65429/' -TimeoutSec 3
      if ($response.StatusCode -eq 200 -and $response.Content -match 'flutter_bootstrap') {
        Write-Host 'NOOP is already running at http://localhost:65429 — opening it in Chrome.'
        Start-Process 'http://localhost:65429'
        exit 0
      }
    } catch {
      # A different program has the port. The normal Flutter error below names
      # the conflict rather than silently opening an unrelated local service.
    }
  }
}
# A unique directory is intentional. Reusing one preview meant Flutter could
# reuse stale build artefacts from an earlier source copy, so the launcher could
# open an old screen after an update. Each launch now starts from the source
# tree that exists at the moment the batch file is pressed.
$preview = Join-Path $env:TEMP ("openstrap-edge-web-preview-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $preview | Out-Null

try {
  $revision = (& git -C $source rev-parse --short HEAD 2>$null)
} catch {
  $revision = $null
}
if ([string]::IsNullOrWhiteSpace($revision)) {
  $revision = 'local changes'
}
Write-Host "OpenStrap source revision: $revision"
Write-Host "Fresh preview: $preview"

& robocopy $source $preview /E `
  /XD .git .flutter-appdata .pub-cache .generated-l10n protocol-research build `
  /XF '*.db' '*.sqlite' '*.log' /R:1 /W:1 /NFL /NDL /NJH /NJS
if ($LASTEXITCODE -gt 7) {
  throw "Could not prepare the local web preview (robocopy exit code $LASTEXITCODE)."
}

# OneDrive can mark copied source files read-only. Flutter's localization step
# regenerates code next to the ARB files, so a preview must be writable even
# when the source checkout itself is cloud-managed.
Get-ChildItem -LiteralPath $preview -Recurse -Force | ForEach-Object {
  if ($_.Attributes -band [IO.FileAttributes]::ReadOnly) {
    $_.Attributes = $_.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly)
  }
}

 $defaultRun = $normalLaunch
if ($defaultRun) {
  # Web Bluetooth permission and the local app database are scoped to the
  # browser origin, including its port. A random Flutter port made every new
  # launch look like a different app: users could reopen an old tab and a
  # WHOOP permission granted in the previous run was unusable. Keep one stable
  # local address for this Windows preview.
  $FlutterArgs = @('run', '-d', 'chrome', '--web-hostname', 'localhost', '--web-port', '65429')
}

Push-Location $preview
try {
  # `flutter-local.ps1` honours this when it runs inside the temporary copy.
  # Keep dependencies stable between launches without copying the entire cache.
  $env:OPENSTRAP_PUB_CACHE = Join-Path $source '.pub-cache'
  if ($defaultRun) {
    & powershell -ExecutionPolicy Bypass -File .\flutter-local.ps1 pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  & powershell -ExecutionPolicy Bypass -File .\flutter-local.ps1 @FlutterArgs
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
