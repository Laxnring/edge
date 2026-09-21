# Flutter launcher for this Windows checkout. The SDK lives at C:\flutter-sdk,
# while this workspace owns a writable config/cache so the CLI can create its
# lockfile and package cache without touching the restricted user profile.
$ErrorActionPreference = 'Stop'
$sdk = 'C:\flutter-sdk'
$workspace = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:FLUTTER_ROOT = $sdk
$env:GIT_CONFIG_GLOBAL = Join-Path $workspace '.gitconfig-flutter'
$env:APPDATA = Join-Path $workspace '.flutter-appdata'
$env:PUB_CACHE = if ($env:OPENSTRAP_PUB_CACHE) {
  # The web preview is compiled from a short-lived copy. Reusing the checked
  # out project's cache avoids downloading every Flutter package on each run.
  $env:OPENSTRAP_PUB_CACHE
} else {
  Join-Path $workspace '.pub-cache'
}
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:PUB_CACHE | Out-Null
$dart = Join-Path $sdk 'bin\cache\dart-sdk\bin\dart.exe'
$packages = Join-Path $sdk 'packages\flutter_tools\.dart_tool\package_config.json'
$snapshot = Join-Path $sdk 'bin\cache\flutter_tools.snapshot'

# OneDrive-backed checkouts can fail Flutter's normal gen-l10n writability
# probe. Generate into a project-local staging directory instead, then copy
# the ignored generated sources to the path used by the app imports.
$localizations = Join-Path $workspace 'lib\l10n\app_localizations.dart'
$stage = Join-Path $workspace '.generated-l10n'
$arb = Join-Path $stage 'arb'
if (-not (Test-Path (Join-Path $arb 'app_en.arb'))) {
  New-Item -ItemType Directory -Force -Path $arb | Out-Null
  Copy-Item (Join-Path $workspace 'lib\l10n\app_*.arb') $arb -Force
}
if (-not (Test-Path $localizations)) {
  $config = Join-Path $workspace 'l10n.yaml'
  $disabled = Join-Path $workspace 'l10n.yaml.codex-disabled'
  $hadConfig = Test-Path $config
  if ($hadConfig) { Move-Item -LiteralPath $config -Destination $disabled -Force }
  try {
    & $dart --packages=$packages $snapshot gen-l10n `
      --arb-dir $arb `
      --template-arb-file app_en.arb `
      --output-dir $stage `
      --output-localization-file app_localizations.dart
    if ($LASTEXITCODE -ne 0) { throw 'Flutter localization generation failed.' }
    Copy-Item (Join-Path $stage 'app_localizations*.dart') (Join-Path $workspace 'lib\l10n') -Force
  } finally {
    if ($hadConfig) { Move-Item -LiteralPath $disabled -Destination $config -Force }
  }
}
& $dart --packages=$packages $snapshot @args
exit $LASTEXITCODE
