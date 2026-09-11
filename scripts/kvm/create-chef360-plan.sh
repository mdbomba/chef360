#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Ignore any existing plan so the operator can revise defaults from scratch.
PLAN_OVERRIDE="${CHEF360_PLAN_FILE+x}"
PLAN_OVERRIDE_VALUE="${CHEF360_PLAN_FILE-}"
export CHEF360_PLAN_FILE="/dev/null"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

if [[ "${PLAN_OVERRIDE}" == "1" && "${PLAN_OVERRIDE_VALUE}" != "/dev/null" ]]; then
  PLAN_TARGET="${PLAN_OVERRIDE_VALUE}"
else
  PLAN_TARGET="${KVM_WORK_DIR}/${VM_NAME}-PLAN.env"
fi
PLAN_MD="${KVM_WORK_DIR}/${VM_NAME}-PLAN.md"

EXECUTE=false
INTERACTIVE=false
errors=0
warnings=0

usage() {
  cat <<'EOF'
Usage: create-chef360-plan.sh [--execute] [--interactive]

Validate the current build parameters and materialize a per-build project plan
that both build scripts and config generation source automatically.

Without --execute the script prints the plan it would create and reports
validation results but writes nothing.

--execute      Write ${KVM_WORK_DIR}/${VM_NAME}-PLAN.md and ${VM_NAME}-PLAN.env (mode 0600).
--interactive  Prompt for provisioning source (os_iso | clone | existing) and
               every guest-identity item (hostname, IP, gateway, DNS, user,
               SSH keys). "existing" records that the VM is already built and
               running; the plan then drives only config + install steps.
               MAC addresses are never prompted; they are assigned by the
               build process (or already present on an existing VM).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    --interactive) INTERACTIVE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

# --- helpers ----------------------------------------------------------------

require_file() {
  local path
  for path in "$@"; do
    if [[ ! -f "${path}" ]]; then
      printf 'FAIL: required file missing: %s\n' "${path}" >&2
      errors=$((errors + 1))
    fi
  done
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'FAIL: required command missing: %s\n' "$1" >&2
    errors=$((errors + 1))
  fi
}

validate_ip() {
  local label="$1" ip="$2"
  local oct='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'
  if [[ ! "${ip}" =~ ^${oct}(\.${oct}){3}$ ]]; then
    printf 'FAIL: invalid IPv4 address for %s: %s\n' "${label}" "${ip}" >&2
    errors=$((errors + 1))
  fi
}

