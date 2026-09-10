# Provider-Neutral Infrastructure Automation

Chef 360 installation should be portable across AWS, Azure, KVM, Hyper-V, and
Proxmox. Separate infrastructure provisioning from the in-guest installation so
that each platform produces the same Linux guest contract and invokes the same
Chef 360 workflow.

## Layered Model

1. The infrastructure layer creates compute, disks, networks, firewall rules,
   DNS, and guest access.
2. The guest-preparation layer establishes the hostname, packages, time sync,
   filesystem, and operating-system prerequisites.
3. The installation layer supplies the Chef 360 installer, license, and
   release-specific `ConfigValues` document.
4. The validation layer checks Kubernetes workloads and user-facing endpoints.

Terraform is one valid infrastructure layer. It is not required for the guest
preparation, installation, or validation layers. Avoid making Terraform
`remote-exec` blocks the only representation of Chef 360 installation logic.

## Platform Realization Matrix

| Platform | Provisioning choices | Guest bootstrap | Platform-specific considerations |
|---|---|---|---|
| AWS | Terraform, CloudFormation, console | cloud-init, SSM, SSH | Security groups, EBS latency and encryption, IMDSv2, stable DNS or addresses |
| Azure | Terraform, ARM/Bicep, portal | cloud-init, Run Command, SSH | NSGs, managed-disk performance, private DNS, accelerated networking where appropriate |
| KVM/libvirt | Terraform libvirt provider, `virt-install`, Cockpit | cloud-init, SSH | Linux bridge or routed networking, storage-pool durability, disk cache mode, guest agent |
| Hyper-V | PowerShell, System Center, suitable Terraform provider | cloud-init-capable image, PowerShell Direct, SSH | Generation 2 guests, virtual switches, VLANs, secure-boot compatibility, dynamic-memory policy |
| Proxmox VE | Terraform provider, API, UI | cloud-init, guest agent, SSH | Template lifecycle, bridge/VLAN selection, storage backend, disk discard and cache settings |

Provider tools and plugins have independent support and release lifecycles.
Record tested versions with each executable example rather than presenting a
generic Terraform provider as a Chef 360 product requirement.

## Common Provisioner Contract

A provider implementation should produce or document these values:

- Controller and worker addresses.
- Stable hostnames and their DNS records.
- SSH, guest-agent, or console access method.
- Embedded Cluster data-disk mount point and capacity.
- Admin Console URL.
- Tenant URL.
- Location or secure delivery method for the installer and license.
- Location of the Chef 360 version-specific ConfigValues file.

After provisioning, use the provider-neutral scripts:

```bash
scripts/chef360/check-host-requirements.sh
scripts/chef360/install-server.sh \
  --installer ./chef-360 \
  --license ./license.yaml \
  --config-values ./kots-config.yaml
scripts/chef360/validate-installation.sh
```

## Terraform Guidance

When Terraform is selected:

- Use provider-native resources for infrastructure only.
- Stage or invoke the common scripts instead of duplicating installation shell
  commands across modules.
- Prefer cloud-init or a post-provision orchestration step over `remote-exec`.
- Make release/channel selection explicit and reproducible.
- Keep cloud credentials in the provider's standard credential chain.
- Use encrypted, access-controlled remote state for non-disposable environments.
- Remember that state and user data can contain rendered configuration,
  passwords, license content, and artifact authorization values.
- Return comparable outputs across providers: node addresses, Admin Console URL,
  tenant URL, and installation target.

## Bash-First Guidance

A Bash-first workflow does not mean manually creating infrastructure. It means
that the canonical in-guest behavior is executable without a specific
provisioner. The same scripts can be called by Terraform, cloud-init, Ansible,
CI, or an operator over SSH.

This model is especially useful while provider examples mature at different
rates. A tested KVM or Proxmox guest can use the same installation workflow as a
Terraform-created AWS or Azure guest without waiting for feature parity between
providers.

## Current Repository Inputs

The imported AWS Terraform projects provide useful implementation evidence:

- `chef-360-single-node-terraform-main/` demonstrates modular networking,
  compute, security groups, DNS, encrypted disks, IMDSv2, and topology data.
- `kots-demo-stand-main/` demonstrates rendering ConfigValues into cloud-init
  and passing `--config-values` during noninteractive installation.

These imports are reference material, not the provider-neutral contract. Their
AWS resource choices, public-IP assumptions, incomplete multi-node joining, and
unintegrated RDS/S3 resources must not be interpreted as Chef 360 requirements.

## Choosing an Approach

Use Terraform when repeatable lifecycle management of platform resources is the
primary requirement and a maintained provider covers the target platform. Use
native tooling or manual provisioning when it is more reliable for the local
hypervisor. In either case, keep the guest contract and Chef 360 installation
workflow unchanged.
