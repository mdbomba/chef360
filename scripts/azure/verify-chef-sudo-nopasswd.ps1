param(
  [string]$SshPrivateKey = $env:SSH_PRIVATE_KEY,
  [string]$ChefNodeUser = '',
  [string]$Node1Target = '',
  [string]$Node2Target = '',
  [string]$KnownHostsFile = $(Join-Path $HOME '.ssh/known_hosts')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SshPrivateKey)) {
  $SshPrivateKey = Join-Path $HOME '.ssh/id_ed25519'
}

$ScriptDir = Split-Path -Parent $PSCommandPath
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir '../..')
$StateFile = if ($env:AZURE_TWO_LINUX_STATE_FILE) { $env:AZURE_TWO_LINUX_STATE_FILE } else { Join-Path $ProjectRoot 'config/azure-two-linux.env' }
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

if ([string]::IsNullOrWhiteSpace($ChefNodeUser)) { $ChefNodeUser = if ($state.ContainsKey('CHEF_NODE_USER')) { $state['CHEF_NODE_USER'] } else { 'chef' } }
if ([string]::IsNullOrWhiteSpace($Node1Target)) { $Node1Target = if ($state.ContainsKey('NODE1_TARGET')) { $state['NODE1_TARGET'] } else { 'node1' } }
if ([string]::IsNullOrWhiteSpace($Node2Target)) { $Node2Target = if ($state.ContainsKey('NODE2_TARGET')) { $state['NODE2_TARGET'] } else { 'node2' } }

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

function Invoke-SshChecked {
  param([string]$Target, [string]$Command, [string]$ErrorMessage)
  $args = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10', '-i', $SshPrivateKey, "$ChefNodeUser@$Target", $Command)
  $output = & ssh @args 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "$ErrorMessage`n$($output -join "`n")"
  }
  return $output
}

if (-not (Test-Path -LiteralPath $SshPrivateKey -PathType Leaf)) {
  throw "SSH private key not found: $SshPrivateKey"
}

Require-Command 'ssh'
Require-Command 'ssh-keygen'
Require-Command 'ssh-keyscan'
Require-Command 'ssh-keygen'

& $EnsureSshAccessScript | Out-Null

$publicKey = ((& ssh-keygen -y -f $SshPrivateKey 2>&1) -join '').Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Unable to derive public key from $SshPrivateKey"
}
$keyParts = $publicKey -split '\s+'
$expectedKey = "$($keyParts[0]) $($keyParts[1])"

foreach ($node in @($Node1Target, $Node2Target)) {
  Seed-HostKeyIfMissing -HostName $node
  Write-Step "Verifying passwordless sudo for $ChefNodeUser@$node"
  Invoke-SshChecked -Target $node -Command 'sudo -n true' -ErrorMessage "Passwordless sudo command failed for $ChefNodeUser@$node" | Out-Null
  $sudoOutput = (Invoke-SshChecked -Target $node -Command 'sudo -n -l' -ErrorMessage "Unable to list sudo permissions for $ChefNodeUser@$node") -join "`n"
  if ($sudoOutput -notmatch 'NOPASSWD:\s*ALL') {
    throw "Passwordless sudo policy verification failed for $ChefNodeUser@$node"
  }
  $command = 'set -euo pipefail; test "$(id -un)" = ''{0}''; command -v sshd >/dev/null; systemctl is-enabled ssh >/dev/null; systemctl is-active ssh >/dev/null; sudo test "$(stat -c ''%U:%G:%a'' /etc/sudoers.d/chef)" = ''root:root:440''; sudo test "$(cat /etc/sudoers.d/chef)" = ''{0} ALL=(ALL) NOPASSWD:ALL''; awk ''{{print $1 " " $2}}'' "$HOME/.ssh/authorized_keys" | grep -Fqx ''{1}''' -f $ChefNodeUser, $expectedKey
  Invoke-SshChecked -Target $node -Command $command -ErrorMessage "Node prerequisite validation failed for $ChefNodeUser@$node" | Out-Null
  Write-Step "Verified passwordless sudo for $ChefNodeUser@$node"
}

Write-Step 'Passwordless sudo verification completed for both nodes'
