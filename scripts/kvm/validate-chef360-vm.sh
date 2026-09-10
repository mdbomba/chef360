#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

failures=0
pass() { printf 'PASS: %s\n' "$*"; }
fail_check() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }

for command in virsh ssh; do require_command "${command}"; done

if ! vm_exists; then
  fail "VM does not exist: ${VM_NAME}"
fi

state="$(virsh_system domstate "${VM_NAME}")"
[[ "${state}" == "running" ]] && pass "VM is running" || fail_check "VM state is ${state}"

xml="$(virsh_system dumpxml "${VM_NAME}")"
grep -q "<vcpu placement='static'>${VM_VCPUS}</vcpu>" <<<"${xml}" && pass "vCPU allocation is ${VM_VCPUS}" || fail_check "Unexpected vCPU allocation"
grep -q "<shares>${VM_CPU_SHARES}</shares>" <<<"${xml}" && pass "CPU shares are ${VM_CPU_SHARES}" || fail_check "Unexpected CPU shares"
grep -Eq "<source network='${VM_NETWORK}'([ />])" <<<"${xml}" && pass "Network is ${VM_NETWORK}" || fail_check "Unexpected network"
grep -Fq "<mac address='${VM_MAC}'/>" <<<"${xml}" && pass "MAC address is ${VM_MAC}" || fail_check "Unexpected MAC address"

if [[ ! -f "${SSH_PRIVATE_KEY}" ]]; then
  fail_check "SSH private key not found: ${SSH_PRIVATE_KEY}"
elif ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i "${SSH_PRIVATE_KEY}" "${VM_USER}@${VM_IP}" true >/dev/null 2>&1; then
  pass "Key-based SSH succeeds"
  remote=(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i "${SSH_PRIVATE_KEY}" "${VM_USER}@${VM_IP}")
  [[ "$("${remote[@]}" hostnamectl --static)" == "${VM_HOSTNAME}" ]] && pass "Static hostname is ${VM_HOSTNAME}" || fail_check "Static hostname mismatch"
  [[ "$("${remote[@]}" hostname -f)" == "${VM_HOSTNAME}" ]] && pass "Guest FQDN is ${VM_HOSTNAME}" || fail_check "Guest FQDN mismatch"
  resolved_fqdn_ip="$("${remote[@]}" getent ahostsv4 "${VM_HOSTNAME}" | awk 'NR==1 {print $1}')"
  [[ "${resolved_fqdn_ip}" == "${VM_IP}" ]] && pass "Guest FQDN resolves to ${VM_IP}" || fail_check "Guest FQDN resolves to ${resolved_fqdn_ip:-nothing}"
  "${remote[@]}" sudo -n true >/dev/null 2>&1 && pass "Passwordless sudo succeeds" || fail_check "Passwordless sudo failed"
  remote_authorized_fingerprint="$("${remote[@]}" ssh-keygen -lf "/home/${VM_USER}/.ssh/authorized_keys" 2>/dev/null | awk 'NR==1 {print $2}')"
  local_public_fingerprint="$(ssh-keygen -lf "${SSH_PUBLIC_KEY}" | awk '{print $2}')"
  [[ "${remote_authorized_fingerprint}" == "${local_public_fingerprint}" ]] && pass "Guest authorized_keys contains fury_rsa.pub" || fail_check "Guest authorized key fingerprint mismatch"
  for host in "${KVM_HOST_FQDN}" "${AUTOMATE_FQDN}" "${NODE1_FQDN}" "${NODE2_FQDN}"; do
    "${remote[@]}" getent hosts "${host}" >/dev/null 2>&1 && pass "Guest resolves ${host}" || fail_check "Guest does not resolve ${host}"
  done
  "${remote[@]}" systemctl is-active --quiet ssh && pass "OpenSSH server is active" || fail_check "OpenSSH server is inactive"
  "${remote[@]}" systemctl is-active --quiet qemu-guest-agent && pass "QEMU guest agent is active" || fail_check "QEMU guest agent is inactive"
  "${remote[@]}" 'files=$(find /etc/netplan -type f -name "*.yaml" -print); test -n "$files" && test -z "$(find /etc/netplan -type f -name "*.yaml" ! -perm 0600 -print)"' && pass "Netplan YAML files use mode 0600" || fail_check "Netplan YAML file permissions are not mode 0600"
  "${remote[@]}" 'test "$(swapon --noheadings 2>/dev/null | wc -l)" -eq 0' && pass "Swap is disabled" || fail_check "Swap is active"
  "${remote[@]}" findmnt -n -o FSTYPE /var/lib/embedded-cluster | grep -qx xfs && pass "Chef 360 data path uses XFS" || fail_check "Chef 360 data path is not XFS"
  "${remote[@]}" xfs_info /var/lib/embedded-cluster 2>/dev/null | grep -q 'ftype=1' && pass "XFS ftype=1 is enabled" || fail_check "XFS ftype=1 not verified"
else
  fail_check "Key-based SSH failed for ${VM_USER}@${VM_IP}"
fi

if ((failures > 0)); then
  printf '\nValidation failed with %d issue(s).\n' "${failures}" >&2
  exit 1
fi
printf '\nVM validation passed.\n'
