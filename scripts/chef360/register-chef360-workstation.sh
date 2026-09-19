#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=scripts/lib/load-parameters.sh
source "${PROJECT_ROOT}/scripts/lib/load-parameters.sh"
load_chef360_parameters "${PROJECT_ROOT}"

ENDPOINT="${CHEF360_ENDPOINT:-${CHEF360_SERVER:-}}"
PROFILE="${CHEF360_PROFILE:-default}"
DEVICE_NAME="${CHEF360_DEVICE_NAME:-$(hostname -s)}"
CA_FILE="${CHEF360_CA_FILE:-}"
INSECURE="${CHEF360_INSECURE:-false}"
OVERWRITE=false
SET_DEFAULT=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Register this management workstation with a Chef 360 tenant through interactive
browser authorization, then verify the role associated with the local profile.

Options:
  --endpoint URL       Chef 360 tenant URL (default: CHEF360_ENDPOINT)
  --profile NAME       Local CLI profile name (default: CHEF360_PROFILE or default)
  --device-name NAME   Device name recorded by Chef 360 (default: host name)
  --cafile PATH        CA certificate or chain used to verify the endpoint
  --insecure           Skip TLS verification for an isolated lab only
  --overwrite          Replace an existing profile with the same name
  --set-default        Set the registered profile as the CLI default
  -h, --help           Show this help

Environment equivalents:
  CHEF360_ENDPOINT, CHEF360_PROFILE, CHEF360_DEVICE_NAME, CHEF360_CA_FILE,
  CHEF360_INSECURE

Registration does not grant or create roles. The identity and active role are
selected during browser authorization and must already exist in Chef 360.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_value() {
  local option="$1"
  local value="${2:-}"
  [[ -n "${value}" ]] || fail "${option} requires a value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint)
      require_value "$1" "${2:-}"
      ENDPOINT="$2"
      shift 2
      ;;
    --profile)
      require_value "$1" "${2:-}"
      PROFILE="$2"
      shift 2
      ;;
    --device-name)
      require_value "$1" "${2:-}"
      DEVICE_NAME="$2"
      shift 2
      ;;
    --cafile)
      require_value "$1" "${2:-}"
      CA_FILE="$2"
      shift 2
      ;;
    --insecure)
      INSECURE=true
      shift
      ;;
    --overwrite)
      OVERWRITE=true
      shift
      ;;
    --set-default)
      SET_DEFAULT=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

command -v chef-platform-auth-cli >/dev/null 2>&1 || fail "chef-platform-auth-cli is not installed"

[[ "${ENDPOINT}" =~ ^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?$ ]] || \
  fail "Endpoint must be a complete HTTPS origin with an optional port"
[[ "${PROFILE}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || \
  fail "Profile may contain only letters, numbers, periods, underscores, and hyphens"
[[ "${DEVICE_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || \
  fail "Device name may contain only letters, numbers, periods, underscores, and hyphens"
[[ "${INSECURE}" == true || "${INSECURE}" == false ]] || \
  fail "CHEF360_INSECURE must be true or false"

if [[ -n "${CA_FILE}" && "${INSECURE}" == true ]]; then
  fail "Use either --cafile or --insecure, not both"
fi
if [[ -n "${CA_FILE}" && ! -r "${CA_FILE}" ]]; then
  fail "CA file is not readable: ${CA_FILE}"
fi

profile_exists=false
while IFS= read -r line; do
  if [[ "${line}" =~ ^[[:space:]]+[0-9]+\.[[:space:]]+(.+)$ && "${BASH_REMATCH[1]}" == "${PROFILE}" ]]; then
    profile_exists=true
    break
  fi
done < <(chef-platform-auth-cli list-profile-names)

if [[ "${profile_exists}" == true && "${OVERWRITE}" != true ]]; then
  fail "Profile '${PROFILE}' already exists; use a different name or pass --overwrite"
fi

register_args=(
  register-device
  --device-name "${DEVICE_NAME}"
  --profile-name "${PROFILE}"
  --url "${ENDPOINT}"
)
if [[ -n "${CA_FILE}" ]]; then
  register_args+=(--cafile "${CA_FILE}")
elif [[ "${INSECURE}" == true ]]; then
  register_args+=(--insecure)
fi
if [[ "${OVERWRITE}" == true ]]; then
  register_args+=(--overwrite)
fi

printf 'Registering device %q with %s as local profile %q.\n' "${DEVICE_NAME}" "${ENDPOINT}" "${PROFILE}"
printf 'Complete the browser authorization using the intended tenant, organization, and role.\n'
chef-platform-auth-cli "${register_args[@]}"

printf '\nVerifying the active role for profile %q:\n' "${PROFILE}"
chef-platform-auth-cli user-account self get-role --profile "${PROFILE}" --format json

if [[ "${SET_DEFAULT}" == true ]]; then
  chef-platform-auth-cli set-default-profile "${PROFILE}"
  printf 'Set %q as the default Chef 360 CLI profile.\n' "${PROFILE}"
fi

printf '\nAvailable local profile names:\n'
chef-platform-auth-cli list-profile-names
printf 'WORKSTATION_PROFILE=%s\n' "${PROFILE}"
