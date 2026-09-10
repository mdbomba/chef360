#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
HOSTS_FILE="${CHEF360_HOSTS_FILE:-/etc/hosts}"
SSH_CONFIG="${CHEF360_SSH_CONFIG:-${HOME}/.ssh/config}"
CA_INSTALL_DIR="${CHEF360_CA_INSTALL_DIR:-/usr/local/share/ca-certificates}"
CA_UPDATE_COMMAND="${CHEF360_CA_UPDATE_COMMAND:-/usr/sbin/update-ca-certificates}"
SYSTEM_CA_BUNDLE="${CHEF360_SYSTEM_CA_BUNDLE:-/etc/ssl/certs/ca-certificates.crt}"
HOSTS_BEGIN="# BEGIN CHEF360 PROJECT ${VM_NAME}"
HOSTS_END="# END CHEF360 PROJECT ${VM_NAME}"
SSH_BEGIN="# BEGIN CHEF360 PROJECT ${VM_NAME}"
SSH_END="# END CHEF360 PROJECT ${VM_NAME}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute]

Without --execute, print the Linux Mint Workstation configuration plan.
--execute  Configure local name resolution, CA trust, and the SSH alias.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

for file in "${SSH_PRIVATE_KEY}" "${SSH_PUBLIC_KEY}" "${CHEF360_ISSUING_CA}" "${CHEF360_ROOT_CA}"; do
  require_file "${file}"
done

cat <<EOF
Linux Mint Chef Workstation configuration plan
  Name resolution:
    ${VM_IP} ${VM_HOSTNAME} ${VM_SHORT_HOSTNAME}
    ${KVM_HOST_IP} ${KVM_HOST_FQDN} fury host
    ${AUTOMATE_IP} ${AUTOMATE_FQDN} automate
    ${NODE1_IP} ${NODE1_FQDN} node1
    ${NODE2_IP} ${NODE2_FQDN} node2
  Host trust files:
    ${CA_INSTALL_DIR}/chef360-2_ica.crt <- ${CHEF360_ISSUING_CA}
    ${CA_INSTALL_DIR}/chef360-2_rca.crt <- ${CHEF360_ROOT_CA}
  SSH alias:
    Host ${VM_SHORT_HOSTNAME}
    HostName ${VM_IP}
    User ${VM_USER}
    IdentityFile ${SSH_PRIVATE_KEY}
    IdentitiesOnly yes
EOF

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. No host configuration was changed.\n'
  exit 0
fi

for command in awk install mktemp openssl ssh ssh-keygen sudo; do require_command "${command}"; done
[[ -x "${CA_UPDATE_COMMAND}" ]] || fail "CA update command is not executable: ${CA_UPDATE_COMMAND}"

openssl verify -CAfile "${CHEF360_ROOT_CA}" "${CHEF360_ISSUING_CA}" >/dev/null || fail "Issuing CA does not verify against root CA"
openssl verify -CAfile "${CHEF360_ROOT_CA}" -untrusted "${CHEF360_ISSUING_CA}" "${CHEF360_TLS_CERT}" >/dev/null || fail "Leaf certificate trust path is invalid"
private_public_key="$(ssh-keygen -y -f "${SSH_PRIVATE_KEY}" | awk '{print $2}')"
configured_public_key="$(awk '{print $2}' "${SSH_PUBLIC_KEY}")"
[[ "${private_public_key}" == "${configured_public_key}" ]] || fail "SSH private and public keys do not match"

if [[ -f "${SSH_CONFIG}" ]]; then
  unmanaged_ssh_conflict="$(awk \
    -v begin="${SSH_BEGIN}" \
    -v end="${SSH_END}" \
    -v alias="${VM_SHORT_HOSTNAME}" '
      $0 == begin {managed=1; next}
      $0 == end {managed=0; next}
      managed || /^[[:space:]]*#/ {next}
      tolower($1) == "host" {
        for (i = 2; i <= NF; i++) if ($i == alias) print
      }
    ' "${SSH_CONFIG}")"
  [[ -z "${unmanaged_ssh_conflict}" ]] || fail "Unmanaged SSH Host ${VM_SHORT_HOSTNAME} block already exists"
fi

