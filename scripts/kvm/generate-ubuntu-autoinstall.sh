#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

VM_INITIAL_PASSWORD="${VM_INITIAL_PASSWORD:-devsecops}"
USER_DATA="${KVM_WORK_DIR}/${VM_NAME}-user-data"
META_DATA="${KVM_WORK_DIR}/${VM_NAME}-meta-data"

for command in openssl genisoimage xorriso python3; do
  require_command "${command}"
done
require_file "${UBUNTU_ISO}"
require_file "${SSH_PUBLIC_KEY}"

install -d -m 0700 "${KVM_WORK_DIR}"
password_hash="$(openssl passwd -6 "${VM_INITIAL_PASSWORD}")"
ssh_key="$(<"${SSH_PUBLIC_KEY}")"

resolve_vm_mac

cat >"${USER_DATA}" <<EOF
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  refresh-installer:
    update: false
  source:
    id: ubuntu-server
    search_drivers: false
  apt:
    geoip: false
    mirror-selection:
primary:
            - uri: ${UBUNTU_MIRROR}
          arches: [amd64]
    fallback: abort
  identity:
    hostname: ${VM_SHORT_HOSTNAME}
    realname: Chef Administrator
    username: ${VM_USER}
    password: '${password_hash}'
  ssh:
    install-server: true
    allow-pw: true
    authorized-keys:
      - ${ssh_key}
  storage:
    swap:
      size: 0
    config:
      - type: disk
        id: os-disk
        match:
          serial: ${VM_OS_DISK_SERIAL}
        ptable: gpt
        wipe: superblock-recursive
        grub_device: true
      - type: partition
        id: efi-partition
        device: os-disk
        size: 1G
        flag: boot
        grub_device: true
        number: 1
      - type: format
        id: efi-format
        volume: efi-partition
        fstype: fat32
        label: EFI
      - type: mount
        id: efi-mount
        device: efi-format
        path: /boot/efi
      - type: partition
        id: root-partition
        device: os-disk
        size: -1
        number: 2
      - type: format
        id: root-format
        volume: root-partition
        fstype: ext4
        label: ubuntu-root
      - type: mount
        id: root-mount
        device: root-format
        path: /
      - type: disk
        id: data-disk
        match:
          serial: ${VM_DATA_DISK_SERIAL}
        ptable: gpt
        wipe: superblock-recursive
      - type: partition
        id: data-partition
        device: data-disk
        size: -1
        number: 1
      - type: format
        id: data-format
        volume: data-partition
        fstype: xfs
        label: chef360-data
      - type: mount
        id: data-mount
        device: data-format
        path: /var/lib/embedded-cluster
  packages:
    - apparmor
    - ca-certificates
    - curl
    - jq
    - openssh-server
    - python3-yaml
    - qemu-guest-agent
    - tree
    - xfsprogs
  updates: security
  late-commands:
    - curtin in-target -- env DEBIAN_FRONTEND=noninteractive apt-get update
    - curtin in-target -- env DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
    - curtin in-target -- swapoff --all
    - [sed, -i, '/[[:space:]]swap[[:space:]]/s/^/# disabled by Chef 360 autoinstall: /', /target/etc/fstab]
    - [find, /target/etc/netplan, -type, f, -name, '*.yaml', -exec, chmod, '0600', '{}', +]
    - [sed, -i, 's/^127\.0\.1\.1.*/127.0.1.1 ${VM_SHORT_HOSTNAME}/', /target/etc/hosts]
    - printf '${VM_IP} ${VM_HOSTNAME} ${VM_SHORT_HOSTNAME}\n${KVM_HOST_IP} ${KVM_HOST_FQDN} fury\n${AUTOMATE_IP} ${AUTOMATE_FQDN} automate\n${NODE1_IP} ${NODE1_FQDN} node1\n${NODE2_IP} ${NODE2_FQDN} node2\n' >> /target/etc/hosts
    - curtin in-target -- hostnamectl set-hostname ${VM_HOSTNAME}
    - printf '${VM_USER} ALL=(ALL) NOPASSWD:ALL\n' > /target/etc/sudoers.d/90-chef
    - chmod 0440 /target/etc/sudoers.d/90-chef
    - curtin in-target -- visudo -cf /etc/sudoers.d/90-chef
    - curtin in-target -- systemctl enable ssh
    - curtin in-target -- systemctl enable qemu-guest-agent
    - xfs_info /target/var/lib/embedded-cluster | grep -q 'ftype=1'
  user-data:
    write_files:
      - path: /usr/local/sbin/configure-chef360-netplan.py
        owner: root:root
        permissions: '0700'
        content: |
          #!/usr/bin/env python3
          import glob
          import os
          from pathlib import Path

          import yaml

          expected_mac = "${VM_MAC}"
          interface = ""
          for address_path in glob.glob("/sys/class/net/*/address"):
              if Path(address_path).read_text(encoding="utf-8").strip().lower() == expected_mac.lower():
                  interface = Path(address_path).parent.name
                  break
          if not interface:
              raise SystemExit(f"No interface found for MAC {expected_mac}")

          config_path = None
          document = None
          for candidate in sorted(Path("/etc/netplan").glob("*.yaml")):
              loaded = yaml.safe_load(candidate.read_text(encoding="utf-8")) or {}
              ethernets = loaded.get("network", {}).get("ethernets", {})
              if interface in ethernets:
                  config_path = candidate
                  document = loaded
                  break
          if config_path is None or document is None:
              raise SystemExit(f"No existing Netplan file defines interface {interface}")

          entry = document["network"]["ethernets"][interface]
          entry["dhcp4"] = False
          entry.pop("dhcp6", None)
          entry["addresses"] = ["${VM_IP}/${VM_PREFIX}"]
          entry["routes"] = [{"to": "default", "via": "${VM_GATEWAY}"}]
          entry["nameservers"] = {"addresses": ["${VM_DNS}"], "search": ["demo.lab"]}

          temporary = config_path.with_suffix(".yaml.tmp")
          temporary.write_text(yaml.safe_dump(document, sort_keys=False), encoding="utf-8")
          os.chmod(temporary, 0o600)
          temporary.replace(config_path)
          for path in Path("/etc/netplan").glob("*.yaml"):
              os.chmod(path, 0o600)
          Path("/var/lib/chef360-primary-interface").write_text(interface + "\n", encoding="utf-8")
    runcmd:
      - [/usr/local/sbin/configure-chef360-netplan.py]
      - [netplan, generate]
      - [netplan, apply]
      - [hostnamectl, set-hostname, ${VM_HOSTNAME}]
      - [touch, /var/lib/chef360-autoinstall-ready]
  shutdown: poweroff
