#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/lib/load-parameters.sh"
load_chef360_parameters "${PROJECT_ROOT}"
STATE_FILE="${AZURE_TWO_LINUX_STATE_FILE:-${PROJECT_ROOT}/config/azure-two-linux.env}"
SSH_SOURCE_CIDR_OVERRIDE="${SSH_SOURCE_CIDR:-}"
load_env_defaults "${STATE_FILE}"

SSH_PRIVATE_KEY="${1:-}"
CHEF_NODE_USER="${2:-chef}"
NODE1_TARGET="${3:-${NODE1_TARGET:-node1}}"
NODE2_TARGET="${4:-${NODE2_TARGET:-node2}}"
KNOWN_HOSTS_FILE="${HOME}/.ssh/known_hosts"
ENSURE_SSH_ACCESS_SCRIPT="${SCRIPT_DIR}/ensure-azure-ssh-access.sh"

SSH_OPTIONS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=10
)

log_step() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

verify_node_sudo_nopasswd() {
  local node="$1"
  local sudo_output

  log_step "Verifying passwordless sudo for ${CHEF_NODE_USER}@${node}"

  ssh "${SSH_OPTIONS[@]}" -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node}" "sudo -n true"
  sudo_output="$(ssh "${SSH_OPTIONS[@]}" -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node}" "sudo -n -l")"

  if [[ "${sudo_output}" != *"NOPASSWD: ALL"* && "${sudo_output}" != *"NOPASSWD:ALL"* ]]; then
    printf "Passwordless sudo policy verification failed for %s@%s\n" "${CHEF_NODE_USER}" "${node}"
    printf "Expected sudo -n -l output to include NOPASSWD: ALL\n"
    exit 1
  fi

  log_step "Verified passwordless sudo for ${CHEF_NODE_USER}@${node}"
}

seed_host_key_if_missing() {
  local node="$1"

  mkdir -p "$(dirname "${KNOWN_HOSTS_FILE}")"
  touch "${KNOWN_HOSTS_FILE}"

  if ssh-keygen -F "${node}" -f "${KNOWN_HOSTS_FILE}" >/dev/null 2>&1; then
    return
  fi

  ssh-keyscan -H -T 5 "${node}" >> "${KNOWN_HOSTS_FILE}" 2>/dev/null || true
}

if [[ -z "${SSH_PRIVATE_KEY}" ]]; then
  printf "Usage: %s <ssh-private-key> [chef-node-user] [node1-target] [node2-target]\n" "$(basename "$0")"
  exit 1
fi

if [[ ! -f "${SSH_PRIVATE_KEY}" ]]; then
  printf "SSH private key not found: %s\n" "${SSH_PRIVATE_KEY}"
  exit 1
fi

bash "${ENSURE_SSH_ACCESS_SCRIPT}" "${RESOURCE_GROUP:-rg-chef360-linux}" "${NAME_PREFIX:-${OBJECT_OWNER_PREFIX:-chef360}-sa-linux}" "${SSH_SOURCE_CIDR_OVERRIDE}" >/dev/null

seed_host_key_if_missing "${NODE1_TARGET}"
seed_host_key_if_missing "${NODE2_TARGET}"

verify_node_sudo_nopasswd "${NODE1_TARGET}"
verify_node_sudo_nopasswd "${NODE2_TARGET}"

log_step "Passwordless sudo verification completed for both nodes"
