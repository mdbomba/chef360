param(
  [string]$ResourceGroup = 'rg-chef360-linux',
  [string]$ObjectOwnerPrefix = $(if ($env:OBJECT_OWNER_PREFIX) { $env:OBJECT_OWNER_PREFIX } else { 'chef360' }),
  [string]$NamePrefix = $(if ($env:NAME_PREFIX) { $env:NAME_PREFIX } else { '' }),
  [switch]$Force,
  [string]$Chef360Profile = $(if ($env:CHEF360_PROFILE) { $env:CHEF360_PROFILE } else { 'default' }),
  [string]$WindowsHostsFile = '/mnt/c/Windows/System32/drivers/etc/hosts',
  [string]$KnownHostsFile = $(Join-Path $HOME '.ssh/known_hosts')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir '../..')
. (Join-Path $ProjectRoot 'scripts/lib/Import-Chef360Parameters.ps1')
$parameters = Import-Chef360Parameters -ProjectRoot $ProjectRoot
$ProjectAzureDir = Join-Path $ProjectRoot '.azure'
$StateFile = if ($env:AZURE_TWO_LINUX_STATE_FILE) { $env:AZURE_TWO_LINUX_STATE_FILE } else { Join-Path $ProjectRoot 'config/azure-two-linux.env' }

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
if ([string]::IsNullOrWhiteSpace($NamePrefix) -and $state.ContainsKey('NAME_PREFIX')) { $NamePrefix = $state['NAME_PREFIX'] }
if ($Chef360Profile -eq 'default' -and $state.ContainsKey('CHEF360_PROFILE')) { $Chef360Profile = $state['CHEF360_PROFILE'] }

if ([string]::IsNullOrWhiteSpace($NamePrefix)) {
  $NamePrefix = "$ObjectOwnerPrefix-sa-linux"
}

$DefaultDeploymentName = "$ObjectOwnerPrefix-azure-two-linux-lowcost"

function Write-Step {
  param([string]$Message)
  Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$ErrorMessage = 'Command failed'
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$ErrorMessage (exit code $LASTEXITCODE): $FilePath $($Arguments -join ' ')"
  }
}

function Get-CheckedOutput {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$ErrorMessage = 'Command failed'
  )

  $output = & $FilePath @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "$ErrorMessage (exit code $LASTEXITCODE): $FilePath $($Arguments -join ' ')`n$($output -join "`n")"
  }
  return $output
}

function Invoke-BestEffort {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$What
  )

  & $FilePath @Arguments *> $null
  if ($LASTEXITCODE -eq 0) {
    if ($What) {
      Write-Step "$What completed"
    }
  }
  else {
    if ($What) {
      Write-Step "$What skipped/failed (continuing)"
    }
  }
}

function Get-AzureVmIps {
  param([string]$VmName)

  $json = & az vm show -d --resource-group $ResourceGroup --name $VmName --output json 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($json -join ''))) {
    return $null
  }
  $vm = ($json -join "`n") | ConvertFrom-Json
  return [pscustomobject]@{
    PublicIp = if ($vm.publicIps) { ($vm.publicIps -split ',')[0].Trim() } else { '' }
    PrivateIp = if ($vm.privateIps) { ($vm.privateIps -split ',')[0].Trim() } else { '' }
  }
}

function Remove-WindowsHostsEntries {
  if (-not (Test-Path -LiteralPath $WindowsHostsFile)) {
    Write-Step "Windows hosts file not found at '$WindowsHostsFile'; skipping hosts cleanup"
    return
  }

  $lines = Get-Content -LiteralPath $WindowsHostsFile
  $filtered = [System.Collections.Generic.List[string]]::new()
  foreach ($line in $lines) {
    if ($line -match '^\s*#' -or $line -match '^\s*$') {
      $filtered.Add($line)
      continue
    }
    $tokens = @($line -split '\s+' | Where-Object { $_ -ne '' })
    if ($tokens.Count -ge 2) {
      $hosts = $tokens[1..($tokens.Count - 1)]
      if ($hosts -contains 'node1' -or $hosts -contains 'node2') {
        continue
      }
    }
    $filtered.Add($line)
  }
  Set-Content -LiteralPath $WindowsHostsFile -Value $filtered -Encoding Ascii
  Write-Step 'Removed node1/node2 entries from Windows hosts file'
}

