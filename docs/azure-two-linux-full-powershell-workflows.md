# Azure Two Linux Full PowerShell Workflows

This project now includes PowerShell companion scripts for full deploy and destroy flows.

## Scripts

- `scripts/azure/deploy-azure-two-linux-full.ps1`
  - Deploys (or reuses) two Azure Linux nodes.
  - Resolves node IPs.
  - Ensures and validates passwordless sudo for `chef`.
  - Updates Windows hosts entries for `node1` and `node2`.
  - Bootstraps Chef Infra nodes (`knife bootstrap`) and validates policy.
  - Runs `sudo chef-client` on both nodes.
  - Runs Chef 360 registration helper (optional via switch/env).

- `scripts/azure/destroy-azure-two-linux-full.ps1`
  - Removes Chef Infra node/client records for `node1` and `node2`.
  - Archives matching Chef360 node records.
  - Removes `node1`/`node2` from Windows hosts and SSH known_hosts.
  - Tears down Azure resources (VMs, NICs, PIPs, VNet, NSG, deployment records).

## Prerequisites

- `pwsh` 7+
- Azure CLI (`az`) authenticated
- Chef Infra CLI (`knife`) configured
- Chef360 CLI (`chef-node-management-cli`) configured
- SSH key for node access
- For hosts file updates from Linux/WSL: access to `/mnt/c/Windows/System32/drivers/etc/hosts`

## Deploy Usage

Basic:

```powershell
pwsh ./scripts/azure/deploy-azure-two-linux-full.ps1 -SshPrivateKey "$HOME/.ssh/id_ed25519"
```

Example with explicit settings:

```powershell
pwsh ./scripts/azure/deploy-azure-two-linux-full.ps1 \
  -ResourceGroup rg-chef360-linux \
  -VmSize Standard_D2s_v5 \
  -SshPrivateKey "$HOME/.ssh/id_ed25519" \
  -ChefNodeUser chef \
  -ChefPolicyName stig_base \
  -ChefPolicyGroup dev \
  -EnableChef360Registration $true
```

## Destroy Usage

Interactive confirm:

```powershell
pwsh ./scripts/azure/destroy-azure-two-linux-full.ps1
```

Non-interactive force:

```powershell
pwsh ./scripts/azure/destroy-azure-two-linux-full.ps1 -Force
```

## Notes

- Destroy archives Chef360 nodes (best effort) based on `node1/node2` names and known Azure IPs.
- Destroy does not delete resource group or template specs.
