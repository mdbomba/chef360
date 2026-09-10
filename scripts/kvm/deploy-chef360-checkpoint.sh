#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
if [[ "${1:-}" == "--execute" ]]; then
  EXECUTE=true
elif [[ $# -gt 0 ]]; then
  fail "Usage: $(basename "$0") [--execute]"
fi

cat <<EOF
Chef 360 checkpoint deployment (steps 1-9)
  1. Configure Mint hosts, CA trust, and SSH alias
  2. Generate Ubuntu autoinstall artifacts
  3. Generate Chef 360 ConfigValues
  4. Prepare local installation staging
  5. Create VM and wait for Ubuntu autoinstall poweroff
  6. Remove installer boot media and start installed Ubuntu
  7. Wait for SSH and autoinstall readiness
  8. Validate VM, SSH, sudo, hosts, swap, and XFS
  9. Stage Chef 360 inputs and configure guest CA trust

STOP: Chef 360 will not be installed.
EOF

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. Use --execute to run through the review checkpoint.\n'
  exit 0
fi

"${SCRIPT_DIR}/configure-chef360-workstation.sh" --execute
"${SCRIPT_DIR}/check-libvirt-dns.sh"
"${SCRIPT_DIR}/generate-ubuntu-autoinstall.sh"
"${SCRIPT_DIR}/generate-chef360-config.sh"
"${SCRIPT_DIR}/prepare-chef360-install-inputs.sh"
"${SCRIPT_DIR}/deploy-chef360-vm.sh" --execute --wait
"${SCRIPT_DIR}/finalize-chef360-vm-boot.sh"
virsh_system start "${VM_NAME}" >/dev/null

log_step "Waiting for SSH and Ubuntu readiness marker"
ready=false
for attempt in $(seq 1 120); do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
    -i "${SSH_PRIVATE_KEY}" "${VM_USER}@${VM_IP}" \
    'test -f /var/lib/chef360-autoinstall-ready && systemctl is-active --quiet ssh' >/dev/null 2>&1; then
    ready=true
    break
  fi
  printf 'WAIT: Ubuntu first boot is not ready (%d/120)\n' "${attempt}"
  sleep 10
done
[[ "${ready}" == true ]] || fail "Timed out waiting for Ubuntu first boot"

"${SCRIPT_DIR}/validate-chef360-vm.sh"
"${SCRIPT_DIR}/stage-chef360-install-inputs.sh" --execute

cat <<EOF

CHECKPOINT REACHED
  VM ${VM_NAME} is running at ${VM_IP}.
  Ubuntu, SSH, sudo, lab host mappings, swap, XFS, and CA trust are configured.
  Chef 360 1.7.3 inputs are staged under /opt/chef360.
  Chef 360 has NOT been installed.

Review with:
  ssh ${VM_SHORT_HOSTNAME}
  virsh --connect ${LIBVIRT_URI} dominfo ${VM_NAME}
  ${SCRIPT_DIR}/status-chef360-vm.sh
EOF
