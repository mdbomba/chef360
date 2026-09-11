#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
AIRGAP=false
AUTH=""
VERSION="1.7.3"
BASE_URL="https://appservice.chef360.chef.io/embedded/chef-360/stable/${VERSION}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute] [--airgap] [--auth-token TOKEN]

Download the Chef 360 ${VERSION} installer, license, and optional air-gap bundle
from the Chef 360 distribution endpoint, verify the archive, and stage the files
that the KVM workflow expects:

  ${CHEF360_INSTALLER_SOURCE}
  ${CHEF360_LICENSE_SOURCE}
  ${ASSET_AIRGAP_SOURCE:-$(dirname "${CHEF360_INSTALLER_SOURCE}")/chef-360.airgap} (with --airgap)

The authorization code must come from the AUTH_TOKEN environment variable or
--auth-token so the header can be passed to curl on stdin. When neither is set
the script prompts, matching the quick-start helper.

--execute       Download and stage the assets.
--airgap        Fetch the full air-gapped bundle instead of the online package.
--auth-token    Authorization code; overrides the AUTH_TOKEN environment variable.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    --airgap) AIRGAP=true; shift ;;
    --auth-token) AUTH="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

if [[ "${AIRGAP}" == true ]]; then
  DOWNLOAD_URL="${BASE_URL}?airgap=true"
  ARCHIVE="chef-360-${VERSION}-airgap.tgz"
else
  DOWNLOAD_URL="${BASE_URL}"
  ARCHIVE="chef-360-${VERSION}.tgz"
fi

if [[ -z "${AUTH}" ]]; then
  if [[ -n "${AUTH_TOKEN:-}" ]]; then
    AUTH="${AUTH_TOKEN}"
  elif [[ "${EXECUTE}" == true ]]; then
    read -r -s -p "Enter your Chef 360 authorization code: " AUTH
    printf '\n'
  fi
fi

cat <<EOF
Chef 360 asset plan
  Archive:   ${ARCHIVE}
  Source:    ${BASE_URL}
  Mode:      ${AIRGAP:+air-gapped }${AIRGAP:+bundle}${AIRGAP:-online package}
  Installer: ${CHEF360_INSTALLER_SOURCE}
  License:   ${CHEF360_LICENSE_SOURCE}
  AUTH:      ${AUTH:+set (not printed)}
EOF

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. Nothing was downloaded. Use --execute with AUTH_TOKEN or --auth-token.\n'
  exit 0
fi

[[ -n "${AUTH}" ]] || fail "AUTH_TOKEN or --auth-token is required for --execute"

for command in curl install tar; do require_command "${command}"; done

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

printf 'Authorization: %s\n' "${AUTH}" |
  curl --fail --location --show-error --header @- "${DOWNLOAD_URL}" -o "${work_dir}/${ARCHIVE}"

tar -xzf "${work_dir}/${ARCHIVE}" -C "${work_dir}"
chmod 0700 "${work_dir}/chef-360"

[[ -x "${work_dir}/chef-360" ]] || fail "Archive did not contain an executable chef-360"
[[ -s "${work_dir}/license.yaml" ]] || fail "Archive did not contain a non-empty license.yaml"
version_output="$(cd "${work_dir}" && ./chef-360 version)"
grep -Eq '\| chef-360[[:space:]]+\| 1\.7\.3[[:space:]]+\|' <<<"${version_output}" || fail "Archive chef-360 is not version 1.7.3"
if [[ "${AIRGAP}" == true ]]; then
  [[ -s "${work_dir}/chef-360.airgap" ]] || fail "Air-gapped archive did not contain chef-360.airgap"
fi

assets_dir="$(dirname "${CHEF360_INSTALLER_SOURCE}")"
sudo install -d -m 0755 "${assets_dir}"
sudo install -m 0700 "${work_dir}/chef-360" "${CHEF360_INSTALLER_SOURCE}"
sudo install -m 0600 "${work_dir}/license.yaml" "${CHEF360_LICENSE_SOURCE}"

log_step "Staged Chef 360 1.7.3 assets"
printf '  %s -> %s\n' "chef-360" "${CHEF360_INSTALLER_SOURCE}"
printf '  %s -> %s\n' "license.yaml" "${CHEF360_LICENSE_SOURCE}"

save_kvm_state
printf 'Next: %s/deploy-chef360-checkpoint.sh --execute\n' "${SCRIPT_DIR}"