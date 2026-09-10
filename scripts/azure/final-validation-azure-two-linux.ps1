param(
  [string]$SshPrivateKey = $env:SSH_PRIVATE_KEY,
  [string]$ResourceGroup = 'rg-chef360-linux',
  [string]$ObjectOwnerPrefix = $(if ($env:OBJECT_OWNER_PREFIX) { $env:OBJECT_OWNER_PREFIX } else { 'chef360' }),
  [string]$NamePrefix = $(if ($env:NAME_PREFIX) { $env:NAME_PREFIX } else { '' }),
  [string]$ChefNodeUser = $(if ($env:CHEF_NODE_USER) { $env:CHEF_NODE_USER } else { 'chef' }),
  [string]$ExpectedPolicyName = $(if ($env:CHEF_POLICY_NAME) { $env:CHEF_POLICY_NAME } else { 'stig_base' }),
  [string]$ExpectedPolicyGroup = $(if ($env:CHEF_POLICY_GROUP) { $env:CHEF_POLICY_GROUP } else { 'dev' }),
  [string]$Node1Target = 'node1',
  [string]$Node2Target = 'node2',
  [string]$ExpectedCohortName = $(if ($env:CHEF360_COHORT_NAME) { $env:CHEF360_COHORT_NAME } else { 'all-nodes' }),
  [string]$Chef360Profile = $(if ($env:CHEF360_PROFILE) { $env:CHEF360_PROFILE } else { 'default' }),
  [string]$ExpectedCohortId = $(if ($env:CHEF360_COHORT_ID) { $env:CHEF360_COHORT_ID } else { '' }),
  [string]$KnownHostsFile = $(Join-Path $HOME '.ssh/known_hosts')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SshPrivateKey)) {
  $SshPrivateKey = Join-Path $HOME '.ssh/id_ed25519'
}

$ScriptDir = Split-Path -Parent $PSCommandPath
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir '../..')
. (Join-Path $ProjectRoot 'scripts/lib/Import-Chef360Parameters.ps1')
$parameters = Import-Chef360Parameters -ProjectRoot $ProjectRoot
$StateFile = if ($env:AZURE_TWO_LINUX_STATE_FILE) { $env:AZURE_TWO_LINUX_STATE_FILE } else { Join-Path $ProjectRoot 'config/azure-two-linux.env' }
$EnsureSshAccessScript = Join-Path $ScriptDir 'ensure-azure-ssh-access.ps1'

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
if ([string]::IsNullOrWhiteSpace($ChefNodeUser) -and $state.ContainsKey('CHEF_NODE_USER')) { $ChefNodeUser = $state['CHEF_NODE_USER'] }
if ($ExpectedPolicyName -eq 'stig_base' -and $state.ContainsKey('CHEF_POLICY_NAME')) { $ExpectedPolicyName = $state['CHEF_POLICY_NAME'] }
if ($ExpectedPolicyGroup -eq 'dev' -and $state.ContainsKey('CHEF_POLICY_GROUP')) { $ExpectedPolicyGroup = $state['CHEF_POLICY_GROUP'] }
if ($Node1Target -eq 'node1' -and $state.ContainsKey('NODE1_TARGET')) { $Node1Target = $state['NODE1_TARGET'] }
if ($Node2Target -eq 'node2' -and $state.ContainsKey('NODE2_TARGET')) { $Node2Target = $state['NODE2_TARGET'] }
if ($ExpectedCohortName -eq 'all-nodes' -and $state.ContainsKey('CHEF360_COHORT_NAME')) { $ExpectedCohortName = $state['CHEF360_COHORT_NAME'] }
if ($Chef360Profile -eq 'default' -and $state.ContainsKey('CHEF360_PROFILE')) { $Chef360Profile = $state['CHEF360_PROFILE'] }
if ([string]::IsNullOrWhiteSpace($ExpectedCohortId) -and $state.ContainsKey('CHEF360_COHORT_ID')) { $ExpectedCohortId = $state['CHEF360_COHORT_ID'] }

if ([string]::IsNullOrWhiteSpace($NamePrefix)) {
  $NamePrefix = "$ObjectOwnerPrefix-sa-linux"
}

$script:Failures = 0

