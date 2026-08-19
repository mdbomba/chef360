#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/lib/load-parameters.sh"
load_chef360_parameters "${PROJECT_ROOT}"

NODE_TARGET="${1:-}"
SSH_USER="${2:-chef}"
SSH_KEY_FILE="${3:-${HOME}/.ssh/id_ed25519}"
COHORT_ID="${4:-${CHEF360_COHORT_ID:-}}"
PROFILE="${5:-${CHEF360_PROFILE:-default}}"
NODE_URL="${6:-${NODE_TARGET}}"
COHORT_NAME="${CHEF360_COHORT_NAME:-}"
ENSURE_SSH_ACCESS_SCRIPT="${SCRIPT_DIR}/../azure/ensure-azure-ssh-access.sh"
SSH_SOURCE_CIDR_OVERRIDE="${SSH_SOURCE_CIDR:-}"

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

resolve_cohort_id() {
  if [[ -n "${COHORT_ID}" ]]; then
    return
  fi

  if [[ -z "${COHORT_NAME}" ]]; then
    return
  fi

  COHORT_ID="$({ chef-node-management-cli management cohort find-all-cohorts --pagination.size 1000 --profile "${PROFILE}" --format json; } | jq -r --arg n "${COHORT_NAME}" '.items[]? | select(.name == $n) | (.cohortId // .id)' | sed -n '1p')"
}

