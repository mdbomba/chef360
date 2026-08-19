param(
  [Parameter(Mandatory = $true)]
  [string]$Node1Ip,

  [Parameter(Mandatory = $true)]
  [string]$Node2Ip,

  [Parameter(Mandatory = $true)]
  [string]$HostsFilePath
)

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
  $argList = @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    ('"{0}"' -f $PSCommandPath),
    '-Node1Ip',
    ('"{0}"' -f $Node1Ip),
    '-Node2Ip',
    ('"{0}"' -f $Node2Ip),
    '-HostsFilePath',
    ('"{0}"' -f $HostsFilePath)
  )

  $process = Start-Process PowerShell -Verb RunAs -Wait -PassThru -ArgumentList ($argList -join ' ')
  exit $process.ExitCode
}

if (-not (Test-Path -LiteralPath $HostsFilePath)) {
  throw "Windows hosts file not found: $HostsFilePath"
}

$lines = Get-Content -LiteralPath $HostsFilePath
$filtered = New-Object System.Collections.Generic.List[string]

foreach ($line in $lines) {
  if ($line -match '^\s*#' -or $line -match '^\s*$') {
    $filtered.Add($line)
    continue
  }

  $tokens = ($line -split '\s+') | Where-Object { $_ -ne '' }
  if ($tokens.Count -ge 2) {
    $hostTokens = $tokens[1..($tokens.Count - 1)]
    if ($hostTokens -contains 'node1' -or $hostTokens -contains 'node2') {
      continue
    }
  }

  $filtered.Add($line)
}

$filtered.Add("$Node1Ip`tnode1")
$filtered.Add("$Node2Ip`tnode2")

Set-Content -LiteralPath $HostsFilePath -Value $filtered -Encoding ASCII
Write-Output "Updated Windows hosts file: $HostsFilePath"
