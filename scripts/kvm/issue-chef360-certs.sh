#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
FORCE=false
CA_DIR="${KVM_CA_DIR:-${KVM_WORK_DIR}/${VM_NAME}-ca}"
ROOT_DAYS="${ROOT_DAYS:-3650}"
ISSUING_DAYS="${ISSUING_DAYS:-1825}"
LEAF_DAYS="${LEAF_DAYS:-825}"
ROOT_SUBJECT="${ROOT_SUBJECT:-/O=Chef 360 Lab/CN=Chef 360 Demo Root CA}"
ISSUING_SUBJECT="${ISSUING_SUBJECT:-/O=Chef 360 Lab/CN=Chef 360 Demo Issuing CA}"
LEAF_SUBJECT="${LEAF_SUBJECT:-/O=Chef 360 Lab/CN=${VM_HOSTNAME}}"

ROOT_KEY="${CA_DIR}/${VM_NAME}-rca.key"
ROOT_CRT="${CA_DIR}/${VM_NAME}-rca.crt"
ISSUING_KEY="${CA_DIR}/${VM_NAME}-ica.key"
ISSUING_CRT="${CA_DIR}/${VM_NAME}-ica.crt"
LEAF_CSR="${CA_DIR}/${VM_NAME}.csr"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute] [--force]

Issue the Chef 360 1.7.3 runtime certificates for ${VM_HOSTNAME}:

  ${CHEF360_TLS_CERT}   leaf certificate
  ${CHEF360_TLS_KEY}    leaf private key
  ${CHEF360_TLS_CHAIN}  issuing plus root CA bundle
  ${CHEF360_ISSUING_CA} issuing CA certificate
  ${CHEF360_ROOT_CA}    root CA certificate

The root and issuing CA keys remain under ${CA_DIR} (mode 0700) and are never
copied to the guest. The leaf certificate covers ${VM_HOSTNAME} and ${VM_IP}.

--execute  Generate or refresh the certificate files.
--force    Reissue the leaf certificate even when the existing one is valid.
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

require_command openssl

cat <<EOF
Chef 360 certificate plan
  Root CA:     ${CHEF360_ROOT_CA}
  Issuing CA:  ${CHEF360_ISSUING_CA}
  Chain:       ${CHEF360_TLS_CHAIN}
  Leaf:        ${CHEF360_TLS_CERT} / ${CHEF360_TLS_KEY}
  SANs:        DNS:${VM_HOSTNAME}, DNS:${VM_SHORT_HOSTNAME}, IP:${VM_IP}
  CA keys:     ${CA_DIR} (host-only, mode 0600)
EOF

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. No certificate files were written. Use --execute to issue them.\n'
  exit 0
fi

install -d -m 0700 "${CA_DIR}"
install -d -m 0700 "$(dirname "${CHEF360_TLS_CERT}")" "$(dirname "${CHEF360_TLS_KEY}")" "$(dirname "${CHEF360_TLS_CHAIN}")"
umask 077

if [[ ! -f "${ROOT_KEY}" ]] || [[ ! -f "${ROOT_CRT}" ]]; then
  log_step "Generating root certificate authority"
  openssl genrsa 4096 >"${ROOT_KEY}"
  openssl req -x509 -new -key "${ROOT_KEY}" -sha256 -days "${ROOT_DAYS}" \
    -subj "${ROOT_SUBJECT}" -out "${ROOT_CRT}"
  chmod 0600 "${ROOT_KEY}"
  chmod 0644 "${ROOT_CRT}"
fi
openssl x509 -in "${ROOT_CRT}" -noout -text | grep -q 'CA:TRUE' || fail "Root CA is missing CA:TRUE"
root_subject="$(openssl x509 -in "${ROOT_CRT}" -noout -subject | sed 's/^subject=//')"
root_issuer="$(openssl x509 -in "${ROOT_CRT}" -noout -issuer | sed 's/^issuer=//')"
[[ "${root_subject}" == "${root_issuer}" ]] || fail "Root CA is not self-signed"

if [[ ! -f "${ISSUING_KEY}" ]] || [[ ! -f "${ISSUING_CRT}" ]]; then
  log_step "Generating issuing certificate authority"
  openssl genrsa 4096 >"${ISSUING_KEY}"
  openssl req -new -key "${ISSUING_KEY}" -subj "${ISSUING_SUBJECT}" -out "${CA_DIR}/${VM_NAME}-issuing.csr"
  openssl x509 -req -in "${CA_DIR}/${VM_NAME}-issuing.csr" -CA "${ROOT_CRT}" -CAkey "${ROOT_KEY}" \
    -days "${ISSUING_DAYS}" -sha256 -set_serial "0x$(openssl rand -hex 16)" \
    -extfile <(printf '%s\n' 'basicConstraints=critical,CA:TRUE,pathlen:0' 'keyUsage=critical,keyCertSign,cRLSign') \
    -out "${ISSUING_CRT}"
  rm -f -- "${CA_DIR}/${VM_NAME}-issuing.csr"
  chmod 0600 "${ISSUING_KEY}"
  chmod 0644 "${ISSUING_CRT}"
