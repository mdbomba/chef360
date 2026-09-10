#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/kvm/lib-chef360-kvm.sh
source "${SCRIPT_DIR}/lib-chef360-kvm.sh"

EXECUTE=false
OPEN_MAILPIT=false
SKIP_CLI_INSTALL=false
SKIP_MAILPIT_EMAIL=false
FAILURES=0
ADMIN_CONSOLE_PORT=30000
CHEF360_PORT=31000
MAILPIT_PORT=31101
POD_POLL_SECONDS="${POD_POLL_SECONDS:-15}"
POD_POLL_ATTEMPTS="${POD_POLL_ATTEMPTS:-120}"
MAILPIT_INITIAL_DELAY="${MAILPIT_INITIAL_DELAY:-60}"
MAILPIT_POLL_SECONDS="${MAILPIT_POLL_SECONDS:-10}"
MAILPIT_POLL_ATTEMPTS="${MAILPIT_POLL_ATTEMPTS:-60}"
MAILPIT_EMAIL_POLL_SECONDS="${MAILPIT_EMAIL_POLL_SECONDS:-10}"
MAILPIT_EMAIL_POLL_ATTEMPTS="${MAILPIT_EMAIL_POLL_ATTEMPTS:-60}"
TENANT_ADMIN_EMAIL="${TENANT_ADMIN_EMAIL:-admin@demo.lab}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute] [--open-mailpit] [--skip-cli-install] [--skip-mailpit-email]

Without --execute, print the validation plan without contacting the VM.
--execute  Run host, guest, Kubernetes, TLS, and endpoint checks.
--open-mailpit  Open the Mailpit UI after an administrator email is available.
--skip-cli-install  Verify current deployment without reinstalling Workstation CLIs.
--skip-mailpit-email  Verify Mailpit reachability without waiting for administrator mail.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    --open-mailpit) OPEN_MAILPIT=true; shift ;;
    --skip-cli-install) SKIP_CLI_INSTALL=true; shift ;;
    --skip-mailpit-email) SKIP_MAILPIT_EMAIL=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