EOF

cat >"${META_DATA}" <<EOF
instance-id: ${VM_NAME}-$(date -u '+%Y%m%d%H%M%S')
local-hostname: ${VM_SHORT_HOSTNAME}
EOF

chmod 0600 "${USER_DATA}" "${META_DATA}"

log_step "Extracting Ubuntu installer kernel and initrd"
xorriso -osirrox on -indev "${UBUNTU_ISO}" \
  -extract /casper/vmlinuz "${INSTALL_KERNEL}" \
  -extract /casper/initrd "${INSTALL_INITRD}" >/dev/null 2>&1
chmod 0600 "${INSTALL_KERNEL}" "${INSTALL_INITRD}"

log_step "Creating NoCloud seed ISO"
rm -f -- "${SEED_ISO}"
genisoimage -quiet -output "${SEED_ISO}" -volid cidata -joliet -rock \
  "${USER_DATA}" "${META_DATA}"
chmod 0600 "${SEED_ISO}"

save_kvm_state

python3 - "${USER_DATA}" "${SSH_PUBLIC_KEY}" "${VM_HOSTNAME}" "${VM_SHORT_HOSTNAME}" "${VM_DNS}" <<'PY'
import sys
from pathlib import Path

import yaml

path = Path(sys.argv[1])
public_key = Path(sys.argv[2]).read_text(encoding="utf-8").strip()
vm_hostname, vm_short_hostname, vm_dns = sys.argv[3:]
document = yaml.safe_load(path.read_text(encoding="utf-8"))
config = document["autoinstall"]
assert config["version"] == 1
assert config["ssh"]["install-server"] is True
assert config["ssh"]["allow-pw"] is True
assert config["ssh"]["authorized-keys"] == [public_key]
assert "network" not in config
assert config["storage"]["swap"]["size"] == 0
assert any(item.get("fstype") == "xfs" for item in config["storage"]["config"])
late = config["late-commands"]
assert all(
    isinstance(command, str)
    or (isinstance(command, list) and all(isinstance(argument, str) for argument in command))
    for command in late
)
flat_late = [" ".join(command) if isinstance(command, list) else command for command in late]
assert any("apt-get update" in command for command in flat_late)
assert any("apt-get -y upgrade" in command for command in flat_late)
assert any("/target/etc/netplan" in command and "0600" in command for command in flat_late)
user_data = config["user-data"]
assert any(item["path"] == "/usr/local/sbin/configure-chef360-netplan.py" for item in user_data["write_files"])
assert ["netplan", "generate"] in user_data["runcmd"]
assert ["netplan", "apply"] in user_data["runcmd"]
assert ["hostnamectl", "set-hostname", vm_hostname] in user_data["runcmd"]
assert ["touch", "/var/lib/chef360-autoinstall-ready"] in user_data["runcmd"]
netplan_script = next(
    item["content"]
    for item in user_data["write_files"]
    if item["path"] == "/usr/local/sbin/configure-chef360-netplan.py"
)
assert f'["{vm_dns}"]' in netplan_script
efi_partition = next(item for item in config["storage"]["config"] if item.get("id") == "efi-partition")
assert efi_partition["grub_device"] is True
hosts_command = next(command for command in flat_late if "/target/etc/hosts" in command and "fury.demo.lab" in command)
assert any(f"127.0.1.1 {vm_short_hostname}" in command for command in flat_late)
for expected in ("fury.demo.lab", "automate.demo.lab", "node1.demo.lab", "node2.demo.lab"):
    assert expected in hosts_command
assert "tree" in config["packages"]
assert config["shutdown"] == "poweroff"
PY

cat <<EOF
Generated Ubuntu autoinstall artifacts:
  user-data: ${USER_DATA}
  meta-data: ${META_DATA}
  seed ISO:  ${SEED_ISO}
  kernel:    ${INSTALL_KERNEL}
  initrd:    ${INSTALL_INITRD}

No VM or libvirt resource was created.
EOF
