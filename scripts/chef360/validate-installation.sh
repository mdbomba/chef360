#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="/var/lib/embedded-cluster"
NAMESPACE="chef-360"
ADMIN_URL=""
TENANT_URL=""

usage() {
  printf 'Usage: %s [--data-dir PATH] [--namespace NAME] [--admin-url URL] [--tenant-url URL]\n' "$(basename "$0")"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --data-dir) DATA_DIR="${2:?Missing value for --data-dir}"; shift 2 ;;
    --namespace) NAMESPACE="${2:?Missing value for --namespace}"; shift 2 ;;
    --admin-url) ADMIN_URL="${2:?Missing value for --admin-url}"; shift 2 ;;
    --tenant-url) TENANT_URL="${2:?Missing value for --tenant-url}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

KUBECTL="${DATA_DIR}/bin/kubectl"
KUBECONFIG="${DATA_DIR}/k0s/pki/admin.conf"
if [[ ! -x "${KUBECTL}" || ! -r "${KUBECONFIG}" ]]; then
  printf 'Embedded Cluster kubectl or kubeconfig not found below %s.\n' "${DATA_DIR}" >&2
  exit 1
fi

run_kubectl() {
  if ((EUID == 0)); then
    env KUBECONFIG="${KUBECONFIG}" "${KUBECTL}" "$@"
  else
    sudo env KUBECONFIG="${KUBECONFIG}" "${KUBECTL}" "$@"
  fi
}

printf 'Cluster nodes:\n'
run_kubectl get nodes -o wide
printf '\nChef 360 workloads:\n'
run_kubectl -n "${NAMESPACE}" get pods

pod_readiness="$(run_kubectl -n "${NAMESPACE}" get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.ready}{" "}{end}{"\n"}{end}')"
if [[ -z "${pod_readiness}" ]]; then
  printf 'No workloads found in namespace %s.\n' "${NAMESPACE}" >&2
  exit 1
fi
not_ready="$(printf '%s\n' "${pod_readiness}" | awk '$0 ~ /false/ {print $1}')"
if [[ -n "${not_ready}" ]]; then
  printf '\nNot-ready workloads:\n%s\n' "${not_ready}" >&2
  exit 1
fi

for endpoint in "${ADMIN_URL}" "${TENANT_URL}"; do
  [[ -z "${endpoint}" ]] && continue
  if curl --fail --silent --show-error --insecure --max-time 15 --output /dev/null "${endpoint}"; then
    printf 'Endpoint reachable: %s\n' "${endpoint}"
  else
    printf 'Endpoint is not reachable: %s\n' "${endpoint}" >&2
    exit 1
  fi
done

printf '\nChef 360 installation validation passed.\n'
