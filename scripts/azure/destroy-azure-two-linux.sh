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
DEFAULT_DEPLOYMENT_NAME="${OBJECT_OWNER_PREFIX}-azure-two-linux-lowcost"
NAME_PREFIX="${2:-${NAME_PREFIX:-${DEFAULT_NAME_PREFIX}}}"
AUTO_YES="${3:-}"
PROJECT_AZURE_DIR="${PROJECT_ROOT}/.azure"
KNOWN_HOSTS_FILE="${HOME}/.ssh/known_hosts"
CHEF360_PROFILE="${CHEF360_PROFILE:-default}"

if [[ -d "${PROJECT_AZURE_DIR}" ]]; then
  export AZURE_CONFIG_DIR="${PROJECT_AZURE_DIR}"
fi

vnet_id=""
subnet_name=""
subnet_nsg_id=""
candidate_ips=()

log_step() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

command_exists() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1
}

remove_known_host_entry() {
  local host_alias="$1"

  if [[ ! -f "${KNOWN_HOSTS_FILE}" ]]; then
    return
  fi

  ssh-keygen -f "${KNOWN_HOSTS_FILE}" -R "${host_alias}" >/dev/null 2>&1 || true
}

add_candidate_ip() {
  local ip="$1"
  if [[ -n "${ip}" ]]; then
    candidate_ips+=("${ip}")
  fi
}

collect_candidate_ips() {
  local vm_name
  local public_ip
  local private_ip

  for vm_name in "${NAME_PREFIX}-1" "${NAME_PREFIX}-2"; do
    public_ip="$(az vm show -d --resource-group "${RESOURCE_GROUP}" --name "${vm_name}" --query "publicIps" --output tsv --only-show-errors 2>/dev/null || true)"
    private_ip="$(az vm show -d --resource-group "${RESOURCE_GROUP}" --name "${vm_name}" --query "privateIps" --output tsv --only-show-errors 2>/dev/null || true)"
    add_candidate_ip "${public_ip%%,*}"
    add_candidate_ip "${private_ip%%,*}"
  done
}

remove_chef_infra_nodes() {
  local node
  if ! command_exists "knife"; then
    log_step "knife not found; skipping Chef Infra node/client cleanup"
    return
  fi

  for node in node1 node2; do
    if knife node delete "${node}" --yes >/dev/null 2>&1; then
      log_step "Deleted Chef Infra node '${node}'"
    else
      log_step "Chef Infra node '${node}' delete skipped/failed (continuing)"
    fi

    if knife client delete "${node}" --yes >/dev/null 2>&1; then
      log_step "Deleted Chef Infra client '${node}'"
    else
      log_step "Chef Infra client '${node}' delete skipped/failed (continuing)"
    fi
  done
}

remove_chef360_nodes() {
  local nodes_json
  local ip_json
  local name_json
  local jq_output
  local node_id
  local archive_ids=()

  if ! command_exists "chef-node-management-cli"; then
    log_step "chef-node-management-cli not found; skipping Chef 360 node archive"
    return
  fi

  if ! command_exists "jq"; then
    log_step "jq not found; skipping Chef 360 node archive"
    return
  fi

  nodes_json="$(chef-node-management-cli management node find-all-nodes --pagination.size 1000 --profile "${CHEF360_PROFILE}" --format json 2>/dev/null || true)"
  if [[ -z "${nodes_json}" ]]; then
    log_step "Unable to query Chef 360 nodes; skipping Chef 360 node archive"
    return
  fi

  ip_json="$(printf '%s\n' "${candidate_ips[@]}" | jq -R . | jq -s .)"
  name_json='["node1","node2"]'

  jq_output="$(
    printf "%s" "${nodes_json}" | jq -r \
      --argjson names "${name_json}" \
      --argjson ips "${ip_json}" \
      '
        def attr($ns; $name): ([.attributes[]? | select(.namespace==$ns and .name==$name) | .value] | first // "");
        .items[]?
        | . as $n
        | (attr("enroll"; "hostname")) as $host
        | (attr("enroll"; "primary_ip")) as $ip
        | (attr("enroll"; "fqdn")) as $fqdn
        | select(
            (($names | index($host)) != null)
            or (($names | index($fqdn)) != null)
            or (($ips | index($ip)) != null)
            or (($ips | index($fqdn)) != null)
          )
        | .id // empty
      ' 2>/dev/null || true
  )"

  while IFS= read -r node_id; do
    if [[ -n "${node_id}" && ! " ${archive_ids[*]} " =~ " ${node_id} " ]]; then
      archive_ids+=("${node_id}")
    fi
  done <<< "${jq_output}"

  if [[ "${#archive_ids[@]}" -eq 0 ]]; then
    log_step "No matching Chef 360 node records found to archive"
    return
  fi

  for node_id in "${archive_ids[@]}"; do
    chef-node-management-cli management node archive-node --nodeId "${node_id}" --profile "${CHEF360_PROFILE}" --format json >/dev/null 2>&1 || true
  done
  log_step "Chef 360 archive attempted for ${#archive_ids[@]} node record(s)"
}

