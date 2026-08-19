#!/usr/bin/env bash
set -euo pipefail

COHORT_NAME="${1:-all-nodes}"
SETTING_ID="${2:-${CHEF360_SETTING_ID:-}}"
SKILL_ASSEMBLY_ID="${3:-${CHEF360_SKILL_ASSEMBLY_ID:-}}"
DESCRIPTION="${4:-Cohort for demo nodes}"
PROFILE="${5:-${CHEF360_PROFILE:-default}}"

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

require_command "chef-node-management-cli"
require_command "jq"

log_step "Looking up cohort '${COHORT_NAME}'"
existing_id="$({ chef-node-management-cli management cohort find-all-cohorts --profile "${PROFILE}"; } | jq -r --arg n "${COHORT_NAME}" '.items[]? | select(.name == $n) | (.cohortId // .id)' | sed -n '1p')"

if [[ -n "${existing_id}" ]]; then
  log_step "Cohort already exists: ${COHORT_NAME} (${existing_id})"
  printf "COHORT_ID=%s\n" "${existing_id}"
  exit 0
fi

if [[ -z "${SETTING_ID}" || -z "${SKILL_ASSEMBLY_ID}" ]]; then
  printf "Cohort '%s' was not found.\n" "${COHORT_NAME}"
  printf "To create it, provide setting and skill assembly IDs:\n"
  printf "  %s <cohort-name> <setting-id> <skill-assembly-id> [description] [profile]\n" "$(basename "$0")"
  printf "or set CHEF360_SETTING_ID and CHEF360_SKILL_ASSEMBLY_ID.\n"
  exit 1
fi

body_file="$(mktemp)"
trap 'rm -f "${body_file}"' EXIT

jq -n \
  --arg name "${COHORT_NAME}" \
  --arg description "${DESCRIPTION}" \
  --arg settingId "${SETTING_ID}" \
  --arg skillAssemblyId "${SKILL_ASSEMBLY_ID}" \
  '{name:$name, description:$description, settingId:$settingId, skillAssemblyId:$skillAssemblyId}' > "${body_file}"

log_step "Creating cohort '${COHORT_NAME}'"
create_out="$(chef-node-management-cli management cohort create-cohort --body-file "${body_file}" --profile "${PROFILE}")"
created_id="$(printf "%s" "${create_out}" | jq -r '.item.cohortId // .item.id // empty')"

if [[ -z "${created_id}" ]]; then
  printf "Failed to parse cohort ID from create-cohort output.\n"
  exit 1
fi

log_step "Cohort created: ${COHORT_NAME} (${created_id})"
printf "COHORT_ID=%s\n" "${created_id}"
