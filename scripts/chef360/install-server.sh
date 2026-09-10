#!/usr/bin/env bash
set -euo pipefail

INSTALLER=""
LICENSE_FILE=""
CONFIG_VALUES=""
PASSWORD_ENV="CHEF360_ADMIN_CONSOLE_PASSWORD"
DATA_DIR=""
IGNORE_HOST_PREFLIGHTS=0
SKIP_HOST_CHECK=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") --installer PATH --license PATH --config-values PATH [options]

Options:
  --admin-console-password-env NAME  Environment variable containing the password
                                     (default: CHEF360_ADMIN_CONSOLE_PASSWORD)
  --data-dir PATH                    Override Embedded Cluster's data directory
  --ignore-host-preflights          Lab-only: pass the installer bypass flag
  --skip-host-check                 Skip this repository's preliminary host check
  -h, --help                        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --installer) INSTALLER="${2:?Missing value for --installer}"; shift 2 ;;
    --license) LICENSE_FILE="${2:?Missing value for --license}"; shift 2 ;;
    --config-values) CONFIG_VALUES="${2:?Missing value for --config-values}"; shift 2 ;;
    --admin-console-password-env) PASSWORD_ENV="${2:?Missing value for --admin-console-password-env}"; shift 2 ;;
    --data-dir) DATA_DIR="${2:?Missing value for --data-dir}"; shift 2 ;;
    --ignore-host-preflights) IGNORE_HOST_PREFLIGHTS=1; shift ;;
    --skip-host-check) SKIP_HOST_CHECK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

for required in INSTALLER LICENSE_FILE CONFIG_VALUES; do
  if [[ -z "${!required}" ]]; then
    printf 'Missing required argument for %s.\n' "${required}" >&2
    usage >&2
    exit 2
  fi
done

if [[ ! -x "${INSTALLER}" ]]; then
  printf 'Installer is missing or not executable: %s\n' "${INSTALLER}" >&2
  exit 1
fi
if [[ ! -r "${LICENSE_FILE}" ]]; then
  printf 'License is not readable: %s\n' "${LICENSE_FILE}" >&2
  exit 1
fi
if [[ ! -r "${CONFIG_VALUES}" ]]; then
  printf 'ConfigValues file is not readable: %s\n' "${CONFIG_VALUES}" >&2
  exit 1
fi
if ! grep -Eq '^kind:[[:space:]]*ConfigValues[[:space:]]*$' "${CONFIG_VALUES}" ||
   ! grep -Eq '^[[:space:]]*name:[[:space:]]*chef-360[[:space:]]*$' "${CONFIG_VALUES}"; then
  printf 'ConfigValues must contain kind ConfigValues and metadata.name chef-360: %s\n' "${CONFIG_VALUES}" >&2
  exit 1
fi
if [[ -z "${!PASSWORD_ENV:-}" ]]; then
  printf 'Required password environment variable is unset or empty: %s\n' "${PASSWORD_ENV}" >&2
  exit 1
fi

if ((SKIP_HOST_CHECK == 0)); then
  check_args=()
  [[ -n "${DATA_DIR}" ]] && check_args+=(--data-dir "${DATA_DIR}")
  "${SCRIPT_DIR}/check-host-requirements.sh" "${check_args[@]}"
fi

install_args=(
  install
  --license "${LICENSE_FILE}"
  --no-prompt
  --admin-console-password "${!PASSWORD_ENV}"
  --config-values "${CONFIG_VALUES}"
)
[[ -n "${DATA_DIR}" ]] && install_args+=(--data-dir "${DATA_DIR}")
((IGNORE_HOST_PREFLIGHTS == 1)) && install_args+=(--ignore-host-preflights)

printf 'Installing Chef 360 with ConfigValues from %s.\n' "${CONFIG_VALUES}"
if ((EUID == 0)); then
  "${INSTALLER}" "${install_args[@]}"
else
  sudo --preserve-env="${PASSWORD_ENV}" "${INSTALLER}" "${install_args[@]}"
fi