function Write-Step {
  param([string]$Message)
  Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

function Write-Pass {
  param([string]$Message)
  Write-Host "[PASS] $Message"
}

function Write-Fail {
  param([string]$Message)
  Write-Host "[FAIL] $Message"
  $script:Failures += 1
}

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Normalize-PolicyName {
  param([string]$Value)
  return $Value -replace '_', '-'
}

function Invoke-Checked {
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

function Seed-HostKeyIfMissing {
  param([string]$HostName)

  $dir = Split-Path -Parent $KnownHostsFile
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  if (-not (Test-Path -LiteralPath $KnownHostsFile)) {
    New-Item -ItemType File -Path $KnownHostsFile -Force | Out-Null
  }

  & ssh-keygen -F $HostName -f $KnownHostsFile *> $null
  if ($LASTEXITCODE -eq 0) {
    return
  }

  & ssh-keyscan -H -T 5 $HostName 2>$null | Add-Content -LiteralPath $KnownHostsFile -Encoding Ascii
}

function Test-NetworkPort {
  param(
    [Parameter(Mandatory = $true)][string]$ComputerName,
    [Parameter(Mandatory = $true)][int]$Port,
    [int]$TimeoutMs = 5000
  )

  $testNetConnectionCmd = Get-Command -Name 'Test-NetConnection' -ErrorAction SilentlyContinue
  if ($testNetConnectionCmd) {
    try {
      $result = Test-NetConnection -ComputerName $ComputerName -Port $Port -WarningAction SilentlyContinue
      return [bool]$result.TcpTestSucceeded
    }
    catch {
      return $false
    }
  }

  try {
    $client = [System.Net.Sockets.TcpClient]::new()
    $async = $client.BeginConnect($ComputerName, $Port, $null, $null)
    $wait = $async.AsyncWaitHandle.WaitOne($TimeoutMs)
    if (-not $wait) {
      $client.Close()
      return $false
    }
    $client.EndConnect($async)
    $client.Close()
    return $true
  }
  catch {
    return $false
  }
}

function Get-ChefPolicyValue {
  param(
    [string]$NodeName,
    [string]$FieldName
  )

  $lines = & knife node show $NodeName -a $FieldName 2>$null
  foreach ($line in $lines) {
    if ($line -match "^\s*$([regex]::Escape($FieldName)):\s*(.+?)\s*$") {
      return $Matches[1]
    }
  }
  return ''
}

function Find-Chef360Node {
  param(
    [object]$Nodes,
    [string]$NodeTarget,
    [string]$PublicIp,
    [string]$PrivateIp
  )

  foreach ($item in ($Nodes.items | Where-Object { $_ })) {
    $map = @{}
    foreach ($attr in ($item.attributes | Where-Object { $_ })) {
      $key = "{0}:{1}" -f $attr.namespace, $attr.name
      if (-not $map.ContainsKey($key)) {
        $map[$key] = [string]$attr.value
      }
    }

    $nodeHost = $map['enroll:hostname']
    $nodeIp = $map['enroll:primary_ip']
    $nodeFqdn = $map['enroll:fqdn']

    $matched = $false
    if ($nodeHost -and $nodeHost -eq $NodeTarget) { $matched = $true }
    if (-not $matched -and $nodeIp -and $nodeIp -eq $NodeTarget) { $matched = $true }
    if (-not $matched -and $nodeFqdn -and $nodeFqdn -eq $NodeTarget) { $matched = $true }
    if (-not $matched -and $PublicIp -and (($nodeIp -eq $PublicIp) -or ($nodeFqdn -eq $PublicIp))) { $matched = $true }
    if (-not $matched -and $PrivateIp -and (($nodeIp -eq $PrivateIp) -or ($nodeFqdn -eq $PrivateIp))) { $matched = $true }

    if ($matched) {
      return [pscustomobject]@{
        Id = [string]$item.id
        CohortId = [string]$item.cohortId
        EnrollmentLevel = [string]$item.enrollmentLevel
        Host = $nodeHost
        Ip = $nodeIp
        Fqdn = $nodeFqdn
        Source = [string]$item.source
      }
    }
  }
  return $null
}

if (-not (Test-Path -LiteralPath $SshPrivateKey -PathType Leaf)) {
  throw "SSH private key not found: $SshPrivateKey"
}

Require-Command 'az'
Require-Command 'knife'
Require-Command 'ssh'
Require-Command 'ssh-keyscan'
Require-Command 'ssh-keygen'
Require-Command 'chef-node-management-cli'
Require-Command 'jq'

& $EnsureSshAccessScript -ResourceGroup $ResourceGroup -NamePrefix $NamePrefix | Out-Null

Write-Step 'Final PowerShell validation started'

$cohortsJson = (Invoke-Checked -FilePath 'chef-node-management-cli' -Arguments @('management', 'cohort', 'find-all-cohorts', '--pagination.size', '1000', '--profile', $Chef360Profile, '--format', 'json') -ErrorMessage 'Unable to query Chef360 cohorts') -join "`n" | ConvertFrom-Json
$nodesJson = (Invoke-Checked -FilePath 'chef-node-management-cli' -Arguments @('management', 'node', 'find-all-nodes', '--pagination.size', '1000', '--profile', $Chef360Profile, '--format', 'json') -ErrorMessage 'Unable to query Chef360 nodes') -join "`n" | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($ExpectedCohortId)) {
  $cohort = $cohortsJson.items | Where-Object { $_.name -eq $ExpectedCohortName } | Select-Object -First 1
  if ($cohort) {
    $cohortIdProp = $cohort.PSObject.Properties['cohortId']
    $idProp = $cohort.PSObject.Properties['id']
    if ($cohortIdProp -and -not [string]::IsNullOrWhiteSpace([string]$cohortIdProp.Value)) {
      $ExpectedCohortId = [string]$cohortIdProp.Value
    }
    elseif ($idProp -and -not [string]::IsNullOrWhiteSpace([string]$idProp.Value)) {
      $ExpectedCohortId = [string]$idProp.Value
    }
  }
}

if ([string]::IsNullOrWhiteSpace($ExpectedCohortId)) {
  Write-Fail "Chef360 cohort '$ExpectedCohortName' was not found"
}
else {
  Write-Pass "Chef360 cohort '$ExpectedCohortName' resolved as '$ExpectedCohortId'"
}

$nodeAliases = @('node1', 'node2')
$nodeTargets = @($Node1Target, $Node2Target)
$expectedPolicyNameNormalized = Normalize-PolicyName $ExpectedPolicyName

for ($i = 0; $i -lt 2; $i++) {
  $nodeAlias = $nodeAliases[$i]
  $nodeTarget = $nodeTargets[$i]
  $vmName = "$NamePrefix-$($i + 1)"

  Write-Host ""
  Write-Host "=== $nodeAlias ($nodeTarget) ==="

  try {
    $vm = (Invoke-Checked -FilePath 'az' -Arguments @('vm', 'show', '-d', '--resource-group', $ResourceGroup, '--name', $vmName, '--output', 'json') -ErrorMessage "Unable to query VM $vmName") -join "`n" | ConvertFrom-Json
    $vmPowerState = [string]$vm.powerState
    $vmPublicIp = if ($vm.publicIps) { ([string]$vm.publicIps -split ',')[0].Trim() } else { '' }
    $vmPrivateIp = if ($vm.privateIps) { ([string]$vm.privateIps -split ',')[0].Trim() } else { '' }
  }
  catch {
    Write-Fail "Unable to query Azure VM '$vmName': $($_.Exception.Message)"
    continue
  }

  if ($vmPowerState -eq 'VM running') {
    Write-Pass "Azure VM '$vmName' is running (public: $(if ($vmPublicIp) { $vmPublicIp } else { 'n/a' }), private: $(if ($vmPrivateIp) { $vmPrivateIp } else { 'n/a' }))"
  }
  else {
    Write-Fail "Azure VM '$vmName' is not running (state: $(if ($vmPowerState) { $vmPowerState } else { 'unknown' }))"
  }

  & knife node show $nodeAlias *> $null
  if ($LASTEXITCODE -eq 0) {
    Write-Pass "Chef Infra node '$nodeAlias' exists"
  }
  else {
    Write-Fail "Chef Infra node '$nodeAlias' is missing"
  }

  $policyName = Get-ChefPolicyValue -NodeName $nodeAlias -FieldName 'policy_name'
  $policyGroup = Get-ChefPolicyValue -NodeName $nodeAlias -FieldName 'policy_group'
  $policyNameNormalized = Normalize-PolicyName $policyName
  if ($policyName -and $policyGroup -and $policyNameNormalized -eq $expectedPolicyNameNormalized -and $policyGroup -eq $ExpectedPolicyGroup) {
    Write-Pass "Policy assignment is $policyName/$policyGroup"
  }
  else {
    Write-Fail "Policy assignment mismatch (found '$policyName/$policyGroup', expected '$ExpectedPolicyName/$ExpectedPolicyGroup')"
  }

  Seed-HostKeyIfMissing -HostName $nodeTarget
  $sshBase = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10', '-i', $SshPrivateKey)

  if (Test-NetworkPort -ComputerName $nodeTarget -Port 22) {
    Write-Pass "Network port check passed (Test-NetConnection style): ${nodeTarget}:22 reachable"
  }
  else {
    Write-Fail "Network port check failed (Test-NetConnection style): ${nodeTarget}:22 unreachable"
  }

  & ssh @sshBase "$ChefNodeUser@$nodeTarget" 'true' *> $null
  if ($LASTEXITCODE -eq 0) {
    Write-Pass "SSH connectivity works for $ChefNodeUser@$nodeTarget"
  }
  else {
    Write-Fail "SSH connectivity failed for $ChefNodeUser@$nodeTarget"
    continue
  }

  & ssh @sshBase "$ChefNodeUser@$nodeTarget" 'sudo -n true' *> $null
  if ($LASTEXITCODE -eq 0) {
    Write-Pass "Passwordless sudo works for $ChefNodeUser@$nodeTarget"
  }
  else {
    Write-Fail "Passwordless sudo failed for $ChefNodeUser@$nodeTarget"
  }

  $timerEnabled = (& ssh @sshBase "$ChefNodeUser@$nodeTarget" 'sudo systemctl is-enabled chef-client.timer' 2>$null | Out-String).Trim()
  $timerActive = (& ssh @sshBase "$ChefNodeUser@$nodeTarget" 'sudo systemctl is-active chef-client.timer' 2>$null | Out-String).Trim()
  $chefVersion = (& ssh @sshBase "$ChefNodeUser@$nodeTarget" 'chef-client --version' 2>$null | Out-String).Trim()

  if ($timerEnabled -eq 'enabled') {
    Write-Pass 'chef-client.timer is enabled'
  }
  else {
    Write-Fail "chef-client.timer is not enabled (value: $(if ($timerEnabled) { $timerEnabled } else { 'unknown' }))"
  }

  if ($timerActive -eq 'active') {
    Write-Pass 'chef-client.timer is active'
  }
  else {
    Write-Fail "chef-client.timer is not active (value: $(if ($timerActive) { $timerActive } else { 'unknown' }))"
  }

  if ($chefVersion) {
    Write-Pass $chefVersion
  }
  else {
    Write-Fail 'Unable to read chef-client version'
  }

  $chef360Node = Find-Chef360Node -Nodes $nodesJson -NodeTarget $nodeTarget -PublicIp $vmPublicIp -PrivateIp $vmPrivateIp
  if (-not $chef360Node) {
    Write-Fail "Chef360 node record not found for $nodeAlias"
    continue
  }

  Write-Pass "Chef360 node found (id: $($chef360Node.Id), host: $(if ($chef360Node.Host) { $chef360Node.Host } else { 'n/a' }), ip: $(if ($chef360Node.Ip) { $chef360Node.Ip } else { 'n/a' }), fqdn: $(if ($chef360Node.Fqdn) { $chef360Node.Fqdn } else { 'n/a' }), source: $(if ($chef360Node.Source) { $chef360Node.Source } else { 'n/a' }))"

  if ($ExpectedCohortId -and ($chef360Node.CohortId -eq $ExpectedCohortId)) {
    Write-Pass "Chef360 cohort assignment matches '$ExpectedCohortName'"
  }
  else {
    Write-Fail "Chef360 cohort mismatch (found '$($chef360Node.CohortId)', expected '$ExpectedCohortId')"
  }

  if ($chef360Node.EnrollmentLevel -eq 'enrolled') {
    Write-Pass "Chef360 enrollment level is '$($chef360Node.EnrollmentLevel)'"
  }
  else {
    Write-Fail "Chef360 enrollment level is '$($chef360Node.EnrollmentLevel)'"
  }

  try {
    $statusJson = (Invoke-Checked -FilePath 'chef-node-management-cli' -Arguments @('status', 'get-status', '--nodeId', $chef360Node.Id, '--profile', $Chef360Profile, '--format', 'json') -ErrorMessage "Unable to read Chef360 status for $($chef360Node.Id)") -join "`n" | ConvertFrom-Json
    $state = [string]$statusJson.item.state
    if ($state) {
      Write-Pass "Chef360 node state is '$state'"
    }
    else {
      Write-Fail "Chef360 node state unavailable for node id '$($chef360Node.Id)'"
    }

    $failedSteps = @($statusJson.item.stateWorkflow | Where-Object { $_.status -and $_.status.ToString().ToLowerInvariant() -eq 'failed' })
    if ($failedSteps.Count -gt 0) {
      $first = $failedSteps[0]
      Write-Fail "Chef360 state workflow failure detected: $($first.state): $($first.log)"
    }
    else {
      Write-Pass 'Chef360 state workflow has no failed steps'
    }
  }
  catch {
    Write-Fail "Unable to evaluate Chef360 node status for '$($chef360Node.Id)': $($_.Exception.Message)"
  }
}

Write-Host ''
if ($script:Failures -eq 0) {
  Write-Step 'Final validation passed: all checks succeeded'
  exit 0
}

Write-Step "Final validation failed: $script:Failures check(s) failed"
exit 1
