#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

INTERACTIVE=false
ROTATE_TOKENS=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [--interactive] [--rotate-tokens]

Generate the Chef 360 1.7.3 runtime ConfigValues YAML. Existing generated
tokens are retained unless --rotate-tokens is supplied.

--interactive  Prompt for each deploy-defining value (hostname, tenant,
               domain, admin contact, ports), showing the default and
               keeping it on Enter. Without this flag the script uses
               environment defaults and is safe to run non-interactively.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interactive) INTERACTIVE=true; shift ;;
    --rotate-tokens) ROTATE_TOKENS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

prompt_value() {
  local name="$1" label="$2" default="$3" input
  printf '%s [%s]: ' "${label}" "${default}" >&2
  IFS= read -r input
  if [[ -n "${input}" ]]; then
    printf -v "${name}" '%s' "${input}"
  fi
}

if [[ "${INTERACTIVE}" == true ]]; then
  printf '\nChef 360 1.7.3 ConfigValues generator\n' >&2
  printf 'Press Enter to keep the shown default or type a replacement.\n\n' >&2
  prompt_value VM_HOSTNAME "Gateway FQDN" "${VM_HOSTNAME}"
  VM_SHORT_HOSTNAME="${VM_SHORT_HOSTNAME:-${VM_HOSTNAME%%.*}}"
  prompt_value VM_SHORT_HOSTNAME "Short hostname" "${VM_SHORT_HOSTNAME}"
  prompt_value TENANT_TLD "Tenant domain (TLD)" "${TENANT_TLD}"
  prompt_value TENANT_NAME "Tenant name" "${TENANT_NAME}"
  prompt_value TENANT_SUBDOMAIN "Tenant subdomain" "${TENANT_SUBDOMAIN:-${VM_SHORT_HOSTNAME}}"
  prompt_value TENANT_OU "Organization unit name" "${TENANT_OU}"
  prompt_value TENANT_OU_DESCRIPTION "Organization unit description" "${TENANT_OU_DESCRIPTION}"
  prompt_value TENANT_ADMIN_FIRST_NAME "Tenant admin first name" "${TENANT_ADMIN_FIRST_NAME}"
  prompt_value TENANT_ADMIN_LAST_NAME "Tenant admin last name" "${TENANT_ADMIN_LAST_NAME}"
  prompt_value TENANT_ADMIN_EMAIL "Tenant admin email" "${TENANT_ADMIN_EMAIL}"
  prompt_value GATEWAY_NODEPORT "Chef 360 gateway HTTPS port" "${GATEWAY_NODEPORT}"
  prompt_value MAILPIT_NODEPORT "Mailpit HTTP port" "${MAILPIT_NODEPORT}"
  prompt_value RABBITMQ_AMQP_NODEPORT "RabbitMQ AMQP port" "${RABBITMQ_AMQP_NODEPORT}"
  printf '\n' >&2
fi

tenant_portal="${TENANT_SUBDOMAIN}.${TENANT_TLD}"
if [[ "${tenant_portal}" != "${VM_HOSTNAME}" ]]; then
  printf 'WARN: tenant portal %s does not match gateway hostname %s\n' \
    "${tenant_portal}" "${VM_HOSTNAME}" >&2
  printf '      Converted email links will point at %s and may be unreachable.\n' \
    "${tenant_portal}" >&2
fi
if [[ "${TENANT_ADMIN_EMAIL}" != *"@${TENANT_TLD}" ]]; then
  printf 'WARN: admin email %s does not end in @%s\n' \
    "${TENANT_ADMIN_EMAIL}" "${TENANT_TLD}" >&2
fi

for command in openssl python3 sha256sum; do
  require_command "${command}"
done
for file in "${CHEF360_CONFIG_TEMPLATE}" "${CHEF360_TLS_CERT}" "${CHEF360_TLS_KEY}" "${CHEF360_TLS_CHAIN}"; do
  require_file "${file}"
done

openssl x509 -in "${CHEF360_TLS_CERT}" -noout -checkend 0 >/dev/null || fail "TLS certificate is expired or not yet valid"
openssl verify -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null || fail "TLS certificate chain verification failed"
openssl verify -verify_hostname "${VM_HOSTNAME}" -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null || fail "TLS certificate does not cover ${VM_HOSTNAME}"
openssl verify -verify_ip "${VM_IP}" -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null || fail "TLS certificate does not cover ${VM_IP}"
cert_public_key="$(openssl x509 -in "${CHEF360_TLS_CERT}" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)"
private_public_key="$(openssl pkey -in "${CHEF360_TLS_KEY}" -pubout -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)"
[[ "${cert_public_key}" == "${private_public_key}" ]] || fail "TLS certificate and private key do not match"

