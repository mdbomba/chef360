#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="/var/lib/embedded-cluster"
MIN_CPUS=2
MIN_MEMORY_MIB=2048
MIN_DISK_GIB=40

usage() {
  printf 'Usage: %s [--data-dir PATH] [--min-cpus N] [--min-memory-mib N] [--min-disk-gib N]\n' "$(basename "$0")"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --data-dir) DATA_DIR="${2:?Missing value for --data-dir}"; shift 2 ;;
    --min-cpus) MIN_CPUS="${2:?Missing value for --min-cpus}"; shift 2 ;;
    --min-memory-mib) MIN_MEMORY_MIB="${2:?Missing value for --min-memory-mib}"; shift 2 ;;
    --min-disk-gib) MIN_DISK_GIB="${2:?Missing value for --min-disk-gib}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

failures=0
warnings=0

pass() { printf 'PASS: %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }

if [[ "$(uname -s)" == "Linux" ]]; then
  pass "Linux operating system detected"
else
  fail "Chef 360 Embedded Cluster requires a Linux guest"
fi

if command -v systemctl >/dev/null 2>&1; then
  pass "systemd tools are available"
else
  fail "systemd tools are not available"
fi

cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '0')"
if [[ "${cpu_count}" =~ ^[0-9]+$ ]] && ((cpu_count >= MIN_CPUS)); then
  pass "${cpu_count} CPU cores available (minimum ${MIN_CPUS})"
else
  fail "${cpu_count} CPU cores available (minimum ${MIN_CPUS})"
fi

memory_mib="$(awk '/^MemTotal:/ {printf "%d", $2 / 1024}' /proc/meminfo 2>/dev/null || true)"
memory_mib="${memory_mib:-0}"
if ((memory_mib >= MIN_MEMORY_MIB)); then
  pass "${memory_mib} MiB memory available (minimum ${MIN_MEMORY_MIB} MiB)"
else
  fail "${memory_mib} MiB memory available (minimum ${MIN_MEMORY_MIB} MiB)"
fi

disk_probe="${DATA_DIR}"
while [[ ! -e "${disk_probe}" && "${disk_probe}" != "/" ]]; do
  disk_probe="$(dirname "${disk_probe}")"
done
disk_total_kib="$(df -Pk "${disk_probe}" | awk 'NR==2 {print $2}')"
disk_used_percent="$(df -Pk "${disk_probe}" | awk 'NR==2 {gsub(/%/, "", $5); print $5}')"
disk_total_gib=$((disk_total_kib / 1024 / 1024))
if ((disk_total_gib >= MIN_DISK_GIB)); then
  pass "${disk_probe} filesystem has ${disk_total_gib} GiB total space (minimum ${MIN_DISK_GIB} GiB)"
else
  fail "${disk_probe} filesystem has ${disk_total_gib} GiB total space (minimum ${MIN_DISK_GIB} GiB)"
fi
if ((disk_used_percent < 80)); then
  pass "${disk_probe} filesystem is ${disk_used_percent}% full (must be less than 80%)"
else
  fail "${disk_probe} filesystem is ${disk_used_percent}% full (must be less than 80%)"
fi

hostname_value="$(hostname 2>/dev/null || true)"
if [[ -n "${hostname_value}" && "${hostname_value}" != "localhost" ]]; then
  pass "hostname is ${hostname_value}"
else
  fail "set a stable, non-localhost hostname"
fi

if getent hosts "${hostname_value}" >/dev/null 2>&1; then
  pass "hostname resolves through the guest resolver"
else
  warn "hostname does not resolve; configure DNS or /etc/hosts before installation"
fi

if command -v timedatectl >/dev/null 2>&1 && timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -qx yes; then
  pass "system clock is synchronized"
else
  warn "could not confirm system clock synchronization"
fi

if [[ -e /var/lib/kubelet || -e /etc/k0s/k0s.yaml ]]; then
  warn "existing Kubernetes state detected; use a dedicated host unless this is an existing Chef 360 node"
fi

if ((failures > 0)); then
  printf '\nHost check failed with %d failure(s) and %d warning(s).\n' "${failures}" "${warnings}" >&2
  exit 1
fi

printf '\nHost check passed with %d warning(s). The Chef 360 installer remains authoritative for preflight validation.\n' "${warnings}"
