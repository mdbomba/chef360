#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

require_command dig

check_record() {
  local name="$1"
  local expected="$2"
  local actual
  actual="$(dig +short +time=2 +tries=1 "@${VM_DNS}" "${name}" A | sed -n '1p')"
  [[ "${actual}" == "${expected}" ]] || fail "DNS ${VM_DNS} resolved ${name} as ${actual:-nothing}; expected ${expected}"
  printf 'PASS: %s resolves to %s through %s\n' "${name}" "${actual}" "${VM_DNS}"
}

check_record "${VM_HOSTNAME}" "${VM_IP}"
check_record "${AUTOMATE_FQDN}" "${AUTOMATE_IP}"
check_record "${NODE1_FQDN}" "${NODE1_IP}"
check_record "${NODE2_FQDN}" "${NODE2_IP}"

public_result="$(dig +short +time=3 +tries=1 "@${VM_DNS}" google.com A | sed -n '1p')"
[[ "${public_result}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "DNS ${VM_DNS} did not forward public lookup for google.com"
printf 'PASS: %s forwards public DNS queries\n' "${VM_DNS}"
