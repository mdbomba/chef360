#!/usr/bin/env python3
"""Dependency-free stdio MCP for public Chef 360 and optional Chef CFT knowledge."""

from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
from pathlib import Path
from typing import Any


SERVER_NAME = "chef-cft-knowledge"
SERVER_VERSION = "0.2.0"
PROTOCOL_VERSIONS = ("2025-03-26", "2024-11-05")
MAX_RESULTS = 50
MAX_TEXT_LENGTH = 1200
MAX_KNOWLEDGE_SNIPPET = 1200
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INDEX = ROOT / "docs" / "chef-cft-metadata-index.json"
DEFAULT_GUIDE = ROOT / "docs" / "chef-cft-knowledge-guide.md"
DEFAULT_CORPUS = ROOT / "data" / "chef-cft-knowledge.sqlite3"
DEFAULT_CHEF360_KNOWLEDGE = ROOT / "knowledge-set" / "chef360-1.7.3"
MAX_PUBLIC_EXCERPT = 600
MAX_PUBLIC_PAGE = 1000

SENSITIVE = re.compile(
    r"(?:gh[oprsu]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    r"AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|"
    r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|"
    r"Authorization\s*:\s*(?:Bearer|Basic)\s+\S+|X-Amz-Signature=[A-Fa-f0-9]+|"
    r"(?:client[_-]?secret|account[_-]?key|private[_-]?key|password|passwd|token)\s*[:=]\s*\S+|"
    r"(?:AccountKey|SharedAccessKey)=[^;\s]+|(?:https?|ssh|git)://[^\s/@:]+:[^\s/@]+@)",
    re.I,
)

TOPICS = {
    "chef-360": {"categories": {"Chef 360"}, "signals": {"chef_360"}},
    "node-management": {"categories": {"Node Management"}, "signals": {"node_management"}},
    "courier": {"categories": {"Chef Courier"}, "signals": {"courier"}},
    "chef-infra": {"categories": {"Chef Infra"}, "signals": {"cookbook_metadata", "recipes"}},
    "policyfiles": {"categories": {"Chef Infra"}, "signals": {"policyfiles"}},
    "inspec-compliance": {
        "categories": {"InSpec and Compliance"},
        "signals": {"inspec_profiles", "inspec_controls"},
    },
    "habitat": {"categories": {"Chef Habitat"}, "signals": {"habitat_plans"}},
    "automate": {"categories": {"Chef Automate"}, "signals": set()},
    "provisioning": {
        "categories": {"Infrastructure as Code"},
        "signals": {"terraform", "cloudformation", "bicep", "packer"},
    },
}


class ToolError(ValueError):
    """A safe validation or lookup error that can be returned to the client."""


