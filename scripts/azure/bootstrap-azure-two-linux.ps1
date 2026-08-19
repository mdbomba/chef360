param(
  [string]$SshPrivateKey = $env:SSH_PRIVATE_KEY,
  [string]$ChefNodeUser = '',
  [string]$ChefPolicyName = '',
  [string]$ChefPolicyGroup = '',
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
$BashScript = Join-Path $ScriptDir 'bootstrap-azure-two-linux.sh'

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

if ([string]::IsNullOrWhiteSpace($ChefNodeUser)) { $ChefNodeUser = if ($state.ContainsKey('CHEF_NODE_USER')) { $state['CHEF_NODE_USER'] } else { 'chef' } }
if ([string]::IsNullOrWhiteSpace($ChefPolicyName)) { $ChefPolicyName = if ($state.ContainsKey('CHEF_POLICY_NAME')) { $state['CHEF_POLICY_NAME'] } else { 'stig_base' } }
if ([string]::IsNullOrWhiteSpace($ChefPolicyGroup)) { $ChefPolicyGroup = if ($state.ContainsKey('CHEF_POLICY_GROUP')) { $state['CHEF_POLICY_GROUP'] } else { 'dev' } }
if ([string]::IsNullOrWhiteSpace($Node1Target)) { $Node1Target = if ($state.ContainsKey('NODE1_TARGET')) { $state['NODE1_TARGET'] } else { 'node1' } }
if ([string]::IsNullOrWhiteSpace($Node2Target)) { $Node2Target = if ($state.ContainsKey('NODE2_TARGET')) { $state['NODE2_TARGET'] } else { 'node2' } }

if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
  throw 'Required command not found: bash'
}

if (-not (Test-Path -LiteralPath $BashScript -PathType Leaf)) {
  throw "Companion bash script not found: $BashScript"
}

& bash $BashScript $SshPrivateKey $ChefNodeUser $ChefPolicyName $ChefPolicyGroup $Node1Target $Node2Target
if ($LASTEXITCODE -ne 0) {
  throw "Bootstrap script failed (exit code $LASTEXITCODE)"
}
