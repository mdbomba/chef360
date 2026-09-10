#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys


def expected_ps_counterparts(sh_stem: str) -> set[str]:
    expected = {sh_stem}
    if sh_stem in {"deploy-azure-two-linux", "destroy-azure-two-linux"}:
        expected.add(f"{sh_stem}-full")
    return expected


def expected_sh_counterparts(ps_stem: str) -> set[str]:
    if ps_stem.endswith("-full"):
        return {ps_stem[: -len("-full")]}
    return {ps_stem}


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    azure_dir = repo_root / "scripts" / "azure"

    sh_stems = {p.stem for p in azure_dir.glob("*.sh")}
    ps_stems = {p.stem for p in azure_dir.glob("*.ps1")}

    errors: list[str] = []

    for sh_stem in sorted(sh_stems):
        if expected_ps_counterparts(sh_stem).isdisjoint(ps_stems):
            allowed = ", ".join(sorted(expected_ps_counterparts(sh_stem)))
            errors.append(
                f"Missing PowerShell counterpart for '{sh_stem}.sh' (expected one of: {allowed}.ps1)"
            )

    for ps_stem in sorted(ps_stems):
        if expected_sh_counterparts(ps_stem).isdisjoint(sh_stems):
            allowed = ", ".join(sorted(expected_sh_counterparts(ps_stem)))
            errors.append(
                f"Missing Bash counterpart for '{ps_stem}.ps1' (expected: {allowed}.sh)"
            )

    if errors:
        print("Azure script parity check failed:")
        for err in errors:
            print(f"- {err}")
        return 1

    print("Azure script parity check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