resolve_node_url() {
  if [[ -n "${NODE_URL}" && "${NODE_URL}" != "${NODE_TARGET}" ]]; then
    return
  fi

  if [[ "${NODE_TARGET}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    NODE_URL="${NODE_TARGET}"
    return
  fi

  resolved_ip="$(getent ahostsv4 "${NODE_TARGET}" 2>/dev/null | awk 'NR==1 {print $1}')"
  if [[ -n "${resolved_ip}" ]]; then
    NODE_URL="${resolved_ip}"
  fi
}

find_existing_node() {
  local hostname_short="$1"
  local primary_ip="$2"

  chef-node-management-cli management node find-all-nodes --pagination.size 1000 --profile "${PROFILE}" --format json | jq -r \
    --arg host "${hostname_short}" \
    --arg ip "${primary_ip}" \
    --arg target "${NODE_TARGET}" \
    --arg url "${NODE_URL}" \
    '
      def attr($ns; $name): ([.attributes[]? | select(.namespace==$ns and .name==$name) | .value] | first // "");
      .items[]?
      | . as $n
      | {
          id: $n.id,
          cohortId: ($n.cohortId // ""),
          host: ($n | attr("enroll"; "hostname")),
          ip: ($n | attr("enroll"; "primary_ip")),
          fqdn: ($n | attr("enroll"; "fqdn"))
        }
      | select(
          (.host != "" and .host == $host)
          or (.ip != "" and .ip == $ip)
          or (.fqdn != "" and (.fqdn == $target or .fqdn == $url))
        )
      | [.id, .cohortId, .host, .ip, .fqdn] | @tsv
    ' | sed -n '1p'
}

if [[ -z "${NODE_TARGET}" ]]; then
  printf "Usage: %s <node-target> [ssh-user] [ssh-key-file] [cohort-id] [profile] [node-url]\n" "$(basename "$0")"
  exit 1
fi

if [[ ! -f "${SSH_KEY_FILE}" ]]; then
  printf "SSH key file not found: %s\n" "${SSH_KEY_FILE}"
  exit 1
fi

require_command "chef-node-management-cli"
require_command "jq"
require_command "ssh"
require_command "getent"

if [[ -x "${ENSURE_SSH_ACCESS_SCRIPT}" ]]; then
  bash "${ENSURE_SSH_ACCESS_SCRIPT}" \
    "${RESOURCE_GROUP:-rg-chef360-linux}" \
    "${NAME_PREFIX:-${OBJECT_OWNER_PREFIX:-chef360}-sa-linux}" \
    "${SSH_SOURCE_CIDR_OVERRIDE}" >/dev/null
fi

if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_KEY_FILE}" "${SSH_USER}@${NODE_TARGET}" true >/dev/null 2>&1; then
  printf "SSH connectivity failed for %s@%s\n" "${SSH_USER}" "${NODE_TARGET}"
  exit 1
fi

resolve_cohort_id
resolve_node_url

if [[ -n "${COHORT_ID}" ]]; then
  log_step "Target cohort ID: ${COHORT_ID}${COHORT_NAME:+ (name: ${COHORT_NAME})}"
else
  log_step "No cohort ID resolved; enrollment will fail unless node is already enrolled"
fi

log_step "Enrollment URL set to '${NODE_URL}'"

remote_hostname="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_KEY_FILE}" "${SSH_USER}@${NODE_TARGET}" "hostname -s" 2>/dev/null || true)"
remote_primary_ip="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_KEY_FILE}" "${SSH_USER}@${NODE_TARGET}" "hostname -I | awk '{print \$1}'" 2>/dev/null || true)"

existing_node_line="$(find_existing_node "${remote_hostname}" "${remote_primary_ip}")"

if [[ -n "${existing_node_line}" ]]; then
  existing_node_id="$(printf "%s" "${existing_node_line}" | cut -f1)"
  existing_cohort_id="$(printf "%s" "${existing_node_line}" | cut -f2)"
  existing_host="$(printf "%s" "${existing_node_line}" | cut -f3)"
  existing_ip="$(printf "%s" "${existing_node_line}" | cut -f4)"

  log_step "Node already enrolled: id=${existing_node_id} host=${existing_host} ip=${existing_ip} cohort=${existing_cohort_id:-none}"

  if [[ -n "${COHORT_ID}" && "${existing_cohort_id}" != "${COHORT_ID}" ]]; then
    log_step "Assigning node '${existing_node_id}' to cohort '${COHORT_ID}'"
    chef-node-management-cli management node assign-cohort --nodeId "${existing_node_id}" --cohortId "${COHORT_ID}" --profile "${PROFILE}" >/dev/null
    log_step "Cohort assignment updated"
  fi

  printf "NODE_ID=%s\n" "${existing_node_id}"
  printf "ENROLLMENT_STATUS=already_enrolled\n"
  exit 0
fi

if [[ -z "${COHORT_ID}" ]]; then
  printf "Missing cohort ID. Provide argument 4, set CHEF360_COHORT_ID, or set CHEF360_COHORT_NAME to an existing cohort.\n"
  exit 1
fi

ssh_key_content="$(awk 'NF {sub(/\r/, ""); printf "%s\n", $0;}' "${SSH_KEY_FILE}")"

body_file="$(mktemp)"
trap 'rm -f "${body_file}"' EXIT

jq -n \
  --arg cohortId "${COHORT_ID}" \
  --arg url "${NODE_URL}" \
  --arg username "${SSH_USER}" \
  --arg key "${ssh_key_content}" \
  '{cohortId:$cohortId, url:$url, protocol:"SSH", sshCredentials:{username:$username, key:$key, port:22}}' > "${body_file}"

log_step "Enrolling node '${NODE_TARGET}' into cohort '${COHORT_ID}'"
enroll_out="$(chef-node-management-cli enrollment enroll-node --body-file "${body_file}" --body-format json --profile "${PROFILE}")"
enrollment_id="$(printf "%s" "${enroll_out}" | jq -r '.item.id // .item.enrollmentId // .id // .enrollmentId // empty')"

if [[ -z "${enrollment_id}" ]]; then
  printf "Failed to parse enrollment ID from enrollment response.\n"
  printf "%s\n" "${enroll_out}"
  exit 1
fi

log_step "Enrollment submitted"
printf "ENROLLMENT_ID=%s\n" "${enrollment_id}"