install -d -m 0700 "${KVM_WORK_DIR}"
if [[ "${ROTATE_TOKENS}" == true ]]; then
  rm -f -- "${CHEF360_SECRETS_FILE}"
fi

if [[ -f "${CHEF360_SECRETS_FILE}" ]]; then
  CHEF360_INSTALL_ADMIN_TOKEN="$(awk -F= '$1 == "CHEF360_INSTALL_ADMIN_TOKEN" {print substr($0, index($0, "=") + 1)}' "${CHEF360_SECRETS_FILE}")"
  [[ "${CHEF360_INSTALL_ADMIN_TOKEN}" =~ ^[a-f0-9]{48}$ ]] || fail "Invalid generated token state"
fi
if [[ -z "${CHEF360_INSTALL_ADMIN_TOKEN:-}" ]]; then
  CHEF360_INSTALL_ADMIN_TOKEN="$(openssl rand -hex 24)"
  printf 'CHEF360_INSTALL_ADMIN_TOKEN=%s\n' "${CHEF360_INSTALL_ADMIN_TOKEN}" >"${CHEF360_SECRETS_FILE}"
fi
chmod 0600 "${CHEF360_SECRETS_FILE}"

python3 - \
  "${CHEF360_CONFIG_TEMPLATE}" \
  "${CHEF360_CONFIG_FILE}" \
  "${CHEF360_TLS_CERT}" \
  "${CHEF360_TLS_KEY}" \
  "${CHEF360_TLS_CHAIN}" \
  "${CHEF360_INSTALL_ADMIN_TOKEN}" \
  "${TENANT_NAME}" \
  "${TENANT_SUBDOMAIN}" \
  "${TENANT_TLD}" \
  "${VM_HOSTNAME}:${GATEWAY_NODEPORT}" \
  "${TENANT_OU}" \
  "${TENANT_OU_DESCRIPTION}" \
  "${TENANT_ADMIN_FIRST_NAME}" \
  "${TENANT_ADMIN_LAST_NAME}" \
  "${TENANT_ADMIN_EMAIL}" \
  "${GATEWAY_NODEPORT}" \
  "${MAILPIT_NODEPORT}" \
  "${RABBITMQ_AMQP_NODEPORT}" <<'PY'
import base64
import sys
from pathlib import Path

import yaml

(
    template_path,
    output_path,
    certificate_path,
    key_path,
    chain_path,
    install_token,
    tenant_name,
    tenant_subdomain,
    tenant_tld,
    tenant_fqdn,
    tenant_ou,
    tenant_ou_description,
    admin_first,
    admin_last,
    admin_email,
    gateway_nodeport,
    mailpit_nodeport,
    rabbitmq_amqp_nodeport,
) = sys.argv[1:]

document = yaml.safe_load(Path(template_path).read_text(encoding="utf-8"))
if document.get("kind") != "ConfigValues" or document.get("metadata", {}).get("name") != "chef-360":
    raise SystemExit("Template is not a Chef 360 ConfigValues document")
values = document["spec"]["values"]

def set_value(key: str, value: str) -> None:
    entry = values.setdefault(key, {})
    entry["value"] = value

def encode(path: str) -> str:
    return base64.b64encode(Path(path).read_bytes()).decode("ascii")

set_value("cluster_topology", "hyperconverged-nonha")
set_value("configuration::namespace", "chef-360")
set_value("configuration::addons", "1")
set_value("configuration::advanced", "1")
set_value("progress::chef::eula", "1")
set_value("preflight::strict::mode", "0")
set_value("hab::onprem::isenabled", "1")

set_value("api::gateway::auth::apitoken::isenabled", "1")
set_value("api::gateway::admin::token::isenabled::public", "1")
set_value("api::gateway::install::admin::token", install_token)
set_value("api::gateway::static::auth::token", install_token)
set_value("api::gateway::nodeport::nginx", gateway_nodeport)
set_value("api::gateway::tls::selector", "api::gateway::custom")
set_value("api::gateway::skip::cert::validation", "0")

values["api::gateway::certificate::file"] = {
    "filename": Path(certificate_path).name,
    "value": encode(certificate_path),
}
values["api::gateway::private::key::file"] = {
    "filename": Path(key_path).name,
    "value": encode(key_path),
}
values["api::gateway::root::cert::file"] = {
    "filename": Path(chain_path).name,
    "value": encode(chain_path),
}

