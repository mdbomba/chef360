#!/usr/bin/env python3
"""Download, sanitize, convert, and index selected Chef CFT knowledge in SQLite FTS5."""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import fnmatch
import hashlib
import json
import os
import re
import sqlite3
import subprocess
from pathlib import Path
from typing import Any


ORG = "chef-cft"
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INDEX = ROOT / "docs" / "chef-cft-metadata-index.json"
DEFAULT_CONFIG = ROOT / "config" / "chef-cft-corpus.json"
DEFAULT_OUTPUT = ROOT / "data" / "chef-cft-knowledge.sqlite3"
TOKEN_PATH = Path.home() / ".github" / "chef-cft.token"

SECRET_PATTERNS = [
    re.compile(r"gh[oprsu]_[A-Za-z0-9_]{20,}", re.I),
    re.compile(r"github_pat_[A-Za-z0-9_]{20,}", re.I),
    re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"),
    re.compile(r"Authorization\s*:\s*(?:Bearer|Basic)\s+\S+", re.I),
    re.compile(r"X-Amz-(?:Signature|Credential)=[^&\s]+", re.I),
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----.*?-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", re.I | re.S),
    re.compile(r"(?im)^\s*(?:password|passwd|secret|token|access[_-]?key|secret[_-]?key)\s*[:=]\s*[^\s#]+"),
    re.compile(
        r"(?im)^\s*[A-Za-z0-9_.-]*(?:client[_-]?secret|account[_-]?key|private[_-]?key|password|passwd|token)[A-Za-z0-9_.-]*\s*[:=]\s*[^\s#]+"
    ),
    re.compile(r"(?i)\b(?:AccountKey|SharedAccessKey)=[^;\s]+"),
    re.compile(r"(?i)\b(?:https?|ssh|git)://[^\s/@:]+:[^\s/@]+@"),
]


def gh_api(endpoint: str) -> Any:
    environment = os.environ.copy()
    if "GH_TOKEN" not in environment:
        if not TOKEN_PATH.is_file():
            raise RuntimeError(f"GitHub token file not found: {TOKEN_PATH}")
        environment["GH_TOKEN"] = TOKEN_PATH.read_text(encoding="utf-8").strip()
    result = subprocess.run(
        ["gh", "api", "-X", "GET", endpoint],
        check=True,
        capture_output=True,
        text=True,
        env=environment,
        timeout=60,
    )
    return json.loads(result.stdout)


def sanitize(text: str) -> tuple[str, int]:
    redactions = 0
    for pattern in SECRET_PATTERNS:
        text, count = pattern.subn("[REDACTED]", text)
        redactions += count
    text = text.replace("\x00", "")
    return text, redactions


