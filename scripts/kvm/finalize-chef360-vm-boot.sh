#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

require_command virsh
require_command python3
vm_exists || fail "VM does not exist: ${VM_NAME}"
[[ "$(virsh_system domstate "${VM_NAME}")" == "shut off" ]] || fail "VM must be shut off before finalizing boot"

xml_file="${KVM_WORK_DIR}/${VM_NAME}-installed.xml"
virsh_system dumpxml "${VM_NAME}" >"${xml_file}"
python3 - "${xml_file}" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
tree = ET.parse(path)
root = tree.getroot()
os_node = root.find("os")
for tag in ("kernel", "initrd", "cmdline"):
    node = os_node.find(tag) if os_node is not None else None
    if node is not None:
        os_node.remove(node)
devices = root.find("devices")
if devices is not None:
    for disk in list(devices.findall("disk")):
        if disk.get("device") == "cdrom":
            devices.remove(disk)
tree.write(path, encoding="unicode")
PY
virsh_system define "${xml_file}" --validate >/dev/null
sudo rm -f -- "${LIBVIRT_SEED_ISO}" "${LIBVIRT_INSTALL_KERNEL}" "${LIBVIRT_INSTALL_INITRD}"
log_step "Removed installer boot overrides and CD-ROMs from ${VM_NAME}"
