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

for command in scp ssh; do require_command "${command}"; done
for file in \
  "${CHEF360_STAGE_DIR}/chef-360" \
  "${CHEF360_STAGE_DIR}/license.yaml" \
  "${CHEF360_STAGE_DIR}/chef-config.yaml" \
  "${CHEF360_STAGE_DIR}/tls/chef360-2.crt" \
  "${CHEF360_STAGE_DIR}/tls/chef360-2.key" \
  "${CHEF360_STAGE_DIR}/tls/chef360-2.chain.crt" \
  "${CHEF360_STAGE_DIR}/ca/chef360-2_ica.crt" \
  "${CHEF360_STAGE_DIR}/ca/chef360-2_rca.crt"; do
  require_file "${file}"
done
require_file "${SSH_PRIVATE_KEY}"

cat <<EOF
Chef 360 guest staging plan
  Target: ${VM_USER}@${VM_IP} (${VM_HOSTNAME})
  Runtime directory: /opt/chef360
  Ubuntu trust inputs:
    chef360-2_ica.crt
    chef360-2_rca.crt
  Leaf certificate will not be installed as a CA.
EOF

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. No connection was made. Use --execute after this item is approved and the VM exists.\n'
  exit 0
fi

ssh_args=(
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=accept-new
  -i "${SSH_PRIVATE_KEY}"
)
target="${VM_USER}@${VM_IP}"
actual_hostname="$(ssh "${ssh_args[@]}" "${target}" hostname -f)"
[[ "${actual_hostname}" == "${VM_HOSTNAME}" ]] || fail "Refusing unexpected target hostname: ${actual_hostname}"
ssh "${ssh_args[@]}" "${target}" test -f /var/lib/chef360-autoinstall-ready || fail "Autoinstall readiness marker is missing"
ssh "${ssh_args[@]}" "${target}" sudo -n true || fail "Passwordless sudo is unavailable"

remote_stage="/home/${VM_USER}/.chef360-stage"
ssh "${ssh_args[@]}" "${target}" "rm -rf '${remote_stage}' && install -d -m 0700 '${remote_stage}'"
scp "${ssh_args[@]}" -r "${CHEF360_STAGE_DIR}/." "${target}:${remote_stage}/"

ssh "${ssh_args[@]}" "${target}" "sudo -n env REMOTE_STAGE='${remote_stage}' sh -eu" <<'REMOTE'
install -d -m 0700 /opt/chef360 /opt/chef360/tls
install -m 0700 "$REMOTE_STAGE/chef-360" /opt/chef360/chef-360
install -m 0600 "$REMOTE_STAGE/license.yaml" /opt/chef360/license.yaml
install -m 0600 "$REMOTE_STAGE/chef-config.yaml" /opt/chef360/chef-config.yaml
install -m 0644 "$REMOTE_STAGE/tls/chef360-2.crt" /opt/chef360/tls/chef360-2.crt
install -m 0600 "$REMOTE_STAGE/tls/chef360-2.key" /opt/chef360/tls/chef360-2.key
install -m 0644 "$REMOTE_STAGE/tls/chef360-2.chain.crt" /opt/chef360/tls/chef360-2.chain.crt
install -m 0644 "$REMOTE_STAGE/ca/chef360-2_ica.crt" /usr/local/share/ca-certificates/chef360-2_ica.crt
install -m 0644 "$REMOTE_STAGE/ca/chef360-2_rca.crt" /usr/local/share/ca-certificates/chef360-2_rca.crt
update-ca-certificates
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /opt/chef360/tls/chef360-2.crt
/opt/chef360/chef-360 version | grep -Eq '\| chef-360[[:space:]]+\| 1\.7\.3[[:space:]]+\|'
touch /var/lib/chef360-install-inputs-ready
REMOTE

ssh "${ssh_args[@]}" "${target}" "rm -rf '${remote_stage}'"
log_step "Chef 360 installation inputs staged and Ubuntu CA trust updated"
