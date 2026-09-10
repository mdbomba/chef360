"""Shared secret resolution for Chef CFT content builders.

Secrets are read from the environment first, then from a dedicated local file
if one is supplied, then from `export VAR="..."` lines in ~/.bashrc. Values
are never written to any output artifact by the callers.
"""

from __future__ import annotations

import os
from pathlib import Path


def load_secret(
    name: str,
    fallback_path: str | Path | None = None,
    rc: str | Path | None = None,
) -> str | None:
    value = os.environ.get(name)
    if value:
        return value

    if fallback_path is not None:
        path = Path(fallback_path)
        if path.is_file():
            value = path.read_text(encoding="utf-8").strip()
            if value:
                return value

    if rc is None:
        rc = Path.home() / ".bashrc"
    try:
        lines = Path(rc).read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None

    prefix = f"{name}="
    for line in lines:
        line = line.strip()
        if line.startswith("export "):
            line = line[len("export ") :]
        if not line.startswith(prefix):
            continue
        value = line[len(prefix) :]
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        value = value.split("#", 1)[0].strip()
        if value:
            return value
    return None