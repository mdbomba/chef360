#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/lib/load-parameters.sh"
load_chef360_parameters "${PROJECT_ROOT}"

COHORT_INPUT="${1:-${CHEF360_COHORT_NAME:-all-nodes}}"
JOB_NAME="${2:-chef360-demo-sleep}"
SLEEP_SECONDS="${3:-10}"
PROFILE="${4:-${CHEF360_PROFILE:-default}}"
COHORT_ID=""

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

if [[ -z "${COHORT_INPUT}" ]]; then
  printf "Usage: %s <cohort-id-or-name> [job-name] [sleep-seconds] [profile]\n" "$(basename "$0")"
  exit 1
fi

if [[ ! "${SLEEP_SECONDS}" =~ ^[0-9]+$ ]]; then
  printf "sleep-seconds must be a non-negative integer.\n"
  exit 1
fi

require_command "chef-courier-cli"
require_command "chef-node-management-cli"
require_command "jq"

COHORT_ID="$({ chef-node-management-cli management cohort find-all-cohorts --pagination.size 1000 --profile "${PROFILE}" --format json; } | jq -r --arg q "${COHORT_INPUT}" '.items[]? | select((.id == $q) or (.cohortId == $q) or (.name == $q)) | (.cohortId // .id)' | sed -n '1p')"

if [[ -z "${COHORT_ID}" ]]; then
  printf "Unable to resolve cohort from input: %s\n" "${COHORT_INPUT}"
  exit 1
fi

log_step "Target cohort resolved: ${COHORT_INPUT} -> ${COHORT_ID}"

existing_job_id="$({ chef-courier-cli scheduler jobs list-jobs --pagination.size 10000 --profile "${PROFILE}"; } | jq -r --arg n "${JOB_NAME}" '.items[]? | select(.name == $n) | .id' | sed -n '1p')"

if [[ -n "${existing_job_id}" ]]; then
  log_step "Job exists; activating '${JOB_NAME}' (${existing_job_id})"
  run_out="$(chef-courier-cli scheduler jobs activated-job --jobId "${existing_job_id}" --profile "${PROFILE}")"
  activated_job_id="$(printf "%s" "${run_out}" | jq -r '.item.id // empty')"
  printf "JOB_ID=%s\n" "${existing_job_id}"
  printf "ACTIVATED_JOB_ID=%s\n" "${activated_job_id}"
  exit 0
fi

body_file="$(mktemp)"
trap 'rm -f "${body_file}"' EXIT

jq -n \
  --arg name "${JOB_NAME}" \
  --arg description "Demo job that sleeps for ${SLEEP_SECONDS} seconds" \
  --arg cohortId "${COHORT_ID}" \
  --arg sleepSeconds "${SLEEP_SECONDS}" \
  '{
    name:$name,
    description:$description,
    scheduleRule:"immediate",
    exceptionRules:[],
    target:{
      executionType:"sequential",
      groups:[{
        timeoutSeconds:240,
        batchSize:{type:"percent", value:100},
        distributionMethod:"batching",
        successCriteria:[{numRuns:{type:"percent", value:100}, status:"success"}],
        nodeListType:"cohorts",
        nodeIdentifiers:[$cohortId]
      }]
    },
    actions:{
      accessMode:"agent",
      steps:[{
        name:"sleep-step",
        interpreter:{name:"chef-platform/shell-interpreter", skill:{minVersion:"1.0.0", maxVersion:"1.0.0"}},
        command:{linux:["sleep \($sleepSeconds)"], windows:["timeout \($sleepSeconds)"]},
        inputs:{},
        expectedInputs:{},
        outputFieldRules:{},
        retryCount:1,
        failureBehavior:{action:"retryThenFail", retryBackoffStrategy:{type:"linear", delaySeconds:1, arguments:[]}},
        limits:{},
        conditions:[]
      }]
    }
  }' > "${body_file}"

log_step "Creating and running job '${JOB_NAME}'"
create_out="$(chef-courier-cli scheduler jobs add-job --body-file "${body_file}" --profile "${PROFILE}")"
job_id="$(printf "%s" "${create_out}" | jq -r '.item.id // .Response201.item.id // empty')"

if [[ -z "${job_id}" ]]; then
  printf "Failed to parse job ID from add-job output.\n"
  printf "%s\n" "${create_out}"
  exit 1
fi

printf "JOB_ID=%s\n" "${job_id}"
