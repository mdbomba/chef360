Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir '../..')
$TargetDir = Join-Path $ProjectRoot '.azure'
$SourceDir = Join-Path $HOME '.azure'

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
  throw "Source Azure CLI directory not found: $SourceDir"
}

if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
  New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$files = @(
  'azureProfile.json',
  'az.sess',
  'msal_token_cache.json',
  'msal_http_cache.bin',
  'config',
  'clouds.config'
)

foreach ($file in $files) {
  $sourcePath = Join-Path $SourceDir $file
  $targetPath = Join-Path $TargetDir $file
  if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
  }
}

Write-Host "Azure CLI auth artifacts staged at: $TargetDir"
Write-Host "Scripts in this repo will use AZURE_CONFIG_DIR=$TargetDir when present."
