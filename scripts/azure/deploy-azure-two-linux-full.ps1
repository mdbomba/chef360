param(
  [string]$ResourceGroup = 'rg-chef360-linux',
  [string]$VmSize = 'Standard_D2s_v5',
  [string]$SshPrivateKey = $env:SSH_PRIVATE_KEY,
  [string]$ObjectOwnerPrefix = $(if ($env:OBJECT_OWNER_PREFIX) { $env:OBJECT_OWNER_PREFIX } else { 'chef360' }),
  [string]$NamePrefix = $(if ($env:NAME_PREFIX) { $env:NAME_PREFIX } else { '' }),
  [string]$DeploymentName = $(if ($env:DEPLOYMENT_NAME) { $env:DEPLOYMENT_NAME } else { '' }),
  [string]$TemplateSpecId = $(if ($env:TEMPLATE_SPEC_ID) { $env:TEMPLATE_SPEC_ID } else { '' }),
  [bool]$UseTemplateSpec = $false,
  [string]$ChefNodeUser = $(if ($env:CHEF_NODE_USER) { $env:CHEF_NODE_USER } else { 'chef' }),
  [string]$ChefPolicyName = $(if ($env:CHEF_POLICY_NAME) { $env:CHEF_POLICY_NAME } else { 'stig_base' }),
  [string]$ChefPolicyGroup = $(if ($env:CHEF_POLICY_GROUP) { $env:CHEF_POLICY_GROUP } else { 'dev' }),
  [bool]$EnableChef360Registration = $(if ($env:ENABLE_CHEF360_REGISTRATION) { $env:ENABLE_CHEF360_REGISTRATION -eq 'true' } else { $true }),
  [string]$SshSourceCidr = $(if ($env:SSH_SOURCE_CIDR) { $env:SSH_SOURCE_CIDR } else { '' }),
  [string]$Expiration = $(if ($env:EXPIRATION) { $env:EXPIRATION } else { '' }),
  [string]$Node1Target = 'node1',
  [string]$Node2Target = 'node2',
  [string]$WindowsHostsFile = '/mnt/c/Windows/System32/drivers/etc/hosts'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SshPrivateKey)) {
  $SshPrivateKey = Join-Path $HOME '.ssh/id_ed25519'
}

if ([string]::IsNullOrWhiteSpace($Expiration)) {
  $Expiration = [DateTime]::UtcNow.AddDays(2).ToString('yyyy-MM-dd')
}

$ScriptDir = Split-Path -Parent $PSCommandPath
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir '../..')
$ProjectAzureDir = Join-Path $ProjectRoot '.azure'
$StateFile = if ($env:AZURE_TWO_LINUX_STATE_FILE) { $env:AZURE_TWO_LINUX_STATE_FILE } else { Join-Path $ProjectRoot 'config/azure-two-linux.env' }
$ParamFile = Join-Path $ProjectRoot 'infra/azure/azure-two-linux-lowcost.parameters.json'
$TemplateFile = Join-Path $ProjectRoot 'infra/azure/azure-two-linux-lowcost.json'
$RegisterChef360Script = Join-Path $ScriptDir 'register-chef360-nodes.sh'
$CheckWindowsHostsScript = Join-Path $ScriptDir 'check-windows-hosts.sh'
$UpdateWindowsHostsScript = Join-Path $ScriptDir 'update-windows-hosts.sh'
$EnsureSshAccessScript = Join-Path $ScriptDir 'ensure-azure-ssh-access.ps1'

$state = @{}
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
if ($VmSize -eq 'Standard_D2s_v5' -and $state.ContainsKey('VM_SIZE')) { $VmSize = $state['VM_SIZE'] }
if ($ChefNodeUser -eq 'chef' -and $state.ContainsKey('CHEF_NODE_USER')) { $ChefNodeUser = $state['CHEF_NODE_USER'] }
if ($ChefPolicyName -eq 'stig_base' -and $state.ContainsKey('CHEF_POLICY_NAME')) { $ChefPolicyName = $state['CHEF_POLICY_NAME'] }
if ($ChefPolicyGroup -eq 'dev' -and $state.ContainsKey('CHEF_POLICY_GROUP')) { $ChefPolicyGroup = $state['CHEF_POLICY_GROUP'] }
if ([string]::IsNullOrWhiteSpace($NamePrefix) -and $state.ContainsKey('NAME_PREFIX')) { $NamePrefix = $state['NAME_PREFIX'] }
if ([string]::IsNullOrWhiteSpace($DeploymentName) -and $state.ContainsKey('DEPLOYMENT_NAME')) { $DeploymentName = $state['DEPLOYMENT_NAME'] }

