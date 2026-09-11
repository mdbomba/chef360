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

KVM_HOST_PACKAGES="${KVM_HOST_PACKAGES:-qemu-kvm libvirt-daemon-system libvirt-clients virtinst dnsmasq-base genisoimage xorriso openssl curl jq dnsutils openssh-client python3 ca-certificates}"
LIBVIRTD_SERVICE="${LIBVIRTD_SERVICE:-libvirtd}"

cat <<EOF
KVM host bootstrap plan
  Platform:        Linux with system libvirt (QEMU/KVM)
  Packages:        ${KVM_HOST_PACKAGES}
  Services:        enable and start ${LIBVIRTD_SERVICE}
  Libvirt network: start and autostart ${VM_NETWORK}
  SSH key:         ${SSH_PRIVATE_KEY} (+ ${SSH_PUBLIC_KEY})
  Staging dirs:    $(dirname "${UBUNTU_ISO}") and $(dirname "${CHEF360_INSTALLER_SOURCE}")

Continue with:
  fetch-ubuntu-iso.sh --execute
  issue-chef360-certs.sh --execute
  acquire-chef360-assets.sh --execute
EOF

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. No host changes were made. Use --execute to install and configure.\n'
  exit 0
fi

[[ "$(uname -s)" == "Linux" ]] || fail "KVM host bootstrap requires Linux"
for command in apt-get dpkg id install ssh-keygen sudo systemctl; do require_command "${command}"; done

missing_packages=()
for package in ${KVM_HOST_PACKAGES}; do
  if ! dpkg -s "${package}" >/dev/null 2>&1; then
    missing_packages+=("${package}")
  fi
done
if (( ${#missing_packages[@]} > 0 )); then
  log_step "Installing packages: ${missing_packages[*]}"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing_packages[@]}"
else
  printf 'Package prerequisites already present\n'
fi

if ! sudo systemctl is-enabled "${LIBVIRTD_SERVICE}" >/dev/null 2>&1; then
  sudo systemctl enable "${LIBVIRTD_SERVICE}"
fi
sudo systemctl start "${LIBVIRTD_SERVICE}" 2>/dev/null || sudo systemctl restart "${LIBVIRTD_SERVICE}"
printf 'Service %s is %s\n' "${LIBVIRTD_SERVICE}" "$(systemctl is-active "${LIBVIRTD_SERVICE}")"

if ! virsh_system net-info "${VM_NETWORK}" >/dev/null 2>&1; then
  for default_xml in /usr/share/libvirt/networks/default.xml /etc/libvirt/qemu/networks/default.xml; do
    if [[ -f "${default_xml}" ]]; then
      sudo virsh --connect "${LIBVIRT_URI}" net-define "${default_xml}"
      break
    fi
  done
fi
network_state="$(virsh_system net-info "${VM_NETWORK}" 2>/dev/null | awk -F': +' '$1 == "Active" {print $2}')"
if [[ "${network_state}" != "yes" ]]; then
  virsh_system net-start "${VM_NETWORK}"
fi
virsh_system net-autostart "${VM_NETWORK}" || true
printf 'Libvirt network %s is active\n' "${VM_NETWORK}"

sudo install -d -m 0755 "$(dirname "${UBUNTU_ISO}")" "$(dirname "${CHEF360_INSTALLER_SOURCE}")"

if [[ ! -f "${SSH_PRIVATE_KEY}" ]] || [[ ! -f "${SSH_PUBLIC_KEY}" ]]; then
  install -d -m 0700 "$(dirname "${SSH_PRIVATE_KEY}")"
  ssh-keygen -t ed25519 -f "${SSH_PRIVATE_KEY}" -N "" -C "chef360-kvm" >/dev/null
  chmod 0600 "${SSH_PRIVATE_KEY}"
  printf 'Generated Chef 360 KVM SSH keypair %s\n' "${SSH_PRIVATE_KEY}"
fi
private_public="$(ssh-keygen -y -f "${SSH_PRIVATE_KEY}" | awk '{print $2}')"
public_fingerprint="$(awk '{print $2}' "${SSH_PUBLIC_KEY}")"
[[ "${private_public}" == "${public_fingerprint}" ]] || fail "SSH private and public keys do not match"

if virsh_system uri >/dev/null 2>&1; then
  printf 'Unprivileged %s access works\n' "${LIBVIRT_URI}"
else
  printf 'WARNING: unprivileged virsh access is unavailable; add this user to the libvirt and kvm groups, then log out and back in.\n' >&2
fi

save_kvm_state

cat <<EOF

KVM host bootstrap complete.
  ISO directory:    $(dirname "${UBUNTU_ISO}")
  Asset directory:  $(dirname "${CHEF360_INSTALLER_SOURCE}")
  Next:             ${SCRIPT_DIR}/fetch-ubuntu-iso.sh --execute
EOF