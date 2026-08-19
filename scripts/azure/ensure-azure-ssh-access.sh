#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_FILE="${AZURE_TWO_LINUX_STATE_FILE:-${PROJECT_ROOT}/config/azure-two-linux.env}"
if [[ -f "${STATE_FILE}" ]]; then
  set -a
  source "${STATE_FILE}"
  set +a
fi

RESOURCE_GROUP="${1:-${RESOURCE_GROUP:-rg-chef360-linux}}"
OBJECT_OWNER_PREFIX="${OBJECT_OWNER_PREFIX:-chef360}"
NAME_PREFIX="${2:-${NAME_PREFIX:-${OBJECT_OWNER_PREFIX}-sa-linux}}"
CIDR_OVERRIDE="${3:-}"
NSG_NAME="${NAME_PREFIX}-nsg"
RULE_NAME="allow-ssh"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "Required command not found: %s\n" "$1" >&2
    exit 1
  fi
}

resolve_cidr() {
  local public_ip
  local address
  local prefix
  local o1 o2 o3 o4

  if [[ -n "${CIDR_OVERRIDE}" ]]; then
    if [[ ! "${CIDR_OVERRIDE}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]]; then
      printf "Invalid SSH source CIDR: %s\n" "${CIDR_OVERRIDE}" >&2
      exit 1
    fi
    address="${CIDR_OVERRIDE%/*}"
    prefix="${CIDR_OVERRIDE#*/}"
    IFS='.' read -r o1 o2 o3 o4 <<< "${address}"
    if ((o1 > 255 || o2 > 255 || o3 > 255 || o4 > 255 || prefix > 32)); then
      printf "Invalid SSH source CIDR: %s\n" "${CIDR_OVERRIDE}" >&2
      exit 1
    fi
    printf '%s' "${CIDR_OVERRIDE}"
    return
  fi

  public_ip="$(curl --fail --silent --show-error "https://api.ipify.org?format=json" | jq -r '.ip // empty')"
  if [[ ! "${public_ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    printf "Unable to resolve a valid public IPv4 address from api.ipify.org: %s\n" "${public_ip}" >&2
    exit 1
  fi
  IFS='.' read -r o1 o2 o3 o4 <<< "${public_ip}"
  if ((o1 > 255 || o2 > 255 || o3 > 255 || o4 > 255)); then
    printf "Invalid public IPv4 address returned by api.ipify.org: %s\n" "${public_ip}" >&2
    exit 1
  fi
  printf '%s/32' "${public_ip}"
}

require_command az
require_command curl
require_command jq

desired_cidr="$(resolve_cidr)"
resource_group_exists="$(az group exists --name "${RESOURCE_GROUP}" --output tsv --only-show-errors)"
if [[ "${resource_group_exists}" != "true" ]]; then
  printf "Resource group does not exist; skipping NSG update: %s\n" "${RESOURCE_GROUP}" >&2
  printf '%s\n' "${desired_cidr}"
  exit 0
fi

nsg_id="$(az network nsg show --resource-group "${RESOURCE_GROUP}" --name "${NSG_NAME}" --query id --output tsv --only-show-errors 2>/dev/null || true)"
if [[ -z "${nsg_id}" ]]; then
  printf "NSG does not exist; skipping rule update: %s/%s\n" "${RESOURCE_GROUP}" "${NSG_NAME}" >&2
  printf '%s\n' "${desired_cidr}"
  exit 0
fi

rule_json="$(az network nsg rule show --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" --name "${RULE_NAME}" --output json --only-show-errors 2>/dev/null || true)"

if [[ -z "${rule_json}" ]]; then
  printf "Creating NSG rule %s/%s for %s\n" "${NSG_NAME}" "${RULE_NAME}" "${desired_cidr}" >&2
  az network nsg rule create \
    --resource-group "${RESOURCE_GROUP}" \
    --nsg-name "${NSG_NAME}" \
    --name "${RULE_NAME}" \
    --priority 1000 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes "${desired_cidr}" \
    --destination-port-ranges 22 \
    --only-show-errors \
    --output none
else
  current_cidr="$(printf '%s' "${rule_json}" | jq -r '.sourceAddressPrefix // .sourceAddressPrefixes[0] // empty')"
  if [[ "${current_cidr}" != "${desired_cidr}" ]]; then
    printf "Updating NSG rule %s/%s from %s to %s\n" "${NSG_NAME}" "${RULE_NAME}" "${current_cidr:-<unset>}" "${desired_cidr}" >&2
    az network nsg rule update \
      --resource-group "${RESOURCE_GROUP}" \
      --nsg-name "${NSG_NAME}" \
      --name "${RULE_NAME}" \
      --source-address-prefixes "${desired_cidr}" \
      --destination-port-ranges 22 \
      --access Allow \
      --protocol Tcp \
      --direction Inbound \
      --only-show-errors \
      --output none
  else
    printf "NSG SSH access is current: %s\n" "${desired_cidr}" >&2
  fi
fi

printf '%s\n' "${desired_cidr}"
