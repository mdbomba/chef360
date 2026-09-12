#!/usr/bin/env bash
set -euo pipefail

# Set AIRGAP=true to download the air-gapped package.
VERSION="1.7.3"
AIRGAP=false
CHECK_LATEST=true
RELEASE_NOTES_URL="https://docs.chef.io/360/1.7/release_notes/"
BASE_URL="https://appservice.chef360.chef.io/embedded/chef-360/stable/${VERSION}"

check_latest() {
  local latest
  latest="$(curl --fail --location --silent --show-error --max-time 15 "${RELEASE_NOTES_URL}" 2>/dev/null | grep -Eom1 'Chef 360 Platform [0-9]+\.[0-9]+\.[0-9]+' | awk '{print $4}' || true)"
  if [[ -z "${latest}" ]]; then
    printf 'WARN: Could not check the latest documented Chef 360 release; using %s.\n' "${VERSION}" >&2
  elif [[ "${latest}" == "${VERSION}" ]]; then
    printf 'Chef 360 Platform %s is the latest documented release.\n' "${VERSION}"
  else
    printf 'WARN: Latest documented release is %s; this download remains pinned to %s.\n' "${latest}" "${VERSION}" >&2
  fi
}

if [[ "${CHECK_LATEST}" == true ]]; then check_latest; fi
if [[ "${AIRGAP}" == true ]]; then
  DOWNLOAD_URL="${BASE_URL}?airgap=true"
  ARCHIVE="chef-360-${VERSION}-airgap.tgz"
else
  DOWNLOAD_URL="${BASE_URL}"
  ARCHIVE="chef-360-${VERSION}.tgz"
fi

read -r -s -p 'Enter Chef 360 authorization code: ' AUTH_CODE
printf '\n'
trap 'unset AUTH_CODE' EXIT
printf 'Authorization: %s\n' "${AUTH_CODE}" | curl --fail --location --show-error --header @- "${DOWNLOAD_URL}" --output "${ARCHIVE}"
unset AUTH_CODE
trap - EXIT

tar -xzf "${ARCHIVE}"
[[ -x chef-360 ]] || { printf 'Package did not provide executable chef-360.\n' >&2; exit 1; }
[[ -s license.yaml ]] || { printf 'Package did not provide license.yaml.\n' >&2; exit 1; }
if [[ "${AIRGAP}" == true ]]; then
  [[ -s chef-360.airgap ]] || { printf 'Package did not provide chef-360.airgap.\n' >&2; exit 1; }
fi

printf 'Package extracted successfully. No installation was started.\n'
if [[ "${AIRGAP}" == true ]]; then
  printf 'Next: run install-server.sh with --installer ./chef-360 --license ./license.yaml --airgap-bundle ./chef-360.airgap.\n'
else
  printf 'Next: run install-server.sh with --installer ./chef-360 --license ./license.yaml.\n'
fi
