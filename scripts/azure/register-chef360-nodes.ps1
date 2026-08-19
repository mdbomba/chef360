param(
  [string]$SshPrivateKey = $env:SSH_PRIVATE_KEY,
  [string]$ChefNodeUser = '',
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
$StateFile = if ($env:AZURE_TWO_LINUX_STATE_FILE) { $env:AZURE_TWO_LINUX_STATE_FILE } else { Join-Path $ProjectRoot 'config/azure-two-linux.env' }
$BashScript = Join-Path $ScriptDir 'register-chef360-nodes.sh'

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

if ([string]::IsNullOrWhiteSpace($ChefNodeUser)) { $ChefNodeUser = if ($state.ContainsKey('CHEF_NODE_USER')) { $state['CHEF_NODE_USER'] } else { 'chef' } }
if ([string]::IsNullOrWhiteSpace($Node1Target)) { $Node1Target = if ($state.ContainsKey('NODE1_TARGET')) { $state['NODE1_TARGET'] } else { 'node1' } }
if ([string]::IsNullOrWhiteSpace($Node2Target)) { $Node2Target = if ($state.ContainsKey('NODE2_TARGET')) { $state['NODE2_TARGET'] } else { 'node2' } }

if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
  throw 'Required command not found: bash'
}

if (-not (Test-Path -LiteralPath $BashScript -PathType Leaf)) {
  throw "Companion bash script not found: $BashScript"
}

& bash $BashScript $SshPrivateKey $ChefNodeUser $Node1Target $Node2Target
if ($LASTEXITCODE -ne 0) {
  throw "Registration script failed (exit code $LASTEXITCODE)"
}
