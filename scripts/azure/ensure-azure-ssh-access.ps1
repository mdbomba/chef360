param(
  [string]$ResourceGroup = 'rg-chef360-linux',
  [string]$ObjectOwnerPrefix = $(if ($env:OBJECT_OWNER_PREFIX) { $env:OBJECT_OWNER_PREFIX } else { 'chef360' }),
  [string]$NamePrefix = $(if ($env:NAME_PREFIX) { $env:NAME_PREFIX } else { '' }),
  [string]$SshSourceCidr = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir '../..')
$StateFile = if ($env:AZURE_TWO_LINUX_STATE_FILE) { $env:AZURE_TWO_LINUX_STATE_FILE } else { Join-Path $ProjectRoot 'config/azure-two-linux.env' }
$state = @{}
if (Test-Path -LiteralPath $StateFile -PathType Leaf) {
  Get-Content -LiteralPath $StateFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) { $state[$parts[0].Trim()] = $parts[1].Trim() }
  }
}

if ($ResourceGroup -eq 'rg-chef360-linux' -and $state.ContainsKey('RESOURCE_GROUP')) { $ResourceGroup = $state['RESOURCE_GROUP'] }
if ([string]::IsNullOrWhiteSpace($NamePrefix) -and $state.ContainsKey('NAME_PREFIX')) { $NamePrefix = $state['NAME_PREFIX'] }
if ([string]::IsNullOrWhiteSpace($NamePrefix)) { $NamePrefix = "$ObjectOwnerPrefix-sa-linux" }

if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw 'Required command not found: az' }

if ([string]::IsNullOrWhiteSpace($SshSourceCidr)) {
  $response = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -Method Get
  $publicIp = [string]$response.ip
  $parsedIp = $null
  if (-not [System.Net.IPAddress]::TryParse($publicIp, [ref]$parsedIp) -or $parsedIp.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
    throw "api.ipify.org did not return a valid public IPv4 address: '$publicIp'"
  }
  $SshSourceCidr = "$publicIp/32"
}
else {
  $parts = $SshSourceCidr -split '/', 2
  $parsedIp = $null
  $prefix = 0
  if ($parts.Count -ne 2 -or -not [System.Net.IPAddress]::TryParse($parts[0], [ref]$parsedIp) -or $parsedIp.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or -not [int]::TryParse($parts[1], [ref]$prefix) -or $prefix -lt 0 -or $prefix -gt 32) {
    throw "Invalid SSH source CIDR: '$SshSourceCidr'"
  }
}

$nsgName = "$NamePrefix-nsg"
$resourceGroupExists = (& az group exists --name $ResourceGroup --output tsv --only-show-errors 2>$null) -join ''
if ($LASTEXITCODE -ne 0) { throw "Unable to query resource group: $ResourceGroup" }
if ($resourceGroupExists.Trim() -ne 'true') {
  Write-Host "Resource group does not exist; skipping NSG update: $ResourceGroup"
  Write-Output $SshSourceCidr
  return
}

$nsgId = (& az network nsg show --resource-group $ResourceGroup --name $nsgName --query id --output tsv --only-show-errors 2>$null) -join ''
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($nsgId)) {
  Write-Host "NSG does not exist; skipping rule update: $ResourceGroup/$nsgName"
  Write-Output $SshSourceCidr
  return
}

$ruleJson = & az network nsg rule show --resource-group $ResourceGroup --nsg-name $nsgName --name allow-ssh --output json --only-show-errors 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($ruleJson -join ''))) {
  Write-Host "Creating NSG rule $nsgName/allow-ssh for $SshSourceCidr"
  & az network nsg rule create --resource-group $ResourceGroup --nsg-name $nsgName --name allow-ssh --priority 1000 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes $SshSourceCidr --destination-port-ranges 22 --only-show-errors --output none
}
else {
  $rule = ($ruleJson -join "`n") | ConvertFrom-Json
  $currentCidr = if ($rule.sourceAddressPrefix) { [string]$rule.sourceAddressPrefix } elseif ($rule.sourceAddressPrefixes) { [string]$rule.sourceAddressPrefixes[0] } else { '' }
  if ($currentCidr -ne $SshSourceCidr) {
    Write-Host "Updating NSG rule $nsgName/allow-ssh from '$currentCidr' to '$SshSourceCidr'"
    & az network nsg rule update --resource-group $ResourceGroup --nsg-name $nsgName --name allow-ssh --source-address-prefixes $SshSourceCidr --destination-port-ranges 22 --access Allow --protocol Tcp --direction Inbound --only-show-errors --output none
  }
  else {
    Write-Host "NSG SSH access is current: $SshSourceCidr"
  }
}

if ($LASTEXITCODE -ne 0) { throw 'Failed to ensure Azure NSG SSH access' }
Write-Output $SshSourceCidr
