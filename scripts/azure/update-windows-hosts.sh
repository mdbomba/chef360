#!/usr/bin/env bash
set -euo pipefail

NODE1_IP="${1:-}"
NODE2_IP="${2:-}"
WINDOWS_HOSTS_FILE="${WINDOWS_HOSTS_FILE:-/mnt/c/Windows/System32/drivers/etc/hosts}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWERSHELL_SCRIPT="${SCRIPT_DIR}/update-windows-hosts.ps1"

if [[ -z "${NODE1_IP}" || -z "${NODE2_IP}" ]]; then
  printf "Usage: %s <node1-ip> <node2-ip>\n" "$(basename "$0")"
  exit 1
fi

is_ipv4() {
  local value="$1"
  local -a octets
  local octet
  IFS=. read -r -a octets <<<"${value}"
  [[ "${#octets[@]}" -eq 4 ]] || return 1
  for octet in "${octets[@]}"; do
    [[ "${octet}" =~ ^[0-9]{1,3}$ ]] && ((10#${octet} <= 255)) || return 1
  done
}

if ! is_ipv4 "${NODE1_IP}" || ! is_ipv4 "${NODE2_IP}"; then
  printf 'Node addresses must be IPv4 addresses.\n' >&2
  exit 1
fi

if [[ ! -f "${POWERSHELL_SCRIPT}" ]]; then
  printf "PowerShell hosts update script not found: %s\n" "${POWERSHELL_SCRIPT}"
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

POWERSHELL_SCRIPT_WIN="$(wslpath -w "${POWERSHELL_SCRIPT}")"
WINDOWS_HOSTS_FILE_WIN="$(wslpath -w "${WINDOWS_HOSTS_FILE}")"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${POWERSHELL_SCRIPT_WIN}" -Node1Ip "${NODE1_IP}" -Node2Ip "${NODE2_IP}" -HostsFilePath "${WINDOWS_HOSTS_FILE_WIN}"
