# Chef Knowledge MCP Service

The active dependency-free Python MCP service combines two explicitly separate
read-only sources:

- The checked-in public Chef 360 Platform 1.7.3 knowledge set.
- An optional protected local Chef CFT metadata index and sanitized SQLite FTS5 corpus.

The public source works in every repository checkout. Protected Chef CFT data
is never committed and is only available when supplied through local files.
The service performs no query-time GitHub, Chef, Azure, shell, or credential
access.

## Start

```bash
scripts/mcp/run-chef-knowledge-mcp.sh
```

The process uses MCP JSON-RPC over standard input/output. See
`config/chef-knowledge-mcp.example.json` for client configuration.

## Tools

| Tool | Source | Purpose |
|---|---|---|
| `search_chef360_knowledge` | Public | Search versioned Chef 360 1.7.3 guidance. |
| `get_chef360_document` | Public | Read bounded pages from manifest-declared documents. |
| `search_chef_knowledge` | Protected overlay | Full-text search over revision-pinned sanitized Chef CFT content. |
| `get_chef_document` | Protected overlay | Read bounded chunks from a protected corpus document. |
| `search_chef_repositories` | Protected overlay | Search repository metadata, taxonomy, visibility, freshness, and signals. |
| `get_chef_repository` | Protected overlay | Return safe metadata and representative artifact paths. |
| `find_chef_artifacts` | Protected overlay | Locate Policyfiles, cookbooks, InSpec profiles, Courier assets, and IaC. |
| `recommend_chef_references` | Protected overlay | Rank current repositories for a focused Chef topic. |
| `get_chef_knowledge_summary` | Both | Report source availability and statistics. |

Protected-overlay tools return a safe unavailable error when their local data
is absent. Public tools remain operational.

## Resources

- `chef360://knowledge/1.7.3/manifest`
- `chef360://knowledge/1.7.3/readme`
- `chef-cft://knowledge/guide` (protected overlay)
- `chef-cft://knowledge/summary` (protected overlay)
- `chef-cft://knowledge/corpus-stats` (protected overlay)

## Configuration

Defaults:

- Public knowledge: `knowledge-set/chef360-1.7.3`
- Protected metadata: `docs/chef-cft-metadata-index.json`
- Protected guide: `docs/chef-cft-knowledge-guide.md`
- Protected corpus: `data/chef-cft-knowledge.sqlite3`

Environment overrides:

- `CHEF360_KNOWLEDGE_PATH`
- `CHEF_CFT_INDEX_PATH`
- `CHEF_CFT_GUIDE_PATH`
- `CHEF_CFT_CORPUS_PATH`

The protected files are gitignored and should be owner-readable only. No
GitHub token or Chef credentials are passed to the MCP process.

## Optional Protected Overlay

The checked-in builders can create the local Chef CFT overlay for an authorized
operator. Generated metadata and corpus files remain excluded from Git.

```bash
cp config/chef-cft-corpus.example.json config/chef-cft-corpus.json
chmod 600 config/chef-cft-corpus.json
# Replace the placeholder with repositories the operator is authorized to read.
python3 scripts/content/chef_cft_org_index.py build
python3 scripts/content/build_chef_cft_corpus.py build
```

The Chef CFT organization is a strictly read-only source for these builders.
Do not mutate its repositories or organization resources.

## Verification

```bash
python3 -m unittest -v tests/test_chef_knowledge_mcp.py
python3 tests/mcp_stdio_smoke.py
```

Tests exercise public-only operation in a fresh checkout and additionally test
the protected overlay when local data is present.

## Security Model

- Explicit allowlist of tools and arguments.
- No arbitrary command or unrestricted filesystem tool.
- Manifest-only public document access with traversal and symlink checks.
- Bounded result counts, excerpts, document pages, and input strings.
- Secret-pattern redaction before responses.
- Generic internal errors without tracebacks or local filesystem disclosure.
- No blending of public product guidance with protected implementation results.
