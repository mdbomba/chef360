#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
failures=0

while IFS= read -r -d '' script; do
  if bash -n "${script}"; then
    printf 'PASS: bash syntax %s\n' "${script}"
  else
    printf 'FAIL: bash syntax %s\n' "${script}"
    failures=$((failures + 1))
  fi
done < <(git -C "${REPO_ROOT}" ls-files -z 'scripts/*.sh' 'scripts/**/*.sh')

while IFS= read -r -d '' script; do
  if python3 -m py_compile "${script}"; then
    printf 'PASS: Python syntax %s\n' "${script}"
  else
    printf 'FAIL: Python syntax %s\n' "${script}"
    failures=$((failures + 1))
  fi
done < <(git -C "${REPO_ROOT}" ls-files -z 'scripts/*.py' 'scripts/**/*.py')

if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r -d '' script; do
    if shellcheck -S error "${script}"; then
      printf 'PASS: shellcheck %s\n' "${script}"
    else
      printf 'FAIL: shellcheck %s\n' "${script}"
      failures=$((failures + 1))
    fi
  done < <(git -C "${REPO_ROOT}" ls-files -z 'scripts/*.sh' 'scripts/**/*.sh')
else
  printf 'WARN: shellcheck is unavailable; skipped shell static analysis.\n'
fi

if command -v pwsh >/dev/null 2>&1; then
  while IFS= read -r -d '' script; do
    if TARGET_SCRIPT="${REPO_ROOT}/${script}" pwsh -NoProfile -Command "\$errors = \$null; [System.Management.Automation.Language.Parser]::ParseFile(\$env:TARGET_SCRIPT, [ref]\$null, [ref]\$errors) | Out-Null; if (\$errors.Count) { \$errors | ForEach-Object { Write-Error \$_.Message }; exit 1 }"; then
      printf 'PASS: PowerShell syntax %s\n' "${script}"
    else
      printf 'FAIL: PowerShell syntax %s\n' "${script}"
      failures=$((failures + 1))
    fi
  done < <(git -C "${REPO_ROOT}" ls-files -z 'scripts/azure/*.ps1' 'scripts/lib/*.ps1')
else
  printf 'WARN: pwsh is unavailable; skipped PowerShell syntax analysis.\n'
fi

if (( failures > 0 )); then
  printf 'Script verification failed with %d issue(s).\n' "${failures}" >&2
  exit 1
fi

printf 'Script verification passed.\n'