if ([string]::IsNullOrWhiteSpace($NamePrefix)) {
  $NamePrefix = "$ObjectOwnerPrefix-sa-linux"
}

if ([string]::IsNullOrWhiteSpace($DeploymentName)) {
  $DeploymentName = "$ObjectOwnerPrefix-azure-two-linux-lowcost"
}

if ($UseTemplateSpec -and [string]::IsNullOrWhiteSpace($TemplateSpecId)) {
  throw 'TemplateSpecId or TEMPLATE_SPEC_ID is required when UseTemplateSpec is enabled'
}

function Write-Step {
  param([string]$Message)
  Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

function Save-RuntimeParameters {
  $lines = @(
    "RESOURCE_GROUP=$ResourceGroup",
    "VM_SIZE=$VmSize",
    "NAME_PREFIX=$NamePrefix",
    "DEPLOYMENT_NAME=$DeploymentName",
    "NODE1_VM=$NamePrefix-1",
    "NODE2_VM=$NamePrefix-2",
    "NODE1_IP=$($ips.Node1)",
    "NODE2_IP=$($ips.Node2)",
    "NODE1_TARGET=$($ips.Node1)",
    "NODE2_TARGET=$($ips.Node2)",
    "CHEF_NODE_USER=$ChefNodeUser",
    "CHEF_POLICY_NAME=$ChefPolicyName",
    "CHEF_POLICY_GROUP=$ChefPolicyGroup",
    "SSH_SOURCE_CIDR=$SshSourceCidr"
  )
  $dir = Split-Path -Parent $StateFile
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  Set-Content -LiteralPath $StateFile -Value $lines -Encoding Ascii
  Write-Step "Updated runtime parameters file: $StateFile"
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

function Sync-ResourceGroupTags {
  $parameters = (Get-Content -LiteralPath $ParamFile -Raw | ConvertFrom-Json).parameters
  $tags = [ordered]@{
    'X-Customer' = $parameters.xCustomer.value
    'X-Project' = $parameters.xProject.value
    'X-Application' = $parameters.xApplication.value
    'X-Dept' = $parameters.xDept.value
    'X-Name' = $parameters.xName.value
    'X-Contact' = $parameters.xContact.value
    'X-TTL' = $parameters.xTTL.value
    'Application' = $parameters.application.value
    'Team' = $parameters.team.value
    'owner' = $parameters.owner.value
    'Expiration' = $Expiration
    'ephemeral' = $parameters.ephemeral.value
  }
  $arguments = @(
    'group', 'update',
    '--name', $ResourceGroup,
    '--tags'
  )
  foreach ($tag in $tags.GetEnumerator()) {
    $arguments += "$($tag.Key)=$($tag.Value)"
  }
  $arguments += @('--only-show-errors', '--output', 'none')

  Invoke-Checked -FilePath 'az' -Arguments $arguments -ErrorMessage 'Unable to synchronize resource group tags'
  Write-Step "Synchronized deployment tags on resource group $ResourceGroup"
}

function Sync-DeployedResourceTags {
  $parameters = (Get-Content -LiteralPath $ParamFile -Raw | ConvertFrom-Json).parameters
  $tags = [ordered]@{
    'X-Customer' = $parameters.xCustomer.value
    'X-Project' = $parameters.xProject.value
    'X-Application' = $parameters.xApplication.value
    'X-Dept' = $parameters.xDept.value
    'X-Name' = $parameters.xName.value
    'X-Contact' = $parameters.xContact.value
    'X-TTL' = $parameters.xTTL.value
    'application' = $parameters.application.value
    'team' = $parameters.team.value
    'owner' = $parameters.owner.value
    'expiration' = $Expiration
    'ephemeral' = $parameters.ephemeral.value
  }
  $resourceIds = Get-CheckedOutput -FilePath 'az' -Arguments @(
    'resource', 'list',
    '--resource-group', $ResourceGroup,
    '--query', "[?tags.'X-Application' == '$($parameters.xApplication.value)'].id",
    '--output', 'tsv'
  ) -ErrorMessage 'Unable to list tagged deployment resources'

  foreach ($resourceId in $resourceIds) {
    if ([string]::IsNullOrWhiteSpace($resourceId)) { continue }
    $arguments = @('tag', 'create', '--resource-id', $resourceId, '--tags')
    foreach ($tag in $tags.GetEnumerator()) {
      $arguments += "$($tag.Key)=$($tag.Value)"
    }
    $arguments += @('--only-show-errors', '--output', 'none')
    Invoke-Checked -FilePath 'az' -Arguments $arguments -ErrorMessage "Unable to synchronize tags on $resourceId"
  }
  Write-Step "Synchronized deployment tags on existing resources in $ResourceGroup"
}

function Test-ChefNodeExists {
  param([string]$NodeName)
  & knife node show $NodeName *> $null
  return $LASTEXITCODE -eq 0
}

function Get-ChefNodePolicyValue {
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

function Resolve-NodeIps {
  $node1Vm = "$NamePrefix-1"
  $node2Vm = "$NamePrefix-2"

  $vm1 = (Get-CheckedOutput -FilePath 'az' -Arguments @('vm', 'show', '-d', '--resource-group', $ResourceGroup, '--name', $node1Vm, '--output', 'json') -ErrorMessage "Unable to read VM details for $node1Vm") -join "`n" | ConvertFrom-Json
  $vm2 = (Get-CheckedOutput -FilePath 'az' -Arguments @('vm', 'show', '-d', '--resource-group', $ResourceGroup, '--name', $node2Vm, '--output', 'json') -ErrorMessage "Unable to read VM details for $node2Vm") -join "`n" | ConvertFrom-Json

  $node1Ip = if ($vm1.publicIps) { ($vm1.publicIps -split ',')[0].Trim() } else { ($vm1.privateIps -split ',')[0].Trim() }
  $node2Ip = if ($vm2.publicIps) { ($vm2.publicIps -split ',')[0].Trim() } else { ($vm2.privateIps -split ',')[0].Trim() }

  if ([string]::IsNullOrWhiteSpace($node1Ip) -or [string]::IsNullOrWhiteSpace($node2Ip)) {
    throw "Unable to resolve node IPs. node1='$node1Ip', node2='$node2Ip'"
  }

  return @{
    Node1 = $node1Ip
    Node2 = $node2Ip
  }
}

function Resolve-SshSourceCidr {
  $arguments = @('-ResourceGroup', $ResourceGroup, '-NamePrefix', $NamePrefix)
  if (-not [string]::IsNullOrWhiteSpace($SshSourceCidr)) { $arguments += @('-SshSourceCidr', $SshSourceCidr) }
  $output = & $EnsureSshAccessScript @arguments
  $cidrLine = @($output | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$' } | Select-Object -Last 1)
  if ($cidrLine.Count -eq 0) { throw 'Unable to determine SSH source CIDR' }
  $script:SshSourceCidr = [string]$cidrLine[0]
  Write-Step "Restricting inbound SSH to $SshSourceCidr"
}

function Update-SshNsgRule {
  & $EnsureSshAccessScript -ResourceGroup $ResourceGroup -NamePrefix $NamePrefix -SshSourceCidr $SshSourceCidr | Out-Null
}

function Ensure-SudoNoPassword {
  Write-Step "Step 3: Ensuring passwordless sudo for user '$ChefNodeUser' on both nodes"
  foreach ($i in 1, 2) {
    $vmName = "$NamePrefix-$i"
    $scripts = @(
      'set -euo pipefail',
      "USER_NAME='$ChefNodeUser'",
      "SUDOERS_FILE='/etc/sudoers.d/chef'",
      'printf ''%s ALL=(ALL) NOPASSWD:ALL\n'' "${USER_NAME}" > "${SUDOERS_FILE}"',
      'chown root:root "${SUDOERS_FILE}"',
      'chmod 0440 "${SUDOERS_FILE}"',
      'visudo -cf "${SUDOERS_FILE}"'
    )

    $arguments = @(
      'vm', 'run-command', 'invoke',
      '--resource-group', $ResourceGroup,
      '--name', $vmName,
      '--command-id', 'RunShellScript',
      '--scripts'
    ) + $scripts + @('--only-show-errors', '--output', 'none')
    Invoke-Checked -FilePath 'az' -Arguments $arguments -ErrorMessage "Failed to set passwordless sudo on $vmName"
  }
}

function Test-SudoNoPassword {
  param([string]$Target)

  $sshArgs = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10', '-i', $SshPrivateKey)
  Invoke-Checked -FilePath 'ssh' -Arguments ($sshArgs + @("$ChefNodeUser@$Target", 'sudo -n true')) -ErrorMessage "Passwordless sudo check failed for $Target"
  $sudoList = Get-CheckedOutput -FilePath 'ssh' -Arguments ($sshArgs + @("$ChefNodeUser@$Target", 'sudo -n -l')) -ErrorMessage "Unable to list sudo permissions on $Target"
  $sudoText = ($sudoList -join "`n")
  if ($sudoText -notmatch 'NOPASSWD:\s*ALL') {
    throw "Sudo policy verification failed for $ChefNodeUser@$Target"
  }
}

function Wait-NodeReady {
  param([string]$Target)

  $sshArgs = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10', '-i', $SshPrivateKey)
  for ($attempt = 1; $attempt -le 30; $attempt++) {
    Write-Step "Waiting for cloud-init on $Target (attempt $attempt/30)"
    & ssh @sshArgs "$ChefNodeUser@$Target" 'cloud-init status --wait >/dev/null && test -f /var/lib/chef360-template-ready' *> $null
    if ($LASTEXITCODE -eq 0) {
      return
    }
    Start-Sleep -Seconds 10
  }

  throw "Node did not become ready: $Target"
}

function Test-NodePrerequisites {
  param([string]$Target)

  $publicKey = ((Get-CheckedOutput -FilePath 'ssh-keygen' -Arguments @('-y', '-f', $SshPrivateKey) -ErrorMessage 'Unable to derive SSH public key') -join '').Trim()
  $keyParts = $publicKey -split '\s+'
  if ($keyParts.Count -lt 2) {
    throw 'Unable to parse SSH public key'
  }
  $expectedKey = "$($keyParts[0]) $($keyParts[1])"
  $remoteCommand = 'set -euo pipefail; test "$(id -un)" = ''{0}''; command -v sshd >/dev/null; systemctl is-enabled ssh >/dev/null; systemctl is-active ssh >/dev/null; sudo test "$(stat -c ''%U:%G:%a'' /etc/sudoers.d/chef)" = ''root:root:440''; sudo test "$(cat /etc/sudoers.d/chef)" = ''{0} ALL=(ALL) NOPASSWD:ALL''; awk ''{{print $1 " " $2}}'' "$HOME/.ssh/authorized_keys" | grep -Fqx ''{1}''' -f $ChefNodeUser, $expectedKey
  $sshArgs = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10', '-i', $SshPrivateKey)
  Invoke-Checked -FilePath 'ssh' -Arguments ($sshArgs + @("$ChefNodeUser@$Target", $remoteCommand)) -ErrorMessage "Node prerequisite validation failed for $Target"
}

function Sync-WindowsHosts {
  param(
    [string]$Node1Ip,
    [string]$Node2Ip
  )

  if (-not (Test-Path -LiteralPath $WindowsHostsFile -PathType Leaf)) {
    throw "Windows hosts file not found at '$WindowsHostsFile'"
  }

  $env:WINDOWS_HOSTS_FILE = $WindowsHostsFile
  Write-Step 'Step 4: Ensuring Windows hosts entries for node1/node2'
  & bash $CheckWindowsHostsScript $Node1Ip $Node2Ip
  if ($LASTEXITCODE -ne 0) {
    Invoke-Checked -FilePath 'bash' -Arguments @($UpdateWindowsHostsScript, $Node1Ip, $Node2Ip) -ErrorMessage 'Failed to update Windows hosts entries'
  }
  Invoke-Checked -FilePath 'bash' -Arguments @($CheckWindowsHostsScript, $Node1Ip, $Node2Ip) -ErrorMessage 'Windows hosts entries did not validate'

  $node1Resolved = ((Get-CheckedOutput -FilePath 'getent' -Arguments @('hosts', 'node1') -ErrorMessage 'Unable to resolve node1') -join "`n" -split '\s+')[0]
  $node2Resolved = ((Get-CheckedOutput -FilePath 'getent' -Arguments @('hosts', 'node2') -ErrorMessage 'Unable to resolve node2') -join "`n" -split '\s+')[0]
  if ($node1Resolved -ne $Node1Ip -or $node2Resolved -ne $Node2Ip) {
    throw 'WSL hostname resolution does not match the Windows hosts file'
  }

  $sshArgs = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10', '-i', $SshPrivateKey)
  Invoke-Checked -FilePath 'ssh' -Arguments ($sshArgs + @("$ChefNodeUser@node1", 'true')) -ErrorMessage 'Alias SSH validation failed for node1'
  Invoke-Checked -FilePath 'ssh' -Arguments ($sshArgs + @("$ChefNodeUser@node2", 'true')) -ErrorMessage 'Alias SSH validation failed for node2'
  Write-Step 'Windows hosts entries and WSL aliases validated'
}

function Test-DsmPolicy {
  & chef show-policy $ChefPolicyName $ChefPolicyGroup --no-pager *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Chef policy group not found in DSM: $ChefPolicyName/$ChefPolicyGroup"
  }
}

function Test-DsmRegistration {
  foreach ($node in 'node1', 'node2') {
    Invoke-Checked -FilePath 'knife' -Arguments @('node', 'show', $node) -ErrorMessage "Chef Infra node '$node' is missing"
    Invoke-Checked -FilePath 'knife' -Arguments @('client', 'show', $node) -ErrorMessage "Chef Infra client '$node' is missing"
  }
}

if (-not (Test-Path -LiteralPath $SshPrivateKey -PathType Leaf)) {
  throw "SSH private key not found: $SshPrivateKey"
}

if (-not (Test-Path -LiteralPath $ParamFile -PathType Leaf)) {
  throw "Parameter file not found: $ParamFile"
}

if (-not (Test-Path -LiteralPath $TemplateFile -PathType Leaf)) {
  throw "Template file not found: $TemplateFile"
}

if (Test-Path -LiteralPath $ProjectAzureDir -PathType Container) {
  $env:AZURE_CONFIG_DIR = $ProjectAzureDir
}

Require-Command 'az'
Require-Command 'bash'
Require-Command 'chef'
Require-Command 'getent'
Require-Command 'knife'
Require-Command 'ssh'
Require-Command 'ssh-keygen'

foreach ($helper in @($CheckWindowsHostsScript, $UpdateWindowsHostsScript, $RegisterChef360Script, $EnsureSshAccessScript)) {
  if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
    throw "Required helper script not found: $helper"
  }
}

Write-Step 'Step 1: Checking current VM deployment state'
Resolve-SshSourceCidr
Sync-ResourceGroupTags
$vmCount = [int]((Get-CheckedOutput -FilePath 'az' -Arguments @('vm', 'list', '--resource-group', $ResourceGroup, '--query', "[?name=='$NamePrefix-1' || name=='$NamePrefix-2'] | length(@)", '--output', 'tsv') -ErrorMessage 'Failed to query VM count') -join '').Trim()
if ($vmCount -lt 2) {
  Write-Step "Step 2: Deploying missing nodes ($vmCount/2 found)"
  if ($UseTemplateSpec) {
    Invoke-Checked -FilePath 'az' -Arguments @(
      'deployment', 'group', 'create',
      '--name', $DeploymentName,
      '--resource-group', $ResourceGroup,
      '--template-spec', $TemplateSpecId,
      '--parameters', "@$ParamFile",
      '--parameters', "namePrefix=$NamePrefix",
      '--parameters', "vmSize=$VmSize",
      '--parameters', "sshSourceCidr=$SshSourceCidr",
      '--parameters', "expiration=$Expiration",
      '--only-show-errors',
      '--output', 'none'
    ) -ErrorMessage 'Azure deployment failed'
  }
  else {
    Invoke-Checked -FilePath 'az' -Arguments @(
      'deployment', 'group', 'create',
      '--name', $DeploymentName,
      '--resource-group', $ResourceGroup,
      '--template-file', $TemplateFile,
      '--parameters', "@$ParamFile",
      '--parameters', "namePrefix=$NamePrefix",
      '--parameters', "vmSize=$VmSize",
      '--parameters', "sshSourceCidr=$SshSourceCidr",
      '--parameters', "expiration=$Expiration",
      '--only-show-errors',
      '--output', 'none'
    ) -ErrorMessage 'Azure deployment failed'
  }
}
else {
  Write-Step 'Step 2: Both nodes already deployed; skipping deployment'
}

Sync-DeployedResourceTags
Update-SshNsgRule

$ips = Resolve-NodeIps
Write-Step "Resolved node addresses: node1=$($ips.Node1) node2=$($ips.Node2)"
Save-RuntimeParameters

Wait-NodeReady -Target $ips.Node1
Wait-NodeReady -Target $ips.Node2
Ensure-SudoNoPassword
Write-Step "Step 3b: Verifying passwordless sudo for user '$ChefNodeUser'"
Test-SudoNoPassword -Target $ips.Node1
Test-SudoNoPassword -Target $ips.Node2
Test-NodePrerequisites -Target $ips.Node1
Test-NodePrerequisites -Target $ips.Node2

Sync-WindowsHosts -Node1Ip $ips.Node1 -Node2Ip $ips.Node2
Test-DsmPolicy

Write-Step 'Step 5: Checking Chef Infra node registration'
$node1Exists = Test-ChefNodeExists -NodeName 'node1'
$node2Exists = Test-ChefNodeExists -NodeName 'node2'
if (-not ($node1Exists -and $node2Exists)) {
  Write-Step 'One or more nodes missing in Chef Infra; running selective knife bootstrap'
  $bootstrapTargets = @()
  if (-not $node1Exists) { $bootstrapTargets += @{ Alias = 'node1'; Target = $ips.Node1 } }
  if (-not $node2Exists) { $bootstrapTargets += @{ Alias = 'node2'; Target = $ips.Node2 } }
  foreach ($item in $bootstrapTargets) {
    Invoke-Checked -FilePath 'knife' -Arguments @(
      'bootstrap', $item.Target,
      '--yes',
      '--connection-user', $ChefNodeUser,
      '--node-name', $item.Alias,
      '--ssh-identity-file', $SshPrivateKey,
      '--ssh-verify-host-key', 'never',
      '--sudo',
      '--chef-license', 'accept-silent',
      '--policy-group', $ChefPolicyGroup,
      '--policy-name', $ChefPolicyName
    ) -ErrorMessage "Knife bootstrap failed for $($item.Alias)"
  }
}

Test-DsmRegistration
else {
  Write-Step 'Both nodes already exist in Chef Infra'
}

Write-Step 'Step 6: Validating Chef Infra policy assignment'
$expectedNameNormalized = Normalize-PolicyName $ChefPolicyName
foreach ($node in 'node1', 'node2') {
  $currentName = Get-ChefNodePolicyValue -NodeName $node -FieldName 'policy_name'
  $currentGroup = Get-ChefNodePolicyValue -NodeName $node -FieldName 'policy_group'
  $currentNormalized = Normalize-PolicyName $currentName

  if ([string]::IsNullOrWhiteSpace($currentName) -or [string]::IsNullOrWhiteSpace($currentGroup)) {
    throw "Unable to read policy values for $node"
  }

  if ($currentNormalized -ne $expectedNameNormalized -or $currentGroup -ne $ChefPolicyGroup) {
    Write-Step "Policy mismatch on $node; applying $ChefPolicyName/$ChefPolicyGroup"
    Invoke-Checked -FilePath 'knife' -Arguments @('node', 'policy', 'set', $node, $ChefPolicyGroup, $ChefPolicyName) -ErrorMessage "Failed to set policy for $node"
    $currentName = Get-ChefNodePolicyValue -NodeName $node -FieldName 'policy_name'
    $currentGroup = Get-ChefNodePolicyValue -NodeName $node -FieldName 'policy_group'
    $currentNormalized = Normalize-PolicyName $currentName
  }
  if ($currentNormalized -ne $expectedNameNormalized -or $currentGroup -ne $ChefPolicyGroup) {
    throw "Policy validation failed for $node. Found $currentName/$currentGroup expected $ChefPolicyName/$ChefPolicyGroup"
  }
}

Write-Step 'Step 7: Running sudo chef-client on each node'
$sshArgs = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10', '-i', $SshPrivateKey)
Invoke-Checked -FilePath 'ssh' -Arguments ($sshArgs + @("$ChefNodeUser@$($ips.Node1)", 'sudo -n chef-client')) -ErrorMessage 'chef-client failed on node1'
Invoke-Checked -FilePath 'ssh' -Arguments ($sshArgs + @("$ChefNodeUser@$($ips.Node2)", 'sudo -n chef-client')) -ErrorMessage 'chef-client failed on node2'

if ($EnableChef360Registration) {
  Write-Step 'Step 8: Registering nodes with Chef 360'
  if (-not (Test-Path -LiteralPath $RegisterChef360Script -PathType Leaf)) {
    throw "Chef 360 registration helper not found: $RegisterChef360Script"
  }
  Invoke-Checked -FilePath 'bash' -Arguments @($RegisterChef360Script, $SshPrivateKey, $ChefNodeUser, 'node1', 'node2') -ErrorMessage 'Chef 360 registration script failed'
}
else {
  Write-Step 'Step 8: Chef 360 registration disabled'
}

Write-Step 'Deploy workflow complete: Azure, hosts, sudo, Chef DSM bootstrap, and Chef 360 enrollment steps executed'
