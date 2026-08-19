#!/usr/bin/env bash
set -euo pipefail

NODE1_IP="${1:-}"
NODE2_IP="${2:-}"
WINDOWS_HOSTS_FILE="${WINDOWS_HOSTS_FILE:-/mnt/c/Windows/System32/drivers/etc/hosts}"

if [[ -z "${NODE1_IP}" || -z "${NODE2_IP}" ]]; then
  printf "Usage: %s <node1-ip> <node2-ip>\n" "$(basename "$0")"
  exit 1
fi

if [[ ! -f "${WINDOWS_HOSTS_FILE}" ]]; then
  printf "Windows hosts file not found: %s\n" "${WINDOWS_HOSTS_FILE}"
  exit 1
fi

if ! command -v powershell.exe >/dev/null 2>&1; then
  printf "Required command not found: powershell.exe\n"
  exit 1
fi

if ! command -v wslpath >/dev/null 2>&1; then
  printf "Required command not found: wslpath\n"
  exit 1
fi

WINDOWS_HOSTS_FILE_WIN="$(wslpath -w "${WINDOWS_HOSTS_FILE}")"

HOSTS_RESULT="$(powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "\
  \$hostsPath = '${WINDOWS_HOSTS_FILE_WIN}'; \
  if (-not (Test-Path -LiteralPath \$hostsPath)) { Write-Output '|'; exit 0 }; \
  \$n1 = ''; \$n2 = ''; \
  foreach (\$line in Get-Content -LiteralPath \$hostsPath) { \
    if (\$line -match '^\\s*#' -or \$line -match '^\\s*$') { continue }; \
    \$tokens = (\$line -split '\\s+') | Where-Object { \$_ -ne '' }; \
    if (\$tokens.Count -lt 2) { continue }; \
    \$ip = \$tokens[0]; \
    \$hosts = \$tokens[1..(\$tokens.Count - 1)]; \
    if (\$hosts -contains 'node1') { \$n1 = \$ip }; \
    if (\$hosts -contains 'node2') { \$n2 = \$ip }; \
  }; \
  Write-Output (\"\$n1|\$n2\")" | tr -d '\r')"

NODE1_CURRENT="${HOSTS_RESULT%%|*}"
NODE2_CURRENT="${HOSTS_RESULT#*|}"

if [[ "${NODE1_CURRENT}" == "${NODE1_IP}" && "${NODE2_CURRENT}" == "${NODE2_IP}" ]]; then
  printf "Windows hosts entries are correct: node1=%s node2=%s\n" "${NODE1_CURRENT}" "${NODE2_CURRENT}"
  exit 0
fi

printf "Windows hosts entries mismatch: node1=%s (expected %s), node2=%s (expected %s)\n" \
  "${NODE1_CURRENT:-<missing>}" "${NODE1_IP}" "${NODE2_CURRENT:-<missing>}" "${NODE2_IP}"
exit 1
