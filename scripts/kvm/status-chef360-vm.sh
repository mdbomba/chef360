#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

require_command virsh

if ! vm_exists; then
  printf 'VM_NAME=%s\nSTATE=absent\n' "${VM_NAME}"
  exit 0
fi

state="$(virsh_system domstate "${VM_NAME}")"
printf 'VM_NAME=%s\nSTATE=%s\nEXPECTED_IP=%s\nHOSTNAME=%s\n' \
  "${VM_NAME}" "${state}" "${VM_IP}" "${VM_HOSTNAME}"
virsh_system dominfo "${VM_NAME}" | grep -E '^(CPU\(s\)|Max memory|Autostart):' || true
virsh_system domblklist "${VM_NAME}" --details
virsh_system domiflist "${VM_NAME}"

if [[ "${state}" == "running" ]]; then
  printf '\nGuest agent interfaces:\n'
  virsh_system domifaddr "${VM_NAME}" --source agent 2>/dev/null || printf 'Guest agent address unavailable.\n'
  if ping -c 1 -W 1 "${VM_IP}" >/dev/null 2>&1; then
    printf 'NETWORK=reachable\n'
  else
    printf 'NETWORK=unreachable\n'
  fi
fi
