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
RESOURCE_GROUP="${2:-${RESOURCE_GROUP:-rg-chef360-linux}}"
OBJECT_OWNER_PREFIX="${OBJECT_OWNER_PREFIX:-chef360}"
DEFAULT_NAME_PREFIX="${OBJECT_OWNER_PREFIX}-sa-linux"
NAME_PREFIX="${3:-${NAME_PREFIX:-${DEFAULT_NAME_PREFIX}}}"
CHEF_NODE_USER="${4:-chef}"
EXPECTED_POLICY_NAME="${5:-stig_base}"
EXPECTED_POLICY_GROUP="${6:-dev}"
NODE1_TARGET="${7:-${NODE1_TARGET:-node1}}"
NODE2_TARGET="${8:-${NODE2_TARGET:-node2}}"
EXPECTED_COHORT_NAME="${9:-${CHEF360_COHORT_NAME:-all-nodes}}"
CHEF360_PROFILE="${CHEF360_PROFILE:-default}"
EXPECTED_COHORT_ID="${CHEF360_COHORT_ID:-}"
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

resolve_expected_cohort_id() {
  if [[ -n "${EXPECTED_COHORT_ID}" ]]; then
    return
  fi

  EXPECTED_COHORT_ID="$(printf "%s" "${CHEF360_COHORTS_JSON}" | jq -r --arg n "${EXPECTED_COHORT_NAME}" '.items[]? | select(.name == $n) | (.cohortId // .id)' | sed -n '1p')"
}

find_chef360_node_line() {
  local node_target="$1"
  local public_ip="$2"
  local private_ip="$3"

  printf "%s" "${CHEF360_NODES_JSON}" | jq -r \
    --arg target "${node_target}" \
    --arg publicIp "${public_ip}" \
    --arg privateIp "${private_ip}" \
    '
      def attr($ns; $name): ([.attributes[]? | select(.namespace==$ns and .name==$name) | .value] | first // "");
      .items[]?
      | . as $n
      | {
          id: $n.id,
          cohortId: ($n.cohortId // ""),
          enrollmentLevel: ($n.enrollmentLevel // ""),
          source: ($n.source // ""),
          host: ($n | attr("enroll"; "hostname")),
          ip: ($n | attr("enroll"; "primary_ip")),
          fqdn: ($n | attr("enroll"; "fqdn"))
        }
      | select(
          (.host != "" and .host == $target)
          or (.ip != "" and .ip == $target)
          or (.fqdn != "" and .fqdn == $target)
          or ($publicIp != "" and ((.ip == $publicIp) or (.fqdn == $publicIp)))
          or ($privateIp != "" and ((.ip == $privateIp) or (.fqdn == $privateIp)))
        )
      | [.id, .cohortId, .enrollmentLevel, .host, .ip, .fqdn, .source] | @tsv
    ' | sed -n '1p'
}

if [[ -z "${SSH_PRIVATE_KEY}" ]]; then
  printf "Usage: %s <ssh-private-key> [resource-group] [name-prefix] [chef-node-user] [expected-policy-name] [expected-policy-group] [node1-target] [node2-target] [expected-chef360-cohort-name]\n" "$(basename "$0")"
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
require_command "chef-node-management-cli"
require_command "jq"
bash "${ENSURE_SSH_ACCESS_SCRIPT}" "${RESOURCE_GROUP}" "${NAME_PREFIX}" "${SSH_SOURCE_CIDR_OVERRIDE}" >/dev/null

EXPECTED_POLICY_NAME_NORMALIZED="$(normalize_policy_name "${EXPECTED_POLICY_NAME}")"
NODE_ALIASES=("node1" "node2")
NODE_TARGETS=("${NODE1_TARGET}" "${NODE2_TARGET}")

CHEF360_COHORTS_JSON="$(chef-node-management-cli management cohort find-all-cohorts --pagination.size 1000 --profile "${CHEF360_PROFILE}" --format json 2>/dev/null || true)"
CHEF360_NODES_JSON="$(chef-node-management-cli management node find-all-nodes --pagination.size 1000 --profile "${CHEF360_PROFILE}" --format json 2>/dev/null || true)"
resolve_expected_cohort_id

log_step "Final validation started"
if [[ -n "${EXPECTED_COHORT_ID}" ]]; then
  ok "Chef360 cohort '${EXPECTED_COHORT_NAME}' resolved as '${EXPECTED_COHORT_ID}'"
else
  fail "Chef360 cohort '${EXPECTED_COHORT_NAME}' was not found"
fi

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

  chef360_line="$(find_chef360_node_line "${node_target}" "${vm_public_ip}" "${vm_private_ip}")"
  if [[ -z "${chef360_line}" ]]; then
    fail "Chef360 node record not found for ${node_alias}"
    continue
  fi

  chef360_node_id="$(printf "%s" "${chef360_line}" | cut -f1)"
  chef360_cohort_id="$(printf "%s" "${chef360_line}" | cut -f2)"
  chef360_enrollment_level="$(printf "%s" "${chef360_line}" | cut -f3)"
  chef360_host="$(printf "%s" "${chef360_line}" | cut -f4)"
  chef360_ip="$(printf "%s" "${chef360_line}" | cut -f5)"
  chef360_fqdn="$(printf "%s" "${chef360_line}" | cut -f6)"
  chef360_source="$(printf "%s" "${chef360_line}" | cut -f7)"

  ok "Chef360 node found (id: ${chef360_node_id}, host: ${chef360_host:-n/a}, ip: ${chef360_ip:-n/a}, fqdn: ${chef360_fqdn:-n/a}, source: ${chef360_source:-n/a})"

  if [[ -n "${EXPECTED_COHORT_ID}" && "${chef360_cohort_id}" == "${EXPECTED_COHORT_ID}" ]]; then
    ok "Chef360 cohort assignment matches '${EXPECTED_COHORT_NAME}'"
  else
    fail "Chef360 cohort mismatch (found '${chef360_cohort_id:-none}', expected '${EXPECTED_COHORT_ID:-unknown}')"
  fi

  if [[ "${chef360_enrollment_level}" == "enrolled" ]]; then
    ok "Chef360 enrollment level is '${chef360_enrollment_level}'"
  else
    fail "Chef360 enrollment level is '${chef360_enrollment_level:-unknown}'"
  fi

  chef360_status_json="$(chef-node-management-cli status get-status --nodeId "${chef360_node_id}" --profile "${CHEF360_PROFILE}" --format json 2>/dev/null || true)"
  chef360_state="$(printf "%s" "${chef360_status_json}" | jq -r '.item.state // empty')"
  chef360_failed_workflow="$(printf "%s" "${chef360_status_json}" | jq -r '.item.stateWorkflow[]? | select((.status // "") | ascii_downcase == "failed") | "\(.state): \(.log // "")"' | sed -n '1p')"

  if [[ -n "${chef360_state}" ]]; then
    ok "Chef360 node state is '${chef360_state}'"
  else
    fail "Chef360 node state unavailable for node id '${chef360_node_id}'"
  fi

  if [[ -n "${chef360_failed_workflow}" ]]; then
    fail "Chef360 state workflow failure detected: ${chef360_failed_workflow}"
  else
    ok "Chef360 state workflow has no failed steps"
  fi
done

printf "\n"
if [[ "${FAILURES}" -eq 0 ]]; then
  log_step "Final validation passed: all checks succeeded"
  exit 0
fi

log_step "Final validation failed: ${FAILURES} check(s) failed"
exit 1