def convert_text(path: str, text: str) -> str:
    suffix = Path(path).suffix.lower()
    if suffix == ".md":
        text = re.sub(r"!\[([^]]*)]\([^)]*\)", r"[image: \1]", text)
        text = re.sub(r"\[([^]]+)]\(([^)]+)\)", r"\1 (\2)", text)
        text = re.sub(r"<[^>]+>", " ", text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{4,}", "\n\n\n", text)
    return text.strip()


def chunks(text: str, size: int, overlap: int) -> list[tuple[int, int, str]]:
    if not text:
        return []
    result = []
    start = 0
    while start < len(text):
        end = min(start + size, len(text))
        if end < len(text):
            split = max(text.rfind("\n\n", start, end), text.rfind("\n", start, end))
            if split > start + size // 2:
                end = split
        body = text[start:end].strip()
        if body:
            result.append((start, end, body))
        if end >= len(text):
            break
        start = max(end - overlap, start + 1)
    return result


def matches(path: str, patterns: list[str], allowed: set[str], excluded: list[str]) -> bool:
    if Path(path).suffix.lower() not in allowed:
        return False
    lower = path.lower()
    if any(part.lower() in lower for part in excluded):
        return False
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def create_database(path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    connection.executescript(
        """
        PRAGMA journal_mode=DELETE;
        PRAGMA synchronous=FULL;
        PRAGMA temp_store=MEMORY;
        CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE repositories (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          full_name TEXT NOT NULL,
          visibility TEXT NOT NULL,
          url TEXT NOT NULL,
          default_branch TEXT NOT NULL,
          revision TEXT NOT NULL,
          pushed_at TEXT NOT NULL,
          freshness TEXT NOT NULL,
          purpose TEXT NOT NULL,
          categories_json TEXT NOT NULL,
          keywords_json TEXT NOT NULL
        );
        CREATE TABLE documents (
          id INTEGER PRIMARY KEY,
          repository_id INTEGER NOT NULL REFERENCES repositories(id),
          path TEXT NOT NULL,
          source_url TEXT NOT NULL,
          sha256 TEXT NOT NULL,
          byte_count INTEGER NOT NULL,
          character_count INTEGER NOT NULL,
          chunk_count INTEGER NOT NULL,
          redaction_count INTEGER NOT NULL,
          UNIQUE(repository_id, path)
        );
        CREATE TABLE chunks (
          id INTEGER PRIMARY KEY,
          document_id INTEGER NOT NULL REFERENCES documents(id),
          repository TEXT NOT NULL,
          path TEXT NOT NULL,
          source_url TEXT NOT NULL,
          heading TEXT,
          start_character INTEGER NOT NULL,
          end_character INTEGER NOT NULL,
          content TEXT NOT NULL
        );
        CREATE VIRTUAL TABLE chunks_fts USING fts5(
          repository, path, heading, content,
          content='chunks', content_rowid='id',
          tokenize='porter unicode61'
        );
        CREATE INDEX idx_documents_repository ON documents(repository_id);
        CREATE INDEX idx_chunks_document ON chunks(document_id);
        CREATE INDEX idx_chunks_repository ON chunks(repository);
        CREATE TRIGGER chunks_ai AFTER INSERT ON chunks BEGIN
          INSERT INTO chunks_fts(rowid, repository, path, heading, content)
          VALUES (new.id, new.repository, new.path, new.heading, new.content);
        END;
        """
    )
    return connection


def heading_for(content: str) -> str | None:
    for line in content.splitlines():
        match = re.match(r"^#{1,6}\s+(.+)$", line.strip())
        if match:
            return match.group(1)[:200]
    return None


def build(index_path: Path, config_path: Path, output_path: Path) -> dict[str, Any]:
    index = json.loads(index_path.read_text(encoding="utf-8"))
    config = json.loads(config_path.read_text(encoding="utf-8"))
    by_name = {repo["name"]: repo for repo in index["repositories"]}
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_suffix(output_path.suffix + ".tmp")
    temporary.unlink(missing_ok=True)
    connection = create_database(temporary)
    generated = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    totals = {"repositories": 0, "documents": 0, "chunks": 0, "redactions": 0, "skipped_large": 0, "failures": 0}

    try:
        for name, selection in config["repositories"].items():
            repository = by_name.get(name)
            if not repository:
                raise RuntimeError(f"Selected repository is missing from metadata index: {name}")
            print(f"Indexing content from {ORG}/{name}")
            revision = repository["tree_sha"]
            tree = gh_api(f"repos/{ORG}/{name}/git/trees/{revision}?recursive=1")
            paths = [item for item in tree.get("tree", []) if item["type"] == "blob"]
            selected = [
                item
                for item in paths
                if matches(
                    item["path"],
                    selection["include"],
                    set(config["allowed_extensions"]),
                    config["excluded_path_parts"],
                )
            ]
            cursor = connection.execute(
                """INSERT INTO repositories
                   (name, full_name, visibility, url, default_branch, revision, pushed_at, freshness,
                    purpose, categories_json, keywords_json)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    name,
                    repository["full_name"],
                    repository["visibility"],
                    repository["url"],
                    repository["default_branch"],
                    revision,
                    repository["pushed_at"],
                    repository["freshness"],
                    selection["purpose"],
                    json.dumps(repository["categories"]),
                    json.dumps(repository["keywords"]),
                ),
            )
            repository_id = cursor.lastrowid
            totals["repositories"] += 1

            for item in selected:
                if item.get("size", 0) > config["max_file_bytes"]:
                    totals["skipped_large"] += 1
                    continue
                try:
                    blob = gh_api(f"repos/{ORG}/{name}/git/blobs/{item['sha']}")
                    if blob.get("encoding") != "base64":
                        totals["failures"] += 1
                        continue
                    raw = base64.b64decode(blob["content"])
                    if b"\x00" in raw:
                        continue
                    text = raw.decode("utf-8", errors="replace")
                    text, redactions = sanitize(text)
                    converted = convert_text(item["path"], text)
                    document_chunks = chunks(
                        converted,
                        config["chunk_characters"],
                        config["chunk_overlap_characters"],
                    )
                    source_url = f"https://github.com/{ORG}/{name}/blob/{revision}/{item['path']}"
                    document = connection.execute(
                        """INSERT INTO documents
                           (repository_id, path, source_url, sha256, byte_count, character_count,
                            chunk_count, redaction_count)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                        (
                            repository_id,
                            item["path"],
                            source_url,
                            hashlib.sha256(raw).hexdigest(),
                            len(raw),
                            len(converted),
                            len(document_chunks),
                            redactions,
                        ),
                    )
                    for start, end, content in document_chunks:
                        connection.execute(
                            """INSERT INTO chunks
                               (document_id, repository, path, source_url, heading,
                                start_character, end_character, content)
                               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                            (
                                document.lastrowid,
                                repository["full_name"],
                                item["path"],
                                source_url,
                                heading_for(content),
                                start,
                                end,
                                content,
                            ),
                        )
                    totals["documents"] += 1
                    totals["chunks"] += len(document_chunks)
                    totals["redactions"] += redactions
                except (subprocess.SubprocessError, OSError, ValueError, KeyError):
                    totals["failures"] += 1

        metadata = {
            "schema_version": 1,
            "generated_at": generated,
            "source_index_generated_at": index["generated_at"],
            "organization": ORG,
            "totals": totals,
        }
        for key, value in metadata.items():
            connection.execute("INSERT INTO metadata (key, value) VALUES (?, ?)", (key, json.dumps(value)))
        connection.commit()
        connection.execute("PRAGMA optimize")
        connection.commit()
    finally:
        connection.close()

    if totals["failures"]:
        temporary.unlink(missing_ok=True)
        raise RuntimeError(f"Chef CFT corpus build had {totals['failures']} download failures")
    temporary.chmod(0o600)
    temporary.replace(output_path)
    output_path.chmod(0o600)
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("build", nargs="?")
    parser.add_argument("--index", type=Path, default=DEFAULT_INDEX)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    metadata = build(args.index.resolve(), args.config.resolve(), args.output.resolve())
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
