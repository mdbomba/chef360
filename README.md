# Chef 360 Project

This repository is the project of record for Chef 360 automation, versioned
public knowledge, and MCP services.

It helps people and AI clients find Chef 360 guidance, retrieve focused source
material, install Chef 360 on a prepared Linux guest, and inspect an allowlisted
local lab. The MCP services are read-only knowledge and inspection interfaces;
they do not administer Chef 360, cloud accounts, or hypervisors.

## Start Here

Choose the path that matches your goal:

| Goal | Start with |
|---|---|
| Ask a Chef 360 question | Connect the Python MCP using `config/chef-knowledge-mcp.example.json`, then ask normally. |
| Understand available MCP sources | Call `get_chef_service_overview`; its default response is intentionally brief. |
| Install Chef 360 on an existing Linux guest | Follow `docs/provider-neutral-chef360-installation.md`. |
| Build the reviewed KVM lab | Follow `docs/kvm-chef360-lab.md` and stop at its pre-Chef review checkpoint. |
| Provision Azure infrastructure | Follow `docs/azure-two-linux-vms.md`. |
| Study other infrastructure patterns | Review the imported Terraform references, noting their documented limitations. |
| Inspect the local KVM lab | Run the TypeScript MCP directly on the lab host. |

The primary MCP workflow is progressive: search first, inspect a short result,
then retrieve only the relevant document page. It does not load the complete
knowledge set into every conversation.

## MCP Choices

| Service | Best fit | Sources and capabilities |
|---|---|---|
| Python MCP | Primary local knowledge service | Chef 360 1.7.3 public knowledge plus an optional protected Chef CFT overlay |
| TypeScript MCP | Standalone or hosted public service | Chef 360 1.7.3 knowledge and, when run on the lab host, read-only lab inspection |

## Layout

- `infra/azure/`: two-node Azure infrastructure templates.
- `scripts/azure/`: paired Bash and PowerShell deployment workflows.
- `scripts/chef360/`: reusable Chef 360 enrollment and Courier workflows.
- `scripts/kvm/`: reviewed KVM provisioning, staging, installation, and validation workflow.
- `chef-360-single-node-terraform-main/`: imported AWS Terraform reference for modular infrastructure and topology patterns.
- `kots-demo-stand-main/`: imported AWS lab reference for cloud-init and ConfigValues rendering patterns.
- `knowledge-set/chef360-1.7.3/`: checked-in public Chef 360 documentation set.
- `src/chef_knowledge_mcp/`: active Python MCP with public knowledge, allowlisted lab inspection, and an optional protected local overlay.
- `tests/`: Python MCP tests and stdio smoke verification.
- `docs/`: public runbooks and implementation notes.

Protected Chef CFT metadata, private/internal source corpora, credentials,
customer exports, and host runtime state are deliberately excluded from Git.
See `SECURITY.md`.

## Chef 360 Platform Quick Start

The operator-focused [Chef 360 Platform 1.7.3 quick start](docs/quick-start/README.md)
covers planning, host preparation, online and air-gapped installation, initial
tenant configuration, and successful tenant administrator sign-in. Validate
quick-start changes from the repository root:

```bash
bash scripts/ci/check-quick-start.sh
```

## Shared Parameters

Copy the shared parameter template before running Chef 360 or infrastructure
workflows:

```bash
cp config/chef360.parameters.example.env config/chef360.parameters.env
```

The local file centralizes `PROVIDER`, `CHEF360_ENDPOINT`, the optional Chef
Automate Data Collector URL, CLI profile/cohort, managed-node defaults, and
provider-specific resource naming. Supported provider values are `azure.com`,
`azure.us`, `hyperv`, `kvm`, `aws.com`, and `aws.gov`.
The Chef 360 endpoint must be a complete HTTPS origin such as
`https://internal.cloud.chef.io:443` or `https://chef360.example.com:3100`.

The file contains no secrets and is gitignored because it identifies the local
environment. Set `CHEF360_PARAMETERS_FILE` to use another path. Explicit
environment variables and command-line arguments override file values.

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

## Provider-Neutral Installation

Chef 360 installation is separated from infrastructure provisioning. Terraform,
native cloud tools, hypervisor tools, or manual workflows can provide a Linux
guest on AWS, Azure, KVM, Hyper-V, or Proxmox; the same scripts then check,
install, and validate Chef 360:

```bash
sudo scripts/chef360/check-host-requirements.sh
export CHEF360_ADMIN_CONSOLE_PASSWORD='set-from-a-local-secret-source'
sudo --preserve-env=CHEF360_ADMIN_CONSOLE_PASSWORD \
  scripts/chef360/install-server.sh \
  --installer /path/to/chef-360 \
  --license /path/to/license.yaml \
  --config-values knowledge-set/chef360-1.7.3/examples/kots-config.yaml
sudo scripts/chef360/validate-installation.sh
```

The ConfigValues example is a version-specific Chef 360 1.7.3 export from an
isolated KVM lab. See `docs/provider-neutral-chef360-installation.md` for the
automation contract and platform guidance. The imported Terraform projects are
reference inputs; they are not the canonical installation workflow.

## Active Knowledge MCP

The dependency-free Python service always exposes the checked-in Chef 360 1.7.3
knowledge set and read-only allowlisted lab inspection. If protected Chef CFT
metadata and corpus files are supplied locally, it also exposes
implementation-reference search without copying that data into this repository.

```bash
scripts/mcp/run-chef-knowledge-mcp.sh
python3 -m unittest -v tests/test_chef_knowledge_mcp.py
python3 tests/mcp_stdio_smoke.py
```

See `docs/chef-knowledge-mcp.md` for tools, resources, and configuration.