class KnowledgeCorpus:
    """Read-only FTS access to pre-downloaded and sanitized Chef documentation."""

    def __init__(self, path: Path) -> None:
        if not path.is_file():
            raise RuntimeError(f"Chef knowledge corpus not found: {path}")
        self.path = path
        uri = f"file:{path.as_posix()}?mode=ro&immutable=1"
        self.connection = sqlite3.connect(uri, uri=True, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.connection.execute("PRAGMA query_only=ON")

    @staticmethod
    def fts_query(query: str) -> str:
        terms = re.findall(r"[A-Za-z0-9][A-Za-z0-9_.-]{1,63}", query)
        if not terms:
            raise ToolError("query must contain searchable words")
        return " AND ".join(f'"{term}"*' for term in terms[:12])

    def stats(self) -> dict[str, Any]:
        metadata = {
            row["key"]: json.loads(row["value"])
            for row in self.connection.execute("SELECT key, value FROM metadata")
        }
        metadata["database_bytes"] = self.path.stat().st_size
        return metadata

    def search(self, arguments: dict[str, Any]) -> dict[str, Any]:
        query = optional_string(arguments, "query", max_length=300)
        repository = optional_string(arguments, "repository", max_length=150)
        path_prefix = optional_string(arguments, "path_prefix", max_length=250)
        limit = result_limit(arguments, 8)
        if not query:
            raise ToolError("query is required")

        where = ["chunks_fts MATCH ?"]
        parameters: list[Any] = [self.fts_query(query)]
        if repository:
            normalized = repository if "/" in repository else f"chef-cft/{repository}"
            where.append("c.repository = ?")
            parameters.append(normalized)
        if path_prefix:
            where.append("c.path LIKE ? ESCAPE '\\'")
            escaped = path_prefix.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            parameters.append(escaped + "%")
        parameters.append(limit)
        rows = self.connection.execute(
            f"""SELECT c.repository, c.path, c.source_url, c.heading,
                       snippet(chunks_fts, 3, '[', ']', ' ... ', 32) AS snippet,
                       bm25(chunks_fts, 3.0, 2.0, 1.5, 1.0) AS rank
                FROM chunks_fts
                JOIN chunks c ON c.id = chunks_fts.rowid
                WHERE {' AND '.join(where)}
                ORDER BY rank
                LIMIT ?""",
            parameters,
        ).fetchall()
        matches = []
        for row in rows:
            snippet = SENSITIVE.sub("[redacted sensitive value]", row["snippet"])
            matches.append(
                {
                    "repository": row["repository"],
                    "path": row["path"],
                    "heading": row["heading"],
                    "source_url": row["source_url"],
                    "snippet": snippet[:MAX_KNOWLEDGE_SNIPPET],
                    "rank": round(row["rank"], 6),
                }
            )
        return {"query": query, "returned": len(matches), "matches": matches}

    def document_chunks(self, arguments: dict[str, Any]) -> dict[str, Any]:
        repository = optional_string(arguments, "repository", max_length=150)
        path = optional_string(arguments, "path", max_length=300)
        limit = result_limit(arguments, 5)
        offset = arguments.get("offset", 0)
        if not repository or not path:
            raise ToolError("repository and path are required")
        if isinstance(offset, bool) or not isinstance(offset, int) or not 0 <= offset <= 10000:
            raise ToolError("offset must be an integer from 0 to 10000")
        normalized = repository if "/" in repository else f"chef-cft/{repository}"
        document = self.connection.execute(
            """SELECT d.id, d.source_url, d.character_count, d.chunk_count, d.redaction_count
               FROM documents d JOIN repositories r ON r.id=d.repository_id
               WHERE r.full_name=? AND d.path=?""",
            (normalized, path),
        ).fetchone()
        if not document:
            raise ToolError("document not found in the optimized corpus")
        rows = self.connection.execute(
            """SELECT heading, start_character, end_character, content
               FROM chunks WHERE document_id=? ORDER BY start_character LIMIT ? OFFSET ?""",
            (document["id"], limit, offset),
        ).fetchall()
        return {
            "repository": normalized,
            "path": path,
            "source_url": document["source_url"],
            "character_count": document["character_count"],
            "chunk_count": document["chunk_count"],
            "redaction_count": document["redaction_count"],
            "offset": offset,
            "returned": len(rows),
            "chunks": [
                {
                    "heading": row["heading"],
                    "start_character": row["start_character"],
                    "end_character": row["end_character"],
                    "content": SENSITIVE.sub("[redacted sensitive value]", row["content"]),
                }
                for row in rows
            ],
        }


class Chef360KnowledgeSet:
    """Read-only access to the checked-in, versioned Chef 360 knowledge set."""

    def __init__(self, root: Path = DEFAULT_CHEF360_KNOWLEDGE) -> None:
        self.root = root.expanduser().resolve(strict=True)
        manifest_path = self.root / "manifest.json"
        if not manifest_path.is_file():
            raise RuntimeError(f"Chef 360 knowledge manifest not found: {manifest_path}")
        self.manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if self.manifest.get("version") != "1.7.3":
            raise RuntimeError("Unsupported Chef 360 knowledge-set version")

        self.documents: list[dict[str, Any]] = []
        self.by_id: dict[str, dict[str, Any]] = {}
        seen_paths: set[str] = set()
        for item in self.manifest.get("documents", []):
            document_id = item.get("id")
            relative_path = item.get("path")
            if not isinstance(document_id, str) or not document_id or document_id in self.by_id:
                raise RuntimeError("Chef 360 manifest contains an invalid or duplicate document ID")
            if not isinstance(relative_path, str) or not relative_path or relative_path in seen_paths:
                raise RuntimeError("Chef 360 manifest contains an invalid or duplicate document path")
            path = Path(relative_path)
            if path.is_absolute() or ".." in path.parts or path.suffix.lower() != ".md":
                raise RuntimeError("Chef 360 manifest contains an unsafe document path")
            resolved = (self.root / path).resolve(strict=True)
            try:
                resolved.relative_to(self.root)
            except ValueError as error:
                raise RuntimeError("Chef 360 manifest document escapes the knowledge root") from error
            if not resolved.is_file():
                raise RuntimeError("Chef 360 manifest document is not a file")
            document = {
                "id": document_id,
                "path": relative_path,
                "title": str(item.get("title") or document_id),
                "topics": [str(topic) for topic in item.get("topics", [])],
                "file": resolved,
            }
            self.documents.append(document)
            self.by_id[document_id] = document
            seen_paths.add(relative_path)

    @staticmethod
    def _terms(value: str) -> list[str]:
        return re.findall(r"[a-z0-9][a-z0-9_.-]+", value.lower())[:12]

    def summary(self) -> dict[str, Any]:
        return {
            "available": True,
            "name": self.manifest.get("name"),
            "version": self.manifest["version"],
            "source": self.manifest.get("source"),
            "document_count": len(self.documents),
        }

    def search(self, arguments: dict[str, Any]) -> dict[str, Any]:
        query = optional_string(arguments, "query", max_length=300)
        topic = optional_string(arguments, "topic", max_length=80)
        limit = result_limit(arguments, 5)
        if not query:
            raise ToolError("query is required")
        terms = self._terms(query)
        if not terms:
            raise ToolError("query must contain searchable words")

        ranked: list[tuple[int, str, dict[str, Any], str]] = []
        for document in self.documents:
            topics = [value.lower() for value in document["topics"]]
            if topic and topic.lower() not in topics:
                continue
            content = document["file"].read_text(encoding="utf-8")
            lowered = content.lower()
            title = document["title"].lower()
            metadata = " ".join(topics)
            if not all(term in lowered or term in title or term in metadata for term in terms):
                continue
            score = sum(lowered.count(term) for term in terms)
            score += sum(20 for term in terms if term in title)
            score += sum(10 for term in terms if term in metadata)
            phrase_index = lowered.find(query.lower())
            if phrase_index >= 0:
                score += 50
                match_index = phrase_index
            else:
                indexes = [lowered.find(term) for term in terms if lowered.find(term) >= 0]
                match_index = min(indexes) if indexes else 0
            start = max(0, match_index - 180)
            excerpt = content[start : start + MAX_PUBLIC_EXCERPT].strip()
            ranked.append((score, document["id"], document, excerpt))

        ranked.sort(key=lambda item: (-item[0], item[1]))
        matches = [
            {
                "id": document["id"],
                "title": document["title"],
                "path": document["path"],
                "topics": document["topics"],
                "excerpt": SENSITIVE.sub("[redacted sensitive value]", excerpt),
                "version": self.manifest["version"],
                "source": self.manifest.get("source"),
            }
            for _, _, document, excerpt in ranked[:limit]
        ]
        return {"query": query, "topic": topic, "returned": len(matches), "matches": matches}

    def document(self, arguments: dict[str, Any]) -> dict[str, Any]:
        document_id = optional_string(arguments, "id", max_length=100)
        if not document_id:
            raise ToolError("id is required")
        document = self.by_id.get(document_id)
        if not document:
            raise ToolError(f"Chef 360 document not found: {document_id}")
        offset = arguments.get("offset", 0)
        max_characters = arguments.get("max_characters", MAX_PUBLIC_PAGE)
        if isinstance(offset, bool) or not isinstance(offset, int) or not 0 <= offset <= 1000000:
            raise ToolError("offset must be an integer from 0 to 1000000")
        if (
            isinstance(max_characters, bool)
            or not isinstance(max_characters, int)
            or not 1 <= max_characters <= MAX_PUBLIC_PAGE
        ):
            raise ToolError(f"max_characters must be an integer from 1 to {MAX_PUBLIC_PAGE}")
        content = document["file"].read_text(encoding="utf-8")
        raw_page = content[offset : offset + max_characters]
        page = SENSITIVE.sub("[redacted sensitive value]", raw_page)
        return {
            "id": document["id"],
            "title": document["title"],
            "path": document["path"],
            "topics": document["topics"],
            "version": self.manifest["version"],
            "source": self.manifest.get("source"),
            "offset": offset,
            "next_offset": offset + len(raw_page) if offset + len(raw_page) < len(content) else None,
            "total_characters": len(content),
            "content": page,
        }

    def readme(self) -> str:
        return SENSITIVE.sub(
            "[redacted sensitive value]", (self.root / "README.md").read_text(encoding="utf-8")
        )


def redact(value: Any) -> Any:
    if isinstance(value, str):
        if SENSITIVE.search(value):
            return "[redacted sensitive value]"
        return value[:MAX_TEXT_LENGTH] if len(value) > MAX_TEXT_LENGTH else value
    if isinstance(value, list):
        return [redact(item) for item in value]
    if isinstance(value, dict):
        return {key: redact(item) for key, item in value.items()}
    return value


def require_object(arguments: Any) -> dict[str, Any]:
    if arguments is None:
        return {}
    if not isinstance(arguments, dict):
        raise ToolError("arguments must be an object")
    return arguments


def optional_string(arguments: dict[str, Any], name: str, *, max_length: int = 200) -> str | None:
    value = arguments.get(name)
    if value is None:
        return None
    if not isinstance(value, str) or not value.strip():
        raise ToolError(f"{name} must be a non-empty string")
    if len(value) > max_length:
        raise ToolError(f"{name} must be at most {max_length} characters")
    return value.strip()


def optional_bool(arguments: dict[str, Any], name: str, default: bool) -> bool:
    value = arguments.get(name, default)
    if not isinstance(value, bool):
        raise ToolError(f"{name} must be a boolean")
    return value


def result_limit(arguments: dict[str, Any], default: int = 10) -> int:
    value = arguments.get("limit", default)
    if isinstance(value, bool) or not isinstance(value, int) or not 1 <= value <= MAX_RESULTS:
        raise ToolError(f"limit must be an integer from 1 to {MAX_RESULTS}")
    return value


class KnowledgeBase:
    def __init__(self, index_path: Path = DEFAULT_INDEX, guide_path: Path = DEFAULT_GUIDE) -> None:
        if not index_path.is_file():
            raise RuntimeError(f"Chef metadata index not found: {index_path}")
        self.index_path = index_path
        self.guide_path = guide_path
        self._index: dict[str, Any] | None = None
        self._repositories: list[dict[str, Any]] | None = None
        self._by_name: dict[str, dict[str, Any]] | None = None
        self._signal_names: list[str] | None = None

    def _load(self) -> None:
        if self._index is not None:
            return
        self._index = json.loads(self.index_path.read_text(encoding="utf-8"))
        self._repositories = self._index.get("repositories", [])
        self._by_name = {}
        for repository in self._repositories:
            self._by_name[repository["name"].lower()] = repository
            self._by_name[repository["full_name"].lower()] = repository
        self._signal_names = sorted(
            {name for repository in self._repositories for name in repository.get("signals", {})}
        )

    @property
    def index(self) -> dict[str, Any]:
        self._load()
        assert self._index is not None
        return self._index

    @property
    def repositories(self) -> list[dict[str, Any]]:
        self._load()
        assert self._repositories is not None
        return self._repositories

    @property
    def by_name(self) -> dict[str, dict[str, Any]]:
        self._load()
        assert self._by_name is not None
        return self._by_name

    @property
    def signal_names(self) -> list[str]:
        self._load()
        assert self._signal_names is not None
        return self._signal_names

    @staticmethod
    def compact_repository(repository: dict[str, Any], *, include_signals: bool = False) -> dict[str, Any]:
        result = {
            "name": repository["full_name"],
            "url": repository["url"],
            "visibility": repository["visibility"],
            "archived": repository["archived"],
            "freshness": repository["freshness"],
            "pushed_at": repository["pushed_at"],
            "categories": repository["categories"],
            "keywords": repository["keywords"],
            "summary": repository["usefulness"],
        }
        if include_signals:
            result["signals"] = {
                name: signal
                for name, signal in repository["signals"].items()
                if signal.get("count", 0) > 0
            }
        return redact(result)

    def summary(self) -> dict[str, Any]:
        return redact(
            {
                "generated_at": self.index["generated_at"],
                "organization": self.index["organization"],
                "coverage": self.index["coverage"],
                "summary": self.index["summary"],
                "available_signals": self.signal_names,
            }
        )

    def search(self, arguments: dict[str, Any]) -> dict[str, Any]:
        query = optional_string(arguments, "query", max_length=200)
        category = optional_string(arguments, "category", max_length=80)
        keyword = optional_string(arguments, "keyword", max_length=80)
        signal = optional_string(arguments, "signal", max_length=80)
        visibility = optional_string(arguments, "visibility", max_length=20)
        freshness = optional_string(arguments, "freshness", max_length=40)
        current_only = optional_bool(arguments, "current_only", False)
        limit = result_limit(arguments)

        if visibility and visibility not in {"public", "private", "internal"}:
            raise ToolError("visibility must be public, private, or internal")
        if freshness and freshness not in {"active-within-2-years", "stale-over-2-years", "archived"}:
            raise ToolError("freshness is not recognized")
        if signal and signal not in self.signal_names:
            raise ToolError(f"unknown signal: {signal}")

        words = query.lower().split() if query else []
        scored = []
        for repository in self.repositories:
            if category and category.lower() not in {item.lower() for item in repository["categories"]}:
                continue
            if keyword and keyword.lower() not in {item.lower() for item in repository["keywords"]}:
                continue
            if signal and repository["signals"].get(signal, {}).get("count", 0) == 0:
                continue
            if visibility and repository["visibility"] != visibility:
                continue
            if freshness and repository["freshness"] != freshness:
                continue
            if current_only and repository["freshness"] != "active-within-2-years":
                continue

            corpus = " ".join(
                [
                    repository["name"],
                    repository.get("description") or "",
                    repository.get("readme_title") or "",
                    repository.get("readme_excerpt") or "",
                    " ".join(repository["categories"]),
                    " ".join(repository["keywords"]),
                    " ".join(repository["signals"]),
                ]
            ).lower()
            if words and not all(word in corpus for word in words):
                continue
            score = sum(5 if word in repository["name"].lower() else 1 for word in words)
            score += 2 if repository["freshness"] == "active-within-2-years" else 0
            score -= 2 if repository["archived"] else 0
            scored.append((score, repository["name"].lower(), repository))

        scored.sort(key=lambda item: (-item[0], item[1]))
        matches = [self.compact_repository(item[2]) for item in scored[:limit]]
        return {"count": len(scored), "returned": len(matches), "repositories": matches}

    def repository(self, arguments: dict[str, Any]) -> dict[str, Any]:
        name = optional_string(arguments, "name", max_length=150)
        if not name:
            raise ToolError("name is required")
        repository = self.by_name.get(name.lower())
        if not repository:
            raise ToolError(f"repository not found: {name}")
        return self.compact_repository(repository, include_signals=True)

    def artifacts(self, arguments: dict[str, Any]) -> dict[str, Any]:
        artifact_type = optional_string(arguments, "artifact_type", max_length=80)
        repository_name = optional_string(arguments, "repository", max_length=150)
        path_query = optional_string(arguments, "path_query", max_length=150)
        limit = result_limit(arguments, 20)
        if not artifact_type:
            raise ToolError("artifact_type is required")
        if artifact_type not in self.signal_names:
            raise ToolError(f"unknown artifact_type: {artifact_type}")

        repositories = self.repositories
        if repository_name:
            repository = self.by_name.get(repository_name.lower())
            if not repository:
                raise ToolError(f"repository not found: {repository_name}")
            repositories = [repository]

        matches = []
        total_artifacts = 0
        for repository in repositories:
            signal = repository["signals"].get(artifact_type, {})
            count = signal.get("count", 0)
            if not count:
                continue
            examples = signal.get("examples", [])
            if path_query:
                examples = [path for path in examples if path_query.lower() in path.lower()]
                if not examples:
                    continue
            total_artifacts += count
            matches.append(
                redact(
                    {
                        "repository": repository["full_name"],
                        "url": repository["url"],
                        "visibility": repository["visibility"],
                        "freshness": repository["freshness"],
                        "artifact_count": count,
                        "representative_paths": examples,
                    }
                )
            )
        matches.sort(key=lambda item: (-item["artifact_count"], item["repository"].lower()))
        return {
            "artifact_type": artifact_type,
            "repository_count": len(matches),
            "artifact_count": total_artifacts,
            "returned": len(matches[:limit]),
            "repositories": matches[:limit],
            "note": "Paths are representative examples; counts may exceed the listed paths.",
        }

    def recommend(self, arguments: dict[str, Any]) -> dict[str, Any]:
        topic = optional_string(arguments, "topic", max_length=80)
        use_case = optional_string(arguments, "use_case", max_length=200)
        current_only = optional_bool(arguments, "current_only", True)
        limit = result_limit(arguments, 5)
        if not topic or topic not in TOPICS:
            raise ToolError(f"topic must be one of: {', '.join(TOPICS)}")

        desired = TOPICS[topic]
        words = use_case.lower().split() if use_case else []
        ranked = []
        for repository in self.repositories:
            categories = set(repository["categories"])
            matched_categories = desired["categories"] & categories
            matched_signals = {
                signal
                for signal in desired["signals"]
                if repository["signals"].get(signal, {}).get("count", 0) > 0
            }
            if not matched_categories and not matched_signals:
                continue
            if current_only and repository["freshness"] != "active-within-2-years":
                continue
            corpus = " ".join(
                [repository["name"], repository.get("description") or "", repository["usefulness"]]
            ).lower()
            score = 5 * len(matched_categories) + 3 * len(matched_signals)
            score += sum(3 if word in repository["name"].lower() else 1 for word in words if word in corpus)
            score += 3 if repository["freshness"] == "active-within-2-years" else 0
            score -= 3 if repository["archived"] else 0
            ranked.append((score, repository["name"].lower(), repository))
        ranked.sort(key=lambda item: (-item[0], item[1]))
        return {
            "topic": topic,
            "use_case": use_case,
            "repositories": [self.compact_repository(item[2], include_signals=True) for item in ranked[:limit]],
        }

    def guide(self) -> str:
        if not self.guide_path.is_file():
            raise ToolError("curated knowledge guide is unavailable")
        text = self.guide_path.read_text(encoding="utf-8")
        return SENSITIVE.sub("[redacted sensitive value]", text)


TOOLS = [
    {
        "name": "search_chef360_knowledge",
        "description": "Search the checked-in, versioned Chef 360 Platform 1.7.3 knowledge set.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "maxLength": 300},
                "topic": {"type": "string", "maxLength": 80},
                "limit": {"type": "integer", "minimum": 1, "maximum": MAX_RESULTS, "default": 5},
            },
            "required": ["query"],
            "additionalProperties": False,
        },
    },
    {
        "name": "get_chef360_document",
        "description": "Read a bounded page from a manifest-declared Chef 360 1.7.3 document.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "string", "maxLength": 100},
                "offset": {"type": "integer", "minimum": 0, "maximum": 1000000, "default": 0},
                "max_characters": {
                    "type": "integer",
                    "minimum": 1,
                    "maximum": MAX_PUBLIC_PAGE,
                    "default": MAX_PUBLIC_PAGE,
                },
            },
            "required": ["id"],
            "additionalProperties": False,
        },
    },
    {
        "name": "search_chef_knowledge",
        "description": "Fast full-text search over the pre-downloaded, sanitized Chef documentation corpus. Returns revision-pinned source links and ranked snippets without network access.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "maxLength": 300},
                "repository": {"type": "string", "maxLength": 150},
                "path_prefix": {"type": "string", "maxLength": 250},
                "limit": {"type": "integer", "minimum": 1, "maximum": MAX_RESULTS, "default": 8},
            },
            "required": ["query"],
            "additionalProperties": False,
        },
    },
    {
        "name": "get_chef_document",
        "description": "Read bounded chunks from one sanitized document in the optimized local corpus.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "repository": {"type": "string", "maxLength": 150},
                "path": {"type": "string", "maxLength": 300},
                "offset": {"type": "integer", "minimum": 0, "maximum": 10000, "default": 0},
                "limit": {"type": "integer", "minimum": 1, "maximum": MAX_RESULTS, "default": 5},
            },
            "required": ["repository", "path"],
            "additionalProperties": False,
        },
    },
    {
        "name": "search_chef_repositories",
        "description": "Search the local 209-repository Chef CFT metadata index by text, taxonomy, signal, visibility, and freshness.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "maxLength": 200},
                "category": {"type": "string", "maxLength": 80},
                "keyword": {"type": "string", "maxLength": 80},
                "signal": {"type": "string", "maxLength": 80},
                "visibility": {"type": "string", "enum": ["public", "private", "internal"]},
                "freshness": {
                    "type": "string",
                    "enum": ["active-within-2-years", "stale-over-2-years", "archived"],
                },
                "current_only": {"type": "boolean", "default": False},
                "limit": {"type": "integer", "minimum": 1, "maximum": MAX_RESULTS, "default": 10},
            },
            "additionalProperties": False,
        },
    },
    {
        "name": "get_chef_repository",
        "description": "Get safe metadata and structural Chef artifact signals for one indexed repository.",
        "inputSchema": {
            "type": "object",
            "properties": {"name": {"type": "string", "maxLength": 150}},
            "required": ["name"],
            "additionalProperties": False,
        },
    },
    {
        "name": "find_chef_artifacts",
        "description": "Find repositories containing a structural artifact such as Policyfiles, cookbooks, InSpec profiles, Courier assets, Terraform, or Helm.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "artifact_type": {"type": "string", "maxLength": 80},
                "repository": {"type": "string", "maxLength": 150},
                "path_query": {"type": "string", "maxLength": 150},
                "limit": {"type": "integer", "minimum": 1, "maximum": MAX_RESULTS, "default": 20},
            },
            "required": ["artifact_type"],
            "additionalProperties": False,
        },
    },
    {
        "name": "recommend_chef_references",
        "description": "Recommend current Chef repositories for a focused topic and optional use case.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "topic": {"type": "string", "enum": list(TOPICS)},
                "use_case": {"type": "string", "maxLength": 200},
                "current_only": {"type": "boolean", "default": True},
                "limit": {"type": "integer", "minimum": 1, "maximum": MAX_RESULTS, "default": 5},
            },
            "required": ["topic"],
            "additionalProperties": False,
        },
    },
    {
        "name": "get_chef_knowledge_summary",
        "description": "Return metadata-index coverage plus optimized corpus statistics, category counts, freshness, languages, keywords, and available artifact signals.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
]

