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
CHEF_POLICY_NAME="${3:-stig_base}"
CHEF_POLICY_GROUP="${4:-dev}"
if [[ "${#}" -ge 5 ]]; then
  NODE1_TARGET="$5"
else
  NODE1_TARGET="${NODE1_TARGET:-node1}"
fi
if [[ "${#}" -ge 6 ]]; then
  NODE2_TARGET="$6"
else
  NODE2_TARGET="${NODE2_TARGET:-node2}"
fi
KNOWN_HOSTS_FILE="${HOME}/.ssh/known_hosts"
KNIFE_SSH_VERIFY_HOST_KEY="${KNIFE_SSH_VERIFY_HOST_KEY:-never}"
ENSURE_SSH_ACCESS_SCRIPT="${SCRIPT_DIR}/ensure-azure-ssh-access.sh"

log_step() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    printf "Required command not found: %s\n" "${cmd}"
    exit 1
  fi
}

wait_for_ssh() {
  local host="$1"
  local max_attempts=30
  local attempt

  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    log_step "Checking SSH readiness for ${host} (attempt ${attempt}/${max_attempts})"
    if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${host}" true >/dev/null 2>&1; then
      log_step "SSH ready for ${host}"
      return
    fi
    sleep 10
  done

  printf "SSH did not become ready for host: %s\n" "${host}"
  exit 1
}

seed_host_key_if_missing() {
  local host="$1"

  mkdir -p "$(dirname "${KNOWN_HOSTS_FILE}")"
  touch "${KNOWN_HOSTS_FILE}"

  if ssh-keygen -F "${host}" -f "${KNOWN_HOSTS_FILE}" >/dev/null 2>&1; then
    return
  fi

  ssh-keyscan -H -T 5 "${host}" >> "${KNOWN_HOSTS_FILE}" 2>/dev/null || true
}

if [[ -z "${SSH_PRIVATE_KEY}" ]]; then
  printf "Usage: %s <ssh-private-key> [chef-node-user] [chef-policy-name] [chef-policy-group] [node1-target] [node2-target]\n" "$(basename "$0")"
  exit 1
fi

if [[ ! -f "${SSH_PRIVATE_KEY}" ]]; then
  printf "SSH private key not found: %s\n" "${SSH_PRIVATE_KEY}"
  exit 1
fi

require_command "knife"
require_command "ssh"
bash "${ENSURE_SSH_ACCESS_SCRIPT}" "${RESOURCE_GROUP:-rg-chef360-linux}" "${NAME_PREFIX:-${OBJECT_OWNER_PREFIX:-chef360}-sa-linux}" "${SSH_SOURCE_CIDR_OVERRIDE}" >/dev/null

NODE_ALIASES=("node1" "node2")
NODE_TARGETS=("${NODE1_TARGET}" "${NODE2_TARGET}")

for i in 0 1; do
  NODE_ALIAS="${NODE_ALIASES[i]}"
  BOOTSTRAP_TARGET="${NODE_TARGETS[i]}"

  if [[ -z "${BOOTSTRAP_TARGET}" ]]; then
    continue
  fi

  log_step "Preparing bootstrap for ${NODE_ALIAS} using target ${BOOTSTRAP_TARGET}"
  seed_host_key_if_missing "${BOOTSTRAP_TARGET}"
  wait_for_ssh "${BOOTSTRAP_TARGET}"

  log_step "Running knife bootstrap for ${NODE_ALIAS}"
  knife bootstrap "${BOOTSTRAP_TARGET}" \
    --yes \
    --connection-user "${CHEF_NODE_USER}" \
    --node-name "${NODE_ALIAS}" \
    --ssh-identity-file "${SSH_PRIVATE_KEY}" \
    --ssh-verify-host-key "${KNIFE_SSH_VERIFY_HOST_KEY}" \
    --sudo \
    --chef-license accept-silent \
    --policy-group "${CHEF_POLICY_GROUP}" \
    --policy-name "${CHEF_POLICY_NAME}"

  log_step "Bootstrapped ${NODE_ALIAS} with policy ${CHEF_POLICY_NAME}/${CHEF_POLICY_GROUP}"
done

log_step "Bootstrap workflow completed"
