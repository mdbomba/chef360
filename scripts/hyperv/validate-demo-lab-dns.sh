#!/usr/bin/env bash
# Validate that the pfSense router (10.0.0.2) functions as a DNS server and
# resolves the expected demo.lab hosts from config/demo-lab.env.
# Read-only: queries DNS and reachability only; never changes the router.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${ROOT_DIR}/config/demo-lab.env"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Missing DNS manifest: ${MANIFEST}" >&2
  echo "Create it from the header comments in config/demo-lab.env." >&2
  exit 2
fi

DNS_SERVER=""
DNS_DOMAIN=""
declare -a RECORDS

while IFS= read -r line || [[ -n "${line}" ]]; do
  line="${line%$'\r'}"
  [[ -z "${line}" || "${line}" == \#* ]] && continue
  case "${line}" in
    DNS_SERVER=*)
      DNS_SERVER="${line#DNS_SERVER=}"
      ;;
    DNS_DOMAIN=*)
      DNS_DOMAIN="${line#DNS_DOMAIN=}"
      ;;
    *=*)
      RECORDS+=("${line}")
      ;;
  esac
done < "${MANIFEST}"

[[ -n "${DNS_SERVER}" ]] || { echo "DNS_SERVER missing in ${MANIFEST}" >&2; exit 2; }

# resolve_fwd <name> -> prints A record or nothing.
resolve_fwd() {
  powershell.exe -NoProfile -Command \
    "(Resolve-DnsName -Name '$1' -Server '${DNS_SERVER}' -Type A -ErrorAction SilentlyContinue | Where-Object { \$_.Type -eq 'A' } | ForEach-Object { \$_.IPAddress }) -join ','" \
    2>/dev/null | tr -d '\r'
}

# resolve_ptr <ip> -> prints PTR hostname or nothing.
resolve_ptr() {
  powershell.exe -NoProfile -Command \
    "(Resolve-DnsName -Name '$1' -Server '${DNS_SERVER}' -Type PTR -ErrorAction SilentlyContinue | Where-Object { \$_.Type -eq 'PTR' } | ForEach-Object { \$_.NameHost }) -join ','" \
    2>/dev/null | tr -d '\r'
}

pass=0
fail=0

# 1. Is the router answering DNS at all?
tcp53="$(nc -z -w 2 "${DNS_SERVER}" 53 2>/dev/null && echo open || echo closed)"
echo "[router] ${DNS_SERVER} TCP/53: ${tcp53}"
pub="$(resolve_fwd github.com)"
if [[ -n "${pub}" ]]; then
  echo "[router] recursion github.com -> ${pub}"
  pass=$((pass + 1))
else
  echo "[router] recursion github.com -> FAILED"
  fail=$((fail + 1))
fi

# 2. Forward and reverse lookups for every manifest record.
for rec in "${RECORDS[@]}"; do
  fqdn="${rec%%=*}"
  ip="${rec#*=}"
  fwd="$(resolve_fwd "${fqdn}")"
  ptr="$(resolve_ptr "${ip}")"
  if [[ "${fwd}" == "${ip}"* ]]; then
    printf '%-30s -> %s  [OK]\n' "${fqdn}" "${fwd}"
    pass=$((pass + 1))
  else
    printf '%-30s -> %s  [MISSING forward: expected %s]\n' "${fqdn}" "${fwd:-<none>}" "${ip}"
    fail=$((fail + 1))
  fi
  if [[ -n "${ptr}" ]]; then
    if [[ "${ptr}" == "${fqdn}" ]]; then
      printf '%-30s (PTR %s)   %s  [OK]\n' "${ip}" "${fqdn}" "${ptr}"
      pass=$((pass + 1))
    else
      printf '%-30s (PTR %s)   %s  [MISMATCH]\n' "${ip}" "${fqdn}" "${ptr}"
      fail=$((fail + 1))
    fi
  else
    printf '%-30s (PTR %s)   <none>  [MISSING reverse]\n' "${ip}" "${fqdn}"
    fail=$((fail + 1))
  fi
done

echo "----------------------------------------"
echo "pass=${pass} fail=${fail}"
[[ "${fail}" -eq 0 ]]