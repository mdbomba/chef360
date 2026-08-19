# Azure Node Access Prerequisite

For this project's Azure nodes, public-IP and NSG reconciliation is a mandatory first step for every Azure-node request, including read-only inspection and status questions.

1. Make a public request to `https://api.ipify.org?format=json`.
2. Validate the response as an IPv4 address and convert it to a `/32` CIDR.
3. Run `scripts/azure/ensure-azure-ssh-access.sh` with the nodes' resource group and name prefix before any other Azure-node command.
4. Confirm the Azure NSG `allow-ssh` rule permits the current `/32`.

Do not use a cached or previously observed workstation address. The workstation can roam and its public address can change between requests. Keep Chef 360 service SSH sources in the separate `allow-chef360-ssh` rule so workstation reconciliation cannot remove them.

For the default project nodes, the command shape is:

```bash
scripts/azure/ensure-azure-ssh-access.sh rg-sa-linux-dev mbomba-sa-linux
```

The helper treats a missing resource group or NSG as a safe no-op, creates `allow-ssh` if needed, and updates stale workstation access only after obtaining the current address from the public endpoint.
