param(
  [Parameter(Mandatory = $true)][string]$Node1Ip,
  [Parameter(Mandatory = $true)][string]$Node2Ip,
  [string]$WindowsHostsFile = '/mnt/c/Windows/System32/drivers/etc/hosts'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $WindowsHostsFile -PathType Leaf)) {
  throw "Windows hosts file not found: $WindowsHostsFile"
}

$node1Current = ''
$node2Current = ''

foreach ($line in (Get-Content -LiteralPath $WindowsHostsFile)) {
  if ($line -match '^\s*#' -or $line -match '^\s*$') {
    continue
  }

  $tokens = @($line -split '\s+' | Where-Object { $_ -ne '' })
  if ($tokens.Count -lt 2) {
    continue
  }

  $ip = $tokens[0]
  $hosts = $tokens[1..($tokens.Count - 1)]
  if ($hosts -contains 'node1') {
    $node1Current = $ip
  }
  if ($hosts -contains 'node2') {
    $node2Current = $ip
  }
}

if ($node1Current -eq $Node1Ip -and $node2Current -eq $Node2Ip) {
  Write-Host "Windows hosts entries are correct: node1=$node1Current node2=$node2Current"
  exit 0
}

Write-Host "Windows hosts entries mismatch: node1=$(if ($node1Current) { $node1Current } else { '<missing>' }) (expected $Node1Ip), node2=$(if ($node2Current) { $node2Current } else { '<missing>' }) (expected $Node2Ip)"
exit 1
