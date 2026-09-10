# Azure Two Linux VMs Runbook

This runbook covers deployment, status checks, and teardown for the local Azure two-VM template workflow in `chef360`.

## Files used

- Template source: `infra/azure/azure-two-linux-lowcost.bicep`
- Template JSON: `infra/azure/azure-two-linux-lowcost.json`
- Parameter template: `infra/azure/azure-two-linux-lowcost.parameters.example.json`
- Local parameter file: `infra/azure/azure-two-linux-lowcost.parameters.json` (gitignored)
- Deploy script: `scripts/azure/deploy-azure-two-linux.sh`
- PowerShell deploy script: `scripts/azure/deploy-azure-two-linux-full.ps1`
- Status script: `scripts/azure/status-azure-two-linux.sh`
- PowerShell status script: `scripts/azure/status-azure-two-linux.ps1`
- Destroy script: `scripts/azure/destroy-azure-two-linux.sh`
- PowerShell destroy script: `scripts/azure/destroy-azure-two-linux-full.ps1`
- Bash auth bootstrap script: `scripts/azure/bootstrap-azure-auth.sh`
- PowerShell auth bootstrap script: `scripts/azure/bootstrap-azure-auth.ps1`
- Bash sudo verification script: `scripts/azure/verify-chef-sudo-nopasswd.sh`
- PowerShell sudo verification script: `scripts/azure/verify-chef-sudo-nopasswd.ps1`
- Bash Windows hosts check script: `scripts/azure/check-windows-hosts.sh`
- PowerShell Windows hosts check script: `scripts/azure/check-windows-hosts.ps1`

## Prerequisites

- Azure CLI installed (`az`)
- Logged in to Azure (`az login`)
- Access to the target subscription/resource group
- A populated local parameter file copied from the example
- Optional: `TEMPLATE_SPEC_ID` when using a published template spec

## Optional local auth bootstrap

To stage reusable Azure CLI auth artifacts in this project:

```bash
./scripts/azure/bootstrap-azure-auth.sh
```

This copies key files from `~/.azure` into project-local `.azure/` (gitignored). The Azure scripts in this repo automatically set `AZURE_CONFIG_DIR` to that folder when it exists.

## Deploy

From the project root:

```bash
cp infra/azure/azure-two-linux-lowcost.parameters.example.json \
  infra/azure/azure-two-linux-lowcost.parameters.json
```

Replace the SSH public key, source CIDR, and ownership tags before deployment.

```bash
./scripts/azure/deploy-azure-two-linux.sh [resource-group] [vm-size]
```

Defaults:

- `resource-group`: `rg-chef360-linux`
- `vm-size`: `Standard_D2s_v5`
- `OBJECT_OWNER_PREFIX`: `chef360` (so the default Azure object prefix becomes `chef360-sa-linux`)

The deploy workflows use the local Bicep-generated ARM template by default. Set `USE_TEMPLATE_SPEC=true` for Bash or pass `-UseTemplateSpec $true` to PowerShell only when the template spec has been published with equivalent cloud-init configuration.

Example:

```bash
./scripts/azure/deploy-azure-two-linux.sh rg-chef360-linux Standard_B2s
```

Optional custom owner prefix example:

```bash
OBJECT_OWNER_PREFIX=demo ./scripts/azure/deploy-azure-two-linux.sh
```

## Check status

```bash
./scripts/azure/status-azure-two-linux.sh [resource-group] [name-prefix]
```

Defaults:

- `resource-group`: `rg-chef360-linux`
- `name-prefix`: `chef360-sa-linux` (derived from `OBJECT_OWNER_PREFIX` unless explicitly set)

Example:

```bash
./scripts/azure/status-azure-two-linux.sh rg-chef360-linux chef360-sa-linux
```

## Destroy deployed resources

```bash
./scripts/azure/destroy-azure-two-linux.sh [resource-group] [name-prefix] [--yes]
```

Defaults:

- `resource-group`: `rg-chef360-linux`
- `name-prefix`: `chef360-sa-linux` (derived from `OBJECT_OWNER_PREFIX` unless explicitly set)

Behavior:

- Deletes VMs, NICs, public IPs, VNet, NSG, and deployment records.
- Preserves the resource group and template specs.
- Prompts for confirmation unless `--yes` is passed as the third argument.

Example with confirmation bypass:

```bash
./scripts/azure/destroy-azure-two-linux.sh rg-chef360-linux chef360-sa-linux --yes
```

## Notes

- Script parity check: `python3 scripts/ci/check-azure-script-parity.py`
- Runtime state file: deploy scripts now write `config/azure-two-linux.env` with resolved values (resource group, name prefix, node IPs, and related settings) so follow-on scripts can run without re-entering or guessing node targets.
- To override runtime state location, set `AZURE_TWO_LINUX_STATE_FILE=/path/to/file.env`.
- Destroy scripts remove the runtime state file after successful teardown.
- `deploy-azure-two-linux.sh` resolves the parameter file relative to the script path, so it remains portable inside this repo.
- Both deploy workflows replace the target resource group's tags with the same 12 values used by the template, sourced from `infra/azure/azure-two-linux-lowcost.parameters.json`. The RG keys `Application`, `Team`, and `Expiration` use the capitalization required by organization policy; the template's corresponding resource keys are lowercase.
- Expiration defaults to two days from each deployment/tagging run in UTC (`YYYY-MM-DD`). The workflows refresh tags on the RG and existing tagged deployment resources even when VM creation is skipped. Set `EXPIRATION` to explicitly override the default.
- The Azure template configures static private IPs, local `node1`/`node2` host entries, SSH prerequisites, passwordless sudo for the admin user, and a `/var/lib/chef360-template-ready` cloud-init marker.
- Windows hosts updates and Chef Infra/Chef360 enrollment remain workflow operations because they require workstation access and external service credentials.
- If deployment fails, verify the resource group name, Azure subscription context, template spec ID, and values in `infra/azure/azure-two-linux-lowcost.parameters.json`.
