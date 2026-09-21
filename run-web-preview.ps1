# Runs Edge in Chrome from a normal local copy. Flutter cannot reliably build
# from this OneDrive-backed checkout because cloud placeholder files fail its
# writability checks; source changes still remain in this checkout.
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$preview = Join-Path $env:TEMP 'openstrap-edge-web-preview'
New-Item -ItemType Directory -Force -Path $preview | Out-Null

& robocopy $source $preview /E `
  /XD .git .flutter-appdata .pub-cache .generated-l10n protocol-research build `
  /XF '*.db' '*.sqlite' '*.log' /R:1 /W:1 /NFL /NDL /NJH /NJS
if ($LASTEXITCODE -gt 7) {
  throw "Could not prepare the local web preview (robocopy exit code $LASTEXITCODE)."
}

 $defaultRun = $FlutterArgs.Count -eq 0
if ($defaultRun) {
  $FlutterArgs = @('run', '-d', 'chrome')
}

Push-Location $preview
try {
  if ($defaultRun) {
    & powershell -ExecutionPolicy Bypass -File .\flutter-local.ps1 pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  & powershell -ExecutionPolicy Bypass -File .\flutter-local.ps1 @FlutterArgs
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
