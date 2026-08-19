# Chef 360 Automation and Knowledge

This repository combines reusable Chef 360 automation, Azure two-node lab infrastructure, a versioned Chef 360 1.7.3 knowledge set, and read-only MCP services.

## Contents

- `scripts/chef360/`: cohort, enrollment, Courier demo job, and status workflows.
- `scripts/azure/`: Bash and PowerShell deployment, readiness, bootstrap, registration, validation, status, and teardown workflows.
- `infra/azure/`: Bicep and generated ARM templates for two low-cost Linux nodes.
- `knowledge-set/chef360-1.7.3/`: versioned public Chef 360 reference material.
- `mcp-service/`: TypeScript MCP service for the bundled public knowledge set and optional local-lab inspection.
- `docs/`: runbooks for Azure nodes, CLI demos, and legacy-script guidance.

The numbered scripts in the repository root are legacy lab references. See `docs/legacy-scripts.md` before using them.

## Azure Two-Node Workflow

Create a local parameter file:

```bash
cp infra/azure/azure-two-linux-lowcost.parameters.example.json \
  infra/azure/azure-two-linux-lowcost.parameters.json
```

Replace the example SSH key, source CIDR, and tags. Then run from the repository root:

```bash
RESOURCE_GROUP=rg-chef360-linux \
OBJECT_OWNER_PREFIX=chef360 \
SSH_PRIVATE_KEY="$HOME/.ssh/id_ed25519" \
./scripts/azure/deploy-azure-two-linux.sh
```

See `docs/azure-two-linux-vms.md` for the complete workflow.

## Chef 360 CLI Demo

The scripts use the locally configured Chef 360 CLI profile and do not embed access keys:

```bash
scripts/chef360/create-or-get-cohort.sh demo-nodes
scripts/chef360/run-demo-job-sleep.sh <node-id> 10
scripts/chef360/job-status.sh <job-id>
```

See `docs/chef360-cli-demo.md` for enrollment and profile details.

## MCP Service

The TypeScript service under `mcp-service/` searches the bundled public knowledge set. It supports stdio and Streamable HTTP transports.

```bash
cd mcp-service
npm ci
npm test
npm run build
```

See `mcp-service/README.md` for configuration and deployment guidance.

## Safety

- Never commit credentials, SSH private keys, signed enrollment configurations, Azure CLI state, runtime IDs, or generated response files.
- The `chef-cft` GitHub organization is used only as a read-only research source. No private/internal `chef-cft` metadata or downloaded corpus is stored here.
- Populate local files from the checked-in examples; sensitive and generated paths are covered by `.gitignore`.
- Review all legacy scripts before execution.

## Validation

```bash
python3 scripts/ci/check-azure-script-parity.py
python3 -m py_compile scripts/ci/check-azure-script-parity.py
```
