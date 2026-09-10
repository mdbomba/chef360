#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

AUTO_YES=false
if [[ "${1:-}" == "--yes" ]]; then
  AUTO_YES=true
elif [[ $# -gt 0 ]]; then
  fail "Usage: $(basename "$0") [--yes]"
fi

require_command virsh

expected_prefix="${LIBVIRT_IMAGE_DIR}/${VM_NAME}-"
for disk in "${OS_DISK}" "${DATA_DISK}"; do
  [[ "${disk}" == "${expected_prefix}"*.qcow2 ]] || fail "Refusing unsafe disk path: ${disk}"
done
for artifact in "${LIBVIRT_SEED_ISO}" "${LIBVIRT_INSTALL_KERNEL}" "${LIBVIRT_INSTALL_INITRD}"; do
  [[ "${artifact}" == "${LIBVIRT_IMAGE_DIR}/${VM_NAME}-"* ]] || fail "Refusing unsafe artifact path: ${artifact}"
done
[[ "${KVM_WORK_DIR}" == "${PROJECT_ROOT}/.kvm/${VM_NAME}" ]] || fail "Refusing unsafe work directory: ${KVM_WORK_DIR}"

if [[ "${AUTO_YES}" != true ]]; then
  printf 'This will delete VM %s and these dedicated resources:\n  %s\n  %s\n  %s\n' \
    "${VM_NAME}" "${OS_DISK}" "${DATA_DISK}" "${KVM_WORK_DIR}"
  read -r -p "Type '${VM_NAME}' to confirm: " confirmation
  [[ "${confirmation}" == "${VM_NAME}" ]] || fail "Confirmation did not match; nothing was deleted"
fi

if vm_exists; then
  state="$(virsh_system domstate "${VM_NAME}")"
  if [[ "${state}" != "shut off" ]]; then
    log_step "Stopping ${VM_NAME}"
    virsh_system destroy "${VM_NAME}"
  fi
  log_step "Removing libvirt definition for ${VM_NAME}"
  virsh_system undefine "${VM_NAME}" --nvram --managed-save --snapshots-metadata 2>/dev/null || \
    virsh_system undefine "${VM_NAME}" --nvram
fi

for disk in "${OS_DISK}" "${DATA_DISK}"; do
  if [[ -e "${disk}" ]]; then
    log_step "Removing ${disk}"
    sudo rm -f -- "${disk}"
  fi
done
for artifact in "${LIBVIRT_SEED_ISO}" "${LIBVIRT_INSTALL_KERNEL}" "${LIBVIRT_INSTALL_INITRD}"; do
  if [[ -e "${artifact}" ]]; then
    log_step "Removing ${artifact}"
    sudo rm -f -- "${artifact}"
  fi
done
if [[ -d "${KVM_WORK_DIR}" ]]; then
  log_step "Removing generated work directory ${KVM_WORK_DIR}"
  rm -rf -- "${KVM_WORK_DIR}"
fi

if [[ -f "${HOME}/.ssh/known_hosts" ]]; then
  ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${VM_IP}" >/dev/null 2>&1 || true
  ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${VM_HOSTNAME}" >/dev/null 2>&1 || true
fi
rm -f -- "${KVM_STATE_FILE}"
log_step "KVM deployment resources removed"
