#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
WAIT_FOR_INSTALL=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute] [--wait]

Without --execute, print the deployment plan and perform read-only validation.
--execute  Create the two disks and launch the Ubuntu autoinstall VM.
--wait     Wait for the unattended installer to shut down the VM.

The NoCloud seed ISO must already exist at:
  ${SEED_ISO}
Item 2 must also extract the installer kernel and initrd to:
  ${INSTALL_KERNEL}
  ${INSTALL_INITRD}
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    --wait) WAIT_FOR_INSTALL=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

for command in virsh virt-install qemu-img; do
  require_command "${command}"
done
require_file "${UBUNTU_ISO}"
require_file "${SSH_PUBLIC_KEY}"

"${SCRIPT_DIR}/check-libvirt-dns.sh"
host_mapping="$(getent ahostsv4 "${VM_HOSTNAME}" | awk 'NR==1 {print $1}')"
[[ "${host_mapping}" == "${VM_IP}" ]] || fail "Host must resolve ${VM_HOSTNAME} to ${VM_IP} before deployment"
log_step "Host and libvirt DNS prerequisites passed"

virsh_system net-info "${VM_NETWORK}" >/dev/null 2>&1 || fail "Libvirt network not found: ${VM_NETWORK}"
network_state="$(virsh_system net-info "${VM_NETWORK}" | awk -F': +' '$1 == "Active" {print $2}')"
[[ "${network_state}" == "yes" ]] || fail "Libvirt network is not active: ${VM_NETWORK}"

if vm_exists; then
  fail "VM already exists: ${VM_NAME}"
fi
[[ ! -e "${OS_DISK}" ]] || fail "OS disk already exists: ${OS_DISK}"
[[ ! -e "${DATA_DISK}" ]] || fail "Data disk already exists: ${DATA_DISK}"

if ip neigh show "${VM_IP}" 2>/dev/null | grep -Eq '(REACHABLE|STALE|DELAY|PROBE|PERMANENT)'; then
  fail "IP address appears in the host neighbor table: ${VM_IP}"
fi
if ping -c 1 -W 1 "${VM_IP}" >/dev/null 2>&1; then
  fail "IP address responds to ping: ${VM_IP}"
fi

cat <<EOF
Chef 360 KVM deployment plan
  VM:               ${VM_NAME}
  Hostname:         ${VM_HOSTNAME}
  Network:          ${VM_NETWORK} (${VM_IP}/${VM_PREFIX}, gateway ${VM_GATEWAY}, DNS ${VM_DNS})
  MAC:              ${VM_MAC}
  Compute:          ${VM_VCPUS} vCPUs, ${VM_CPU_SHARES} CPU shares, ${VM_MEMORY_MIB} MiB RAM
  OS disk:          ${OS_DISK} (${VM_OS_DISK_GIB} GiB qcow2, ${VM_DISK_PREALLOCATION}, serial ${VM_OS_DISK_SERIAL})
  Data disk:        ${DATA_DISK} (${VM_DATA_DISK_GIB} GiB qcow2, ${VM_DISK_PREALLOCATION}, serial ${VM_DATA_DISK_SERIAL})
  Ubuntu ISO:       ${UBUNTU_ISO}
  NoCloud seed ISO: ${SEED_ISO}
  Install kernel:   ${INSTALL_KERNEL}
  Install initrd:   ${INSTALL_INITRD}
  Libvirt seed:     ${LIBVIRT_SEED_ISO}
  SSH public key:   ${SSH_PUBLIC_KEY}
EOF

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. No disks or VM were created. Use --execute after reviewing Item 2.\n'
  exit 0
fi

require_file "${SEED_ISO}"
require_file "${INSTALL_KERNEL}"
require_file "${INSTALL_INITRD}"
for artifact in "${LIBVIRT_SEED_ISO}" "${LIBVIRT_INSTALL_KERNEL}" "${LIBVIRT_INSTALL_INITRD}"; do
  [[ ! -e "${artifact}" ]] || fail "Libvirt install artifact already exists: ${artifact}"
