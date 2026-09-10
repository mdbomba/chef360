#!/bin/bash

set -euo pipefail

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

read -r -s -p "Enter your Chef 360 authorization code: " AUTH
printf '\n'
trap 'unset AUTH' EXIT

# Read the header from stdin so the authorization code is not in curl's arguments.
printf 'Authorization: %s\n' "$AUTH" |
    curl --fail --location --show-error --header @- "$DOWNLOAD_URL" -o "$ARCHIVE"
unset AUTH
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
