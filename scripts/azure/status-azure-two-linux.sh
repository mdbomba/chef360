#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${PROJECT_ROOT}/scripts/lib/load-parameters.sh"
load_chef360_parameters "${PROJECT_ROOT}"
STATE_FILE="${AZURE_TWO_LINUX_STATE_FILE:-${PROJECT_ROOT}/config/azure-two-linux.env}"
load_env_defaults "${STATE_FILE}"

RESOURCE_GROUP="${1:-${RESOURCE_GROUP:-rg-chef360-linux}}"
OBJECT_OWNER_PREFIX="${OBJECT_OWNER_PREFIX:-chef360}"
DEFAULT_NAME_PREFIX="${OBJECT_OWNER_PREFIX}-sa-linux"
NAME_PREFIX="${2:-${NAME_PREFIX:-${DEFAULT_NAME_PREFIX}}}"
OUTPUT_MODE="${3:-}"
PROJECT_AZURE_DIR="${PROJECT_ROOT}/.azure"

if [[ -d "${PROJECT_AZURE_DIR}" ]]; then
  export AZURE_CONFIG_DIR="${PROJECT_AZURE_DIR}"
fi

if [[ -n "${OUTPUT_MODE}" && "${OUTPUT_MODE}" != "--short" ]]; then
  printf "Usage: %s [resource-group] [name-prefix] [--short]\n" "$(basename "$0")"
  exit 1
fi

DEFAULT_QUERY="[?starts_with(name, '${NAME_PREFIX}-')].{name:name,powerState:powerState,privateIps:privateIps,publicIps:publicIps,location:location,vmSize:hardwareProfile.vmSize,os:storageProfile.osDisk.osType,imageOffer:storageProfile.imageReference.offer,imageSku:storageProfile.imageReference.sku,osVersion:storageProfile.imageReference.exactVersion}"
SHORT_QUERY="[?starts_with(name, '${NAME_PREFIX}-')].{name:name,powerState:powerState,publicIp:publicIps,osVersion:storageProfile.imageReference.exactVersion}"

QUERY="${DEFAULT_QUERY}"
if [[ "${OUTPUT_MODE}" == "--short" ]]; then
  QUERY="${SHORT_QUERY}"
fi

az vm list \
  --resource-group "${RESOURCE_GROUP}" \
  -d \
  --query "${QUERY}" \
  --output table
