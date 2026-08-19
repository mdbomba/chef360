from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from chef_knowledge_mcp.server import (  # noqa: E402
    DEFAULT_CORPUS,
    DEFAULT_INDEX,
    Chef360KnowledgeSet,
    KnowledgeBase,
    KnowledgeCorpus,
    McpServer,
    ToolError,
    redact,
)


class ChefKnowledgeMcpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.public_knowledge = Chef360KnowledgeSet()
        cls.knowledge = KnowledgeBase() if DEFAULT_INDEX.is_file() else None
        cls.corpus = KnowledgeCorpus(DEFAULT_CORPUS) if DEFAULT_CORPUS.is_file() else None
        cls.server = McpServer(cls.public_knowledge, cls.knowledge, cls.corpus)

    def require_protected_sources(self) -> None:
        if self.knowledge is None or self.corpus is None:
            self.skipTest("protected Chef CFT test data is not available")

    def test_public_manifest_has_expected_documents(self) -> None:
        self.assertEqual("1.7.3", self.public_knowledge.manifest["version"])
        self.assertEqual(19, len(self.public_knowledge.documents))

    def test_public_search_finds_azure_node_access_prerequisite(self) -> None:
        result = self.public_knowledge.search(
            {"query": "mandatory Azure node public IP NSG", "limit": 3}
        )
        self.assertTrue(
            any(match["id"] == "operations-azure-node-access" for match in result["matches"])
        )

    def test_public_search_finds_node_enrollment(self) -> None:
        result = self.public_knowledge.search({"query": "node enrollment", "limit": 3})
        self.assertTrue(result["matches"])
        self.assertTrue(any(match["id"] == "node-management-enrollment" for match in result["matches"]))
        self.assertTrue(all(not match["path"].startswith("/") for match in result["matches"]))

    def test_public_search_filters_topics(self) -> None:
        result = self.public_knowledge.search(
            {"query": "enrollment", "topic": "self-enrollment", "limit": 5}
        )
        self.assertEqual(["node-management-enrollment"], [match["id"] for match in result["matches"]])

    def test_public_document_is_paginated(self) -> None:
        first = self.public_knowledge.document(
            {"id": "node-management-enrollment", "max_characters": 100}
        )
        self.assertEqual(100, len(first["content"]))
        self.assertIsNotNone(first["next_offset"])
        second = self.public_knowledge.document(
            {"id": "node-management-enrollment", "offset": first["next_offset"], "max_characters": 100}
        )
        self.assertNotEqual(first["content"], second["content"])

    def test_public_document_rejects_unknown_id(self) -> None:
        with self.assertRaises(ToolError):
            self.public_knowledge.document({"id": "missing"})

    def test_public_manifest_rejects_unsafe_paths(self) -> None:
        for unsafe_path in ("../outside.md", "/tmp/outside.md"):
            with self.subTest(path=unsafe_path), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "README.md").write_text("# Fixture\n", encoding="utf-8")
                (root / "manifest.json").write_text(
                    json.dumps(
                        {
                            "version": "1.7.3",
                            "documents": [
                                {"id": "unsafe", "path": unsafe_path, "title": "Unsafe", "topics": []}
                            ],
                        }
                    ),
                    encoding="utf-8",
                )
                with self.assertRaises(RuntimeError):
                    Chef360KnowledgeSet(root)

    def test_public_manifest_rejects_symlink_escape(self) -> None:
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as outside:
            root = Path(directory)
            target = Path(outside) / "outside.md"
            target.write_text("outside", encoding="utf-8")
            (root / "README.md").write_text("# Fixture\n", encoding="utf-8")
            (root / "linked.md").symlink_to(target)
            (root / "manifest.json").write_text(
                json.dumps(
                    {
                        "version": "1.7.3",
                        "documents": [
                            {"id": "linked", "path": "linked.md", "title": "Linked", "topics": []}
                        ],
                    }
                ),
                encoding="utf-8",
            )
            with self.assertRaises(RuntimeError):
                Chef360KnowledgeSet(root)

    def test_index_has_complete_repository_coverage(self) -> None:
        self.require_protected_sources()
        assert self.knowledge is not None
        self.assertEqual(209, len(self.knowledge.repositories))
        self.assertEqual(209, self.knowledge.index["organization"]["visible_repository_count"])

    def test_search_finds_node_management(self) -> None:
        self.require_protected_sources()
        assert self.knowledge is not None
        result = self.knowledge.search({"category": "Node Management", "current_only": True})
        names = {repository["name"] for repository in result["repositories"]}
        self.assertIn("chef-cft/node-management", names)

    def test_repository_returns_structural_signals(self) -> None:
        self.require_protected_sources()
        assert self.knowledge is not None
        result = self.knowledge.repository({"name": "chef-cft/node-enrollment"})
        self.assertGreater(result["signals"]["policyfiles"]["count"], 0)
        self.assertGreater(result["signals"]["cookbook_metadata"]["count"], 0)

    def test_artifacts_find_policyfiles(self) -> None:
        self.require_protected_sources()
        assert self.knowledge is not None
        result = self.knowledge.artifacts({"artifact_type": "policyfiles", "limit": 5})
        self.assertGreater(result["repository_count"], 0)
        self.assertGreater(result["artifact_count"], 0)

    def test_recommendations_are_current_by_default(self) -> None:
        self.require_protected_sources()
        assert self.knowledge is not None
        result = self.knowledge.recommend({"topic": "chef-360", "limit": 10})
        self.assertTrue(result["repositories"])
        self.assertTrue(
            all(repository["freshness"] == "active-within-2-years" for repository in result["repositories"])
        )

    def test_redaction_removes_tokens(self) -> None:
        self.assertEqual("[redacted sensitive value]", redact("github_pat_" + "a" * 30))

    def test_redaction_removes_common_credentials(self) -> None:
        for value in (
            "CHEF_CLIENT_SECRET=super-secret-value",
            "client_secret: super-secret-value",
            "AccountKey=super-secret-value",
            "https://user:password@example.com/path",
        ):
            with self.subTest(value=value):
                self.assertEqual("[redacted sensitive value]", redact(value))

    def test_unknown_arguments_are_rejected(self) -> None:
        with self.assertRaises(ToolError):
            self.server.call_tool("get_chef_knowledge_summary", {"command": "whoami"})

    def test_initialize_and_tools_list(self) -> None:
        initialized = self.server.handle(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {"protocolVersion": "2025-03-26", "capabilities": {}},
            }
        )
        self.assertEqual("2025-03-26", initialized["result"]["protocolVersion"])
        tools = self.server.handle({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        self.assertEqual(9, len(tools["result"]["tools"]))

    def test_fts_search_finds_enrollment_guidance(self) -> None:
        self.require_protected_sources()
        assert self.corpus is not None
        result = self.corpus.search({"query": "node enrollment", "limit": 10})
        repositories = {match["repository"] for match in result["matches"]}
        self.assertTrue(repositories & {"chef-cft/node-enrollment", "chef-cft/node-management"})

    def test_fts_document_can_be_read(self) -> None:
        self.require_protected_sources()
        assert self.corpus is not None
        result = self.corpus.document_chunks(
            {"repository": "node-enrollment", "path": "README.md", "limit": 1}
        )
        self.assertEqual("chef-cft/node-enrollment", result["repository"])
        self.assertTrue(result["chunks"])

    def test_tool_validation_error_is_safe_tool_result(self) -> None:
        self.require_protected_sources()
        response = self.server.handle(
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {"name": "find_chef_artifacts", "arguments": {"artifact_type": "not-a-signal"}},
            }
        )
        self.assertTrue(response["result"]["isError"])
        self.assertNotIn("Traceback", response["result"]["content"][0]["text"])

    def test_guide_resource_can_be_read(self) -> None:
        self.require_protected_sources()
        response = self.server.handle(
            {
                "jsonrpc": "2.0",
                "id": 4,
                "method": "resources/read",
                "params": {"uri": "chef-cft://knowledge/guide"},
            }
        )
        self.assertIn("Chef CFT Knowledge Guide", response["result"]["contents"][0]["text"])

    def test_public_resources_can_be_read(self) -> None:
        manifest = self.server.handle(
            {
                "jsonrpc": "2.0",
                "id": 5,
                "method": "resources/read",
                "params": {"uri": "chef360://knowledge/1.7.3/manifest"},
            }
        )
        self.assertEqual("1.7.3", json.loads(manifest["result"]["contents"][0]["text"])["version"])
        readme = self.server.handle(
            {
                "jsonrpc": "2.0",
                "id": 6,
                "method": "resources/read",
                "params": {"uri": "chef360://knowledge/1.7.3/readme"},
            }
        )
        self.assertIn("Chef 360", readme["result"]["contents"][0]["text"])

    def test_summary_reports_both_sources(self) -> None:
        result = self.server.call_tool("get_chef_knowledge_summary", {})["structuredContent"]
        self.assertEqual("1.7.3", result["chef360_public_knowledge"]["version"])
        if self.knowledge:
            self.assertIn("coverage", result["metadata_index"])
        else:
            self.assertFalse(result["metadata_index"]["available"])

    def test_public_only_server_remains_operational(self) -> None:
        server = McpServer(self.public_knowledge)
        result = server.call_tool("search_chef360_knowledge", {"query": "Courier jobs"})
        self.assertTrue(result["structuredContent"]["matches"])
        unavailable = server.call_tool("get_chef_knowledge_summary", {})["structuredContent"]
        self.assertFalse(unavailable["metadata_index"]["available"])

    def test_custom_index_does_not_require_github_access(self) -> None:
        self.require_protected_sources()
        assert self.knowledge is not None
        with tempfile.TemporaryDirectory() as directory:
            index_path = Path(directory) / "index.json"
            guide_path = Path(directory) / "guide.md"
            index_path.write_text(json.dumps(self.knowledge.index), encoding="utf-8")
            guide_path.write_text("# Guide\n", encoding="utf-8")
            knowledge = KnowledgeBase(index_path, guide_path)
            self.assertEqual(209, len(knowledge.repositories))

    def test_metadata_is_loaded_lazily(self) -> None:
        self.require_protected_sources()
        knowledge = KnowledgeBase()
        self.assertIsNone(knowledge._index)
        self.assertEqual(209, len(knowledge.repositories))
        self.assertIsNotNone(knowledge._index)


if __name__ == "__main__":
    unittest.main()
