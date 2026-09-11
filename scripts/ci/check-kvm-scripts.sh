#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KVM_DIR="${REPO_ROOT}/scripts/kvm"

failures=0
while IFS= read -r -d '' script; do
  if bash -n "${script}"; then
    printf 'PASS: bash syntax %s\n' "${script}"
  else
    printf 'FAIL: bash syntax %s\n' "${script}"
    failures=$((failures + 1))
  fi
done < <(find "${KVM_DIR}" -maxdepth 1 -type f -name '*.sh' -print0)

if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r -d '' script; do
    if shellcheck -S error "${script}" >/dev/null 2>&1; then
      printf 'PASS: shellcheck %s\n' "${script}"
    else
      printf 'FAIL: shellcheck %s\n' "${script}"
      failures=$((failures + 1))
    fi
  done < <(find "${KVM_DIR}" -maxdepth 1 -type f -name '*.sh' -print0)
fi

if (( failures > 0 )); then
  printf '\nKVM script verification failed with %d issue(s).\n' "${failures}" >&2
  exit 1
fi

printf '\nKVM script verification passed.\n'