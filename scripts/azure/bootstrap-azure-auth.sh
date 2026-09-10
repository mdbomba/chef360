#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TARGET_DIR="${PROJECT_ROOT}/.azure"
SOURCE_DIR="${HOME}/.azure"

if [[ ! -d "${SOURCE_DIR}" ]]; then
  printf "Source Azure CLI directory not found: %s\n" "${SOURCE_DIR}"
  exit 1
fi

mkdir -p "${TARGET_DIR}"

FILES=(
  "azureProfile.json"
  "az.sess"
  "msal_token_cache.json"
  "msal_http_cache.bin"
  "config"
  "clouds.config"
)

for FILE in "${FILES[@]}"; do
  if [[ -f "${SOURCE_DIR}/${FILE}" ]]; then
    cp -f "${SOURCE_DIR}/${FILE}" "${TARGET_DIR}/${FILE}"
  fi
done

chmod 700 "${TARGET_DIR}"
find "${TARGET_DIR}" -type f -exec chmod 600 {} \;

printf "Azure CLI auth artifacts staged at: %s\n" "${TARGET_DIR}"
printf "Scripts in this repo will use AZURE_CONFIG_DIR=%s when present.\n" "${TARGET_DIR}"
