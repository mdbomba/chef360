#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
INSTALL_MODE="${CHEF360_INSTALL_MODE:-browser}"
ADMIN_CONSOLE_PASSWORD="${CHEF360_ADMIN_CONSOLE_PASSWORD:-}"
REMOTE_ROOT="/opt/chef360"
REMOTE_INSTALLER="${REMOTE_ROOT}/chef-360"
REMOTE_LICENSE="${REMOTE_ROOT}/license.yaml"
REMOTE_CONFIG="${REMOTE_ROOT}/chef-config.yaml"
REMOTE_CERT="${REMOTE_ROOT}/tls/chef360-2.crt"
REMOTE_KEY="${REMOTE_ROOT}/tls/chef360-2.key"
REMOTE_AIRGAP="${REMOTE_ROOT}/chef-360.airgap"
REMOTE_LOG="/var/log/chef360-install.log"

ADMIN_CONSOLE_PORT="${CHEF360_ADMIN_CONSOLE_PORT:-30000}"
CLUSTER_CIDR="${CHEF360_CLUSTER_CIDR:-10.244.0.0/16}"
DATA_DIR="${CHEF360_DATA_DIR:-/var/lib/embedded-cluster}"
ARTIFACT_MIRROR_PORT="${CHEF360_LOCAL_ARTIFACT_MIRROR_PORT:-50000}"
NETWORK_INTERFACE="${CHEF360_NETWORK_INTERFACE:-enp1s0}"
if [[ -z "${CHEF360_AIRGAP_BUNDLE}" ]]; then
  default_airgap_bundle="$(dirname "${CHEF360_INSTALLER_SOURCE}")/chef-360.airgap"
  [[ ! -r "${default_airgap_bundle}" ]] || CHEF360_AIRGAP_BUNDLE="${default_airgap_bundle}"
fi

case "${INSTALL_MODE}" in
  browser|config-values) ;;
  *) fail "CHEF360_INSTALL_MODE must be browser or config-values" ;;
esac
CHEF360_CONFIG_PRESENT=false
[[ "${INSTALL_MODE}" == "config-values" ]] && CHEF360_CONFIG_PRESENT=true
config_values_plan="(not supplied; configure and deploy in the Admin Console)"
[[ "${CHEF360_CONFIG_PRESENT}" != true ]] || config_values_plan="${REMOTE_CONFIG}"

local_tls_pair_available() {
  [[ -r "${CHEF360_TLS_CERT}" && -r "${CHEF360_TLS_KEY}" && -r "${CHEF360_TLS_CHAIN}" ]] || return 1
  openssl x509 -in "${CHEF360_TLS_CERT}" -noout -checkend 0 >/dev/null 2>&1 || return 1
  openssl verify -purpose sslserver -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null 2>&1 || return 1
  openssl verify -verify_hostname "${VM_HOSTNAME}" -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null 2>&1 || return 1
  openssl verify -verify_ip "${VM_IP}" -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null 2>&1 || return 1
  local cert_public key_public
  cert_public="$(openssl x509 -in "${CHEF360_TLS_CERT}" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)" || return 1
  key_public="$(openssl pkey -in "${CHEF360_TLS_KEY}" -pubout -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)" || return 1
  [[ -n "${cert_public}" && "${cert_public}" == "${key_public}" ]]
}

LOCAL_TLS_PAIR_AVAILABLE=false
local_tls_pair_available && LOCAL_TLS_PAIR_AVAILABLE=true

PLAN_INSTALL_ARGS=(
  install
  --license "${REMOTE_LICENSE}"
  --hostname "${VM_HOSTNAME}"
  --admin-console-password '<redacted>'
)
if [[ "${LOCAL_TLS_PAIR_AVAILABLE}" == true ]]; then
  PLAN_INSTALL_ARGS+=(--tls-cert "${REMOTE_CERT}" --tls-key "${REMOTE_KEY}")
fi
if [[ "${CHEF360_CONFIG_PRESENT}" == true ]]; then
  PLAN_INSTALL_ARGS+=(--config-values "${REMOTE_CONFIG}")
