# Chef 360 Project

This repository is the project of record for Chef 360 automation, versioned
public knowledge, and MCP services.

## Layout

- `infra/azure/`: two-node Azure infrastructure templates.
- `scripts/azure/`: paired Bash and PowerShell deployment workflows.
- `scripts/chef360/`: reusable Chef 360 enrollment and Courier workflows.
- `knowledge-set/chef360-1.7.3/`: checked-in public Chef 360 documentation set.
- `src/chef_knowledge_mcp/`: active Python MCP with public knowledge and an optional protected local overlay.
- `mcp-service/`: standalone TypeScript MCP for the public knowledge set and allowlisted lab inspection.
- `tests/`: Python MCP tests and stdio smoke verification.
- `docs/`: public runbooks and implementation notes.

Protected Chef CFT metadata, private/internal source corpora, credentials,
customer exports, and host runtime state are deliberately excluded from Git.
See `SECURITY.md`.

## Azure Two-Node Workflow

Copy and populate the example parameters before deployment:

```bash
cp infra/azure/azure-two-linux-lowcost.parameters.example.json \
  infra/azure/azure-two-linux-lowcost.parameters.json
./scripts/azure/deploy-azure-two-linux.sh
./scripts/azure/status-azure-two-linux.sh
./scripts/azure/destroy-azure-two-linux.sh
```

See `docs/azure-two-linux-vms.md` for the complete workflow. Azure scripts are
maintained as Bash and PowerShell pairs; validate parity with:

```bash
python3 scripts/ci/check-azure-script-parity.py
```

## Active Knowledge MCP

The dependency-free Python service always exposes the checked-in Chef 360 1.7.3
knowledge set. If protected Chef CFT metadata and corpus files are supplied
locally, it also exposes implementation-reference search without copying that
data into this repository.

```bash
scripts/mcp/run-chef-knowledge-mcp.sh
python3 -m unittest -v tests/test_chef_knowledge_mcp.py
python3 tests/mcp_stdio_smoke.py
```

See `docs/chef-knowledge-mcp.md` for tools, resources, and configuration.

## Standalone TypeScript MCP

The public service supports stdio and Streamable HTTP transports:

```bash
cd mcp-service
npm ci
npm test
npm run typecheck
npm run build
```

Build its container from the repository root:

```bash
docker build -f mcp-service/Dockerfile -t chef360-mcp .
```

The HTTP transport has no built-in authentication. Do not expose it directly
to an untrusted network.