done
save_kvm_state

created_os=false
created_data=false
created_install_artifacts=false
cleanup_failed_deploy() {
  local exit_code=$?
  if ((exit_code == 0)); then
    return
  fi
  printf 'Deployment failed; cleaning up resources created by this invocation.\n' >&2
  virsh_system destroy "${VM_NAME}" >/dev/null 2>&1 || true
  virsh_system undefine "${VM_NAME}" --nvram >/dev/null 2>&1 || true
  [[ "${created_os}" == true ]] && sudo rm -f -- "${OS_DISK}"
  [[ "${created_data}" == true ]] && sudo rm -f -- "${DATA_DISK}"
  if [[ "${created_install_artifacts}" == true ]]; then
    sudo rm -f -- "${LIBVIRT_SEED_ISO}" "${LIBVIRT_INSTALL_KERNEL}" "${LIBVIRT_INSTALL_INITRD}"
  fi
}
trap cleanup_failed_deploy EXIT

log_step "Creating preallocated OS disk"
sudo qemu-img create -f qcow2 -o "preallocation=${VM_DISK_PREALLOCATION}" "${OS_DISK}" "${VM_OS_DISK_GIB}G"
created_os=true
log_step "Creating preallocated Chef 360 data disk"
sudo qemu-img create -f qcow2 -o "preallocation=${VM_DISK_PREALLOCATION}" "${DATA_DISK}" "${VM_DATA_DISK_GIB}G"
created_data=true
log_step "Staging installer boot artifacts for system QEMU"
sudo install -o root -g root -m 0644 "${SEED_ISO}" "${LIBVIRT_SEED_ISO}"
sudo install -o root -g root -m 0644 "${INSTALL_KERNEL}" "${LIBVIRT_INSTALL_KERNEL}"
sudo install -o root -g root -m 0644 "${INSTALL_INITRD}" "${LIBVIRT_INSTALL_INITRD}"
created_install_artifacts=true

log_step "Launching Ubuntu autoinstall for ${VM_NAME}"
sudo virt-install \
  --connect "${LIBVIRT_URI}" \
  --name "${VM_NAME}" \
  --memory "${VM_MEMORY_MIB}" \
  --vcpus "${VM_VCPUS}" \
  --cpu host-passthrough \
  --cputune "shares=${VM_CPU_SHARES}" \
  --machine q35 \
  --boot "uefi,kernel=${LIBVIRT_INSTALL_KERNEL},initrd=${LIBVIRT_INSTALL_INITRD},kernel_args=autoinstall console=ttyS0,115200n8 serial" \
  --os-variant ubuntu24.04 \
  --disk "path=${OS_DISK},format=qcow2,bus=virtio,cache=none,io=native,discard=unmap,serial=${VM_OS_DISK_SERIAL}" \
  --disk "path=${DATA_DISK},format=qcow2,bus=virtio,cache=none,io=native,discard=unmap,serial=${VM_DATA_DISK_SERIAL}" \
  --cdrom "${UBUNTU_ISO}" \
  --disk "path=${LIBVIRT_SEED_ISO},device=cdrom" \
  --network "network=${VM_NETWORK},model=virtio,mac=${VM_MAC}" \
  --graphics spice \
  --video qxl \
  --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
  --rng /dev/urandom \
  --noautoconsole

trap - EXIT
log_step "VM created; Ubuntu autoinstall is running"
if [[ "${WAIT_FOR_INSTALL}" == true ]]; then
  log_step "Waiting for the installer to shut down ${VM_NAME}"
  for _ in $(seq 1 360); do
    state="$(virsh_system domstate "${VM_NAME}" 2>/dev/null || true)"
    [[ "${state}" == "shut off" ]] && break
    sleep 10
  done
  [[ "$(virsh_system domstate "${VM_NAME}")" == "shut off" ]] || fail "Timed out waiting for autoinstall"
  log_step "Autoinstall shutdown detected; start with: virsh --connect ${LIBVIRT_URI} start ${VM_NAME}"
fi
