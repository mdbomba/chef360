#!/usr/bin/env python3
"""Exercise MCP initialization, listing, resources, and a representative tool call."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "scripts" / "mcp" / "run-chef-knowledge-mcp.sh"


def request(process: subprocess.Popen[str], payload: dict) -> dict:
    assert process.stdin is not None
    assert process.stdout is not None
    process.stdin.write(json.dumps(payload) + "\n")
    process.stdin.flush()
    line = process.stdout.readline()
    if not line:
        raise RuntimeError("MCP server closed stdout before responding")
    return json.loads(line)


def main() -> int:
    process = subprocess.Popen(
        [str(SERVER)],
        cwd=ROOT,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        initialized = request(
            process,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2025-03-26",
                    "capabilities": {},
                    "clientInfo": {"name": "chef-knowledge-smoke", "version": "0.1.0"},
                },
            },
        )
        if initialized.get("result", {}).get("serverInfo", {}).get("name") != "chef-cft-knowledge":
            raise RuntimeError(f"unexpected initialize response: {initialized}")

        assert process.stdin is not None
        process.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n")
        process.stdin.flush()

        tools = request(process, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        tool_names = {tool["name"] for tool in tools["result"]["tools"]}
        expected = {
            "search_chef360_knowledge",
            "get_chef360_document",
            "search_chef_knowledge",
            "get_chef_document",
            "search_chef_repositories",
            "get_chef_repository",
            "find_chef_artifacts",
            "recommend_chef_references",
            "get_chef_knowledge_summary",
        }
        if tool_names != expected:
            raise RuntimeError(f"unexpected tools: {sorted(tool_names)}")

        summary = request(
            process,
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {
                    "name": "get_chef_knowledge_summary",
                    "arguments": {},
                },
            },
        )
        source_summary = summary["result"]["structuredContent"]
        repositories = []
        search_matches = []
        if source_summary["metadata_index"].get("available", True):
            called = request(
                process,
                {
                    "jsonrpc": "2.0",
                    "id": 4,
                    "method": "tools/call",
                    "params": {
                        "name": "recommend_chef_references",
                        "arguments": {"topic": "chef-360", "use_case": "node enrollment", "limit": 3},
                    },
                },
            )
            repositories = called["result"]["structuredContent"]["repositories"]
            if not repositories:
                raise RuntimeError("recommendation tool returned no repositories")

        if source_summary["optimized_corpus"].get("available", True):
            searched = request(
                process,
                {
                    "jsonrpc": "2.0",
                    "id": 6,
                    "method": "tools/call",
                    "params": {
                        "name": "search_chef_knowledge",
                        "arguments": {"query": "node enrollment", "limit": 3},
                    },
                },
            )
            search_matches = searched["result"]["structuredContent"]["matches"]
            if not search_matches:
                raise RuntimeError("optimized knowledge search returned no matches")

        public_search = request(
            process,
            {
                "jsonrpc": "2.0",
                "id": 7,
                "method": "tools/call",
                "params": {
                    "name": "search_chef360_knowledge",
                    "arguments": {"query": "node enrollment", "limit": 3},
                },
            },
        )
        public_matches = public_search["result"]["structuredContent"]["matches"]
        if not public_matches:
            raise RuntimeError("public Chef 360 knowledge search returned no matches")

        resources = request(process, {"jsonrpc": "2.0", "id": 4, "method": "resources/list", "params": {}})
        if len(resources["result"]["resources"]) != 5:
            raise RuntimeError("unexpected resource count")

        guide_read = False
        if source_summary["metadata_index"].get("available", True):
            guide = request(
                process,
                {
                    "jsonrpc": "2.0",
                    "id": 5,
                    "method": "resources/read",
                    "params": {"uri": "chef-cft://knowledge/guide"},
                },
            )
            guide_text = guide["result"]["contents"][0]["text"]
            if "Chef CFT Knowledge Guide" not in guide_text:
                raise RuntimeError("knowledge guide resource was not returned")
            guide_read = True

        manifest = request(
            process,
            {
                "jsonrpc": "2.0",
                "id": 8,
                "method": "resources/read",
                "params": {"uri": "chef360://knowledge/1.7.3/manifest"},
            },
        )
        if json.loads(manifest["result"]["contents"][0]["text"])["version"] != "1.7.3":
            raise RuntimeError("public Chef 360 manifest resource was not returned")

        print(
            json.dumps(
                {
                    "protocol": initialized["result"]["protocolVersion"],
                    "tools": sorted(tool_names),
                    "recommendations": [repository["name"] for repository in repositories],
                    "knowledge_match": search_matches[0]["repository"] if search_matches else None,
                    "public_knowledge_match": public_matches[0]["id"],
                    "resources": [resource["uri"] for resource in resources["result"]["resources"]],
                    "guide_read": guide_read,
                },
                indent=2,
            )
        )
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()


if __name__ == "__main__":
    sys.exit(main())
