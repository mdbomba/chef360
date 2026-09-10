#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

for command in openssl python3 sha256sum; do
  require_command "${command}"
done
for file in \
  "${CHEF360_INSTALLER_SOURCE}" \
  "${CHEF360_LICENSE_SOURCE}" \
  "${CHEF360_CONFIG_FILE}" \
  "${SSH_PUBLIC_KEY}" \
  "${CHEF360_TLS_CERT}" \
  "${CHEF360_TLS_KEY}" \
  "${CHEF360_TLS_CHAIN}" \
  "${CHEF360_ISSUING_CA}" \
  "${CHEF360_ROOT_CA}"; do
  require_file "${file}"
done
[[ -x "${CHEF360_INSTALLER_SOURCE}" ]] || fail "Chef 360 installer is not executable"

version_output="$("${CHEF360_INSTALLER_SOURCE}" version)"
grep -Eq '\| chef-360[[:space:]]+\| 1\.7\.3[[:space:]]+\|' <<<"${version_output}" || \
  fail "Installer is not Chef 360 version 1.7.3"

openssl x509 -in "${CHEF360_TLS_CERT}" -noout -checkend 0 >/dev/null || fail "TLS certificate is expired or not yet valid"
openssl verify -purpose sslserver -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null || fail "TLS chain verification failed"
openssl verify -verify_hostname "${VM_HOSTNAME}" -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null || fail "TLS hostname verification failed"
openssl verify -verify_ip "${VM_IP}" -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null || fail "TLS IP verification failed"
cert_public_key="$(openssl x509 -in "${CHEF360_TLS_CERT}" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)"
private_public_key="$(openssl pkey -in "${CHEF360_TLS_KEY}" -pubout -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)"
[[ "${cert_public_key}" == "${private_public_key}" ]] || fail "TLS certificate and key do not match"

rm -rf -- "${CHEF360_STAGE_DIR}"
install -d -m 0700 "${CHEF360_STAGE_DIR}/tls" "${CHEF360_STAGE_DIR}/ca"
install -m 0700 "${CHEF360_INSTALLER_SOURCE}" "${CHEF360_STAGE_DIR}/chef-360"
install -m 0600 "${CHEF360_LICENSE_SOURCE}" "${CHEF360_STAGE_DIR}/license.yaml"
install -m 0600 "${CHEF360_CONFIG_FILE}" "${CHEF360_STAGE_DIR}/chef-config.yaml"
install -m 0644 "${CHEF360_TLS_CERT}" "${CHEF360_STAGE_DIR}/tls/chef360-2.crt"
install -m 0600 "${CHEF360_TLS_KEY}" "${CHEF360_STAGE_DIR}/tls/chef360-2.key"
install -m 0644 "${CHEF360_TLS_CHAIN}" "${CHEF360_STAGE_DIR}/tls/chef360-2.chain.crt"
install -m 0644 "${CHEF360_ISSUING_CA}" "${CHEF360_STAGE_DIR}/ca/chef360-2_ica.crt"
install -m 0644 "${CHEF360_ROOT_CA}" "${CHEF360_STAGE_DIR}/ca/chef360-2_rca.crt"

for ca_file in "${CHEF360_STAGE_DIR}/ca/chef360-2_ica.crt" "${CHEF360_STAGE_DIR}/ca/chef360-2_rca.crt"; do
  openssl x509 -in "${ca_file}" -noout -text | grep -q 'CA:TRUE' || fail "Certificate is not a CA: ${ca_file}"
done
root_subject="$(openssl x509 -in "${CHEF360_STAGE_DIR}/ca/chef360-2_rca.crt" -noout -subject | sed 's/^subject=//')"
root_issuer="$(openssl x509 -in "${CHEF360_STAGE_DIR}/ca/chef360-2_rca.crt" -noout -issuer | sed 's/^issuer=//')"
[[ "${root_subject}" == "${root_issuer}" ]] || fail "Root CA is not self-signed"
openssl verify -CAfile "${CHEF360_STAGE_DIR}/ca/chef360-2_rca.crt" \
  "${CHEF360_STAGE_DIR}/ca/chef360-2_ica.crt" >/dev/null || fail "Issuing CA validation failed"

