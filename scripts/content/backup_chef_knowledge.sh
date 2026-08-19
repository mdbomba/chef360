#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_ROOT="${CHEF_KNOWLEDGE_BACKUP_DIR:-$HOME/.local/share/chef360-knowledge-backups}"
RETENTION_COUNT="${CHEF_KNOWLEDGE_BACKUP_RETENTION:-8}"

if [[ ! "$RETENTION_COUNT" =~ ^[1-9][0-9]*$ ]]; then
  printf '%s\n' 'CHEF_KNOWLEDGE_BACKUP_RETENTION must be a positive integer.' >&2
  exit 2
fi

required_files=(
  "docs/chef-cft-metadata-index.json"
  "docs/chef-cft-metadata-index.md"
  "docs/chef-cft-knowledge-guide.md"
  "data/chef-cft-knowledge.sqlite3"
  "config/chef-cft-corpus.json"
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -f "$ROOT_DIR/$relative_path" ]]; then
    printf 'Required knowledge artifact is missing: %s\n' "$relative_path" >&2
    exit 1
  fi
done

umask 077
mkdir -p "$BACKUP_ROOT"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
temporary="$BACKUP_ROOT/.${timestamp}.tmp"
destination="$BACKUP_ROOT/$timestamp"
mkdir "$temporary"

cleanup() {
  rm -rf -- "$temporary"
}
trap cleanup EXIT

cp -- "$ROOT_DIR/docs/chef-cft-metadata-index.json" "$temporary/"
cp -- "$ROOT_DIR/docs/chef-cft-metadata-index.md" "$temporary/"
cp -- "$ROOT_DIR/docs/chef-cft-knowledge-guide.md" "$temporary/"
cp -- "$ROOT_DIR/data/chef-cft-knowledge.sqlite3" "$temporary/"
cp -- "$ROOT_DIR/config/chef-cft-corpus.json" "$temporary/"

(
  cd -- "$temporary"
  sha256sum -- * > SHA256SUMS
)

mv -- "$temporary" "$destination"
trap - EXIT
ln -sfn -- "$timestamp" "$BACKUP_ROOT/latest"

mapfile -t backups < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
if (( ${#backups[@]} > RETENTION_COUNT )); then
  for old_backup in "${backups[@]:RETENTION_COUNT}"; do
    rm -rf -- "$BACKUP_ROOT/$old_backup"
  done
fi

printf 'Created protected Chef knowledge backup: %s\n' "$destination"
