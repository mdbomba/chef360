param(
  [string]$ResourceGroup = 'rg-chef360-linux',
  [string]$ObjectOwnerPrefix = $(if ($env:OBJECT_OWNER_PREFIX) { $env:OBJECT_OWNER_PREFIX } else { 'chef360' }),
  [string]$NamePrefix = $(if ($env:NAME_PREFIX) { $env:NAME_PREFIX } else { '' }),
  [switch]$Short
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir '../..')
. (Join-Path $ProjectRoot 'scripts/lib/Import-Chef360Parameters.ps1')
$parameters = Import-Chef360Parameters -ProjectRoot $ProjectRoot
$StateFile = if ($env:AZURE_TWO_LINUX_STATE_FILE) { $env:AZURE_TWO_LINUX_STATE_FILE } else { Join-Path $ProjectRoot 'config/azure-two-linux.env' }
$ProjectAzureDir = Join-Path $ProjectRoot '.azure'

$state = @{}
foreach ($entry in $parameters.GetEnumerator()) { $state[$entry.Key] = $entry.Value }
if (Test-Path -LiteralPath $StateFile -PathType Leaf) {
  Get-Content -LiteralPath $StateFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) {
      $state[$parts[0].Trim()] = $parts[1].Trim()
    }
  }
}

if ($ResourceGroup -eq 'rg-chef360-linux' -and $state.ContainsKey('RESOURCE_GROUP')) { $ResourceGroup = $state['RESOURCE_GROUP'] }
if ([string]::IsNullOrWhiteSpace($NamePrefix) -and $state.ContainsKey('NAME_PREFIX')) {
  $NamePrefix = $state['NAME_PREFIX']
}
if ([string]::IsNullOrWhiteSpace($NamePrefix)) {
  $NamePrefix = "$ObjectOwnerPrefix-sa-linux"
}
if (Test-Path -LiteralPath $ProjectAzureDir -PathType Container) {
  $env:AZURE_CONFIG_DIR = $ProjectAzureDir
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw 'Required command not found: az'
}

$defaultQuery = "[?starts_with(name, '$NamePrefix-')].{name:name,powerState:powerState,privateIps:privateIps,publicIps:publicIps,location:location,vmSize:hardwareProfile.vmSize,os:storageProfile.osDisk.osType,imageOffer:storageProfile.imageReference.offer,imageSku:storageProfile.imageReference.sku,osVersion:storageProfile.imageReference.exactVersion}"
$shortQuery = "[?starts_with(name, '$NamePrefix-')].{name:name,powerState:powerState,publicIp:publicIps,osVersion:storageProfile.imageReference.exactVersion}"
$query = if ($Short) { $shortQuery } else { $defaultQuery }

& az vm list --resource-group $ResourceGroup -d --query $query --output table
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to query Azure VM status'
}