openssl verify \
  -CAfile "${CHEF360_STAGE_DIR}/ca/chef360-2_rca.crt" \
  -untrusted "${CHEF360_STAGE_DIR}/ca/chef360-2_ica.crt" \
  "${CHEF360_STAGE_DIR}/tls/chef360-2.crt" >/dev/null || fail "Split CA trust validation failed"

installer_sha="$(sha256sum "${CHEF360_STAGE_DIR}/chef-360" | cut -d' ' -f1)"
license_sha="$(sha256sum "${CHEF360_STAGE_DIR}/license.yaml" | cut -d' ' -f1)"
config_sha="$(sha256sum "${CHEF360_STAGE_DIR}/chef-config.yaml" | cut -d' ' -f1)"
cert_sha="$(sha256sum "${CHEF360_STAGE_DIR}/tls/chef360-2.crt" | cut -d' ' -f1)"
key_public_sha="$(openssl pkey -in "${CHEF360_STAGE_DIR}/tls/chef360-2.key" -pubout -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)"
chain_sha="$(sha256sum "${CHEF360_STAGE_DIR}/tls/chef360-2.chain.crt" | cut -d' ' -f1)"

cat >"${CHEF360_STAGE_MANIFEST}" <<EOF
Chef 360 1.7.3 installation staging manifest
Generated: $(date --iso-8601=seconds)
Target VM: ${VM_NAME}
Target hostname: ${VM_HOSTNAME}
Target IP: ${VM_IP}

Runtime destination: /opt/chef360

SSH access provisioned by Ubuntu autoinstall
  public key source: ${SSH_PUBLIC_KEY}
  guest destination: /home/${VM_USER}/.ssh/authorized_keys
  guest account: ${VM_USER}
  private key retained on host: ${SSH_PRIVATE_KEY}
  private key copied to guest: no
  expected connection: ssh -i ${SSH_PRIVATE_KEY} ${VM_USER}@${VM_IP}

Guest /etc/hosts entries provisioned by Ubuntu autoinstall
  ${VM_IP} ${VM_HOSTNAME} ${VM_SHORT_HOSTNAME}
  ${KVM_HOST_IP} ${KVM_HOST_FQDN} fury
  ${AUTOMATE_IP} ${AUTOMATE_FQDN} automate
  ${NODE1_IP} ${NODE1_FQDN} node1
  ${NODE2_IP} ${NODE2_FQDN} node2

chef-360
  source: ${CHEF360_INSTALLER_SOURCE}
  mode: 0700 root:root
  sha256: ${installer_sha}
  expected version: 1.7.3

license.yaml
  source: ${CHEF360_LICENSE_SOURCE}
  mode: 0600 root:root
  sha256: ${license_sha}

chef-config.yaml
  source: ${CHEF360_CONFIG_FILE}
  mode: 0600 root:root
  sha256: ${config_sha}

tls/chef360-2.crt
  source: ${CHEF360_TLS_CERT}
  mode: 0644 root:root
  sha256: ${cert_sha}

tls/chef360-2.key
  source: ${CHEF360_TLS_KEY}
  mode: 0600 root:root
  public-key-sha256: ${key_public_sha}

tls/chef360-2.chain.crt
  source: ${CHEF360_TLS_CHAIN}
  mode: 0644 root:root
  sha256: ${chain_sha}
  use: Chef 360 gateway root certificate field

ca/chef360-2_ica.crt
  source: ${CHEF360_ISSUING_CA}
  mode: 0644 root:root
  use: Ubuntu CA trust store

ca/chef360-2_rca.crt
  source: ${CHEF360_ROOT_CA}
  mode: 0644 root:root
  use: Ubuntu CA trust store

Admin Console installer TLS arguments:
  --tls-cert /opt/chef360/tls/chef360-2.crt
  --tls-key /opt/chef360/tls/chef360-2.key

The CA signing key is not required, staged, or transferred.
The generated Chef 360 API token is not included in this manifest.
EOF
chmod 0600 "${CHEF360_STAGE_MANIFEST}"
save_kvm_state

printf 'Prepared Chef 360 installation inputs under %s\nManifest: %s\n' \
  "${CHEF360_STAGE_DIR}" "${CHEF360_STAGE_MANIFEST}"
printf 'No VM or libvirt resource was changed.\n'
