#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
FORCE=false
UBUNTU_RELEASE="${UBUNTU_RELEASE:-24.04.4}"
ISO_BASE_URL="${ISO_BASE_URL:-https://releases.ubuntu.com/${UBUNTU_RELEASE}}"
ISO_NAME="${ISO_NAME:-ubuntu-${UBUNTU_RELEASE}-live-server-amd64.iso}"
ISO_DOWNLOAD_URL="${ISO_DOWNLOAD_URL:-${ISO_BASE_URL}/${ISO_NAME}}"
ISO_SUMS_URL="${ISO_SUMS_URL:-${ISO_BASE_URL}/SHA256SUMS}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute] [--force]

Download the Ubuntu Server live ISO needed by the Chef 360 autoinstall workflow
and verify it against the published SHA256SUMS before installing it at
${UBUNTU_ISO}.

--execute  Download and install the ISO when it is missing or mismatched.
--force    Replace an existing ISO even when no mismatch is detected.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

for command in curl sha256sum; do require_command "${command}"; done

expected_sha="$(curl --fail --location --silent --show-error "${ISO_SUMS_URL}" | awk -v name="${ISO_NAME}" '$2 == name || $2 == ("*" name) {print $1}')"
[[ -n "${expected_sha}" ]] || fail "Published checksums at ${ISO_SUMS_URL} do not list ${ISO_NAME}"

cat <<EOF
Ubuntu ISO fetch plan
  Source:   ${ISO_DOWNLOAD_URL}
  Checksum: ${ISO_SUMS_URL}
  Expected: ${expected_sha}
  Target:   ${UBUNTU_ISO}
EOF

if [[ -f "${UBUNTU_ISO}" ]]; then
  actual_sha="$(sha256sum "${UBUNTU_ISO}" | cut -d' ' -f1)"
  if [[ "${actual_sha}" == "${expected_sha}" ]]; then
    printf 'PASS: existing ISO at %s already matches the published checksum\n' "${UBUNTU_ISO}"
    exit 0
  elif [[ "${FORCE}" != true ]]; then
    fail "Existing ISO checksum mismatch at ${UBUNTU_ISO}; use --force to replace it"
  else
    printf 'Replacing mismatched ISO at %s (old checksum verified ahead, new download is verified below)\n' "${UBUNTU_ISO}"
  fi
fi

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. Nothing was downloaded. Use --execute to fetch and verify the ISO.\n'
  exit 0
fi

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

curl --fail --location --show-error "${ISO_DOWNLOAD_URL}" -o "${work_dir}/${ISO_NAME}"
downloaded_sha="$(sha256sum "${work_dir}/${ISO_NAME}" | cut -d' ' -f1)"
[[ "${downloaded_sha}" == "${expected_sha}" ]] || fail "Downloaded ISO checksum mismatch: expected ${expected_sha}, got ${downloaded_sha}"

install -d -m 0755 "$(dirname "${UBUNTU_ISO}")"
sudo install -m 0644 "${work_dir}/${ISO_NAME}" "${UBUNTU_ISO}"
save_kvm_state

printf 'Installed verified Ubuntu ISO at %s\n' "${UBUNTU_ISO}"
printf 'Next: %s/issue-chef360-certs.sh --execute\n' "${SCRIPT_DIR}"