fi
openssl x509 -in "${ISSUING_CRT}" -noout -text | grep -q 'CA:TRUE' || fail "Issuing CA is missing CA:TRUE"
openssl verify -CAfile "${ROOT_CRT}" "${ISSUING_CRT}" >/dev/null || fail "Issuing CA does not verify against root CA"

cert_is_current() {
  openssl x509 -in "${CHEF360_TLS_CERT}" -noout -checkend 0 >/dev/null 2>&1 || return 1
  openssl verify -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null 2>&1 || return 1
  openssl verify -verify_hostname "${VM_HOSTNAME}" -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null 2>&1 || return 1
  openssl verify -verify_ip "${VM_IP}" -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null 2>&1 || return 1
  cert_public="$(openssl x509 -in "${CHEF360_TLS_CERT}" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)"
  key_public="$(openssl pkey -in "${CHEF360_TLS_KEY}" -pubout -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)"
  [[ "${cert_public}" == "${key_public}" ]]
}

if [[ "${FORCE}" != true ]] && [[ -f "${CHEF360_TLS_CERT}" ]] && [[ -f "${CHEF360_TLS_KEY}" ]] && cert_is_current; then
  printf 'Existing leaf certificate is valid and up to date; reusing it\n'
else
  log_step "Issuing leaf certificate for ${VM_HOSTNAME}"
  openssl genrsa 4096 >"${CHEF360_TLS_KEY}-work"
  openssl req -new -key "${CHEF360_TLS_KEY}-work" -subj "${LEAF_SUBJECT}" -out "${LEAF_CSR}" \
    -addext "subjectAltName=DNS:${VM_HOSTNAME},DNS:${VM_SHORT_HOSTNAME},IP:${VM_IP}" \
    -addext 'basicConstraints=critical,CA:FALSE' \
    -addext 'keyUsage=critical,digitalSignature,keyEncipherment' \
    -addext 'extendedKeyUsage=serverAuth,clientAuth'
  openssl x509 -req -in "${LEAF_CSR}" -CA "${ISSUING_CRT}" -CAkey "${ISSUING_KEY}" \
    -days "${LEAF_DAYS}" -sha256 -set_serial "0x$(openssl rand -hex 16)" -copy_extensions copy \
    -out "${CHEF360_TLS_CERT}-work"
  rm -f -- "${LEAF_CSR}"
  chmod 0600 "${CHEF360_TLS_KEY}-work"
  chmod 0644 "${CHEF360_TLS_CERT}-work"
fi

cat "${ISSUING_CRT}" "${ROOT_CRT}" > "${CHEF360_TLS_CHAIN}-work"
chmod 0644 "${CHEF360_TLS_CHAIN}-work"

install -d -m 0700 "$(dirname "${CHEF360_TLS_CERT}")" "$(dirname "${CHEF360_TLS_KEY}")"
if [[ -f "${CHEF360_TLS_KEY}-work" ]]; then
  mv -f "${CHEF360_TLS_KEY}-work" "${CHEF360_TLS_KEY}"
  mv -f "${CHEF360_TLS_CERT}-work" "${CHEF360_TLS_CERT}"
fi
install -m 0644 "${CHEF360_TLS_CHAIN}-work" "${CHEF360_TLS_CHAIN}"
install -m 0644 "${ROOT_CRT}" "${CHEF360_ROOT_CA}"
install -m 0644 "${ISSUING_CRT}" "${CHEF360_ISSUING_CA}"
chmod 0600 "${CHEF360_TLS_KEY}"
rm -f -- "${CHEF360_TLS_CHAIN}-work" "${CHEF360_TLS_CERT}-work" 2>/dev/null || true

openssl verify -purpose sslserver -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null || fail "Leaf chain verification failed"
openssl verify -verify_hostname "${VM_HOSTNAME}" -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null || fail "Leaf does not cover ${VM_HOSTNAME}"
openssl verify -verify_ip "${VM_IP}" -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null || fail "Leaf does not cover ${VM_IP}"
openssl x509 -in "${CHEF360_ROOT_CA}" -noout -text | grep -q 'CA:TRUE' || fail "Staged root CA is invalid"
openssl verify -CAfile "${CHEF360_ROOT_CA}" "${CHEF360_ISSUING_CA}" >/dev/null || fail "Staged issuing CA does not verify against root CA"

save_kvm_state

cat <<EOF

Certificates ready:
  Leaf:       ${CHEF360_TLS_CERT}
  Key:        ${CHEF360_TLS_KEY}
  Chain:      ${CHEF360_TLS_CHAIN}
  Issuing CA: ${CHEF360_ISSUING_CA}
  Root CA:    ${CHEF360_ROOT_CA}
  CA keys:    ${CA_DIR} (kept on the KVM host; never transferred)
  Next:       ${SCRIPT_DIR}/acquire-chef360-assets.sh --execute
EOF