function Remove-KnownHostsEntries {
  if (-not (Test-Path -LiteralPath $KnownHostsFile)) {
    return
  }

  Invoke-BestEffort -FilePath 'ssh-keygen' -Arguments @('-f', $KnownHostsFile, '-R', 'node1') -What 'Removed node1 from known_hosts'
  Invoke-BestEffort -FilePath 'ssh-keygen' -Arguments @('-f', $KnownHostsFile, '-R', 'node2') -What 'Removed node2 from known_hosts'
}

function Remove-ChefInfraNodes {
  foreach ($node in 'node1', 'node2') {
    Invoke-BestEffort -FilePath 'knife' -Arguments @('node', 'delete', $node, '--yes') -What "Deleted Chef Infra node '$node'"
    Invoke-BestEffort -FilePath 'knife' -Arguments @('client', 'delete', $node, '--yes') -What "Deleted Chef Infra client '$node'"
  }
}

function Remove-Chef360Nodes {
  param(
    [string[]]$CandidateNames,
    [string[]]$CandidateIps
  )

  $nodesJsonRaw = & chef-node-management-cli management node find-all-nodes --pagination.size 1000 --profile $Chef360Profile --format json 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($nodesJsonRaw -join ''))) {
    Write-Step 'Unable to query Chef360 nodes (skipping Chef360 archive cleanup)'
    return
  }

  $nodes = ($nodesJsonRaw -join "`n") | ConvertFrom-Json
  $idsToArchive = [System.Collections.Generic.HashSet[string]]::new()

  foreach ($item in ($nodes.items | Where-Object { $_ })) {
    $id = [string]$item.id
    if ([string]::IsNullOrWhiteSpace($id)) {
      continue
    }

    $attributeMap = @{}
    foreach ($attr in ($item.attributes | Where-Object { $_ })) {
      $key = "{0}:{1}" -f $attr.namespace, $attr.name
      if (-not $attributeMap.ContainsKey($key)) {
        $attributeMap[$key] = [string]$attr.value
      }
    }

    $host = $attributeMap['enroll:hostname']
    $ip = $attributeMap['enroll:primary_ip']
    $fqdn = $attributeMap['enroll:fqdn']

    if (($CandidateNames -contains $host) -or ($CandidateNames -contains $fqdn) -or ($CandidateIps -contains $ip) -or ($CandidateIps -contains $fqdn)) {
      [void]$idsToArchive.Add($id)
    }
  }

  foreach ($nodeId in $idsToArchive) {
    Invoke-BestEffort -FilePath 'chef-node-management-cli' -Arguments @('management', 'node', 'archive-node', '--nodeId', $nodeId, '--profile', $Chef360Profile, '--format', 'json') -What "Archived Chef360 node '$nodeId'"
  }

  if ($idsToArchive.Count -eq 0) {
    Write-Step 'No matching Chef360 nodes found to archive'
  }
}

if (-not $Force) {
  Write-Host "This will remove node records/services and Azure resources for prefix '$NamePrefix' in '$ResourceGroup'."
  Write-Host 'It preserves resource group and template specs.'
  $confirm = Read-Host "Type '$NamePrefix' to confirm"
  if ($confirm -ne $NamePrefix) {
    throw 'Confirmation mismatch. Aborting.'
  }
}

if (Test-Path -LiteralPath $ProjectAzureDir -PathType Container) {
  $env:AZURE_CONFIG_DIR = $ProjectAzureDir
}

Require-Command 'az'
Require-Command 'knife'
Require-Command 'chef-node-management-cli'
Require-Command 'ssh-keygen'

$vm1 = "$NamePrefix-1"
$vm2 = "$NamePrefix-2"

$vm1Ips = Get-AzureVmIps -VmName $vm1
$vm2Ips = Get-AzureVmIps -VmName $vm2
$candidateIps = @()
if ($vm1Ips) {
  if ($vm1Ips.PublicIp) { $candidateIps += $vm1Ips.PublicIp }
  if ($vm1Ips.PrivateIp) { $candidateIps += $vm1Ips.PrivateIp }
}
if ($vm2Ips) {
  if ($vm2Ips.PublicIp) { $candidateIps += $vm2Ips.PublicIp }
  if ($vm2Ips.PrivateIp) { $candidateIps += $vm2Ips.PrivateIp }
}