replace_marked_block() {
  local source_file="$1"
  local destination_file="$2"
  local begin_marker="$3"
  local end_marker="$4"
  local temporary
  temporary="$(mktemp)"
  if [[ -f "${destination_file}" ]]; then
    awk -v begin="${begin_marker}" -v end="${end_marker}" '
      $0 == begin {skip=1; next}
      $0 == end {skip=0; next}
      !skip {print}
    ' "${destination_file}" >"${temporary}"
  fi
  if [[ -s "${temporary}" ]]; then
    printf '\n' >>"${temporary}"
  fi
  cat "${source_file}" >>"${temporary}"
  printf '%s' "${temporary}"
}

remove_managed_host_entries() {
  local source_file="$1"
  local output_file="$2"
  awk \
    -v begin="${HOSTS_BEGIN}" \
    -v end="${HOSTS_END}" \
    -v ip0="${KVM_HOST_IP}" \
    -v ip1="${VM_IP}" \
    -v ip2="${AUTOMATE_IP}" \
    -v ip3="${NODE1_IP}" \
    -v ip4="${NODE2_IP}" '
      $0 == begin {managed=1; next}
      $0 == end {managed=0; next}
      managed {next}
      $1 == ip0 || $1 == ip1 || $1 == ip2 || $1 == ip3 || $1 == ip4 {next}
      {print}
    ' "${source_file}" >"${output_file}"
}

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

cat >"${work_dir}/hosts-block" <<EOF
${HOSTS_BEGIN}
${VM_IP} ${VM_HOSTNAME} ${VM_SHORT_HOSTNAME}
${KVM_HOST_IP} ${KVM_HOST_FQDN} fury host
${AUTOMATE_IP} ${AUTOMATE_FQDN} automate
${NODE1_IP} ${NODE1_FQDN} node1
${NODE2_IP} ${NODE2_FQDN} node2
${HOSTS_END}
EOF
remove_managed_host_entries "${HOSTS_FILE}" "${work_dir}/hosts-base"
hosts_candidate="$(replace_marked_block "${work_dir}/hosts-block" "${work_dir}/hosts-base" "${HOSTS_BEGIN}" "${HOSTS_END}")"
sudo install -m 0644 "${hosts_candidate}" "${HOSTS_FILE}"
pass_message="Configured ${HOSTS_FILE}"
printf '%s\n' "${pass_message}"
if [[ "${HOSTS_FILE}" == "/etc/hosts" ]]; then
  dnsmasq_pid_file="/run/libvirt/network/${VM_NETWORK}.pid"
  if sudo test -r "${dnsmasq_pid_file}"; then
    dnsmasq_pid="$(sudo cat "${dnsmasq_pid_file}")"
    sudo kill -HUP "${dnsmasq_pid}"
    printf 'Reloaded libvirt dnsmasq for network %s\n' "${VM_NETWORK}"
  else
    fail "Libvirt dnsmasq PID file is unavailable: ${dnsmasq_pid_file}"
  fi
fi

install -d -m 0700 "$(dirname "${SSH_CONFIG}")"
cat >"${work_dir}/ssh-block" <<EOF
${SSH_BEGIN}
Host ${VM_SHORT_HOSTNAME}
    HostName ${VM_IP}
    User ${VM_USER}
    IdentityFile ${SSH_PRIVATE_KEY}
    IdentitiesOnly yes
${SSH_END}
EOF
ssh_candidate="$(replace_marked_block "${work_dir}/ssh-block" "${SSH_CONFIG}" "${SSH_BEGIN}" "${SSH_END}")"
ssh -G -F "${ssh_candidate}" "${VM_SHORT_HOSTNAME}" >/dev/null || fail "Generated SSH configuration is invalid"
install -m 0600 "${ssh_candidate}" "${SSH_CONFIG}"
printf 'Configured %s\n' "${SSH_CONFIG}"

sudo install -m 0644 "${CHEF360_ISSUING_CA}" "${CA_INSTALL_DIR}/chef360-2_ica.crt"
sudo install -m 0644 "${CHEF360_ROOT_CA}" "${CA_INSTALL_DIR}/chef360-2_rca.crt"
sudo "${CA_UPDATE_COMMAND}"
openssl verify -CAfile "${SYSTEM_CA_BUNDLE}" "${CHEF360_TLS_CERT}" >/dev/null || fail "Host CA trust verification failed"
printf 'Installed and verified Chef 360 CA trust\n'

ssh-keygen -F "${VM_IP}" -f "${HOME}/.ssh/known_hosts" >/dev/null 2>&1 || true
printf '\nWorkstation configuration complete. After the VM is running, connect with:\n  ssh %s\n' "${VM_SHORT_HOSTNAME}"