set_value("primary::tenant::name", tenant_name)
set_value("primary::tenant::subdomain", tenant_subdomain)
set_value("primary::tenant::tld", tenant_tld)
set_value("primary::tenant::fqdn", tenant_fqdn)
set_value("primary::tenant::direct::access", "1")
set_value("primary::tenant::ou::name", tenant_ou)
set_value("primary::tenant::ou::description", tenant_ou_description)
set_value("primary::tenant::ou::createDefaultSkillAssembly", "1")
set_value("tenant::admin::name::first", admin_first)
set_value("tenant::admin::name::last", admin_last)
set_value("tenant::admin::email", admin_email)

set_value("smtp::option", "smtp::option::mailpit")
set_value("mailpit::http::nodeport", mailpit_nodeport)
set_value("rabbitmq::amqp::nodeport", rabbitmq_amqp_nodeport)
set_value("opensearch::option", "opensearch::option::embedded")
set_value("postgresql::option", "postgresql::option::cnpg")
set_value("postgresql::option::cnpg::backup::enabled", "0")
set_value("storage::option", "storage::option::minio")
set_value("temporal::option", "temporal::option::onprem")
set_value("log::storage::minio::general::logs::retention::period", "30")
set_value("log::storage::minio::audit::logs::retention::period", "365")

# Remove exported opaque values for integrations that are not selected in this lab.
for key in (
    "opensearch::option::external::config::password",
    "postgresql::option::cnpg::backup::s3::secret_key",
    "smtp::password",
    "temporal::cloud::apiKey",
):
    entry = values.get(key)
    if isinstance(entry, dict):
        entry.pop("value", None)

Path(output_path).write_text(
    yaml.safe_dump(document, sort_keys=False, width=1_000_000),
    encoding="utf-8",
)
PY

chmod 0600 "${CHEF360_CONFIG_FILE}"
save_kvm_state

python3 - \
  "${CHEF360_CONFIG_FILE}" \
  "${CHEF360_TLS_CERT}" \
  "${CHEF360_TLS_KEY}" \
  "${CHEF360_TLS_CHAIN}" \
  "${VM_HOSTNAME}:${GATEWAY_NODEPORT}" <<'PY'
import base64
import sys
from pathlib import Path

import yaml

config_path, cert_path, key_path, chain_path, expected_fqdn = sys.argv[1:]
document = yaml.safe_load(Path(config_path).read_text(encoding="utf-8"))
values = document["spec"]["values"]

assert document["apiVersion"] == "kots.io/v1beta1"
assert document["kind"] == "ConfigValues"
assert document["metadata"]["name"] == "chef-360"
assert values["cluster_topology"]["value"] == "hyperconverged-nonha"
assert values["primary::tenant::fqdn"]["value"] == expected_fqdn
assert values["api::gateway::tls::selector"]["value"] == "api::gateway::custom"
assert values["api::gateway::skip::cert::validation"]["value"] == "0"
assert base64.b64decode(values["api::gateway::certificate::file"]["value"]) == Path(cert_path).read_bytes()
assert base64.b64decode(values["api::gateway::private::key::file"]["value"]) == Path(key_path).read_bytes()
assert base64.b64decode(values["api::gateway::root::cert::file"]["value"]) == Path(chain_path).read_bytes()
assert len(values["api::gateway::install::admin::token"]["value"]) >= 16
assert values["api::gateway::install::admin::token"]["value"] == values["api::gateway::static::auth::token"]["value"]
for key in (
    "opensearch::option::external::config::password",
    "postgresql::option::cnpg::backup::s3::secret_key",
    "smtp::password",
    "temporal::cloud::apiKey",
):
    assert "value" not in values[key]
PY

cat <<EOF
Generated Chef 360 1.7.3 runtime configuration:
  ConfigValues: ${CHEF360_CONFIG_FILE}
  Secret state: ${CHEF360_SECRETS_FILE}
  Tenant:       ${TENANT_NAME}
  Endpoint:     https://${VM_HOSTNAME}:${GATEWAY_NODEPORT}
  Admin:        ${TENANT_ADMIN_FIRST_NAME} ${TENANT_ADMIN_LAST_NAME} <${TENANT_ADMIN_EMAIL}>
  TLS cert:     ${CHEF360_TLS_CERT}
  TLS key:      ${CHEF360_TLS_KEY}
  TLS chain:    ${CHEF360_TLS_CHAIN}

The generated API token was not printed. No VM or libvirt resource was changed.
EOF