validate_mac() {
  local mac="$1"
  if [[ ! "${mac}" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
    printf 'FAIL: invalid MAC address: %s\n' "${mac}" >&2
    errors=$((errors + 1))
  fi
}

validate_port() {
  local label="$1" port="$2"
  if [[ ! "${port}" =~ ^[0-9]+$ ]] || (( port < 1024 || port > 65535 )); then
    printf 'FAIL: invalid port for %s: %s (must be 1024-65535)\n' \
      "${label}" "${port}" >&2
    errors=$((errors + 1))
  fi
}

validate_vm_name() {
  if [[ ! "${VM_NAME}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
    printf 'FAIL: invalid VM name: %s (must start with alphanumeric, use [a-zA-Z0-9_-])\n' \
      "${VM_NAME}" >&2
    errors=$((errors + 1))
  fi
}

prompt_value() {
  local name="$1" label="$2" default="$3" input
  printf '%s [%s]: ' "${label}" "${default}" >&2
  if IFS= read -r input; then
    if [[ -n "${input}" ]]; then
      printf -v "${name}" '%s' "${input}"
    fi
  fi
}

if [[ "${INTERACTIVE}" == true ]]; then
  printf '\nChef 360 build plan generator\n' >&2
  printf 'Press Enter to keep the shown default or type a replacement.\n\n' >&2
  printf 'Provisioning source (os_iso | clone | existing) [%s]: ' "${PROVISION_METHOD}" >&2
  if IFS= read -r provisioning_input; then
    if [[ -n "${provisioning_input}" ]]; then
      PROVISION_METHOD="${provisioning_input}"
    fi
  fi
  if [[ "${PROVISION_METHOD}" == "clone" ]]; then
    prompt_value CHEF360_CLONE_SOURCE "Clone source image path or name" "${CHEF360_CLONE_SOURCE:-}"
  fi
  prompt_value VM_NAME "VM name" "${VM_NAME}"
  prompt_value VM_HOSTNAME "Gateway FQDN" "${VM_HOSTNAME}"
  VM_SHORT_HOSTNAME="${VM_SHORT_HOSTNAME:-${VM_HOSTNAME%%.*}}"
  prompt_value VM_SHORT_HOSTNAME "Short hostname" "${VM_SHORT_HOSTNAME}"
  prompt_value VM_IP "Static IP address" "${VM_IP}"
  prompt_value VM_PREFIX "Network prefix length" "${VM_PREFIX}"
  prompt_value VM_GATEWAY "Default gateway" "${VM_GATEWAY}"
  prompt_value VM_DNS "DNS resolver" "${VM_DNS}"
  prompt_value VM_USER "OS Admin User" "${VM_USER}"
  prompt_value VM_INITIAL_PASSWORD "OS Admin Password" "${VM_INITIAL_PASSWORD}"
  prompt_value CHEF360_ADMIN_CONSOLE_PASSWORD "Platform Admin Password" "${CHEF360_ADMIN_CONSOLE_PASSWORD}"
  prompt_value SSH_PRIVATE_KEY "SSH private key path" "${SSH_PRIVATE_KEY}"
  prompt_value SSH_PUBLIC_KEY "SSH public key path" "${SSH_PUBLIC_KEY}"
  prompt_value TENANT_NAME "Tenant name" "${TENANT_NAME}"
  prompt_value TENANT_OU "Organization name" "${TENANT_OU}"
  prompt_value TENANT_OU_DESCRIPTION "Organization description" "${TENANT_OU_DESCRIPTION}"
  printf '\n' >&2

  # Interactive input may have changed VM_NAME; recompute derived paths.
  KVM_WORK_DIR="${PROJECT_ROOT}/.kvm/${VM_NAME}"
  if [[ "${PLAN_OVERRIDE}" == "1" && "${PLAN_OVERRIDE_VALUE}" != "/dev/null" ]]; then
    PLAN_TARGET="${PLAN_OVERRIDE_VALUE}"
  else
    PLAN_TARGET="${KVM_WORK_DIR}/${VM_NAME}-PLAN.env"
  fi
  PLAN_MD="${KVM_WORK_DIR}/${VM_NAME}-PLAN.md"
fi

# For an existing VM the MAC already exists on the guest; record it so the plan
# and validators agree with the running domain instead of prompting.
resolve_existing_vm_mac() {
  [[ "${PROVISION_METHOD}" == "existing" ]] || return 0
  local live_mac
  live_mac="$(virsh --connect "${LIBVIRT_URI}" dumpxml "${VM_NAME}" 2>/dev/null \
    | sed -n "s/.*mac address='\([0-9a-fA-F:]*\)'.*/\1/p" | head -1)"
  if [[ -n "${live_mac}" ]]; then
    VM_MAC="${live_mac}"
    printf 'Using live VM MAC %s for %s\n' "${live_mac}" "${VM_NAME}" >&2
  else
    printf 'WARN: could not read a MAC from the running %s VM; leaving VM_MAC unset\n' \
      "${VM_NAME}" >&2
    warnings=$((warnings + 1))
  fi
}

# For an existing VM the OS and data disk paths already exist on the host;
# record them so validators check the same files the domain actually uses.
resolve_existing_vm_disks() {
  [[ "${PROVISION_METHOD}" == "existing" ]] || return 0
  local xml="" os_path="" data_path=""
  xml="$(virsh --connect "${LIBVIRT_URI}" dumpxml "${VM_NAME}" 2>/dev/null || true)"
  if [[ -z "${xml}" ]]; then
    printf 'WARN: could not read disk sources from the %s VM\n' "${VM_NAME}" >&2
    return 0
  fi
  # For each <disk>...</disk> block, capture the source file the block
  # references and record it against that block's target device (vda/vdb).
  local dev="" path=""
  while IFS='|' read -r path dev; do
    if [[ -n "${path}" && -n "${dev}" ]]; then
      case "${dev}" in
        vda) os_path="${path}" ;;
        vdb) data_path="${path}" ;;
      esac
    fi
  done < <(awk '
    BEGIN { RS="</disk>"; ORS="" }
    /<disk / {
      path=""; dev=""
      if (match($0, /source file=\x27[^\x27]*\x27/))
        path=substr($0, RSTART+13, RLENGTH-14)
      if (match($0, /target dev=\x27[^\x27]*\x27/))
        dev=substr($0, RSTART+12, RLENGTH-13)
      if (path != "" && dev != "") print path "|" dev "\n"
    }' <<<"${xml}")
  if [[ -n "${os_path}" ]]; then
    [[ -n "${SOURCE_ENV_OS_DISK}" ]] || {
      OS_DISK="${os_path}"
      printf 'Using live OS disk %s for %s\n' "${os_path}" "${VM_NAME}" >&2
    }
  fi
  if [[ -n "${data_path}" && "${data_path}" != "${os_path}" ]]; then
    DATA_DISK="${data_path}"
    printf 'Using live data disk %s for %s\n' "${data_path}" "${VM_NAME}" >&2
  fi
}

resolve_clone_source() {
  [[ "${PROVISION_METHOD}" == "clone" ]] || return 0
  [[ -z "${CHEF360_CLONE_SOURCE}" ]] && return 0
  # Already a path?
  [[ "${CHEF360_CLONE_SOURCE}" == /* || "${CHEF360_CLONE_SOURCE}" == ./* ]] && return 0
  # A bare name; resolve to an existing image.
  local candidate
  for candidate in \
    "${LIBVIRT_IMAGE_DIR}/${CHEF360_CLONE_SOURCE}.qcow2" \
    "${LIBVIRT_IMAGE_DIR}/${CHEF360_CLONE_SOURCE}"; do
    if [[ -f "${candidate}" ]]; then
      CHEF360_CLONE_SOURCE="${candidate}"
      return 0
    fi
  done
  printf 'NOTE: clone source %s not found under %s; using value as a path\n' \
    "${CHEF360_CLONE_SOURCE}" "${LIBVIRT_IMAGE_DIR}" >&2
}

# --- commands ---------------------------------------------------------------

require_command openssl
require_file "${CHEF360_TLS_CERT}" "${CHEF360_TLS_KEY}" "${CHEF360_TLS_CHAIN}"
require_file "${CHEF360_INSTALLER_SOURCE}" "${CHEF360_LICENSE_SOURCE}"
require_file "${SSH_PUBLIC_KEY}"

resolve_clone_source
resolve_existing_vm_mac
resolve_existing_vm_disks

if [[ "${PROVISION_METHOD}" == "os_iso" ]]; then
  require_file "${UBUNTU_ISO}"
  require_command xorriso
elif [[ "${PROVISION_METHOD}" == "clone" ]]; then
  if [[ -z "${CHEF360_CLONE_SOURCE}" ]]; then
    printf 'FAIL: PROVISION_METHOD is "clone" but CHEF360_CLONE_SOURCE is empty\n' >&2
    errors=$((errors + 1))
  else
    require_file "${CHEF360_CLONE_SOURCE}"
  fi
elif [[ "${PROVISION_METHOD}" == "existing" ]]; then
  # The VM is already built and running. No ISO, clone source, or installer
  # boot media is needed; the plan covers only config + install steps.
  :
else
  printf 'FAIL: unknown PROVISION_METHOD: %s (expected "os_iso", "clone", or "existing")\n' \
    "${PROVISION_METHOD}" >&2
  errors=$((errors + 1))
fi

# --- structural checks ------------------------------------------------------

validate_vm_name
validate_ip "VM_IP"            "${VM_IP}"
validate_ip "VM_GATEWAY"       "${VM_GATEWAY}"
validate_ip "VM_DNS"           "${VM_DNS}"
validate_ip "KVM_HOST_IP"      "${KVM_HOST_IP}"
validate_ip "AUTOMATE_IP"      "${AUTOMATE_IP}"
validate_ip "NODE1_IP"         "${NODE1_IP}"
validate_ip "NODE2_IP"         "${NODE2_IP}"
if [[ -n "${VM_MAC:-}" ]]; then
  validate_mac "${VM_MAC}"
fi
validate_port "GATEWAY_NODEPORT"           "${GATEWAY_NODEPORT}"
validate_port "MAILPIT_NODEPORT"           "${MAILPIT_NODEPORT}"
validate_port "RABBITMQ_AMQP_NODEPORT"     "${RABBITMQ_AMQP_NODEPORT}"

if [[ "${VM_SHORT_HOSTNAME}" == *"."* ]]; then
  printf 'WARN: short hostname should not contain a dot: %s\n' \
    "${VM_SHORT_HOSTNAME}" >&2
  warnings=$((warnings + 1))
fi

tenant_portal="${TENANT_SUBDOMAIN}.${TENANT_TLD}"
if [[ "${tenant_portal}" != "${VM_HOSTNAME}" ]]; then
  printf 'FAIL: tenant portal (%s) does not match VM_HOSTNAME (%s) — activation email links will be unreachable\n' \
    "${tenant_portal}" "${VM_HOSTNAME}" >&2
  errors=$((errors + 1))
fi

if [[ "${TENANT_ADMIN_EMAIL}" != *"@${TENANT_TLD}" ]]; then
  printf 'WARN: admin email %s does not end in @%s\n' \
    "${TENANT_ADMIN_EMAIL}" "${TENANT_TLD}" >&2
  warnings=$((warnings + 1))
fi

if (( VM_DATA_DISK_GIB < 200 )); then
  printf 'WARN: /var/lib/embedded-cluster drive is %s GiB (recommended >= 200 GiB)\n' \
    "${VM_DATA_DISK_GIB}" >&2
  warnings=$((warnings + 1))
fi

if (( VM_VCPUS < 15 )); then
  printf 'FAIL: vCPUs must be >= 15 for app preflight (configured %s)\n' \
    "${VM_VCPUS}" >&2
  errors=$((errors + 1))
fi

if (( VM_MEMORY_MIB < 32768 )); then
  printf 'FAIL: memory must be >= 32 GiB for app preflight (configured %s MiB)\n' \
    "${VM_MEMORY_MIB}" >&2
  errors=$((errors + 1))
fi

if openssl x509 -in "${CHEF360_TLS_CERT}" -noout -checkend 0 >/dev/null 2>&1; then
  :
else
  printf 'FAIL: TLS certificate is expired or not yet valid: %s\n' \
    "${CHEF360_TLS_CERT}" >&2
  errors=$((errors + 1))
fi

if openssl verify -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null 2>&1; then
  :
else
  printf 'FAIL: TLS chain verification failed for %s against %s\n' \
    "${CHEF360_TLS_CERT}" "${CHEF360_TLS_CHAIN}" >&2
  errors=$((errors + 1))
fi

if openssl verify -verify_hostname "${VM_HOSTNAME}" \
   -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null 2>&1; then
  :
else
  printf 'FAIL: TLS certificate does not cover hostname %s\n' \
    "${VM_HOSTNAME}" >&2
  errors=$((errors + 1))
fi

if openssl verify -verify_ip "${VM_IP}" \
   -CAfile "${CHEF360_TLS_CHAIN}" "${CHEF360_TLS_CERT}" >/dev/null 2>&1; then
  :
else
  printf 'FAIL: TLS certificate does not cover IP %s\n' "${VM_IP}" >&2
  errors=$((errors + 1))
fi

# --- print the resolved plan ------------------------------------------------

if (( errors > 0 )); then
  printf '\nPlan validation failed with %d error(s) and %d warning(s).\n' \
    "${errors}" "${warnings}" >&2
  exit 1
fi

printf 'Chef 360 build plan validation passed (%d warning(s)).\n\n' \
  "${warnings}"

# --- materialize ------------------------------------------------------------

if [[ "${EXECUTE}" != true ]]; then
  printf 'Run with --execute to write the plan to:\n  %s\n  %s\n' \
    "${PLAN_TARGET}" "${PLAN_MD}"
  exit 0
fi

install -d -m 0700 "${KVM_WORK_DIR}"

# PLAN.env — machine-readable source for lib-chef360-kvm.sh, install scripts,
# and generate-chef360-config.sh. Not secret on disk but protected because
# it holds the admin console password. Paths stay relative to the host so they
# resolve consistently on the KVM host.
PLAN_KEYS=(
  VM_NAME VM_HOSTNAME VM_SHORT_HOSTNAME VM_IP VM_PREFIX VM_GATEWAY VM_DNS
  KVM_HOST_IP KVM_HOST_FQDN AUTOMATE_IP AUTOMATE_FQDN
  NODE1_IP NODE1_FQDN NODE2_IP NODE2_FQDN
  VM_NETWORK VM_MEMORY_MIB VM_VCPUS VM_CPU_SHARES
  VM_OS_DISK_GIB VM_DATA_DISK_GIB VM_DISK_PREALLOCATION
  VM_OS_DISK_SERIAL VM_DATA_DISK_SERIAL VM_MAC OS_DISK DATA_DISK
  VM_USER VM_INITIAL_PASSWORD SSH_PRIVATE_KEY SSH_PUBLIC_KEY
  UBUNTU_ISO UBUNTU_MIRROR
  PROVISION_METHOD CHEF360_CLONE_SOURCE
  CHEF360_INSTALLER_SOURCE CHEF360_LICENSE_SOURCE CHEF360_CONFIG_TEMPLATE
  CHEF360_TLS_CERT CHEF360_TLS_KEY CHEF360_TLS_CHAIN
  CHEF360_ISSUING_CA CHEF360_ROOT_CA
  TENANT_NAME TENANT_TLD TENANT_SUBDOMAIN TENANT_OU TENANT_OU_DESCRIPTION
  TENANT_ADMIN_FIRST_NAME TENANT_ADMIN_LAST_NAME TENANT_ADMIN_EMAIL
  GATEWAY_NODEPORT MAILPIT_NODEPORT RABBITMQ_AMQP_NODEPORT
  CHEF360_ADMIN_CONSOLE_PASSWORD CHEF360_IGNORE_APP_PREFLIGHTS
  SMTP_OPTION STORAGE_OPTION OPENSEARCH_OPTION POSTGRESQL_OPTION TEMPORAL_OPTION
  CNPG_BACKUP_ENABLED CLUSTER_TOPOLOGY PREFLIGHT_STRICT_MODE
)

{
  printf '# Chef 360 build plan for %s\n' "${VM_NAME}"
  printf '# Generated by create-chef360-plan.sh — reviewed and approved values.\n'
  for key in "${PLAN_KEYS[@]}"; do
    # Single-quote every value so PLAN.env can be sourced regardless of
    # embedded spaces, quotes, or shell metacharacters.
    printf '%s=%s\n' "${key}" "'$(printf '%s' "${!key}" | sed "s/'/'\\\\''/g")'"
  done
} > "${PLAN_TARGET}"
chmod 0600 "${PLAN_TARGET}"

# PLAN.md — human-readable companion for audit/review.
if [[ "${PROVISION_METHOD}" == "existing" ]]; then
  VM_EXISTING_NOTE='Plan covers the VM as-is (already built); no VM or disk creation step runs.'
else
  VM_EXISTING_NOTE=''
fi
cat <<PLANMD > "${PLAN_MD}"
# Chef 360 Build Plan

- **Created:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')
- **Machine-readable:** [${VM_NAME}-PLAN.env](${VM_NAME}-PLAN.env)

## 1. Provisioning source

| Setting | Value |
|---|---|
| Provision method | ${PROVISION_METHOD} |
| Clone source | ${CHEF360_CLONE_SOURCE:--} |
| Ubuntu ISO | ${UBUNTU_ISO} |
| Mirror | ${UBUNTU_MIRROR} |
${VM_EXISTING_NOTE}

## 2. Guest identity and network

| Setting | Value |
|---|---|
| VM name | ${VM_NAME} |
| Short hostname | ${VM_SHORT_HOSTNAME} |
| FQDN (gateway hostname) | ${VM_HOSTNAME} |
| IP/prefix | ${VM_IP}/${VM_PREFIX} |
| Gateway | ${VM_GATEWAY} |
| DNS | ${VM_DNS} |
| MAC | assigned by build (unique) |
| OS Admin User | ${VM_USER} |
| SSH public key | ${SSH_PUBLIC_KEY} |

## 3. Compute and storage

| Setting | Value |
|---|---|
| vCPUs | ${VM_VCPUS} |
| CPU shares | ${VM_CPU_SHARES} |
| Memory (MiB) | ${VM_MEMORY_MIB} |
| OS disk | ${VM_OS_DISK_GIB} GiB |
| Data disk (/var/lib/embedded-cluster) | ${VM_DATA_DISK_GIB} GiB |
| Disk preallocation | ${VM_DISK_PREALLOCATION} |
| OS serial | ${VM_OS_DISK_SERIAL} |
| Data serial | ${VM_DATA_DISK_SERIAL} |
| Data disk provisioning (clone) | XFS ftype=1 mounted at /var/lib/embedded-cluster + fstab |

## 4. Certificates

| Setting | Value |
|---|---|
| Leaf cert | ${CHEF360_TLS_CERT} |
| Leaf key | ${CHEF360_TLS_KEY} |
| Chain | ${CHEF360_TLS_CHAIN} |
| Issuing CA | ${CHEF360_ISSUING_CA} |
| Root CA | ${CHEF360_ROOT_CA} |

## 5. Chef 360 application

| Setting | Value |
|---|---|
| Installer | ${CHEF360_INSTALLER_SOURCE} |
| License | ${CHEF360_LICENSE_SOURCE} |
| Config template | ${CHEF360_CONFIG_TEMPLATE} |
| OS Admin User | ${VM_USER} |
| OS Admin Password | ${VM_INITIAL_PASSWORD} |
| Platform Admin Password | ${CHEF360_ADMIN_CONSOLE_PASSWORD} |
| App preflight tolerance | ignore=${CHEF360_IGNORE_APP_PREFLIGHTS} |
| SMTP | ${SMTP_OPTION} (fixed) |
| Storage | ${STORAGE_OPTION} (fixed) |
| OpenSearch | ${OPENSEARCH_OPTION} (fixed) |
| PostgreSQL | ${POSTGRESQL_OPTION} (fixed) |
| Temporal | ${TEMPORAL_OPTION} (fixed) |
| CNPG backup | ${CNPG_BACKUP_ENABLED} (fixed) |
| Cluster topology | ${CLUSTER_TOPOLOGY} (fixed) |
| Preflight strict mode | ${PREFLIGHT_STRICT_MODE} (fixed) |

## 6. Tenant and endpoint configuration

| Setting | Value |
|---|---|
| Tenant name | ${TENANT_NAME} |
| Subdomain | ${TENANT_SUBDOMAIN} |
| TLD | ${TENANT_TLD} |
| Tenant portal | ${TENANT_SUBDOMAIN}.${TENANT_TLD} |
| OU | ${TENANT_OU} — ${TENANT_OU_DESCRIPTION} |
| Admin | ${TENANT_ADMIN_FIRST_NAME} ${TENANT_ADMIN_LAST_NAME} |
| Admin email | ${TENANT_ADMIN_EMAIL} |
| Gateway nodeport | ${GATEWAY_NODEPORT} |
| Mailpit nodeport | ${MAILPIT_NODEPORT} |
| RabbitMQ AMQP nodeport | ${RABBITMQ_AMQP_NODEPORT} |

## 7. Integration endpoints

| Setting | Value |
|---|---|
| KVM host | ${KVM_HOST_IP} (${KVM_HOST_FQDN}) |
| Automate | ${AUTOMATE_IP} (${AUTOMATE_FQDN}) |
| Node 1 | ${NODE1_IP} (${NODE1_FQDN}) |
| Node 2 | ${NODE2_IP} (${NODE2_FQDN}) |

## 8. Approvals

- [ ] Reviewed each section above for this specific build.
- [ ] Tenant portal matches VM_HOSTNAME; email link resolution verified.
- [ ] TLS certificate covers VM_HOSTNAME and VM_IP; chain verified.
- [ ] Installer binary and license exist at the paths listed.
- [ ] Data drive size meets recommended minimum (>= 200 GiB).
- [ ] Plan saved as \`${KVM_WORK_DIR}/${VM_NAME}-PLAN.env\` and ${VM_NAME}-PLAN.md.
PLANMD

printf '\nPlan written:\n  %s\n  %s\n' "${PLAN_TARGET}" "${PLAN_MD}"