Write-Step 'Step 1: Removing node records from Chef Infra and Chef360 services'
Remove-ChefInfraNodes
Remove-Chef360Nodes -CandidateNames @('node1', 'node2') -CandidateIps $candidateIps

Write-Step 'Step 2: Cleaning local host mappings'
Remove-WindowsHostsEntries
Remove-KnownHostsEntries

Write-Step 'Step 3: Removing Azure resources'
$vnetId = (& az network vnet show --resource-group $ResourceGroup --name "$NamePrefix-vnet" --query id --output tsv --only-show-errors 2>$null)
$subnetName = (& az network vnet subnet list --resource-group $ResourceGroup --vnet-name "$NamePrefix-vnet" --query '[0].name' --output tsv --only-show-errors 2>$null)
$subnetNsgId = if ($subnetName) { & az network vnet subnet show --resource-group $ResourceGroup --vnet-name "$NamePrefix-vnet" --name $subnetName --query networkSecurityGroup.id --output tsv --only-show-errors 2>$null } else { '' }

foreach ($vm in @($vm1, $vm2)) {
  Invoke-BestEffort -FilePath 'az' -Arguments @('vm', 'delete', '--resource-group', $ResourceGroup, '--name', $vm, '--yes', '--no-wait', '--only-show-errors', '--output', 'none') -What "Issued delete for VM '$vm'"
}

foreach ($vm in @($vm1, $vm2)) {
  Invoke-BestEffort -FilePath 'az' -Arguments @('vm', 'wait', '--resource-group', $ResourceGroup, '--name', $vm, '--deleted', '--only-show-errors') -What "Waited for deletion of VM '$vm'"
}

foreach ($nic in @("$NamePrefix-1-nic", "$NamePrefix-2-nic")) {
  Invoke-BestEffort -FilePath 'az' -Arguments @('network', 'nic', 'delete', '--resource-group', $ResourceGroup, '--name', $nic, '--only-show-errors', '--output', 'none') -What "Deleted NIC '$nic'"
}

foreach ($pip in @("$NamePrefix-1-pip", "$NamePrefix-2-pip")) {
  Invoke-BestEffort -FilePath 'az' -Arguments @('network', 'public-ip', 'delete', '--resource-group', $ResourceGroup, '--name', $pip, '--only-show-errors', '--output', 'none') -What "Deleted public IP '$pip'"
}

if ($vnetId -and $subnetName -and $subnetNsgId) {
  Invoke-BestEffort -FilePath 'az' -Arguments @('network', 'vnet', 'subnet', 'update', '--resource-group', $ResourceGroup, '--vnet-name', "$NamePrefix-vnet", '--name', $subnetName, '--remove', 'networkSecurityGroup', '--only-show-errors', '--output', 'none') -What 'Detached NSG from subnet'
}

Invoke-BestEffort -FilePath 'az' -Arguments @('network', 'vnet', 'delete', '--resource-group', $ResourceGroup, '--name', "$NamePrefix-vnet", '--only-show-errors', '--output', 'none') -What "Deleted VNet '$NamePrefix-vnet'"
Invoke-BestEffort -FilePath 'az' -Arguments @('network', 'nsg', 'delete', '--resource-group', $ResourceGroup, '--name', "$NamePrefix-nsg", '--only-show-errors', '--output', 'none') -What "Deleted NSG '$NamePrefix-nsg'"

foreach ($deploymentName in @($DefaultDeploymentName, 'azure-two-linux-lowcost', '1.0')) {
  Invoke-BestEffort -FilePath 'az' -Arguments @('deployment', 'group', 'delete', '--resource-group', $ResourceGroup, '--name', $deploymentName, '--only-show-errors', '--output', 'none') -What "Deleted deployment record '$deploymentName'"
}

Write-Step "Destroy workflow complete: Chef Infra/Chef360 cleanup, host cleanup, and Azure resource teardown finished"

if (Test-Path -LiteralPath $StateFile -PathType Leaf) {
  Remove-Item -LiteralPath $StateFile -Force
  Write-Step "Removed runtime parameters file: $StateFile"
}
