function Import-Chef360Parameters {
  param([Parameter(Mandatory = $true)][string]$ProjectRoot)

  $path = if ($env:CHEF360_PARAMETERS_FILE) { $env:CHEF360_PARAMETERS_FILE } else { Join-Path $ProjectRoot 'config/chef360.parameters.env' }
  $values = @{}
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    Get-Content -LiteralPath $path | ForEach-Object {
      $line = $_.TrimEnd("`r")
      if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*#') { return }
      if ($line -notmatch '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { throw "Invalid parameter line in ${path}: $line" }
      $key = $Matches[1]
      $value = $Matches[2]
      if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      $environmentValue = [Environment]::GetEnvironmentVariable($key, 'Process')
      if ([string]::IsNullOrWhiteSpace($environmentValue)) {
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        $values[$key] = $value
      }
      else {
        $values[$key] = $environmentValue
      }
    }
  }

  $provider = if ($env:PROVIDER) { $env:PROVIDER } else { 'azure.com' }
  if ($provider -notin @('azure.com', 'azure.us', 'hyperv', 'kvm', 'aws.com', 'aws.gov')) {
    throw "Invalid PROVIDER '$provider'. Expected azure.com, azure.us, hyperv, kvm, aws.com, or aws.gov."
  }

  if ($env:CHEF360_ENDPOINT) {
    if ($env:CHEF360_ENDPOINT -notmatch '^https://[A-Za-z0-9.-]+(?::[0-9]{1,5})?$') {
      throw "Invalid CHEF360_ENDPOINT '$($env:CHEF360_ENDPOINT)'. Expected an HTTPS URL with an optional port."
    }
    $endpoint = [Uri]$env:CHEF360_ENDPOINT
    if ($endpoint.Port -lt 1 -or $endpoint.Port -gt 65535) { throw "Invalid CHEF360_ENDPOINT port: $($endpoint.Port)" }
    if (-not $env:CHEF360_SERVER) { $env:CHEF360_SERVER = $env:CHEF360_ENDPOINT }
  }

  return $values
}