fi
[[ "${DATA_DIR}" == /var/lib/embedded-cluster ]] || PLAN_INSTALL_ARGS+=(--data-dir "${DATA_DIR}")
[[ "${ARTIFACT_MIRROR_PORT}" == 50000 ]] || PLAN_INSTALL_ARGS+=(--local-artifact-mirror-port "${ARTIFACT_MIRROR_PORT}")
[[ "${CLUSTER_CIDR}" == 10.244.0.0/16 ]] || PLAN_INSTALL_ARGS+=(--cidr "${CLUSTER_CIDR}")
[[ "${NETWORK_INTERFACE}" == enp1s0 ]] || PLAN_INSTALL_ARGS+=(--network-interface "${NETWORK_INTERFACE}")
[[ "${ADMIN_CONSOLE_PORT}" == 30000 ]] || PLAN_INSTALL_ARGS+=(--admin-console-port "${ADMIN_CONSOLE_PORT}")
if [[ -n "${CHEF360_AIRGAP_BUNDLE}" && -r "${CHEF360_AIRGAP_BUNDLE}" ]]; then
  PLAN_INSTALL_ARGS+=(--airgap-bundle "${REMOTE_AIRGAP}")
fi
PLAN_INSTALL_ARGS+=(--ignore-host-preflights --ignore-app-preflights --yes)

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute]

Without --execute, print the exact Chef 360 install plan without contacting the VM.
--execute  Validate the staged guest and install Chef 360 1.7.3.

The Admin Console password comes from CHEF360_ADMIN_CONSOLE_PASSWORD or a hidden
interactive prompt. It is never written to the plan output.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

app_preflight_mode="host and application preflights bypassed"

cat <<EOF
Chef 360 1.7.3 installation plan
  Target:              ${VM_USER}@${VM_IP} (${VM_HOSTNAME})
  Installer:           ${REMOTE_INSTALLER}
  License:             ${REMOTE_LICENSE}
  ConfigValues:        ${config_values_plan}
  Data directory:      ${DATA_DIR}
  Admin Console:       https://${VM_HOSTNAME}:${ADMIN_CONSOLE_PORT}
  Admin Console TLS:   $([[ "${LOCAL_TLS_PAIR_AVAILABLE}" == true ]] && printf 'validated certificate/key pair will be used' || printf 'no valid matching pair; installer default certificate will be used')
  Chef 360 endpoint:   https://${VM_HOSTNAME}:${GATEWAY_NODEPORT}
  App preflights:      ${app_preflight_mode}
  Install log:         ${REMOTE_LOG}

Exact remote installer arguments:
EOF
printf '  %q' "${REMOTE_INSTALLER}" "${PLAN_INSTALL_ARGS[@]}"
printf '\n'
[[ -z "${CHEF360_HTTP_PROXY}" ]] || printf '  Optional proxy: --http-proxy <configured; value redacted>\n'
[[ -z "${CHEF360_HTTPS_PROXY}" ]] || printf '  Optional proxy: --https-proxy <configured; value redacted>\n'
[[ -z "${CHEF360_NO_PROXY}" ]] || printf '  Optional proxy: --no-proxy <configured; value redacted>\n'

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. No connection was made. Use --execute after this item is approved and the VM is ready.\n'
  exit 0
fi

[[ -z "${CHEF360_AIRGAP_BUNDLE}" ]] || require_file "${CHEF360_AIRGAP_BUNDLE}"
if [[ -z "${ADMIN_CONSOLE_PASSWORD}" ]]; then
  [[ -t 0 ]] || fail "Set CHEF360_ADMIN_CONSOLE_PASSWORD in ~/.secrets/chef360.params or run interactively"
  read -r -s -p "Admin Console password: " ADMIN_CONSOLE_PASSWORD
  printf '\n'
