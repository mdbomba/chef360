#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
ADMIN_CONSOLE_PASSWORD="${CHEF360_ADMIN_CONSOLE_PASSWORD:-devsecops}"
REMOTE_ROOT="/opt/chef360"
REMOTE_INSTALLER="${REMOTE_ROOT}/chef-360"
REMOTE_LICENSE="${REMOTE_ROOT}/license.yaml"
REMOTE_CONFIG="${REMOTE_ROOT}/chef-config.yaml"
REMOTE_CERT="${REMOTE_ROOT}/tls/chef360-2.crt"
REMOTE_KEY="${REMOTE_ROOT}/tls/chef360-2.key"
REMOTE_LOG="/var/log/chef360-install.log"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute]

Without --execute, print the exact Chef 360 install plan without contacting the VM.
--execute  Validate the staged guest and install Chef 360 1.7.3.

The Admin Console password defaults to the approved lab value. Override it with
CHEF360_ADMIN_CONSOLE_PASSWORD without placing it in this script.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

[[ -n "${ADMIN_CONSOLE_PASSWORD}" ]] || fail "CHEF360_ADMIN_CONSOLE_PASSWORD is empty"
(( ${#ADMIN_CONSOLE_PASSWORD} >= 6 )) || fail "Admin Console password must be at least six characters"

cat <<EOF
Chef 360 1.7.3 installation plan
  Target:              ${VM_USER}@${VM_IP} (${VM_HOSTNAME})
  Installer:           ${REMOTE_INSTALLER}
  License:             ${REMOTE_LICENSE}
  ConfigValues:        ${REMOTE_CONFIG}
  Data directory:      /var/lib/embedded-cluster
  Admin Console:       https://${VM_HOSTNAME}:30000
  Admin Console cert:  ${REMOTE_CERT}
  Admin Console key:   ${REMOTE_KEY}
  Chef 360 endpoint:   https://${VM_HOSTNAME}:31000
  Strict preflights:   enabled; no bypass flags
  Install log:         ${REMOTE_LOG}

Exact remote installer arguments:
  ${REMOTE_INSTALLER} install
    --license ${REMOTE_LICENSE}
    --hostname ${VM_HOSTNAME}
    --tls-cert ${REMOTE_CERT}
    --tls-key ${REMOTE_KEY}
    --config-values ${REMOTE_CONFIG}
    --admin-console-password <redacted>
    --data-dir /var/lib/embedded-cluster
    --network-interface enp1s0
    --yes
EOF

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. No connection was made. Use --execute after this item is approved and the VM is ready.\n'
  exit 0
fi

for command in ssh; do require_command "${command}"; done
require_file "${SSH_PRIVATE_KEY}"

ssh_args=(
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=accept-new
  -i "${SSH_PRIVATE_KEY}"
)
target="${VM_USER}@${VM_IP}"

actual_hostname="$(ssh "${ssh_args[@]}" "${target}" hostname -f)"
[[ "${actual_hostname}" == "${VM_HOSTNAME}" ]] || fail "Refusing unexpected target hostname: ${actual_hostname}"
ssh "${ssh_args[@]}" "${target}" sudo -n true >/dev/null || fail "Passwordless sudo is unavailable"
ssh "${ssh_args[@]}" "${target}" test -f /var/lib/chef360-autoinstall-ready || fail "Autoinstall readiness marker is missing"
ssh "${ssh_args[@]}" "${target}" test -f /var/lib/chef360-install-inputs-ready || fail "Installation-input readiness marker is missing"

ssh "${ssh_args[@]}" "${target}" sudo -n sh -eu <<'REMOTE_CHECKS'
test -x /opt/chef360/chef-360
test -r /opt/chef360/license.yaml
test -r /opt/chef360/chef-config.yaml
test -r /opt/chef360/tls/chef360-2.crt
test -r /opt/chef360/tls/chef360-2.key
test "$(stat -c %a /opt/chef360/tls/chef360-2.key)" = "600"
/opt/chef360/chef-360 version | grep -Eq '\| chef-360[[:space:]]+\| 1\.7\.3[[:space:]]+\|'
findmnt -n -o FSTYPE /var/lib/embedded-cluster | grep -qx xfs
xfs_info /var/lib/embedded-cluster | grep -q 'ftype=1'
test "$(swapon --noheadings 2>/dev/null | wc -l)" -eq 0
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /opt/chef360/tls/chef360-2.crt
openssl verify -verify_hostname chef360-2.demo.lab -CAfile /etc/ssl/certs/ca-certificates.crt /opt/chef360/tls/chef360-2.crt
REMOTE_CHECKS

if ssh "${ssh_args[@]}" "${target}" test -e /var/lib/embedded-cluster/k0s/pki/admin.conf; then
  fail "Chef 360 or Embedded Cluster appears to be installed already"
fi

log_step "Starting Chef 360 1.7.3 installation on ${VM_HOSTNAME}"
printf '%s' "${ADMIN_CONSOLE_PASSWORD}" | \
  ssh "${ssh_args[@]}" "${target}" \
    "sudo -n sh -c 'umask 077; cat > /run/chef360-admin-console-password'"

ssh "${ssh_args[@]}" "${target}" sudo -n bash -euo pipefail <<'REMOTE_INSTALL'
umask 077
password_file=/run/chef360-admin-console-password
trap 'rm -f -- "$password_file"' EXIT
test -s "$password_file"
admin_console_password="$(cat "$password_file")"
/opt/chef360/chef-360 install \
  --license /opt/chef360/license.yaml \
  --hostname chef360-2.demo.lab \
  --tls-cert /opt/chef360/tls/chef360-2.crt \
  --tls-key /opt/chef360/tls/chef360-2.key \
  --config-values /opt/chef360/chef-config.yaml \
  --admin-console-password "$admin_console_password" \
  --data-dir /var/lib/embedded-cluster \
  --network-interface enp1s0 \
  --yes \
  2>&1 | tee /var/log/chef360-install.log
touch /var/lib/chef360-install-complete
REMOTE_INSTALL

log_step "Chef 360 installer completed successfully"
