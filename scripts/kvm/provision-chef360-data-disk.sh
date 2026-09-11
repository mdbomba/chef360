#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

require_command ssh
require_command virsh

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute]

Provision the Chef 360 data disk on a running clone-based VM:

  1. Wait for SSH to come up.
  2. Find the attached data disk by its serial (${VM_DATA_DISK_SERIAL}).
  3. Partition it (GPT, single partition).
  4. Format it XFS with ftype=1 and label chef360-data.
  5. Mount it at /var/lib/embedded-cluster.
  6. Persist the mount in /etc/fstab by UUID.

Fresh OS-install builds do this during autoinstall and should skip this step.
EOF
}

EXECUTE=false
for arg in "$@"; do
  case "${arg}" in
    --execute) EXECUTE=true ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: ${arg}" ;;
  esac
done

vm_exists || fail "VM does not exist: ${VM_NAME}"
state="$(virsh_system domstate "${VM_NAME}" 2>/dev/null || true)"
[[ "${state}" == "running" ]] || fail "VM is not running: ${VM_NAME}"

remote=(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i "${SSH_PRIVATE_KEY}" "${VM_USER}@${VM_IP}")

log_step "Waiting for SSH on ${VM_USER}@${VM_IP}"
ready=false
for attempt in $(seq 1 60); do
  if "${remote[@]}" 'systemctl is-active --quiet ssh' >/dev/null 2>&1; then
    ready=true
    break
  fi
  printf 'WAIT: SSH is not ready (%d/60)\n' "${attempt}"
  sleep 10
done
[[ "${ready}" == true ]] || fail "Timed out waiting for SSH"

if "${remote[@]}" findmnt -n /var/lib/embedded-cluster >/dev/null 2>&1; then
  log_step "/var/lib/embedded-cluster is already mounted; nothing to do"
  exit 0
fi

log_step "Locating data disk by serial ${VM_DATA_DISK_SERIAL}"
data_disk="$("${remote[@]}" "lsblk -dno NAME,SERIAL -r | awk -v s='${VM_DATA_DISK_SERIAL}' '\$2 == s {print \$1; exit}'")"
if [[ -z "${data_disk}" ]]; then
  "${remote[@]}" lsblk -o NAME,SERIAL >&2 || true
  fail "Data disk with serial ${VM_DATA_DISK_SERIAL} not found"
fi
log_step "Found data disk: ${data_disk}"

if [[ "${EXECUTE}" != true ]]; then
  cat <<EOF
Dry run only. No changes were made.

Plan for /dev/${data_disk}:
  sgdisk --zap-all --clear
  sgdisk --new=1:0:0 --typecode=1:8300
  mkfs.xfs -f -L chef360-data (ftype=1)
  mkdir -p /var/lib/embedded-cluster
  mount by UUID at /var/lib/embedded-cluster
  echo UUID=... /var/lib/embedded-cluster xfs defaults 0 0 >> /etc/fstab
EOF
  exit 0
fi

"${remote[@]}" "command -v sgdisk >/dev/null || sudo apt-get install -y gdisk"
"${remote[@]}" "command -v mkfs.xfs >/dev/null || sudo apt-get install -y xfsprogs"

log_step "Partitioning /dev/${data_disk}"
"${remote[@]}" "sudo sgdisk --zap-all --clear /dev/${data_disk}"
"${remote[@]}" "sudo sgdisk --new=1:0:0 --typecode=1:8300 /dev/${data_disk}"
"${remote[@]}" "sudo partprobe /dev/${data_disk}"
sleep 2

partition="/dev/${data_disk}1"

log_step "Formatting ${partition} as XFS"
"${remote[@]}" "sudo mkfs.xfs -f -L chef360-data ${partition}"

"${remote[@]}" 'mkdir -p /var/lib/embedded-cluster' 2>/dev/null || "${remote[@]}" "
  sudo mkdir -p /var/lib/embedded-cluster
  sudo chown \$(id -u):\$(id -g) /var/lib/embedded-cluster"

uuid="$("${remote[@]}" "sudo blkid -s UUID -o value ${partition}")"
[[ -n "${uuid}" ]] || fail "Unable to read filesystem UUID from ${partition}"

log_step "Mounting ${partition} at /var/lib/embedded-cluster"
"${remote[@]}" "sudo mount UUID=${uuid} /var/lib/embedded-cluster"

if "${remote[@]}" "grep -q UUID=${uuid} /etc/fstab"; then
  log_step "/etc/fstab already contains UUID=${uuid}"
else
  log_step "Appending /etc/fstab entry for UUID=${uuid}"
  "${remote[@]}" "echo 'UUID=${uuid} /var/lib/embedded-cluster xfs defaults 0 0' | sudo tee -a /etc/fstab" >/dev/null
fi

"${remote[@]}" "sudo findmnt -n -o TARGET,FSTYPE /var/lib/embedded-cluster" | grep -qx "/var/lib/embedded-cluster xfs"
log_step "Data disk provisioned and mounted at /var/lib/embedded-cluster"