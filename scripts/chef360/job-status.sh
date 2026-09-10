#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/lib/load-parameters.sh"
load_chef360_parameters "${PROJECT_ROOT}"

JOB_ID="${1:-}"
POLL_SECONDS="${2:-10}"
PROFILE="${3:-${CHEF360_PROFILE:-default}}"

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

if [[ -z "${JOB_ID}" ]]; then
  printf "Usage: %s <job-id> [poll-seconds] [profile]\n" "$(basename "$0")"
  exit 1
fi

if [[ ! "${POLL_SECONDS}" =~ ^[0-9]+$ || "${POLL_SECONDS}" -eq 0 ]]; then
  printf "poll-seconds must be a positive integer.\n"
  exit 1
fi

require_command "chef-courier-cli"
require_command "jq"

log_step "Watching latest instance for job ${JOB_ID}"

for _ in $(seq 1 120); do
  instance_json="$(chef-courier-cli state instance list-all --job-id "${JOB_ID}" --pagination.size 1 --profile "${PROFILE}")"
  instance_id="$(printf "%s" "${instance_json}" | jq -r '.items[0].id // empty')"
  status="$(printf "%s" "${instance_json}" | jq -r '.items[0].status // empty')"

  if [[ -n "${instance_id}" && -n "${status}" ]]; then
    printf "INSTANCE_ID=%s\n" "${instance_id}"
    printf "STATUS=%s\n" "${status}"

    if [[ "${status}" == "success" || "${status}" == "failure" ]]; then
      run_id="$(chef-courier-cli state instance list-instance-runs --instanceId "${instance_id}" --pagination.size 1 --profile "${PROFILE}" | jq -r '.items[0].runId // empty')"
      if [[ -n "${run_id}" ]]; then
        printf "RUN_ID=%s\n" "${run_id}"
        chef-courier-cli state run list-steps --runId "${run_id}" --profile "${PROFILE}" | jq -r '.items[]? | "STEP=\(.name // \"unknown\") STATUS=\(.status // \"unknown\")"'
      fi
      if [[ "${status}" == "success" ]]; then
        exit 0
      fi
      exit 1
    fi
  else
    log_step "No job instances visible yet"
  fi

  sleep "${POLL_SECONDS}"
done

printf "Timed out waiting for terminal job status.\n"
exit 1
