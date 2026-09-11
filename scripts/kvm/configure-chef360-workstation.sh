#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
HOSTS_FILE="${CHEF360_HOSTS_FILE:-/etc/hosts}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute]

Without --execute, print the host prerequisite check plan.
--execute  Verify the host has sufficient resources and prerequisites for the Chef 360 VM.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

cat <<EOF
Host prerequisite checks for ${VM_NAME}
  KVM/QEMU tools:     virsh, qemu-img, virt-install
  RAM:                >= ${VM_MEMORY_MIB} MiB available
  Disk:               >= $(( VM_OS_DISK_GIB + VM_DATA_DISK_GIB )) GiB free on $(dirname "${OS_DISK}")
  DNS (dnsmasq):      listening on ${VM_DNS}
  Hosts file:         ${HOSTS_FILE} has entries for ${VM_HOSTNAME} and ${AUTOMATE_FQDN}
EOF

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. No checks were performed. Use --execute to verify host prerequisites.\n'
  exit 0
fi

log_step "Checking KVM/QEMU tools"
for command in virsh qemu-img virt-install; do
  require_command "${command}"
done
printf 'PASS: virsh, qemu-img, virt-install are available\n'

log_step "Checking available RAM"
required_mem_kib=$(( VM_MEMORY_MIB * 1024 ))
available_mem_kib="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
if (( available_mem_kib < required_mem_kib )); then
  avail_mib=$(( available_mem_kib / 1024 ))
  fail "Insufficient RAM: ${avail_mib} MiB available, ${VM_MEMORY_MIB} MiB required"
fi
printf 'PASS: %d MiB available, %d MiB required\n' "$(( available_mem_kib / 1024 ))" "${VM_MEMORY_MIB}"

log_step "Checking available disk space"
required_disk_gib=$(( VM_OS_DISK_GIB + VM_DATA_DISK_GIB ))
disk_dir="$(dirname "${OS_DISK}")"
available_disk_kib="$(df --output=avail "${disk_dir}" | tail -1)"
if (( available_disk_kib < required_disk_gib * 1024 * 1024 )); then
  avail_gib=$(( available_disk_kib / 1024 / 1024 ))
  fail "Insufficient disk space on ${disk_dir}: ${avail_gib} GiB available, ${required_disk_gib} GiB required"
fi
printf 'PASS: %d GiB available on %s, %d GiB required\n' "$(( available_disk_kib / 1024 / 1024 ))" "${disk_dir}" "${required_disk_gib}"

log_step "Checking dnsmasq on ${VM_DNS}"
dnsmasq_listening=false
if ss -tlnp | grep -q "${VM_DNS}:53 "; then
  dnsmasq_listening=true
fi
[[ "${dnsmasq_listening}" == true ]] || fail "No service listening on ${VM_DNS}:53 (dnsmasq)"
printf 'PASS: dnsmasq is listening on %s:53\n' "${VM_DNS}"

log_step "Checking hosts file entries"
if ! grep -q "${VM_IP}.*${VM_HOSTNAME}" "${HOSTS_FILE}"; then
  fail "${HOSTS_FILE} is missing an entry for ${VM_HOSTNAME} (${VM_IP})"
fi
printf 'PASS: %s has entry for %s\n' "${HOSTS_FILE}" "${VM_HOSTNAME}"
if ! grep -q "${AUTOMATE_IP}.*${AUTOMATE_FQDN}" "${HOSTS_FILE}"; then
  fail "${HOSTS_FILE} is missing an entry for ${AUTOMATE_FQDN} (${AUTOMATE_IP})"
fi
printf 'PASS: %s has entry for %s\n' "${HOSTS_FILE}" "${AUTOMATE_FQDN}"

cat <<EOF

All host prerequisite checks passed.
EOF
