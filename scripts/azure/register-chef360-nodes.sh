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
CHEF_NODE_USER="${2:-chef}"
NODE1_TARGET="${3:-${NODE1_TARGET:-node1}}"
NODE2_TARGET="${4:-${NODE2_TARGET:-node2}}"
CHEF360_SERVER="${CHEF360_SERVER:-}"
CHEF360_SIGNED_CONFIG_FILE="${CHEF360_SIGNED_CONFIG_FILE:-}"
CHEF360_COHORT_ID="${CHEF360_COHORT_ID:-}"
CHEF360_COHORT_NAME="${CHEF360_COHORT_NAME:-}"
CHEF360_PROFILE="${CHEF360_PROFILE:-default}"
CHEF360_AUTO_APPROVE="${CHEF360_AUTO_APPROVE:-true}"
KNOWN_HOSTS_FILE="${HOME}/.ssh/known_hosts"
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

seed_host_key_if_missing() {
  local host="$1"

  mkdir -p "$(dirname "${KNOWN_HOSTS_FILE}")"
  touch "${KNOWN_HOSTS_FILE}"

  if ssh-keygen -F "${host}" -f "${KNOWN_HOSTS_FILE}" >/dev/null 2>&1; then
    return
  fi

  ssh-keyscan -H -T 5 "${host}" >> "${KNOWN_HOSTS_FILE}" 2>/dev/null || true
}

find_node_id() {
  local target="$1"
  local hostname
  local primary_ip

  hostname="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${target}" 'hostname -s')"
  primary_ip="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${target}" "hostname -I | awk '{print \$1}'")"
  chef-node-management-cli management node find-all-nodes --pagination.size 1000 --profile "${CHEF360_PROFILE}" --format json | jq -r \
    --arg host "${hostname}" --arg ip "${primary_ip}" --arg target "${target}" '
      def attr($ns; $name): ([.attributes[]? | select(.namespace==$ns and .name==$name) | .value] | first // "");
      .items[]?
      | select((attr("enroll"; "hostname") == $host) or (attr("enroll"; "primary_ip") == $ip) or (attr("enroll"; "fqdn") == $target))
      | .id // empty
    ' | sed -n '1p'
}

