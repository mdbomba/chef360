#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/chef360-knowledge-refresh.lock"
LOG_DIR="${CHEF_KNOWLEDGE_LOG_DIR:-$HOME/.local/state/chef360-knowledge}"

umask 077
mkdir -p "$LOG_DIR"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  printf '%s\n' 'Chef knowledge refresh is already running.'
  exit 0
fi

exec >>"$LOG_DIR/refresh.log" 2>&1
printf '\n[%s] Starting Chef knowledge refresh\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

python3 "$ROOT_DIR/scripts/content/chef_cft_org_index.py" build
python3 "$ROOT_DIR/scripts/content/build_chef_cft_corpus.py" build

python3 - "$ROOT_DIR" <<'PY'
import json
import sqlite3
import sys
from pathlib import Path

root = Path(sys.argv[1])
index = json.loads((root / "docs/chef-cft-metadata-index.json").read_text(encoding="utf-8"))
if index["coverage"]["indexed_repository_count"] != index["organization"]["visible_repository_count"]:
    raise SystemExit("Repository metadata coverage is incomplete")
if index["coverage"].get("tree_failure_count", 0) != 0:
    raise SystemExit("Repository metadata contains tree failures")

database = root / "data/chef-cft-knowledge.sqlite3"
connection = sqlite3.connect(f"file:{database}?mode=ro&immutable=1", uri=True)
metadata = {
    row[0]: json.loads(row[1])
    for row in connection.execute("SELECT key, value FROM metadata")
}
if metadata.get("totals", {}).get("failures", 0) != 0:
    raise SystemExit("Knowledge corpus contains download failures")
if connection.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
    raise SystemExit("Knowledge corpus integrity check failed")
if connection.execute("SELECT COUNT(*) FROM chunks_fts").fetchone()[0] == 0:
    raise SystemExit("Knowledge corpus contains no searchable chunks")
PY

"$ROOT_DIR/scripts/content/backup_chef_knowledge.sh"
printf '[%s] Chef knowledge refresh completed\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