pass() { printf 'PASS: %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; }
fail_check() { printf 'FAIL: %s\n' "$*"; FAILURES=$((FAILURES + 1)); }

cat <<EOF
Chef 360 deployment validation plan
  VM definition:       ${VM_NAME}
  Guest:               ${VM_USER}@${VM_IP} (${VM_HOSTNAME})
  Expected compute:    ${VM_VCPUS} vCPUs, ${VM_CPU_SHARES} CPU shares, ${VM_MEMORY_MIB} MiB RAM
  Expected data path:  /var/lib/embedded-cluster on XFS with ftype=1
  Admin Console:       https://${VM_HOSTNAME}:${ADMIN_CONSOLE_PORT}
  Chef 360 gateway:    https://${VM_HOSTNAME}:${CHEF360_PORT}
  Mailpit:             http://${VM_HOSTNAME}:${MAILPIT_PORT}
  Expected TLS leaf:   ${CHEF360_TLS_CERT}

Checks performed with --execute:
  1. Libvirt VM, compute, disks, network, and CPU shares
  2. SSH, sudo, hostname, services, swap, filesystem, and disk usage
  3. Chef 360 installation marker and installer version
  4. Kubernetes node readiness and Memory/Disk/PID pressure
  5. Poll sudo k0s kubectl until all chef-360 pods are Running or Completed
  6. $([[ "${SKIP_CLI_INSTALL}" == true ]] && printf 'Skip CLI reinstall; use previously verified Workstation CLIs' || printf 'Download and verify all Chef 360 workstation CLIs from the bundled-tools endpoint')
  7. Wait ${MAILPIT_INITIAL_DELAY} seconds, then poll Mailpit until reachable
  8. $([[ "${SKIP_MAILPIT_EMAIL}" == true ]] && printf 'Skip administrator email polling; activation already completed' || printf 'Poll Mailpit for the %s activation email' "${TENANT_ADMIN_EMAIL}")
  9. Check Admin Console pod readiness, evictions, OOM kills, and crash loops
 10. Verify trusted TLS and exact leaf certificate on 30000/31000
 11. Verify Admin Console and Chef 360 gateway HTTP reachability
EOF

if [[ "${EXECUTE}" != true ]]; then
  printf '\nDry run only. No connection was made. Use --execute after deployment.\n'
  exit 0
fi

for command in curl jq openssl ssh virsh; do require_command "${command}"; done
for file in "${SSH_PRIVATE_KEY}" "${CHEF360_TLS_CERT}" "${CHEF360_TLS_CHAIN}"; do require_file "${file}"; done

if ! vm_exists; then
  fail "VM does not exist: ${VM_NAME}"
fi

state="$(virsh_system domstate "${VM_NAME}" 2>/dev/null || true)"
[[ "${state}" == "running" ]] && pass "VM is running" || fail_check "VM state is ${state:-unknown}"
xml="$(virsh_system dumpxml "${VM_NAME}")"
grep -Eq "<vcpu( placement='static')?>${VM_VCPUS}</vcpu>" <<<"${xml}" && pass "vCPU allocation is ${VM_VCPUS}" || fail_check "Unexpected vCPU allocation"
grep -q "<shares>${VM_CPU_SHARES}</shares>" <<<"${xml}" && pass "CPU shares are ${VM_CPU_SHARES}" || fail_check "Unexpected CPU shares"
grep -Eq "<source file='${OS_DISK}'([ />])" <<<"${xml}" && pass "OS disk is attached" || fail_check "OS disk attachment not found"
grep -Eq "<source file='${DATA_DISK}'([ />])" <<<"${xml}" && pass "Data disk is attached" || fail_check "Data disk attachment not found"
grep -Eq "<source network='${VM_NETWORK}'([ />])" <<<"${xml}" && pass "Network is ${VM_NETWORK}" || fail_check "Unexpected VM network"
grep -Fq "<mac address='${VM_MAC}'/>" <<<"${xml}" && pass "MAC address is ${VM_MAC}" || fail_check "Unexpected MAC address"

ssh_args=(
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=accept-new
  -i "${SSH_PRIVATE_KEY}"
)
target="${VM_USER}@${VM_IP}"

if ! ssh "${ssh_args[@]}" "${target}" true >/dev/null 2>&1; then
  fail_check "Key-based SSH failed"
else
  pass "Key-based SSH succeeds"
  static_hostname="$(ssh "${ssh_args[@]}" "${target}" hostnamectl --static)"
  [[ "${static_hostname}" == "${VM_HOSTNAME}" ]] && pass "Static hostname is ${VM_HOSTNAME}" || fail_check "Static hostname is ${static_hostname}"
  actual_hostname="$(ssh "${ssh_args[@]}" "${target}" hostname -f)"
  [[ "${actual_hostname}" == "${VM_HOSTNAME}" ]] && pass "Guest FQDN is ${VM_HOSTNAME}" || fail_check "Guest FQDN is ${actual_hostname}"
  resolved_fqdn_ip="$(ssh "${ssh_args[@]}" "${target}" getent ahostsv4 "${VM_HOSTNAME}" | awk 'NR==1 {print $1}')"
  [[ "${resolved_fqdn_ip}" == "${VM_IP}" ]] && pass "Guest FQDN resolves to ${VM_IP}" || fail_check "Guest FQDN resolves to ${resolved_fqdn_ip:-nothing}"
  ssh "${ssh_args[@]}" "${target}" sudo -n true >/dev/null 2>&1 && pass "Passwordless sudo succeeds" || fail_check "Passwordless sudo failed"
  remote_authorized_fingerprint="$(ssh "${ssh_args[@]}" "${target}" ssh-keygen -lf "/home/${VM_USER}/.ssh/authorized_keys" 2>/dev/null | awk 'NR==1 {print $2}')"
  local_public_fingerprint="$(ssh-keygen -lf "${SSH_PUBLIC_KEY}" | awk '{print $2}')"
  [[ "${remote_authorized_fingerprint}" == "${local_public_fingerprint}" ]] && pass "Guest authorized_keys contains fury_rsa.pub" || fail_check "Guest authorized key fingerprint mismatch"
  for host in "${KVM_HOST_FQDN}" "${AUTOMATE_FQDN}" "${NODE1_FQDN}" "${NODE2_FQDN}"; do
    ssh "${ssh_args[@]}" "${target}" getent hosts "${host}" >/dev/null 2>&1 && pass "Guest resolves ${host}" || fail_check "Guest does not resolve ${host}"
  done
  ssh "${ssh_args[@]}" "${target}" systemctl is-active --quiet ssh && pass "OpenSSH server is active" || fail_check "OpenSSH server is inactive"
  ssh "${ssh_args[@]}" "${target}" systemctl is-active --quiet qemu-guest-agent && pass "QEMU guest agent is active" || fail_check "QEMU guest agent is inactive"
  ssh "${ssh_args[@]}" "${target}" 'files=$(find /etc/netplan -type f -name "*.yaml" -print); test -n "$files" && test -z "$(find /etc/netplan -type f -name "*.yaml" ! -perm 0600 -print)"' && pass "Netplan YAML files use mode 0600" || fail_check "Netplan YAML file permissions are not mode 0600"
  ssh "${ssh_args[@]}" "${target}" 'test "$(swapon --noheadings 2>/dev/null | wc -l)" -eq 0' && pass "Swap is disabled" || fail_check "Swap is active"
  ssh "${ssh_args[@]}" "${target}" findmnt -n -o FSTYPE /var/lib/embedded-cluster | grep -qx xfs && pass "Data path uses XFS" || fail_check "Data path is not XFS"
  ssh "${ssh_args[@]}" "${target}" xfs_info /var/lib/embedded-cluster 2>/dev/null | grep -q 'ftype=1' && pass "XFS ftype=1 is enabled" || fail_check "XFS ftype=1 not verified"
  disk_usage="$(ssh "${ssh_args[@]}" "${target}" df -P /var/lib/embedded-cluster | awk 'NR==2 {gsub(/%/, "", $5); print $5}')"
  if [[ "${disk_usage}" =~ ^[0-9]+$ ]] && ((disk_usage < 80)); then
    pass "Data filesystem usage is ${disk_usage}%"
  else
    fail_check "Data filesystem usage is ${disk_usage:-unknown}% (must be below 80%)"
  fi
  ssh "${ssh_args[@]}" "${target}" test -f /var/lib/chef360-install-complete && pass "Chef 360 install marker exists" || fail_check "Chef 360 install marker is missing"
  version_output="$(ssh "${ssh_args[@]}" "${target}" sudo -n /opt/chef360/chef-360 version 2>/dev/null || true)"
  grep -Eq '\| chef-360[[:space:]]+\| 1\.7\.3[[:space:]]+\|' <<<"${version_output}" && pass "Chef 360 version is 1.7.3" || fail_check "Chef 360 version 1.7.3 not verified"

  pods_ready=false
  for attempt in $(seq 1 "${POD_POLL_ATTEMPTS}"); do
    if ! chef360_pod_table="$(ssh "${ssh_args[@]}" "${target}" sudo -n k0s kubectl get pods -n chef-360 --no-headers 2>/dev/null)"; then
      printf 'WAIT: Chef 360 pod query unavailable (%d/%d)\n' "${attempt}" "${POD_POLL_ATTEMPTS}"
    elif [[ -z "${chef360_pod_table}" ]]; then
      printf 'WAIT: No Chef 360 pods found yet (%d/%d)\n' "${attempt}" "${POD_POLL_ATTEMPTS}"
    else
      nonready_pods="$(printf '%s\n' "${chef360_pod_table}" | grep -v Running | grep -v Completed || true)"
      if [[ -z "${nonready_pods}" ]]; then
        pods_ready=true
        pass "All Chef 360 pods are Running or Completed"
        break
      fi
      printf 'WAIT: Chef 360 pods are not ready (%d/%d):\n%s\n' "${attempt}" "${POD_POLL_ATTEMPTS}" "${nonready_pods}"
    fi
    sleep "${POD_POLL_SECONDS}"
  done
  [[ "${pods_ready}" == true ]] || fail_check "Timed out waiting for Chef 360 pods to be Running or Completed"

  if [[ "${pods_ready}" == true && "${SKIP_CLI_INSTALL}" != true ]]; then
    if "${SCRIPT_DIR}/install-chef360-workstation-clis.sh" --execute; then
      pass "Chef 360 workstation CLIs are installed"
    else
      fail_check "Chef 360 workstation CLI installation failed"
    fi
  fi

  nodes_json="$(ssh "${ssh_args[@]}" "${target}" sudo -n env KUBECONFIG=/var/lib/embedded-cluster/k0s/pki/admin.conf /var/lib/embedded-cluster/bin/kubectl get nodes -o json 2>/dev/null || true)"
  pods_json="$(ssh "${ssh_args[@]}" "${target}" sudo -n env KUBECONFIG=/var/lib/embedded-cluster/k0s/pki/admin.conf /var/lib/embedded-cluster/bin/kubectl get pods -A -o json 2>/dev/null || true)"
  if [[ -z "${nodes_json}" || -z "${pods_json}" ]] || ! jq -e '.items' >/dev/null 2>&1 <<<"${nodes_json}" || ! jq -e '.items' >/dev/null 2>&1 <<<"${pods_json}"; then
    fail_check "Unable to query Kubernetes nodes and pods"
  else
    node_count="$(jq '.items | length' <<<"${nodes_json}")"
    not_ready_nodes="$(jq '[.items[] | select(([.status.conditions[]? | select(.type == "Ready") | .status] | first) != "True")] | length' <<<"${nodes_json}")"
    pressure_conditions="$(jq '[.items[] | .status.conditions[]? | select((.type == "MemoryPressure" or .type == "DiskPressure" or .type == "PIDPressure") and .status == "True")] | length' <<<"${nodes_json}")"
    bad_pods="$(jq '[.items[] | select(.metadata.namespace == "chef-360" or .metadata.namespace == "kotsadm") | select(.status.phase != "Running" and .status.phase != "Succeeded")] | length' <<<"${pods_json}")"
    unready_containers="$(jq '[.items[] | select(.metadata.namespace == "chef-360" or .metadata.namespace == "kotsadm") | select(.status.phase == "Running") | .status.containerStatuses[]? | select(.ready != true)] | length' <<<"${pods_json}")"
    evicted="$(jq '[.items[] | select(.metadata.namespace == "chef-360" or .metadata.namespace == "kotsadm") | select(.status.reason == "Evicted")] | length' <<<"${pods_json}")"
    current_oom="$(jq '[.items[] | select(.metadata.namespace == "chef-360" or .metadata.namespace == "kotsadm") | .status.containerStatuses[]? | select(.state.terminated.reason == "OOMKilled")] | length' <<<"${pods_json}")"
    recovered_oom="$(jq '[.items[] | select(.metadata.namespace == "chef-360" or .metadata.namespace == "kotsadm") | .status.containerStatuses[]? | select(.lastState.terminated.reason == "OOMKilled" and .ready == true)] | length' <<<"${pods_json}")"
    crash_loops="$(jq '[.items[] | select(.metadata.namespace == "chef-360" or .metadata.namespace == "kotsadm") | .status.containerStatuses[]? | select(.state.waiting.reason == "CrashLoopBackOff")] | length' <<<"${pods_json}")"
    ((node_count >= 1 && not_ready_nodes == 0)) && pass "All ${node_count} Kubernetes node(s) are Ready" || fail_check "Kubernetes has ${not_ready_nodes} not-ready node(s)"
    ((pressure_conditions == 0)) && pass "No Kubernetes Memory, Disk, or PID pressure" || fail_check "Kubernetes reports ${pressure_conditions} pressure condition(s)"
    ((bad_pods == 0)) && pass "Chef 360 and Admin Console pods are Running or Succeeded" || fail_check "Chef 360/Admin Console has ${bad_pods} pod(s) in an unexpected phase"
    ((unready_containers == 0)) && pass "Running Chef 360 and Admin Console containers are ready" || fail_check "Chef 360/Admin Console has ${unready_containers} unready running container(s)"
    ((evicted == 0)) && pass "No Chef 360 or Admin Console pod evictions" || fail_check "Chef 360/Admin Console has ${evicted} evicted pod(s)"
    ((current_oom == 0)) && pass "No current Chef 360 or Admin Console OOM terminations" || fail_check "Chef 360/Admin Console has ${current_oom} current OOM termination(s)"
    if ((recovered_oom > 0)); then
      warn "${recovered_oom} running container(s) recovered from an earlier OOM kill; monitor recurrence"
    fi
    ((crash_loops == 0)) && pass "No Chef 360 or Admin Console crash loops" || fail_check "Chef 360/Admin Console has ${crash_loops} crash-looping container(s)"
  fi
fi

expected_fingerprint="$(openssl x509 -in "${CHEF360_TLS_CERT}" -noout -fingerprint -sha256 | cut -d= -f2)"
for port in "${ADMIN_CONSOLE_PORT}" "${CHEF360_PORT}"; do
  tls_output="$(timeout 15 openssl s_client \
    -connect "${VM_IP}:${port}" \
    -servername "${VM_HOSTNAME}" \
    -verify_hostname "${VM_HOSTNAME}" \
    -verify_return_error \
    -CAfile "${CHEF360_TLS_CHAIN}" </dev/null 2>&1 || true)"
  if grep -q 'Verify return code: 0 (ok)' <<<"${tls_output}"; then
    pass "Trusted TLS succeeds on port ${port}"
    served_fingerprint="$(sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' <<<"${tls_output}" | openssl x509 -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2 || true)"
    [[ "${served_fingerprint}" == "${expected_fingerprint}" ]] && pass "Port ${port} serves chef360-2.crt" || fail_check "Port ${port} serves an unexpected leaf certificate"
  else
    fail_check "TLS verification failed on port ${port}"
  fi
done

for endpoint in \
  "https://${VM_HOSTNAME}:${ADMIN_CONSOLE_PORT}/" \
  "https://${VM_HOSTNAME}:${CHEF360_PORT}/"; do
  port="${endpoint#*:}"; port="${port#*:}"; port="${port%%/*}"
  http_status="$(curl --silent --show-error --max-time 15 \
    --cacert "${CHEF360_TLS_CHAIN}" \
    --resolve "${VM_HOSTNAME}:${port}:${VM_IP}" \
    --output /dev/null --write-out '%{http_code}' "${endpoint}" || true)"
  if [[ "${http_status}" =~ ^[1-5][0-9][0-9]$ ]]; then
    pass "Endpoint is reachable: ${endpoint} (HTTP ${http_status})"
  else
    fail_check "Endpoint is unreachable: ${endpoint}"
  fi
done

if [[ "${pods_ready:-false}" == true ]]; then
  printf 'WAIT: Pods are ready; allowing %s seconds for Mailpit startup.\n' "${MAILPIT_INITIAL_DELAY}"
  sleep "${MAILPIT_INITIAL_DELAY}"
fi

mailpit_url="http://${VM_HOSTNAME}:${MAILPIT_PORT}"
mailpit_reachable=false
for attempt in $(seq 1 "${MAILPIT_POLL_ATTEMPTS}"); do
  mailpit_status="$(curl --silent --show-error --max-time 15 \
    --resolve "${VM_HOSTNAME}:${MAILPIT_PORT}:${VM_IP}" \
    --output /dev/null --write-out '%{http_code}' "${mailpit_url}/" || true)"
  if [[ "${mailpit_status}" =~ ^[1-5][0-9][0-9]$ ]]; then
    mailpit_reachable=true
    pass "Mailpit is reachable on port ${MAILPIT_PORT} (HTTP ${mailpit_status})"
    break
  fi
  printf 'WAIT: Mailpit is not reachable (%d/%d)\n' "${attempt}" "${MAILPIT_POLL_ATTEMPTS}"
  sleep "${MAILPIT_POLL_SECONDS}"
done
[[ "${mailpit_reachable}" == true ]] || fail_check "Timed out waiting for Mailpit on port ${MAILPIT_PORT}"

admin_message_id=""
activation_url=""
if [[ "${mailpit_reachable}" == true && "${SKIP_MAILPIT_EMAIL}" != true ]]; then
  for attempt in $(seq 1 "${MAILPIT_EMAIL_POLL_ATTEMPTS}"); do
    messages_json="$(curl --silent --show-error --max-time 15 \
      --resolve "${VM_HOSTNAME}:${MAILPIT_PORT}:${VM_IP}" \
      "${mailpit_url}/api/v1/messages?limit=50" || true)"
    if jq -e '.messages | type == "array"' >/dev/null 2>&1 <<<"${messages_json}"; then
      admin_message_id="$(jq -r --arg email "${TENANT_ADMIN_EMAIL}" '
        [.messages[]? | select(any(.To[]?; ((.Address // .address // "") | ascii_downcase) == ($email | ascii_downcase)))]
        | first.ID // first.id // empty
      ' <<<"${messages_json}")"
    fi
    if [[ -n "${admin_message_id}" ]]; then
      pass "Mailpit received an email for ${TENANT_ADMIN_EMAIL}"
      break
    fi
    printf 'WAIT: Administrator email has not arrived (%d/%d)\n' "${attempt}" "${MAILPIT_EMAIL_POLL_ATTEMPTS}"
    sleep "${MAILPIT_EMAIL_POLL_SECONDS}"
  done

  if [[ -z "${admin_message_id}" ]]; then
    fail_check "Timed out waiting for an email to ${TENANT_ADMIN_EMAIL}"
  else
    message_json="$(curl --silent --show-error --max-time 15 \
      --resolve "${VM_HOSTNAME}:${MAILPIT_PORT}:${VM_IP}" \
      "${mailpit_url}/api/v1/message/${admin_message_id}" || true)"
    if jq -e . >/dev/null 2>&1 <<<"${message_json}"; then
      activation_url="$(jq -r '.. | strings' <<<"${message_json}" \
        | grep -Eo "https?://[^[:space:]<>\"']+" \
        | grep -E "${VM_HOSTNAME//./\\.}|${VM_IP//./\\.}" \
        | sed 's/&amp;/\&/g' \
        | sed 's/[][),.;]*$//' \
        | sed -n '1p' || true)"
    fi
    if [[ -n "${activation_url}" ]]; then
      printf 'ADMIN_ACTIVATION_URL=%s\n' "${activation_url}"
    else
      printf 'Administrator email is available, but no activation URL was extracted.\n'
      printf 'Open Mailpit to complete the initial administrator login: %s\n' "${mailpit_url}/"
    fi
  fi
fi

if [[ "${OPEN_MAILPIT}" == true && "${mailpit_reachable}" == true ]]; then
  if command -v xdg-open >/dev/null 2>&1; then
    nohup xdg-open "${mailpit_url}/" >/dev/null 2>&1 &
    pass "Opened Mailpit in the host browser"
  else
    fail_check "--open-mailpit requested but xdg-open is unavailable"
  fi
fi

if ((FAILURES > 0)); then
  printf '\nChef 360 deployment validation failed with %d issue(s).\n' "${FAILURES}" >&2
  exit 1
fi
printf '\nChef 360 deployment validation passed.\n'