RESOURCES = [
    {
        "uri": "chef360://knowledge/1.7.3/manifest",
        "name": "Chef 360 1.7.3 Knowledge Manifest",
        "description": "Public version, source, document metadata, and declared capabilities.",
        "mimeType": "application/json",
    },
    {
        "uri": "chef360://knowledge/1.7.3/readme",
        "name": "Chef 360 1.7.3 Knowledge README",
        "description": "Scope and usage notes for the checked-in public knowledge set.",
        "mimeType": "text/markdown",
    },
    {
        "uri": "chef-cft://knowledge/guide",
        "name": "Chef CFT Knowledge Guide",
        "description": "Curated map of current Chef 360, Node Management, Courier, provisioning, compliance, and Policyfile references.",
        "mimeType": "text/markdown",
    },
    {
        "uri": "chef-cft://knowledge/summary",
        "name": "Chef CFT Index Summary",
        "description": "Coverage and taxonomy summary for all indexed repositories.",
        "mimeType": "application/json",
    },
    {
        "uri": "chef-cft://knowledge/corpus-stats",
        "name": "Chef CFT Optimized Corpus Statistics",
        "description": "Revision, document, chunk, redaction, and database-size metadata for the local FTS corpus.",
        "mimeType": "application/json",
    },
]


class McpServer:
    def __init__(
        self,
        public_knowledge: Chef360KnowledgeSet,
        knowledge: KnowledgeBase | None = None,
        corpus: KnowledgeCorpus | None = None,
    ) -> None:
        self.public_knowledge = public_knowledge
        self.knowledge = knowledge
        self.corpus = corpus

    @staticmethod
    def response(request_id: Any, result: Any) -> dict[str, Any]:
        return {"jsonrpc": "2.0", "id": request_id, "result": result}

    @staticmethod
    def error(request_id: Any, code: int, message: str) -> dict[str, Any]:
        return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}

    @staticmethod
    def tool_result(payload: Any, *, is_error: bool = False) -> dict[str, Any]:
        safe = redact(payload)
        text = safe if isinstance(safe, str) else json.dumps(safe, indent=2, sort_keys=True)
        result: dict[str, Any] = {"content": [{"type": "text", "text": text}]}
        if isinstance(safe, dict):
            result["structuredContent"] = safe
        if is_error:
            result["isError"] = True
        return result

    def call_tool(self, name: str, arguments: Any) -> dict[str, Any]:
        args = require_object(arguments)
        allowed = {
            "search_chef360_knowledge": self.public_knowledge.search,
            "get_chef360_document": self.public_knowledge.document,
            "search_chef_knowledge": self._search_corpus,
            "get_chef_document": self._get_document,
            "search_chef_repositories": self._search_repositories,
            "get_chef_repository": self._get_repository,
            "find_chef_artifacts": self._find_artifacts,
            "recommend_chef_references": self._recommend,
            "get_chef_knowledge_summary": lambda _: {
                "chef360_public_knowledge": self.public_knowledge.summary(),
                "metadata_index": self.knowledge.summary() if self.knowledge else {"available": False},
                "optimized_corpus": self.corpus.stats() if self.corpus else {"available": False},
            },
        }
        handler = allowed.get(name)
        if not handler:
            raise ToolError(f"unknown tool: {name}")
        schema = next(tool["inputSchema"] for tool in TOOLS if tool["name"] == name)
        unknown = sorted(set(args) - set(schema.get("properties", {})))
        if unknown:
            raise ToolError(f"unknown argument(s): {', '.join(unknown)}")
        return self.tool_result(handler(args))

    def _search_corpus(self, arguments: dict[str, Any]) -> dict[str, Any]:
        if not self.corpus:
            raise ToolError("optimized knowledge corpus is unavailable")
        return self.corpus.search(arguments)

    def _get_document(self, arguments: dict[str, Any]) -> dict[str, Any]:
        if not self.corpus:
            raise ToolError("optimized knowledge corpus is unavailable")
        return self.corpus.document_chunks(arguments)

    def _require_metadata(self) -> KnowledgeBase:
        if not self.knowledge:
            raise ToolError("protected Chef CFT metadata index is unavailable")
        return self.knowledge

    def _search_repositories(self, arguments: dict[str, Any]) -> dict[str, Any]:
        return self._require_metadata().search(arguments)

    def _get_repository(self, arguments: dict[str, Any]) -> dict[str, Any]:
        return self._require_metadata().repository(arguments)

    def _find_artifacts(self, arguments: dict[str, Any]) -> dict[str, Any]:
        return self._require_metadata().artifacts(arguments)

    def _recommend(self, arguments: dict[str, Any]) -> dict[str, Any]:
        return self._require_metadata().recommend(arguments)

    def handle(self, request: Any) -> dict[str, Any] | None:
        if not isinstance(request, dict) or request.get("jsonrpc") != "2.0":
            return self.error(None, -32600, "Invalid Request")
        method = request.get("method")
        request_id = request.get("id")
        is_notification = "id" not in request
        params = request.get("params") or {}

        if method == "notifications/initialized" or method == "notifications/cancelled":
            return None
        if method == "initialize":
            requested = params.get("protocolVersion") if isinstance(params, dict) else None
            protocol = requested if requested in PROTOCOL_VERSIONS else PROTOCOL_VERSIONS[0]
            return self.response(
                request_id,
                {
                    "protocolVersion": protocol,
                    "capabilities": {
                        "tools": {"listChanged": False},
                        "resources": {"subscribe": False, "listChanged": False},
                    },
                    "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
                    "instructions": (
                        "Use search_chef360_knowledge for versioned public Chef 360 1.7.3 product guidance. "
                        "When the optional protected local overlay is available, use search_chef_knowledge "
                        "and metadata tools for Chef CFT implementation references."
                    ),
                },
            )
        if method == "ping":
            return self.response(request_id, {})
        if method == "tools/list":
            return self.response(request_id, {"tools": TOOLS})
        if method == "tools/call":
            if not isinstance(params, dict) or not isinstance(params.get("name"), str):
                return self.error(request_id, -32602, "tools/call requires a tool name")
            try:
                result = self.call_tool(params["name"], params.get("arguments"))
            except ToolError as error:
                result = self.tool_result({"error": str(error)}, is_error=True)
            return self.response(request_id, result)
        if method == "resources/list":
            return self.response(request_id, {"resources": RESOURCES})
        if method == "resources/read":
            uri = params.get("uri") if isinstance(params, dict) else None
            try:
                if uri == "chef-cft://knowledge/guide":
                    contents = [
                        {"uri": uri, "mimeType": "text/markdown", "text": self._require_metadata().guide()}
                    ]
                elif uri == "chef-cft://knowledge/summary":
                    contents = [
                        {
                            "uri": uri,
                            "mimeType": "application/json",
                            "text": json.dumps(self._require_metadata().summary(), indent=2, sort_keys=True),
                        }
                    ]
                elif uri == "chef-cft://knowledge/corpus-stats" and self.corpus:
                    contents = [
                        {
                            "uri": uri,
                            "mimeType": "application/json",
                            "text": json.dumps(self.corpus.stats(), indent=2, sort_keys=True),
                        }
                    ]
                elif uri == "chef360://knowledge/1.7.3/manifest":
                    contents = [
                        {
                            "uri": uri,
                            "mimeType": "application/json",
                            "text": json.dumps(self.public_knowledge.manifest, indent=2, sort_keys=True),
                        }
                    ]
                elif uri == "chef360://knowledge/1.7.3/readme":
                    contents = [
                        {"uri": uri, "mimeType": "text/markdown", "text": self.public_knowledge.readme()}
                    ]
                else:
                    return self.error(request_id, -32002, "Resource not found")
            except ToolError as error:
                return self.error(request_id, -32000, str(error))
            return self.response(request_id, {"contents": contents})
        if is_notification:
            return None
        return self.error(request_id, -32601, "Method not found")


