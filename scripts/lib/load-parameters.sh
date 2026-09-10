#!/usr/bin/env bash

load_env_defaults() {
  local file="$1"
  local line key value

  [[ -f "${file}" ]] || return 0

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    if [[ ! "${line}" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      printf 'Invalid parameter line in %s: %s\n' "${file}" "${line}" >&2
      return 1
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    if [[ "${value}" =~ ^\"(.*)\"$ || "${value}" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    if [[ -z "${!key+x}" ]]; then
      printf -v "${key}" '%s' "${value}"
      export "${key}"
    fi
  done < "${file}"
}

# load_secret VAR [rc_file ...]
#   Resolve a secret/value for the named variable. Returns the currently
#   exported value if already set in the environment; otherwise scans
#   `export VAR="..."` lines in ~/.bashrc (override the search order with
#   explicit rc_file arguments). Exports VAR when found; returns 1 otherwise.
load_secret() {
  local var="${1:?load_secret: variable name required}"
  shift
  local rcs=("$@")
  local rc line value
  (( ${#rcs[@]} > 0 )) || rcs=("${HOME}/.bashrc")
  if [[ -n "${!var:+x}" ]]; then
    export "${var}"
    return 0
  fi
  for rc in "${rcs[@]}"; do
    [[ -r "${rc}" ]] || continue
    while IFS= read -r line; do
      line="${line%$'\r'}"
      [[ "${line}" =~ ^[[:space:]]*(export[[:space:]]+)?${var}=(.*)$ ]] || continue
      value="${BASH_REMATCH[2]}"
      value="${value%%\#*}"
      value="${value#\"}"; value="${value%\"}"
      value="${value#\'}"; value="${value%\'}"
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"
      if [[ -n "${value}" ]]; then
        export "${var}=${value}"
        return 0
      fi
    done < "${rc}"
  done
  return 1
}

load_chef360_parameters() {
  local project_root="$1"
  local parameters_file="${CHEF360_PARAMETERS_FILE:-${project_root}/config/chef360.parameters.env}"
  local endpoint authority port

  load_env_defaults "${parameters_file}"

  PROVIDER="${PROVIDER:-azure.com}"
  case "${PROVIDER}" in
    azure.com|azure.us|hyperv|kvm|aws.com|aws.gov) ;;
    *)
      printf 'Invalid PROVIDER %q. Expected azure.com, azure.us, hyperv, kvm, aws.com, or aws.gov.\n' "${PROVIDER}" >&2
      return 1
      ;;
  esac

  if [[ -n "${CHEF360_ENDPOINT:-}" ]]; then
    if [[ ! "${CHEF360_ENDPOINT}" =~ ^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?$ ]]; then
      printf 'Invalid CHEF360_ENDPOINT %q. Expected an HTTPS URL with an optional port.\n' "${CHEF360_ENDPOINT}" >&2
      return 1
    fi
    authority="${CHEF360_ENDPOINT#https://}"
    if [[ "${authority}" == *:* ]]; then
      port="${authority##*:}"
      if ((port < 1 || port > 65535)); then
        printf 'Invalid CHEF360_ENDPOINT port: %s\n' "${port}" >&2
        return 1
      fi
    fi
    CHEF360_SERVER="${CHEF360_SERVER:-${CHEF360_ENDPOINT}}"
  fi

  export PROVIDER CHEF360_SERVER
}