if ! command_exists "az"; then
  printf "Required command not found: az\n"
  exit 1
fi

set +e
vnet_id=$(az network vnet show --resource-group "${RESOURCE_GROUP}" --name "${NAME_PREFIX}-vnet" --query id --output tsv --only-show-errors 2>/dev/null)
subnet_name=$(az network vnet subnet list --resource-group "${RESOURCE_GROUP}" --vnet-name "${NAME_PREFIX}-vnet" --query "[0].name" --output tsv --only-show-errors 2>/dev/null)
subnet_nsg_id=$(az network vnet subnet show --resource-group "${RESOURCE_GROUP}" --vnet-name "${NAME_PREFIX}-vnet" --name "${subnet_name}" --query networkSecurityGroup.id --output tsv --only-show-errors 2>/dev/null)
set -e

if [[ "${AUTO_YES}" != "--yes" ]]; then
  printf "This will delete deployed VM resources with prefix '%s' in resource group '%s'.\n" "${NAME_PREFIX}" "${RESOURCE_GROUP}"
  printf "It will NOT delete the resource group or template specs.\n"
  read -r -p "Type '${NAME_PREFIX}' to confirm: " CONFIRM
  if [[ "${CONFIRM}" != "${NAME_PREFIX}" ]]; then
    printf "Confirmation mismatch. Aborting.\n"
    exit 1
  fi
fi

collect_candidate_ips

log_step "Step 1/3: Removing node records from Chef Infra and Chef 360"
remove_chef_infra_nodes
remove_chef360_nodes

log_step "Step 2/3: Removing Azure resources"

for VM in "${NAME_PREFIX}-1" "${NAME_PREFIX}-2"; do
  az vm delete --resource-group "${RESOURCE_GROUP}" --name "${VM}" --yes --no-wait --only-show-errors --output none || true
done

for VM in "${NAME_PREFIX}-1" "${NAME_PREFIX}-2"; do
  az vm wait --resource-group "${RESOURCE_GROUP}" --name "${VM}" --deleted --only-show-errors || true
done

for NIC in "${NAME_PREFIX}-1-nic" "${NAME_PREFIX}-2-nic"; do
  az network nic delete --resource-group "${RESOURCE_GROUP}" --name "${NIC}" --only-show-errors --output none || true
done

for PIP in "${NAME_PREFIX}-1-pip" "${NAME_PREFIX}-2-pip"; do
  az network public-ip delete --resource-group "${RESOURCE_GROUP}" --name "${PIP}" --only-show-errors --output none || true
done

if [[ -n "${vnet_id}" && -n "${subnet_name}" && -n "${subnet_nsg_id}" ]]; then
  az network vnet subnet update \
    --resource-group "${RESOURCE_GROUP}" \
    --vnet-name "${NAME_PREFIX}-vnet" \
    --name "${subnet_name}" \
    --remove networkSecurityGroup \
    --only-show-errors \
    --output none || true
fi

az network vnet delete --resource-group "${RESOURCE_GROUP}" --name "${NAME_PREFIX}-vnet" --only-show-errors --output none || true
az network nsg delete --resource-group "${RESOURCE_GROUP}" --name "${NAME_PREFIX}-nsg" --only-show-errors --output none || true

for DEPLOYMENT_NAME in "${DEFAULT_DEPLOYMENT_NAME}" azure-two-linux-lowcost 1.0; do
  az deployment group delete --resource-group "${RESOURCE_GROUP}" --name "${DEPLOYMENT_NAME}" --only-show-errors --output none || true
done

log_step "Step 3/3: Cleaning local SSH host aliases"
remove_known_host_entry "node1"
remove_known_host_entry "node2"

printf "Destroy workflow complete for prefix '%s' in '%s' (Chef Infra/Chef 360 cleanup attempted, Azure resources deleted, template spec preserved).\n" "${NAME_PREFIX}" "${RESOURCE_GROUP}"

if [[ -f "${STATE_FILE}" ]]; then
  rm -f "${STATE_FILE}"
  log_step "Removed runtime parameters file: ${STATE_FILE}"
fi
