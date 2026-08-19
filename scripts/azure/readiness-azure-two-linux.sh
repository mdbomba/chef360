#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_FILE="${AZURE_TWO_LINUX_STATE_FILE:-${PROJECT_ROOT}/config/azure-two-linux.env}"
SSH_SOURCE_CIDR_OVERRIDE="${SSH_SOURCE_CIDR:-}"
if [[ -f "${STATE_FILE}" ]]; then
  set -a
  source "${STATE_FILE}"
  set +a
fi

SSH_PRIVATE_KEY="${1:-}"
RESOURCE_GROUP="${2:-${RESOURCE_GROUP:-rg-chef360-linux}}"
OBJECT_OWNER_PREFIX="${OBJECT_OWNER_PREFIX:-chef360}"
DEFAULT_NAME_PREFIX="${OBJECT_OWNER_PREFIX}-sa-linux"
NAME_PREFIX="${3:-${NAME_PREFIX:-${DEFAULT_NAME_PREFIX}}}"
CHEF_NODE_USER="${4:-chef}"
EXPECTED_POLICY_NAME="${5:-stig_base}"
EXPECTED_POLICY_GROUP="${6:-dev}"
NODE1_TARGET="${7:-${NODE1_TARGET:-node1}}"
NODE2_TARGET="${8:-${NODE2_TARGET:-node2}}"
KNOWN_HOSTS_FILE="${HOME}/.ssh/known_hosts"
ENSURE_SSH_ACCESS_SCRIPT="${SCRIPT_DIR}/ensure-azure-ssh-access.sh"

FAILURES=0

log_step() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

ok() {
  printf "[PASS] %s\n" "$*"
}

fail() {
  printf "[FAIL] %s\n" "$*"
  FAILURES=$((FAILURES + 1))
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    printf "Required command not found: %s\n" "${cmd}"
    exit 1
  fi
}

normalize_policy_name() {
  printf "%s" "$1" | tr '_' '-'
}

get_node_policy_value() {
  local node_name="$1"
  local field_name="$2"
  knife node show "${node_name}" -a "${field_name}" 2>/dev/null | awk -F': *' -v key="${field_name}" '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); if ($1 == key) print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
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
  printf "Usage: %s <ssh-private-key> [resource-group] [name-prefix] [chef-node-user] [expected-policy-name] [expected-policy-group] [node1-target] [node2-target]\n" "$(basename "$0")"
  exit 1
fi

if [[ ! -f "${SSH_PRIVATE_KEY}" ]]; then
  printf "SSH private key not found: %s\n" "${SSH_PRIVATE_KEY}"
  exit 1
fi

require_command "az"
require_command "knife"
require_command "ssh"
require_command "ssh-keyscan"
bash "${ENSURE_SSH_ACCESS_SCRIPT}" "${RESOURCE_GROUP}" "${NAME_PREFIX}" "${SSH_SOURCE_CIDR_OVERRIDE}" >/dev/null

NODE_ALIASES=("node1" "node2")
NODE_TARGETS=("${NODE1_TARGET}" "${NODE2_TARGET}")
EXPECTED_POLICY_NAME_NORMALIZED="$(normalize_policy_name "${EXPECTED_POLICY_NAME}")"

log_step "Readiness review started"

for i in 0 1; do
  node_alias="${NODE_ALIASES[i]}"
  node_target="${NODE_TARGETS[i]}"
  vm_name="${NAME_PREFIX}-$((i + 1))"

  printf "\n=== %s (%s) ===\n" "${node_alias}" "${node_target}"

  vm_power_state="$(az vm show -d --resource-group "${RESOURCE_GROUP}" --name "${vm_name}" --query "powerState" --output tsv 2>/dev/null || true)"
  vm_public_ip="$(az vm show -d --resource-group "${RESOURCE_GROUP}" --name "${vm_name}" --query "publicIps" --output tsv 2>/dev/null || true)"
  vm_private_ip="$(az vm show -d --resource-group "${RESOURCE_GROUP}" --name "${vm_name}" --query "privateIps" --output tsv 2>/dev/null || true)"

  if [[ "${vm_power_state}" == "VM running" ]]; then
    ok "Azure VM '${vm_name}' is running (public: ${vm_public_ip:-n/a}, private: ${vm_private_ip:-n/a})"
  else
    fail "Azure VM '${vm_name}' is not running (state: ${vm_power_state:-unknown})"
  fi

  if knife node show "${node_alias}" >/dev/null 2>&1; then
    ok "Chef Infra node '${node_alias}' exists"
  else
    fail "Chef Infra node '${node_alias}' is missing"
  fi

  policy_name="$(get_node_policy_value "${node_alias}" "policy_name")"
  policy_group="$(get_node_policy_value "${node_alias}" "policy_group")"
  policy_name_normalized="$(normalize_policy_name "${policy_name}")"

  if [[ -n "${policy_name}" && -n "${policy_group}" && "${policy_name_normalized}" == "${EXPECTED_POLICY_NAME_NORMALIZED}" && "${policy_group}" == "${EXPECTED_POLICY_GROUP}" ]]; then
    ok "Policy assignment is ${policy_name}/${policy_group}"
  else
    fail "Policy assignment mismatch (found '${policy_name}/${policy_group}', expected '${EXPECTED_POLICY_NAME}/${EXPECTED_POLICY_GROUP}')"
  fi

  seed_host_key_if_missing "${node_target}"

  if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node_target}" true >/dev/null 2>&1; then
    ok "SSH connectivity works for ${CHEF_NODE_USER}@${node_target}"
  else
    fail "SSH connectivity failed for ${CHEF_NODE_USER}@${node_target}"
    continue
  fi

  if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node_target}" "sudo -n true" >/dev/null 2>&1; then
    ok "Passwordless sudo works for ${CHEF_NODE_USER}@${node_target}"
  else
    fail "Passwordless sudo failed for ${CHEF_NODE_USER}@${node_target}"
  fi

  chef_timer_enabled="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node_target}" "sudo systemctl is-enabled chef-client.timer" 2>/dev/null || true)"
  chef_timer_active="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node_target}" "sudo systemctl is-active chef-client.timer" 2>/dev/null || true)"
  chef_client_version="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node_target}" "chef-client --version" 2>/dev/null || true)"

  if [[ "${chef_timer_enabled}" == "enabled" ]]; then
    ok "chef-client.timer is enabled"
  else
    fail "chef-client.timer is not enabled (value: ${chef_timer_enabled:-unknown})"
  fi

  if [[ "${chef_timer_active}" == "active" ]]; then
    ok "chef-client.timer is active"
  else
    fail "chef-client.timer is not active (value: ${chef_timer_active:-unknown})"
  fi

  if [[ -n "${chef_client_version}" ]]; then
    ok "${chef_client_version}"
  else
    fail "Unable to read chef-client version"
  fi
done

printf "\n"
if [[ "${FAILURES}" -eq 0 ]]; then
  log_step "Readiness review passed: all checks succeeded"
  exit 0
fi

log_step "Readiness review failed: ${FAILURES} check(s) failed"
exit 1
