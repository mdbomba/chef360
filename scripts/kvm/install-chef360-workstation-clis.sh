#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
SERVER="https://${VM_HOSTNAME}:31000"
STANDARD_INSTALL_PATH="/platform/bundledtools/v1/static/install.sh"
HABITAT_INSTALL_PATH="/platform/bundledtools/v1/static/installhab.sh"
STANDARD_TOOLS=(
  chef-platform-auth-cli
  chef-node-enrollment-cli
  chef-import-cli
  chef-node-management-cli
  chef-courier-cli
  chef-dsm-cli
)
HABITAT_TOOL="chef-habitat-cli"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute]

Without --execute, print the trusted CLI installation plan.
--execute  Download installer scripts from ${SERVER}, inspect them, and install all CLIs.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

cat <<EOF
Chef 360 workstation CLI installation plan
  Server:          ${SERVER}
  CA chain:        ${CHEF360_TLS_CHAIN}
  Standard script: ${STANDARD_INSTALL_PATH}
  Habitat script:  ${HABITAT_INSTALL_PATH}
  Version:         latest (standard CLIs)
  Tools:
EOF
printf '    %s\n' "${STANDARD_TOOLS[@]}" "${HABITAT_TOOL}"

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. No network request or installation occurred.\n'
  exit 0
fi

for command in bash curl grep mktemp; do require_command "${command}"; done
require_file "${CHEF360_TLS_CHAIN}"

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

download_installer() {
  local endpoint="$1"
  local output="$2"
  local attempt
  local retries="${CLI_DOWNLOAD_RETRIES:-4}"
  for attempt in $(seq 1 "${retries}"); do
    if curl --fail --silent --show-error --location --max-time 60 \
        --cacert "${CHEF360_TLS_CHAIN}" \
        --resolve "${VM_HOSTNAME}:31000:${VM_IP}" \
        "${SERVER}${endpoint}" \
        --output "${output}" \
        && [[ -s "${output}" ]] \
        && head -n 1 "${output}" | grep -Eq '^#!.*(ba)?sh' \
        && bash -n "${output}"; then
      return 0
    fi
    if (( attempt < retries )); then
      log_step "Retrying download of ${endpoint} (attempt ${attempt}/${retries})"
      sleep "${CLI_DOWNLOAD_RETRY_DELAY:-5}"
    fi
  done
  fail "Unable to download and validate ${endpoint} after ${retries} attempts"
}

standard_installer="${work_dir}/install.sh"
habitat_installer="${work_dir}/installhab.sh"
log_step "Downloading and validating Chef 360 CLI installer scripts"
download_installer "${STANDARD_INSTALL_PATH}" "${standard_installer}"
download_installer "${HABITAT_INSTALL_PATH}" "${habitat_installer}"

for tool in "${STANDARD_TOOLS[@]}"; do
  log_step "Installing ${tool}"
  CURL_CA_BUNDLE="${CHEF360_TLS_CHAIN}" \
    SSL_CERT_FILE="${CHEF360_TLS_CHAIN}" \
    TOOL="${tool}" SERVER="${SERVER}" VERSION="latest" \
    bash "${standard_installer}"
  command -v "${tool}" >/dev/null 2>&1 || fail "Installed command not found: ${tool}"
  if "${tool}" version >/dev/null 2>&1; then
    "${tool}" version
  else
    "${tool}" --help >/dev/null 2>&1 || fail "Installed command is not executable: ${tool}"
  fi
done

log_step "Installing ${HABITAT_TOOL}"
CURL_CA_BUNDLE="${CHEF360_TLS_CHAIN}" \
  SSL_CERT_FILE="${CHEF360_TLS_CHAIN}" \
  TOOL="${HABITAT_TOOL}" SERVER="${SERVER}" \
  bash "${habitat_installer}"
if command -v "${HABITAT_TOOL}" >/dev/null 2>&1; then
  "${HABITAT_TOOL}" --help >/dev/null 2>&1 || fail "Installed command is not executable: ${HABITAT_TOOL}"
elif command -v hab >/dev/null 2>&1; then
  hab --version
else
  fail "Neither ${HABITAT_TOOL} nor hab was found after installation"
fi

log_step "All Chef 360 workstation CLIs installed and verified"
