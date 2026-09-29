#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="${REPO_ROOT}/scripts/kvm/install-chef360.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "${TEST_ROOT}"' EXIT

export HOME="${TEST_ROOT}/home"
mkdir -p "${HOME}"
export CHEF360_SECRETS_PARAMS="${TEST_ROOT}/missing-secrets"
export CHEF360_PROJECT_PARAMS="${TEST_ROOT}/missing-project-params"
export KVM_CHEF360_STATE_FILE="${TEST_ROOT}/missing-state"
export CHEF360_INSTALLER_SOURCE="${TEST_ROOT}/chef-360"

default_output="$("${INSTALLER}")"
for flag in --data-dir --local-artifact-mirror-port --cidr --network-interface \
  --admin-console-port --tls-cert --tls-key --config-values --airgap-bundle; do
  if grep -q -- "${flag}" <<<"${default_output}"; then
    printf 'Unexpected default option: %s\n' "${flag}" >&2
    exit 1
  fi
done
for flag in --ignore-host-preflights --ignore-app-preflights --yes; do
  grep -q -- "${flag}" <<<"${default_output}" || {
    printf 'Missing required option: %s\n' "${flag}" >&2
    exit 1
  }
done

mkdir -p "${TEST_ROOT}/certs" "${TEST_ROOT}/assets"
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${TEST_ROOT}/certs/matching.key" \
  -out "${TEST_ROOT}/certs/matching.crt" -days 2 \
  -subj /CN=chef360.demo.lab \
  -addext 'subjectAltName=DNS:chef360.demo.lab,IP:10.0.0.20' >/dev/null 2>&1
cp "${TEST_ROOT}/certs/matching.crt" "${TEST_ROOT}/certs/chain.crt"
openssl genrsa -out "${TEST_ROOT}/certs/unmatched.key" 2048 >/dev/null 2>&1
: > "${TEST_ROOT}/assets/chef-360.airgap"

export CHEF360_TLS_CERT="${TEST_ROOT}/certs/matching.crt"
export CHEF360_TLS_KEY="${TEST_ROOT}/certs/matching.key"
export CHEF360_TLS_CHAIN="${TEST_ROOT}/certs/chain.crt"
export CHEF360_ADMIN_CONSOLE_PORT=30001
export CHEF360_CLUSTER_CIDR=10.0.0.0/16
export CHEF360_DATA_DIR=/srv/embedded
export CHEF360_LOCAL_ARTIFACT_MIRROR_PORT=50001
export CHEF360_NETWORK_INTERFACE=ens5
export CHEF360_AIRGAP_BUNDLE="${TEST_ROOT}/assets/chef-360.airgap"
export CHEF360_HTTP_PROXY=http://proxy.example:8080
export CHEF360_HTTPS_PROXY=https://proxy.example:8443
export CHEF360_NO_PROXY=localhost

override_output="$("${INSTALLER}")"
for flag in --tls-cert --tls-key --data-dir --local-artifact-mirror-port \
  --cidr --network-interface --admin-console-port --airgap-bundle \
  --http-proxy --https-proxy --no-proxy; do
  grep -q -- "${flag}" <<<"${override_output}" || {
    printf 'Missing override option: %s\n' "${flag}" >&2
    exit 1
  }
done

export CHEF360_TLS_KEY="${TEST_ROOT}/certs/unmatched.key"
mismatched_output="$("${INSTALLER}")"
if grep -q -- --tls-cert <<<"${mismatched_output}" || grep -q -- --tls-key <<<"${mismatched_output}"; then
  printf 'TLS options were emitted for a mismatched certificate/key pair\n' >&2
  exit 1
fi

if grep -q 'should-not-be-printed' <<<"${default_output}"; then
  printf 'A password was unexpectedly printed\n' >&2
  exit 1
fi

printf 'PASS: Chef 360 installer default, override, and TLS-pair argument checks\n'
