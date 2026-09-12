#!/usr/bin/env bash
set -euo pipefail

INSTALLER=""
LICENSE_FILE=""
CONFIG_VALUES=""
TLS_CERT=""
TLS_KEY=""
HOSTNAME=""
AIRGAP_BUNDLE=""
DATA_DIR=""
PASSWORD_ENV="CHEF360_ADMIN_CONSOLE_PASSWORD"
INTERACTIVE=false
IGNORE_HOST_PREFLIGHTS=false
IGNORE_APP_PREFLIGHTS=false
SKIP_HOST_CHECK=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") --installer PATH --license PATH [options]

Options:
  --config-values PATH                 Optional ConfigValues export from a working installation
  --tls-cert PATH --tls-key PATH       Optional matching Admin Console TLS pair
  --hostname FQDN                      Optional Admin Console hostname
  --airgap-bundle PATH                 Optional Chef 360 air-gap bundle
  --admin-console-password-env NAME    Password variable (default: CHEF360_ADMIN_CONSOLE_PASSWORD)
  --data-dir PATH                      Embedded Cluster data directory
  --ignore-host-preflights             Pass the reviewed host-preflight bypass
  --ignore-app-preflights              Pass the reviewed application-preflight bypass
  --skip-host-check                    Skip this repository's host requirement check
  --interactive                        Prompt for a short password/hostname and require confirmation
  -h, --help                           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --installer) INSTALLER="${2:?Missing value for --installer}"; shift 2 ;;
    --license) LICENSE_FILE="${2:?Missing value for --license}"; shift 2 ;;
    --config-values) CONFIG_VALUES="${2:?Missing value for --config-values}"; shift 2 ;;
    --tls-cert) TLS_CERT="${2:?Missing value for --tls-cert}"; shift 2 ;;
    --tls-key) TLS_KEY="${2:?Missing value for --tls-key}"; shift 2 ;;
    --hostname) HOSTNAME="${2:?Missing value for --hostname}"; shift 2 ;;
    --airgap-bundle) AIRGAP_BUNDLE="${2:?Missing value for --airgap-bundle}"; shift 2 ;;
    --admin-console-password-env) PASSWORD_ENV="${2:?Missing value for --admin-console-password-env}"; shift 2 ;;
    --data-dir) DATA_DIR="${2:?Missing value for --data-dir}"; shift 2 ;;
    --ignore-host-preflights) IGNORE_HOST_PREFLIGHTS=true; shift ;;
    --ignore-app-preflights) IGNORE_APP_PREFLIGHTS=true; shift ;;
    --skip-host-check) SKIP_HOST_CHECK=true; shift ;;
    --interactive) INTERACTIVE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -x "${INSTALLER}" ]] || { printf 'Installer is missing or not executable: %s\n' "${INSTALLER}" >&2; exit 1; }
[[ -r "${LICENSE_FILE}" ]] || { printf 'License is not readable: %s\n' "${LICENSE_FILE}" >&2; exit 1; }
[[ -z "${TLS_CERT}" && -z "${TLS_KEY}" || -n "${TLS_CERT}" && -n "${TLS_KEY}" ]] || {
  printf 'Supply both --tls-cert and --tls-key, or neither.\n' >&2; exit 1;
}
[[ -z "${TLS_CERT}" || -r "${TLS_CERT}" ]] || { printf 'TLS certificate is not readable: %s\n' "${TLS_CERT}" >&2; exit 1; }
[[ -z "${TLS_KEY}" || -r "${TLS_KEY}" ]] || { printf 'TLS key is not readable: %s\n' "${TLS_KEY}" >&2; exit 1; }
[[ -z "${CONFIG_VALUES}" || -r "${CONFIG_VALUES}" ]] || { printf 'ConfigValues is not readable: %s\n' "${CONFIG_VALUES}" >&2; exit 1; }
[[ -z "${AIRGAP_BUNDLE}" || -r "${AIRGAP_BUNDLE}" ]] || { printf 'Air-gap bundle is not readable: %s\n' "${AIRGAP_BUNDLE}" >&2; exit 1; }

password="${!PASSWORD_ENV:-}"
if [[ "${INTERACTIVE}" == true ]]; then
  while [[ ${#password} -lt 12 ]]; do
    read -r -s -p 'Enter an Admin Console password (at least 12 characters): ' password
    printf '\n'
  done
  while [[ -z "${HOSTNAME}" ]]; do
    read -r -p 'Enter the Admin Console FQDN: ' HOSTNAME
  done
fi
[[ ${#password} -ge 12 ]] || { printf '%s must contain at least 12 characters.\n' "${PASSWORD_ENV}" >&2; exit 1; }

if [[ -n "${CONFIG_VALUES}" ]]; then
  grep -Eq '^kind:[[:space:]]*ConfigValues[[:space:]]*$' "${CONFIG_VALUES}" &&
    grep -Eq '^[[:space:]]*name:[[:space:]]*chef-360[[:space:]]*$' "${CONFIG_VALUES}" || {
      printf 'ConfigValues must contain kind ConfigValues and metadata.name chef-360: %s\n' "${CONFIG_VALUES}" >&2; exit 1;
    }
fi

printf 'Chef 360 installation plan\n'
printf '  Installer: %s\n  License: %s\n' "${INSTALLER}" "${LICENSE_FILE}"
tls_plan="not supplied"
[[ -z "${TLS_CERT}" ]] || tls_plan="supplied"
printf '  ConfigValues: %s\n  Admin Console TLS: %s\n  Hostname: %s\n' \
  "${CONFIG_VALUES:-not supplied}" "${tls_plan}" "${HOSTNAME:-not supplied}"
printf '  Air-gap bundle: %s\n  Host preflight bypass: %s\n  App preflight bypass: %s\n' \
  "${AIRGAP_BUNDLE:-not supplied}" "${IGNORE_HOST_PREFLIGHTS}" "${IGNORE_APP_PREFLIGHTS}"

if [[ "${INTERACTIVE}" == true ]]; then
  read -r -p 'Press Enter to install, or Ctrl-C to stop: '
fi

if [[ "${SKIP_HOST_CHECK}" != true ]]; then
  check_args=()
  [[ -z "${DATA_DIR}" ]] || check_args+=(--data-dir "${DATA_DIR}")
  "${SCRIPT_DIR}/check-host-requirements.sh" "${check_args[@]}"
fi

install_args=(install --license "${LICENSE_FILE}" --admin-console-password "${password}" --yes)
[[ -z "${HOSTNAME}" ]] || install_args+=(--hostname "${HOSTNAME}")
[[ -z "${CONFIG_VALUES}" ]] || install_args+=(--config-values "${CONFIG_VALUES}")
[[ -z "${TLS_CERT}" ]] || install_args+=(--tls-cert "${TLS_CERT}" --tls-key "${TLS_KEY}")
[[ -z "${AIRGAP_BUNDLE}" ]] || install_args+=(--airgap-bundle "${AIRGAP_BUNDLE}")
[[ -z "${DATA_DIR}" ]] || install_args+=(--data-dir "${DATA_DIR}")
[[ "${IGNORE_HOST_PREFLIGHTS}" != true ]] || install_args+=(--ignore-host-preflights)
[[ "${IGNORE_APP_PREFLIGHTS}" != true ]] || install_args+=(--ignore-app-preflights)

if (( EUID == 0 )); then
  "${INSTALLER}" "${install_args[@]}"
else
  sudo --preserve-env="${PASSWORD_ENV}" "${INSTALLER}" "${install_args[@]}"
fi
unset password
