#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_FILE="${AZURE_TWO_LINUX_STATE_FILE:-${PROJECT_ROOT}/config/azure-two-linux.env}"
SSH_SOURCE_CIDR_OVERRIDE="${SSH_SOURCE_CIDR:-}"
if [[ -f "${STATE_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
  set +a
fi

RESOURCE_GROUP="${1:-${RESOURCE_GROUP:-rg-chef360-linux}}"
VM_SIZE="${2:-${VM_SIZE:-Standard_D2s_v5}}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-${3:-${HOME}/.ssh/id_ed25519}}"
OBJECT_OWNER_PREFIX="${OBJECT_OWNER_PREFIX:-chef360}"
DEFAULT_NAME_PREFIX="${OBJECT_OWNER_PREFIX}-sa-linux"
DEFAULT_DEPLOYMENT_NAME="${OBJECT_OWNER_PREFIX}-azure-two-linux-lowcost"
NAME_PREFIX="${NAME_PREFIX:-${DEFAULT_NAME_PREFIX}}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-${DEFAULT_DEPLOYMENT_NAME}}"
TEMPLATE_SPEC_ID="${TEMPLATE_SPEC_ID:-}"
USE_TEMPLATE_SPEC="${USE_TEMPLATE_SPEC:-false}"
PROJECT_AZURE_DIR="${PROJECT_ROOT}/.azure"
PARAM_FILE="${PROJECT_ROOT}/infra/azure/azure-two-linux-lowcost.parameters.json"
TEMPLATE_FILE="${PROJECT_ROOT}/infra/azure/azure-two-linux-lowcost.json"
WINDOWS_HOSTS_CHECK_SCRIPT="${SCRIPT_DIR}/check-windows-hosts.sh"
WINDOWS_HOSTS_UPDATE_SCRIPT="${SCRIPT_DIR}/update-windows-hosts.sh"
BOOTSTRAP_SCRIPT="${SCRIPT_DIR}/bootstrap-azure-two-linux.sh"
REGISTER_CHEF360_SCRIPT="${SCRIPT_DIR}/register-chef360-nodes.sh"
VERIFY_CHEF_SUDO_SCRIPT="${SCRIPT_DIR}/verify-chef-sudo-nopasswd.sh"
ENSURE_SSH_ACCESS_SCRIPT="${SCRIPT_DIR}/ensure-azure-ssh-access.sh"
CHEF_NODE_USER="${CHEF_NODE_USER:-chef}"
CHEF_POLICY_NAME="${CHEF_POLICY_NAME:-stig_base}"
CHEF_POLICY_GROUP="${CHEF_POLICY_GROUP:-dev}"
ENABLE_CHEF360_REGISTRATION="${ENABLE_CHEF360_REGISTRATION:-true}"
SSH_SOURCE_CIDR="${SSH_SOURCE_CIDR_OVERRIDE}"
EXPIRATION="${EXPIRATION:-$(date -u -d '+2 days' '+%Y-%m-%d')}"

log_step() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

save_runtime_parameters() {
  mkdir -p "$(dirname "${STATE_FILE}")"
  cat > "${STATE_FILE}" <<EOF
RESOURCE_GROUP=${RESOURCE_GROUP}
VM_SIZE=${VM_SIZE}
NAME_PREFIX=${NAME_PREFIX}
DEPLOYMENT_NAME=${DEPLOYMENT_NAME}
NODE1_VM=${NAME_PREFIX}-1
NODE2_VM=${NAME_PREFIX}-2
NODE1_IP=${NODE1_IP}
NODE2_IP=${NODE2_IP}
NODE1_TARGET=${NODE1_IP}
NODE2_TARGET=${NODE2_IP}
CHEF_NODE_USER=${CHEF_NODE_USER}
CHEF_POLICY_NAME=${CHEF_POLICY_NAME}
CHEF_POLICY_GROUP=${CHEF_POLICY_GROUP}
SSH_SOURCE_CIDR=${SSH_SOURCE_CIDR}
EOF
  chmod 600 "${STATE_FILE}" >/dev/null 2>&1 || true
  log_step "Updated runtime parameters file: ${STATE_FILE}"
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    printf "Required command not found: %s\n" "${cmd}"
    exit 1
  fi
}

normalize_policy_name() {
  printf "%s" "$1" | tr '_' '-'
}

get_vm_count() {
  az vm list \
    --resource-group "${RESOURCE_GROUP}" \
    --query "[?name=='${NAME_PREFIX}-1' || name=='${NAME_PREFIX}-2'] | length(@)" \
    --output tsv
}

resolve_ssh_source_cidr() {
  SSH_SOURCE_CIDR="$(bash "${ENSURE_SSH_ACCESS_SCRIPT}" "${RESOURCE_GROUP}" "${NAME_PREFIX}" "${SSH_SOURCE_CIDR_OVERRIDE}")"
  log_step "Restricting inbound SSH to ${SSH_SOURCE_CIDR}"
}

reconcile_ssh_nsg_rule() {
  bash "${ENSURE_SSH_ACCESS_SCRIPT}" "${RESOURCE_GROUP}" "${NAME_PREFIX}" "${SSH_SOURCE_CIDR}" >/dev/null
}

sync_resource_group_tags() {
  local -a resource_group_tags

  mapfile -t resource_group_tags < <(jq -r '
    .parameters
    | {
        "X-Customer": .xCustomer.value,
        "X-Project": .xProject.value,
        "X-Application": .xApplication.value,
        "X-Dept": .xDept.value,
        "X-Name": .xName.value,
        "X-Contact": .xContact.value,
        "X-TTL": .xTTL.value,
        Application: .application.value,
        Team: .team.value,
        owner: .owner.value,
        Expiration: $expiration,
        ephemeral: .ephemeral.value
      }
    | to_entries[]
    | "\(.key)=\(.value)"
  ' --arg expiration "${EXPIRATION}" "${PARAM_FILE}")

  az group update \
    --name "${RESOURCE_GROUP}" \
    --tags "${resource_group_tags[@]}" \
    --only-show-errors \
    --output none
  log_step "Synchronized deployment tags on resource group ${RESOURCE_GROUP}"
}

sync_deployed_resource_tags() {
  local -a resource_tags
  local resource_id

  mapfile -t resource_tags < <(jq -r '
    .parameters
    | {
        "X-Customer": .xCustomer.value,
        "X-Project": .xProject.value,
        "X-Application": .xApplication.value,
        "X-Dept": .xDept.value,
        "X-Name": .xName.value,
        "X-Contact": .xContact.value,
        "X-TTL": .xTTL.value,
        application: .application.value,
        team: .team.value,
        owner: .owner.value,
        expiration: $expiration,
        ephemeral: .ephemeral.value
      }
    | to_entries[]
    | "\(.key)=\(.value)"
  ' --arg expiration "${EXPIRATION}" "${PARAM_FILE}")

  while IFS= read -r resource_id; do
    [[ -z "${resource_id}" ]] && continue
    az tag create \
      --resource-id "${resource_id}" \
      --tags "${resource_tags[@]}" \
      --only-show-errors \
      --output none
  done < <(az resource list \
    --resource-group "${RESOURCE_GROUP}" \
    --query "[?tags.\"X-Application\" == '$(jq -r '.parameters.xApplication.value' "${PARAM_FILE}")'].id" \
    --output tsv)
  log_step "Synchronized deployment tags on existing resources in ${RESOURCE_GROUP}"
}

deploy_nodes_if_missing() {
  local vm_count
  vm_count="$(get_vm_count)"
  if [[ "${vm_count}" -eq 2 ]]; then
    log_step "Step 1/2: Both nodes already deployed; skipping deployment"
    return
  fi

  log_step "Step 1/2: Nodes not fully deployed (found ${vm_count}/2); deploying now"
  if [[ "${USE_TEMPLATE_SPEC}" == "true" ]]; then
    if [[ -z "${TEMPLATE_SPEC_ID}" ]]; then
      printf "TEMPLATE_SPEC_ID is required when USE_TEMPLATE_SPEC=true\n"
      exit 1
    fi
    az deployment group create \
      --name "${DEPLOYMENT_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --template-spec "${TEMPLATE_SPEC_ID}" \
      --parameters "@${PARAM_FILE}" \
      --parameters namePrefix="${NAME_PREFIX}" \
      --parameters vmSize="${VM_SIZE}" \
      --parameters sshSourceCidr="${SSH_SOURCE_CIDR}" \
      --parameters expiration="${EXPIRATION}" \
      --only-show-errors \
      --output none
  else
    az deployment group create \
      --name "${DEPLOYMENT_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --template-file "${TEMPLATE_FILE}" \
      --parameters "@${PARAM_FILE}" \
      --parameters namePrefix="${NAME_PREFIX}" \
      --parameters vmSize="${VM_SIZE}" \
      --parameters sshSourceCidr="${SSH_SOURCE_CIDR}" \
      --parameters expiration="${EXPIRATION}" \
      --only-show-errors \
      --output none
  fi
  log_step "Deployment finished"
}

resolve_node_ips() {
  local vm_name
  local private_ip
  local public_ip

  NODE1_IP=""
  NODE2_IP=""

  for i in 1 2; do
    vm_name="${NAME_PREFIX}-${i}"
    private_ip="$(az vm show -d --resource-group "${RESOURCE_GROUP}" --name "${vm_name}" --query "privateIps" --output tsv)"
    public_ip="$(az vm show -d --resource-group "${RESOURCE_GROUP}" --name "${vm_name}" --query "publicIps" --output tsv)"

    if [[ -n "${public_ip}" ]]; then
      if [[ "${i}" -eq 1 ]]; then
        NODE1_IP="${public_ip%%,*}"
      else
        NODE2_IP="${public_ip%%,*}"
      fi
    else
      if [[ "${i}" -eq 1 ]]; then
        NODE1_IP="${private_ip%%,*}"
      else
        NODE2_IP="${private_ip%%,*}"
      fi
    fi
  done

  if [[ -z "${NODE1_IP}" || -z "${NODE2_IP}" ]]; then
    printf "Unable to resolve node IPs. node1='%s', node2='%s'\n" "${NODE1_IP}" "${NODE2_IP}"
    exit 1
  fi

  log_step "Resolved node addresses: node1=${NODE1_IP} node2=${NODE2_IP}"
}

ensure_chef_sudo_nopasswd() {
  local vm_name
  log_step "Step 3: Ensuring passwordless sudo for user '${CHEF_NODE_USER}' on both nodes"
  for i in 1 2; do
    vm_name="${NAME_PREFIX}-${i}"
    az vm run-command invoke \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${vm_name}" \
      --command-id RunShellScript \
      --scripts "set -euo pipefail" "USER_NAME='${CHEF_NODE_USER}'" "SUDOERS_FILE='/etc/sudoers.d/chef'" "printf '%s ALL=(ALL) NOPASSWD:ALL\n' \"\${USER_NAME}\" > \"\${SUDOERS_FILE}\"" "chown root:root \"\${SUDOERS_FILE}\"" "chmod 0440 \"\${SUDOERS_FILE}\"" "visudo -cf \"\${SUDOERS_FILE}\"" \
      --only-show-errors \
      --output none
  done
}

wait_for_node_readiness() {
  local node_ip="$1"
  local max_attempts=30
  local attempt

  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    log_step "Waiting for cloud-init on ${node_ip} (attempt ${attempt}/${max_attempts})"
    if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node_ip}" \
      "cloud-init status --wait >/dev/null && test -f /var/lib/chef360-template-ready"; then
      return
    fi
    sleep 10
  done

  printf "Node did not become ready: %s\n" "${node_ip}"
  exit 1
}

verify_node_prerequisites() {
  local node_ip="$1"
  local expected_key

  expected_key="$(ssh-keygen -y -f "${SSH_PRIVATE_KEY}" | awk '{print $1 " " $2}')"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node_ip}" \
    "set -euo pipefail; test \"\$(id -un)\" = '${CHEF_NODE_USER}'; command -v sshd >/dev/null; systemctl is-enabled ssh >/dev/null; systemctl is-active ssh >/dev/null; sudo test \"\$(stat -c '%U:%G:%a' /etc/sudoers.d/chef)\" = 'root:root:440'; sudo test \"\$(cat /etc/sudoers.d/chef)\" = '${CHEF_NODE_USER} ALL=(ALL) NOPASSWD:ALL'; awk '{print \$1 \" \" \$2}' \"\${HOME}/.ssh/authorized_keys\" | grep -Fqx '${expected_key}'"
}

verify_chef_sudo_nopasswd() {
  log_step "Step 3b: Verifying passwordless sudo for user '${CHEF_NODE_USER}' on both nodes"
  "${VERIFY_CHEF_SUDO_SCRIPT}" \
    "${SSH_PRIVATE_KEY}" \
    "${CHEF_NODE_USER}" \
    "${NODE1_IP}" \
    "${NODE2_IP}"
}

check_and_fix_windows_hosts() {
  log_step "Step 4/5: Verifying Windows hosts entries for node1/node2"
  if "${WINDOWS_HOSTS_CHECK_SCRIPT}" "${NODE1_IP}" "${NODE2_IP}"; then
    log_step "Windows hosts entries are already correct"
  else
    log_step "Windows hosts entries are missing/incorrect; updating now"
    "${WINDOWS_HOSTS_UPDATE_SCRIPT}" "${NODE1_IP}" "${NODE2_IP}"
    "${WINDOWS_HOSTS_CHECK_SCRIPT}" "${NODE1_IP}" "${NODE2_IP}"
  fi

  if [[ "$(getent hosts node1 | awk 'NR == 1 {print $1}')" != "${NODE1_IP}" || "$(getent hosts node2 | awk 'NR == 1 {print $1}')" != "${NODE2_IP}" ]]; then
    printf "WSL hostname resolution does not match the Windows hosts file.\n"
    exit 1
  fi
  for node in node1 node2; do
    ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node}" true
  done
  log_step "Windows hosts entries updated and verified"
}

node_exists_in_chef() {
  local node_name="$1"
  knife node show "${node_name}" >/dev/null 2>&1
}

get_node_policy_value() {
  local node_name="$1"
  local field_name="$2"
  knife node show "${node_name}" -a "${field_name}" 2>/dev/null | awk -F': ' -v key="${field_name}" '$1 == key { print $2 }'
}

bootstrap_if_needed() {
  local node1_exists=false
  local node2_exists=false

  log_step "Step 6/7: Checking Chef Infra node registration"
  if node_exists_in_chef "node1"; then
    node1_exists=true
  fi
  if node_exists_in_chef "node2"; then
    node2_exists=true
  fi

  if [[ "${node1_exists}" == "true" && "${node2_exists}" == "true" ]]; then
    log_step "Both nodes already exist in Chef Infra"
    return
  fi

  if [[ "${node1_exists}" != "true" ]]; then
    "${BOOTSTRAP_SCRIPT}" "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}" "${CHEF_POLICY_NAME}" "${CHEF_POLICY_GROUP}" "${NODE1_IP}" ""
  fi
  if [[ "${node2_exists}" != "true" ]]; then
    "${BOOTSTRAP_SCRIPT}" "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}" "${CHEF_POLICY_NAME}" "${CHEF_POLICY_GROUP}" "" "${NODE2_IP}"
  fi
}

validate_dsm_prerequisites() {
  if ! chef show-policy "${CHEF_POLICY_NAME}" "${CHEF_POLICY_GROUP}" --no-pager >/dev/null 2>&1; then
    printf "Chef policy group not found in DSM: %s/%s\n" "${CHEF_POLICY_NAME}" "${CHEF_POLICY_GROUP}"
    exit 1
  fi
}

validate_dsm_registration() {
  local node
  for node in node1 node2; do
    knife node show "${node}" >/dev/null
    knife client show "${node}" >/dev/null
  done
}

validate_bootstrap_policy() {
  local expected_name
  local expected_group
  local current_name
  local current_group
  local normalized_current
  local normalized_expected

  expected_name="${CHEF_POLICY_NAME}"
  expected_group="${CHEF_POLICY_GROUP}"
  normalized_expected="$(normalize_policy_name "${expected_name}")"

  log_step "Step 8: Validating node policy assignments"
  for node in node1 node2; do
    current_name="$(get_node_policy_value "${node}" "policy_name")"
    current_group="$(get_node_policy_value "${node}" "policy_group")"
    normalized_current="$(normalize_policy_name "${current_name}")"

    if [[ -z "${current_name}" || -z "${current_group}" ]]; then
      printf "Unable to read policy attributes for node: %s\n" "${node}"
      exit 1
    fi

    if [[ "${normalized_current}" != "${normalized_expected}" || "${current_group}" != "${expected_group}" ]]; then
      log_step "Policy mismatch on ${node}; applying ${expected_name}/${expected_group}"
      knife node policy set "${node}" "${expected_group}" "${expected_name}" >/dev/null
      current_name="$(get_node_policy_value "${node}" "policy_name")"
      current_group="$(get_node_policy_value "${node}" "policy_group")"
      normalized_current="$(normalize_policy_name "${current_name}")"
    fi

    if [[ "${normalized_current}" != "${normalized_expected}" || "${current_group}" != "${expected_group}" ]]; then
      printf "Policy validation failed for %s. Found %s/%s expected %s/%s\n" \
        "${node}" "${current_name}" "${current_group}" "${expected_name}" "${expected_group}"
      exit 1
    fi

    log_step "${node} policy validated: ${current_name}/${current_group}"
  done
}

run_chef_client_on_nodes() {
  log_step "Step 9: Running sudo chef-client on each node"
  for node in node1 node2; do
    ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "${SSH_PRIVATE_KEY}" "${CHEF_NODE_USER}@${node}" "sudo -n chef-client"
  done
}

register_nodes_with_chef360() {
  log_step "Step 10: Registering nodes with Chef 360"
  if [[ "${ENABLE_CHEF360_REGISTRATION}" != "true" ]]; then
    log_step "Chef 360 registration disabled (ENABLE_CHEF360_REGISTRATION=${ENABLE_CHEF360_REGISTRATION})"
    return
  fi

  "${REGISTER_CHEF360_SCRIPT}" \
    "${SSH_PRIVATE_KEY}" \
    "${CHEF_NODE_USER}" \
    "node1" \
    "node2"
}

if [[ -d "${PROJECT_AZURE_DIR}" ]]; then
  export AZURE_CONFIG_DIR="${PROJECT_AZURE_DIR}"
fi

if [[ ! -f "${PARAM_FILE}" ]]; then
  printf "Parameter file not found: %s\n" "${PARAM_FILE}"
  exit 1
fi

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
  printf "Template file not found: %s\n" "${TEMPLATE_FILE}"
  exit 1
fi

if [[ ! -f "${SSH_PRIVATE_KEY}" ]]; then
  printf "SSH private key not found: %s\n" "${SSH_PRIVATE_KEY}"
  exit 1
fi

for script_path in "${WINDOWS_HOSTS_CHECK_SCRIPT}" "${WINDOWS_HOSTS_UPDATE_SCRIPT}" "${BOOTSTRAP_SCRIPT}" "${REGISTER_CHEF360_SCRIPT}" "${VERIFY_CHEF_SUDO_SCRIPT}" "${ENSURE_SSH_ACCESS_SCRIPT}"; do
  if [[ ! -x "${script_path}" ]]; then
    printf "Required helper script not found or not executable: %s\n" "${script_path}"
    exit 1
  fi
done

require_command "az"
require_command "chef"
require_command "curl"
require_command "jq"
require_command "knife"
require_command "ssh"
require_command "ssh-keygen"
require_command "getent"

resolve_ssh_source_cidr
sync_resource_group_tags
deploy_nodes_if_missing
sync_deployed_resource_tags
reconcile_ssh_nsg_rule
resolve_node_ips
save_runtime_parameters
wait_for_node_readiness "${NODE1_IP}"
wait_for_node_readiness "${NODE2_IP}"
ensure_chef_sudo_nopasswd
verify_chef_sudo_nopasswd
verify_node_prerequisites "${NODE1_IP}"
verify_node_prerequisites "${NODE2_IP}"
check_and_fix_windows_hosts
validate_dsm_prerequisites
bootstrap_if_needed
validate_dsm_registration
validate_bootstrap_policy
run_chef_client_on_nodes
register_nodes_with_chef360

log_step "Workflow complete: nodes deployed, configured, bootstrapped, validated, chef-client run, and Chef 360 registration attempted"
