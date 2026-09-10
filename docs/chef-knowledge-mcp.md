# Chef Knowledge MCP Service

The active dependency-free Python MCP service combines explicitly separate
read-only sources:

- The checked-in public Chef 360 Platform 1.7.3 knowledge set.
- Read-only allowlisted lab inspection of local KVM machines and Chef Workstation.
- An optional protected local Chef CFT metadata index and sanitized SQLite FTS5 corpus.

The public source and lab inspection work in every repository checkout.
Protected Chef CFT data is never committed and is only available when supplied
through local files. The service performs no query-time GitHub, Chef, Azure,
shell, or credential access.

## First Connection

The initialization response provides only a short orientation: the service is
read-only, the public knowledge version, optional-source availability, and the
recommended search-then-read workflow. MCP clients may display or suppress
these instructions.

For an explicit introduction, call `get_chef_service_overview`. Its default
`brief` response identifies the service and suggests the next action without
listing the full catalog. Use `detail: "sources"` or `detail: "capabilities"`
only when that additional context is needed.

MCP discovery is client-driven:

- Resources are not loaded until the client calls `resources/read`.
- Tools do not run until the client calls them.
- Initialization instructions are guidance, not an unsolicited chat message.
- The server never injects the README, manifest, or complete corpus into a
  conversation automatically.

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
| `get_chef_service_overview` | Service | Return a brief introduction or requested source/capability details. |
| `get_chef_knowledge_summary` | Both | Report source availability and statistics. |
| `list_lab_machines` | Lab | List the allowlisted KVM machines in the local Chef lab. |
| `inspect_lab_machine` | Lab | Get libvirt state and service-port reachability for a lab machine. |
| `chef_workstation_versions` | Lab | Report Chef Workstation component versions on the MCP host. |

Protected-overlay tools and resources are advertised only when their local data
is present. Public tools remain operational in every checkout. A direct call to
an unavailable protected tool returns a safe error.

## Resources

- `chef360://knowledge/1.7.3/manifest`
- `chef360://knowledge/1.7.3/readme`
- `chef360://service/overview`
- `chef-cft://knowledge/guide` (protected overlay)
- `chef-cft://knowledge/summary` (protected overlay)
- `chef-cft://knowledge/corpus-stats` (protected overlay)

## Configuration

Defaults:

- Public knowledge: `knowledge-set/chef360-1.7.3`
- Protected metadata: `docs/chef-cft-metadata-index.json`
- Protected guide: `docs/chef-cft-knowledge-guide.md`
- Protected corpus: `data/chef-cft-knowledge.sqlite3`
- Lab machines: allowlisted in `server.py`

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