def run() -> None:
    index_path = Path(os.environ.get("CHEF_CFT_INDEX_PATH", DEFAULT_INDEX)).expanduser().resolve()
    guide_path = Path(os.environ.get("CHEF_CFT_GUIDE_PATH", DEFAULT_GUIDE)).expanduser().resolve()
    corpus_path = Path(os.environ.get("CHEF_CFT_CORPUS_PATH", DEFAULT_CORPUS)).expanduser().resolve()
    public_path = Path(
        os.environ.get("CHEF360_KNOWLEDGE_PATH", DEFAULT_CHEF360_KNOWLEDGE)
    ).expanduser().resolve()
    knowledge = KnowledgeBase(index_path, guide_path) if index_path.is_file() else None
    corpus = KnowledgeCorpus(corpus_path) if corpus_path.is_file() else None
    server = McpServer(Chef360KnowledgeSet(public_path), knowledge, corpus)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            response = server.handle(request)
        except json.JSONDecodeError:
            response = server.error(None, -32700, "Parse error")
        except Exception:
            response = server.error(None, -32603, "Internal error")
        if response is not None:
            sys.stdout.write(json.dumps(response, separators=(",", ":")) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    try:
        run()
    except (OSError, RuntimeError, json.JSONDecodeError):
        print("Chef knowledge MCP could not load its configured knowledge sources.", file=sys.stderr)
        raise SystemExit(1)