wait_for_enrollment() {
  local target="$1"
  local node_id=""
  local level=""
  local status_json
  local node_json
  local required_skills_missing
  local workflow_ok
  local approved=false

  for _ in $(seq 1 60); do
    node_id="$(find_node_id "${target}")"
    if [[ -n "${node_id}" ]]; then
      node_json="$(chef-node-management-cli management node find-one-node --nodeId "${node_id}" --profile "${CHEF360_PROFILE}" --format json)"
      level="$(printf '%s' "${node_json}" | jq -r '.item.enrollmentLevel // .enrollmentLevel // empty')"
      if [[ "${level}" == "admitted" && "${CHEF360_AUTO_APPROVE}" == "true" && "${approved}" == "false" ]]; then
        log_step "Approving admitted Chef 360 node ${node_id}"
        chef-node-management-cli management node approve-node --nodeId "${node_id}" --profile "${CHEF360_PROFILE}" --format json >/dev/null
        approved=true
      fi
      if [[ "${level}" == "enrolled" ]]; then
        status_json="$(chef-node-management-cli status get-status --nodeId "${node_id}" --profile "${CHEF360_PROFILE}" --format json 2>/dev/null || true)"
        required_skills_missing="$(printf '%s' "${node_json}" | jq -r '
          ["courier-runner", "shell-interpreter", "chef-client-interpreter"] as $required
          | [(.item.skills // .skills // [])[]? | (.name // .skillName // .package.name // "") | sub("^.*/"; "")] as $installed
          | $required[] as $skill | select(($installed | index($skill)) == null) | $skill
        ')"
        workflow_ok="$(printf '%s' "${status_json}" | jq -r '(.item.stateWorkflow // []) as $steps | (($steps | length) > 0 and all($steps[]; ((.status // "") | ascii_downcase) == "success"))' 2>/dev/null || true)"
        if [[ -z "${required_skills_missing}" && "${workflow_ok}" == "true" ]]; then
          log_step "Chef 360 enrollment verified for ${target} (${node_id})"
          return
        fi
      fi
    fi
    sleep 10
  done

  printf "Chef 360 enrollment did not complete for target: %s\n" "${target}"
  exit 1
}

if [[ -z "${SSH_PRIVATE_KEY}" ]]; then
  printf "Usage: %s <ssh-private-key> [chef-node-user] [node1-target] [node2-target]\n" "$(basename "$0")"
  exit 1
fi

if [[ ! -f "${SSH_PRIVATE_KEY}" ]]; then
  printf "SSH private key not found: %s\n" "${SSH_PRIVATE_KEY}"
  exit 1
fi

require_command "ssh"
require_command "scp"
require_command "ssh-keyscan"
bash "${ENSURE_SSH_ACCESS_SCRIPT}" "${RESOURCE_GROUP:-rg-chef360-linux}" "${NAME_PREFIX:-${OBJECT_OWNER_PREFIX:-chef360}-sa-linux}" "${SSH_SOURCE_CIDR_OVERRIDE}" >/dev/null

if [[ -z "${CHEF360_SERVER}" || -z "${CHEF360_SIGNED_CONFIG_FILE}" ]]; then
  log_step "Skipping Chef 360 registration: CHEF360_SERVER and/or CHEF360_SIGNED_CONFIG_FILE not set"
  exit 0
fi

if [[ ! -f "${CHEF360_SIGNED_CONFIG_FILE}" ]]; then
  printf "Chef 360 signed config file not found: %s\n" "${CHEF360_SIGNED_CONFIG_FILE}"
  exit 1
fi

require_command "chef-node-management-cli"
require_command "jq"

if [[ -n "${CHEF360_COHORT_NAME}" && -z "${CHEF360_COHORT_ID}" ]]; then
  printf "CHEF360_COHORT_NAME is set to '%s' but CHEF360_COHORT_ID is not set.\n" "${CHEF360_COHORT_NAME}"
  printf "Create the cohort in Chef 360 first, then set CHEF360_COHORT_ID to enroll nodes into it.\n"
  exit 1
fi

if [[ -n "${CHEF360_COHORT_ID}" ]]; then
  log_step "Nodes will enroll into cohort ID '${CHEF360_COHORT_ID}'${CHEF360_COHORT_NAME:+ (name: ${CHEF360_COHORT_NAME})}"
else
  log_step "CHEF360_COHORT_ID is not set; nodes will enroll without a cohort"
fi

for node in "${NODE1_TARGET}" "${NODE2_TARGET}"; do
  log_step "Registering ${node} with Chef 360"
  seed_host_key_if_missing "${node}"

  if [[ -n "$(find_node_id "${node}")" ]]; then
    log_step "Chef 360 node already exists for ${node}; skipping re-enrollment"
    wait_for_enrollment "${node}"
    continue
  fi

  scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" \
    "${CHEF360_SIGNED_CONFIG_FILE}" "${CHEF_NODE_USER}@${node}:/tmp/chef-node-enrollment-cli.txt"

  if [[ -n "${CHEF360_COHORT_ID}" ]]; then
    ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node}" \
      "set -euo pipefail; export SERVER=\"${CHEF360_SERVER}\"; curl -sk \"\$SERVER/platform/bundledtools/v1/static/install.sh\" | TOOL=chef-node-enrollment-cli SERVER=\"\$SERVER\" VERSION=latest bash -; sudo mkdir -p /opt/chef-360/chef-node-enrollment-cli; sudo mv /tmp/chef-node-enrollment-cli.txt /opt/chef-360/chef-node-enrollment-cli/chef-node-enrollment-cli.txt; sudo chmod 600 /opt/chef-360/chef-node-enrollment-cli/chef-node-enrollment-cli.txt; sudo chef-node-enrollment-cli enroll-node --cohortId \"${CHEF360_COHORT_ID}\" --sign-config-file /opt/chef-360/chef-node-enrollment-cli/chef-node-enrollment-cli.txt"
  else
    ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node}" \
      "set -euo pipefail; export SERVER=\"${CHEF360_SERVER}\"; curl -sk \"\$SERVER/platform/bundledtools/v1/static/install.sh\" | TOOL=chef-node-enrollment-cli SERVER=\"\$SERVER\" VERSION=latest bash -; sudo mkdir -p /opt/chef-360/chef-node-enrollment-cli; sudo mv /tmp/chef-node-enrollment-cli.txt /opt/chef-360/chef-node-enrollment-cli/chef-node-enrollment-cli.txt; sudo chmod 600 /opt/chef-360/chef-node-enrollment-cli/chef-node-enrollment-cli.txt; sudo chef-node-enrollment-cli enroll-node --sign-config-file /opt/chef-360/chef-node-enrollment-cli/chef-node-enrollment-cli.txt"
  fi
  wait_for_enrollment "${node}"
done

log_step "Chef 360 node registration completed"
