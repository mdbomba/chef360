# Local Chef Lab Topology

This environment runs on the KVM/libvirt hypervisor `fury.demo.lab`. The
hypervisor is also the Chef Workstation administration host.

## Machines

| Role | Libvirt domain | IPv4 address | Known service |
| --- | --- | --- | --- |
| Chef 360 Platform | `20_chef360` | `10.0.0.20` | `https://10.0.0.20:31000` |
| Chef Automate | `21_automate` | `10.0.0.21` | `https://10.0.0.21` |
| Managed node 1 | `31_node1` | `10.0.0.31` | SSH when configured and running |
| Managed node 2 | `32_node2` | `10.0.0.32` | SSH when configured and running |

All four guests use the persistent libvirt network named `default`. IP
addresses are declared lab configuration; use libvirt state and connectivity
checks to determine current availability.

## Chef Workstation Host

Verified installed software on `fury.demo.lab`:

- Chef Workstation 25.14.2
- Chef Infra Client 18.10.17
- Chef InSpec 5.24.7
- Chef CLI 5.6.23
- Chef Habitat 1.6.1243
- Test Kitchen 4.0.0
- Cookstyle 8.6.10
- `knife`
- `chef-platform-auth-cli`
- `chef-node-management-cli`
- `chef-courier-cli`

The MCP service provides read-only lab inventory, VM state, connectivity, and
Chef Workstation version tools. It does not store SSH keys, API tokens, or Chef
credentials in this knowledge set.

## Operational Notes

- Chef 360 uses HTTPS port 31000 in this lab, not the default HTTPS port 443.
- Chef Automate serves HTTPS on port 443.
- The Chef 360 Automate connector Data Collector URL is
  `https://10.0.0.21/data-collector/v0/`. This is distinct from the Automate UI
  base URL and includes the trailing slash.
- The IP-based URL is a verified working form for this lab. Chef 360 pods use
  CoreDNS and do not inherit the node's `/etc/hosts`. Configure the Chef 360 VM
  to use libvirt dnsmasq at `10.0.0.1`; it reads the KVM host's `/etc/hosts` and
  forwards public queries upstream, making private lab names visible to pods.
- After pod DNS validation, the Automate Connector was successfully configured
  with the preferred certificate-matching FQDN URL
  `https://automate.demo.lab/data-collector/v0/`.
- The connector's **API Key** is a dedicated API token generated on `21_automate`
  with `sudo chef-automate iam token create chef360-data-collector --admin`.
  Store the returned value outside this knowledge set.
- The Automate Connector is a Chef 360 1.7.3 feature. It connects this release
  to the separate Automate VM. Future Chef 360 releases may integrate Automate
  capabilities and remove the need for this connection; verify the target
  release documentation before changing or retiring the lab topology.
- Managed node availability depends on the corresponding libvirt domain being
  powered on.
- Certificate validation may require the lab CA certificate. Do not disable TLS
  verification for authenticated production operations.
