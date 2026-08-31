#!/bin/bash

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
GUIDE="$REPO_ROOT/docs/quick-start/chef360-1.7.3-quick-start.md"
EXPORT_GUIDE="$REPO_ROOT/docs/quick-start/chef360-1.7.3-exportable-quick-start.md"
CHECKLIST="$REPO_ROOT/docs/quick-start/checklist.md"
QUICK_START_README="$REPO_ROOT/docs/quick-start/README.md"
GUIDANCE_DIFFERENCES="$REPO_ROOT/docs/quick-start/guidance-differences.md"
HELPER="$REPO_ROOT/scripts/chef360/download-install-server.sh"
PDF="$REPO_ROOT/docs/quick-start/Chef_360_Platform_1.7.3_Quick_Start.pdf"
PDF_STYLESHEET="$REPO_ROOT/docs/quick-start/customer-pdf.css"
PDF_BUILDER="$REPO_ROOT/scripts/content/build-quick-start-pdf.py"
PDF_REQUIREMENTS="$REPO_ROOT/scripts/content/requirements-quick-start-pdf.txt"
QUICK_START_FILES=("$GUIDE" "$EXPORT_GUIDE" "$CHECKLIST" "$QUICK_START_README" "$HELPER")
failures=0

pass() {
    printf 'PASS: %s\n' "$1"
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

require_text() {
    local file=$1
    local text=$2
    local description=$3

    if grep -Fq -- "$text" "$file"; then
        pass "$description"
    else
        fail "$description"
    fi
}

reject_pattern() {
    local pattern=$1
    local description=$2

    if grep -Ein -- "$pattern" "${QUICK_START_FILES[@]}" >/dev/null; then
        fail "$description"
        grep -Ein -- "$pattern" "${QUICK_START_FILES[@]}" >&2
    else
        pass "$description"
    fi
}

for file in "${QUICK_START_FILES[@]}" "$GUIDANCE_DIFFERENCES" "$PDF" "$PDF_STYLESHEET" "$PDF_BUILDER" "$PDF_REQUIREMENTS"; do
    if [[ -f "$file" ]]; then
        pass "${file#"$REPO_ROOT/"} exists"
    else
        fail "${file#"$REPO_ROOT/"} exists"
    fi
done

IFS= read -r -n 5 pdf_header < "$PDF" || true
if [[ "$pdf_header" == '%PDF-' ]]; then
    pass 'customer-facing PDF has a valid PDF header'
else
    fail 'customer-facing PDF has a valid PDF header'
fi

if bash -n "$HELPER"; then
    pass 'download and installation helper has valid Bash syntax'
else
    fail 'download and installation helper has valid Bash syntax'
fi

if bash -n "$SCRIPT_DIR/check-quick-start.sh"; then
    pass 'quick-start verifier has valid Bash syntax'
else
    fail 'quick-start verifier has valid Bash syntax'
fi

require_text "$GUIDE" 'Chef 360 Platform 1.7.3' 'guide targets Chef 360 Platform 1.7.3'
require_text "$EXPORT_GUIDE" 'Chef 360 Platform 1.7.3' 'exportable guide targets Chef 360 Platform 1.7.3'
require_text "$CHECKLIST" 'Chef 360 Platform 1.7.3' 'checklist targets Chef 360 Platform 1.7.3'
require_text "$HELPER" 'VERSION="1.7.3"' 'helper pins Chef 360 Platform 1.7.3'
require_text "$HELPER" '/stable/${VERSION}' 'helper constructs the stable version-specific download URL'
require_text "$HELPER" '?airgap=true' 'helper can select the air-gapped package'
require_text "$HELPER" '--airgap-bundle chef-360.airgap' 'helper installs the selected air-gapped bundle'
require_text "$GUIDE" 'TCP port `30000`' 'guide identifies the Admin Console port'
require_text "$GUIDE" 'https://<FQDN>:31000' 'guide identifies the Apps Console endpoint'
require_text "$GUIDE" 'TCP `31101`' 'guide identifies the Mailpit port'
require_text "$GUIDE" 'Mailpit uses HTTP rather than HTTPS' 'guide identifies the Mailpit protocol'
require_text "$EXPORT_GUIDE" 'https://<FQDN>:31000' 'exportable guide includes Apps Console account activation'
require_text "$EXPORT_GUIDE" 'http://<CHEF360-IP>:31101' 'exportable guide includes Mailpit account-registration access'

reject_pattern 'MailHog' 'quick-start files contain no stale MailHog terminology'
reject_pattern 'Chef 360 Platform 1\.7\.[012]([^0-9]|$)|/stable/1\.7\.[012]([^0-9]|$)' 'quick-start files contain no stale target versions'
reject_pattern 'TCP `?5671|:5671([^0-9]|$)' 'quick-start files contain no stale RabbitMQ 5671 exposure guidance'
reject_pattern 'TCP `?5985|TCP `?5986|:5985([^0-9]|$)|:5986([^0-9]|$)' 'quick-start files contain no WinRM quick-start port requirements'

embedded_script=$(mktemp)
trap 'rm -f "$embedded_script"' EXIT
awk '
    /<!-- BEGIN EMBEDDED SCRIPT: scripts\/chef360\/download-install-server.sh -->/ { marker = 1; next }
    marker && /^```bash$/ { script = 1; next }
    script && /^```$/ { exit }
    script { print }
' "$EXPORT_GUIDE" > "$embedded_script"
if cmp -s "$HELPER" "$embedded_script"; then
    pass 'exportable guide embeds the current download and installation helper'
else
    fail 'exportable guide embeds the current download and installation helper'
fi

marker_ids=$(grep -Eho 'GUIDANCE-DIFFERENCE: GD-[0-9]{3}(, GD-[0-9]{3})*' \
    "$GUIDE" "$EXPORT_GUIDE" "$CHECKLIST" | grep -Eo 'GD-[0-9]{3}' | sort -u)

marker_failure=0
while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if ! grep -Fq -- "## $id:" "$GUIDANCE_DIFFERENCES"; then
        fail "guidance marker $id has a register entry"
        marker_failure=1
    fi
done <<< "$marker_ids"
if [[ "$marker_failure" -eq 0 ]]; then
    pass 'all guidance-difference markers have register entries'
fi

if [[ "$failures" -gt 0 ]]; then
    printf '\nQuick-start verification failed with %d issue(s).\n' "$failures" >&2
    exit 1
fi

printf '\nQuick-start verification passed.\n'
