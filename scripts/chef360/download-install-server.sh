#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/load-parameters.sh"

VERSION="1.7.3"
BASE_URL="https://appservice.chef360.chef.io/embedded/chef-360/stable/${VERSION}"

read -r -p "Download the air-gapped package? [y/N]: " AIRGAP
case "$AIRGAP" in
    [Yy])
        DOWNLOAD_URL="${BASE_URL}?airgap=true"
        ARCHIVE="chef-360-${VERSION}-airgap.tgz"
        AIRGAP=true
        ;;
    *)
        DOWNLOAD_URL="$BASE_URL"
        ARCHIVE="chef-360-${VERSION}.tgz"
        AIRGAP=false
        ;;
esac

# Take the authorization code from the environment or ~/.bashrc when present,
# otherwise prompt for it. Passing the header via stdin keeps the code out of
# curl's arguments.
if ! load_secret AUTH_TOKEN "${HOME}/.bashrc" "${HOME}/.profile"; then
    read -r -s -p "Enter your Chef 360 authorization code: " AUTH_TOKEN
    printf '\n'
fi
trap 'unset AUTH_TOKEN' EXIT

printf 'Authorization: %s\n' "$AUTH_TOKEN" |
    curl --fail --location --show-error --header @- "$DOWNLOAD_URL" -o "$ARCHIVE"
unset AUTH_TOKEN
trap - EXIT

tar -xzf "$ARCHIVE"
test -f chef-360
test -s license.yaml

if [[ "$AIRGAP" == true ]]; then
    test -s chef-360.airgap
    printf '%s\n' \
        "Air-gapped package ready." \
        "Transfer chef-360, chef-360.airgap, and license.yaml to the Chef 360 host." \
        "Also transfer and preload the release-specific Velero plugin images before installation." \
        "Then run: sudo ./chef-360 install --license license.yaml --airgap-bundle chef-360.airgap"
    exit 0
fi

sudo ./chef-360 install --license license.yaml