fi
[[ -n "${ADMIN_CONSOLE_PASSWORD}" ]] || fail "Admin Console password is required"
(( ${#ADMIN_CONSOLE_PASSWORD} >= 6 )) || fail "Admin Console password must be at least six characters"

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
[[ "${PROVISION_METHOD}" == "existing" ]] || \
  ssh "${ssh_args[@]}" "${target}" test -f /var/lib/chef360-autoinstall-ready \
    || fail "Autoinstall readiness marker is missing"
ssh "${ssh_args[@]}" "${target}" test -f /var/lib/chef360-install-inputs-ready || fail "Installation-input readiness marker is missing"

remote_checks_file="$(mktemp)"
trap 'rm -f -- "${remote_checks_file}"' EXIT
ssh "${ssh_args[@]}" "${target}" sudo -n env VM_HOSTNAME="${VM_HOSTNAME}" VM_IP="${VM_IP}" DATA_DIR="${DATA_DIR}" CHEF360_CONFIG_PRESENT="${CHEF360_CONFIG_PRESENT}" sh -eu <<'REMOTE_CHECKS' >"${remote_checks_file}"
test -x /opt/chef360/chef-360
test -r /opt/chef360/license.yaml
if [ "${CHEF360_CONFIG_PRESENT:-}" = true ]; then test -r /opt/chef360/chef-config.yaml; fi
/opt/chef360/chef-360 version | grep -Eq '\| chef-360[[:space:]]+\| 1\.7\.3[[:space:]]+\|'
findmnt -n -o FSTYPE "$DATA_DIR" | grep -qx xfs
xfs_info "$DATA_DIR" | grep -q 'ftype=1'
test "$(swapon --noheadings 2>/dev/null | wc -l)" -eq 0
if [ -r /opt/chef360/tls/chef360-2.crt ] && [ -r /opt/chef360/tls/chef360-2.key ]; then
  if [ "$(stat -c %a /opt/chef360/tls/chef360-2.key)" = 600 ] \
    && openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /opt/chef360/tls/chef360-2.crt >/dev/null 2>&1 \
    && openssl verify -verify_hostname "$VM_HOSTNAME" -CAfile /etc/ssl/certs/ca-certificates.crt /opt/chef360/tls/chef360-2.crt >/dev/null 2>&1 \
    && openssl verify -verify_ip "$VM_IP" -CAfile /etc/ssl/certs/ca-certificates.crt /opt/chef360/tls/chef360-2.crt >/dev/null 2>&1 \
    && [ "$(openssl x509 -in /opt/chef360/tls/chef360-2.crt -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)" = "$(openssl pkey -in /opt/chef360/tls/chef360-2.key -pubout -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)" ]; then
    printf 'CHEF360_ADMIN_TLS_PAIR=true\n'
  else
    printf 'CHEF360_ADMIN_TLS_PAIR=false\n'
  fi
else
  printf 'CHEF360_ADMIN_TLS_PAIR=false\n'
fi
REMOTE_CHECKS
TLS_PAIR_AVAILABLE="$(awk -F= '/^CHEF360_ADMIN_TLS_PAIR=/ {value=$2} END {print value}' "${remote_checks_file}")"
rm -f -- "${remote_checks_file}"
if [[ "${TLS_PAIR_AVAILABLE}" != true ]]; then
  log_step "No valid matching Admin Console certificate/key pair found on guest; omitting --tls-cert and --tls-key"
fi

if ssh "${ssh_args[@]}" "${target}" "ss -ltn 2>/dev/null | grep -q ':${GATEWAY_NODEPORT} '"; then
  fail "Chef 360 appears to be installed already (${VM_IP}:${GATEWAY_NODEPORT} is listening)"
fi
if ssh "${ssh_args[@]}" "${target}" test -e "${DATA_DIR}/k0s/pki/admin.conf"; then
  log_step "Embedded Cluster state present; resuming the addon stage of the install"
fi

log_step "Starting Chef 360 1.7.3 installation on ${VM_HOSTNAME}"
if [[ -n "${CHEF360_AIRGAP_BUNDLE}" ]]; then
  scp "${ssh_args[@]}" "${CHEF360_AIRGAP_BUNDLE}" "${target}:/home/${VM_USER}/.chef-360.airgap"
  ssh "${ssh_args[@]}" "${target}" sudo -n install -m 0600 "/home/${VM_USER}/.chef-360.airgap" "${REMOTE_AIRGAP}"
  ssh "${ssh_args[@]}" "${target}" rm -f "/home/${VM_USER}/.chef-360.airgap"
fi
printf '%s' "${ADMIN_CONSOLE_PASSWORD}" | \
  ssh "${ssh_args[@]}" "${target}" \
    "sudo -n sh -c 'umask 077; cat > /run/chef360-admin-console-password'"

remote_env=(
  "VM_HOSTNAME=${VM_HOSTNAME}"
  "CHEF360_CONFIG_PRESENT=${CHEF360_CONFIG_PRESENT}"
  "CHEF360_ADMIN_TLS_PAIR=${TLS_PAIR_AVAILABLE}"
  "ADMIN_CONSOLE_PORT=${ADMIN_CONSOLE_PORT}"
  "CLUSTER_CIDR=${CLUSTER_CIDR}"
  "DATA_DIR=${DATA_DIR}"
  "ARTIFACT_MIRROR_PORT=${ARTIFACT_MIRROR_PORT}"
  "NETWORK_INTERFACE=${NETWORK_INTERFACE}"
  "CHEF360_HTTP_PROXY=${CHEF360_HTTP_PROXY}"
  "CHEF360_HTTPS_PROXY=${CHEF360_HTTPS_PROXY}"
  "CHEF360_NO_PROXY=${CHEF360_NO_PROXY}"
  "CHEF360_AIRGAP_BUNDLE=${CHEF360_AIRGAP_BUNDLE}"
)
printf -v remote_command '%q ' sudo -n env "${remote_env[@]}" bash -euo pipefail
ssh "${ssh_args[@]}" "${target}" "${remote_command}" <<'REMOTE_INSTALL'
umask 077
ignore_app_preflights=""
[[ "${CHEF360_IGNORE_APP_PREFLIGHTS:-}" =~ ^(1|true|yes)$ ]] && ignore_app_preflights=--ignore-app-preflights
password_file=/run/chef360-admin-console-password
trap 'rm -f -- "$password_file"' EXIT
install_args=(
  install
  --license /opt/chef360/license.yaml
  --hostname "$VM_HOSTNAME"
  --admin-console-password "$(cat /run/chef360-admin-console-password)"
  --yes
  --ignore-host-preflights
  --ignore-app-preflights
)
if [[ "${CHEF360_ADMIN_TLS_PAIR}" == true ]]; then
  install_args+=(--tls-cert /opt/chef360/tls/chef360-2.crt --tls-key /opt/chef360/tls/chef360-2.key)
fi
if [[ "${CHEF360_CONFIG_PRESENT}" == true ]]; then
  install_args+=(--config-values /opt/chef360/chef-config.yaml)
fi
[[ "${DATA_DIR}" == /var/lib/embedded-cluster ]] || install_args+=(--data-dir "${DATA_DIR}")
[[ "${ARTIFACT_MIRROR_PORT}" == 50000 ]] || install_args+=(--local-artifact-mirror-port "${ARTIFACT_MIRROR_PORT}")
[[ "${CLUSTER_CIDR}" == 10.244.0.0/16 ]] || install_args+=(--cidr "${CLUSTER_CIDR}")
[[ "${NETWORK_INTERFACE}" == enp1s0 ]] || install_args+=(--network-interface "${NETWORK_INTERFACE}")
[[ "${ADMIN_CONSOLE_PORT}" == 30000 ]] || install_args+=(--admin-console-port "${ADMIN_CONSOLE_PORT}")
[[ -z "${CHEF360_HTTP_PROXY}" ]] || install_args+=(--http-proxy "${CHEF360_HTTP_PROXY}")
[[ -z "${CHEF360_HTTPS_PROXY}" ]] || install_args+=(--https-proxy "${CHEF360_HTTPS_PROXY}")
[[ -z "${CHEF360_NO_PROXY}" ]] || install_args+=(--no-proxy "${CHEF360_NO_PROXY}")
if [[ -r /opt/chef360/chef-360.airgap ]]; then
  install_args+=(--airgap-bundle /opt/chef360/chef-360.airgap)
fi
/opt/chef360/chef-360 "${install_args[@]}" 2>&1 | tee /var/log/chef360-install.log
touch /var/lib/chef360-install-complete
REMOTE_INSTALL

log_step "Chef 360 installer completed successfully"
