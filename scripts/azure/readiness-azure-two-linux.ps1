param(
  [string]$SshPrivateKey = $env:SSH_PRIVATE_KEY,
  [string]$ResourceGroup = 'rg-chef360-linux',
  [string]$ObjectOwnerPrefix = $(if ($env:OBJECT_OWNER_PREFIX) { $env:OBJECT_OWNER_PREFIX } else { 'chef360' }),
  [string]$NamePrefix = $(if ($env:NAME_PREFIX) { $env:NAME_PREFIX } else { '' }),
  [string]$ChefNodeUser = '',
  [string]$ExpectedPolicyName = '',
  [string]$ExpectedPolicyGroup = 'dev',
  [string]$Node1Target = '',
  [string]$Node2Target = ''
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
$BashScript = Join-Path $ScriptDir 'readiness-azure-two-linux.sh'

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
if ([string]::IsNullOrWhiteSpace($ChefNodeUser)) { $ChefNodeUser = if ($state.ContainsKey('CHEF_NODE_USER')) { $state['CHEF_NODE_USER'] } else { 'chef' } }
if ([string]::IsNullOrWhiteSpace($ExpectedPolicyName)) { $ExpectedPolicyName = if ($state.ContainsKey('CHEF_POLICY_NAME')) { $state['CHEF_POLICY_NAME'] } else { 'stig_base' } }
if ($ExpectedPolicyGroup -eq 'dev' -and $state.ContainsKey('CHEF_POLICY_GROUP')) { $ExpectedPolicyGroup = $state['CHEF_POLICY_GROUP'] }
if ([string]::IsNullOrWhiteSpace($Node1Target)) { $Node1Target = if ($state.ContainsKey('NODE1_TARGET')) { $state['NODE1_TARGET'] } else { 'node1' } }
if ([string]::IsNullOrWhiteSpace($Node2Target)) { $Node2Target = if ($state.ContainsKey('NODE2_TARGET')) { $state['NODE2_TARGET'] } else { 'node2' } }

if ([string]::IsNullOrWhiteSpace($NamePrefix)) {
  $NamePrefix = "$ObjectOwnerPrefix-sa-linux"
}

if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
  throw 'Required command not found: bash'
}

if (-not (Test-Path -LiteralPath $BashScript -PathType Leaf)) {
  throw "Companion bash script not found: $BashScript"
}

& bash $BashScript $SshPrivateKey $ResourceGroup $NamePrefix $ChefNodeUser $ExpectedPolicyName $ExpectedPolicyGroup $Node1Target $Node2Target
if ($LASTEXITCODE -ne 0) {
  throw "Readiness script failed (exit code $LASTEXITCODE)"
}
