# Guidance Differences

This register tracks additions, modifications, and interpretations in `chef360-1.7.3-quick-start.md` that differ from, or are more specific than, published Progress Chef guidance.

`sources.md` identifies the authoritative references. `todo.md` tracks unfinished work. This file records intentional differences so they can be reviewed, tested, and retired when appropriate.

## Status Definitions

- **Proposed:** Included for consideration but not yet accepted.
- **Under review:** Currently used or documented but awaiting a final decision.
- **Accepted:** Intentionally included in the project guide.
- **Field-tested:** Validated in a representative deployment.
- **Rejected:** Evaluated and not adopted.
- **Retired:** No longer differs from the published guidance or is no longer used.

## Difference Register

| ID | Summary | Type | Status | Guide section | Last verified |
|---|---|---|---|---|---|
| GD-001 | Prefer ext4 for `/var/lib` on KVM | Modification | Accepted; further comparative testing pending | Recommended Disk Layout | 2026-08-28 |
| GD-002 | Recommend specific Linux distributions | Addition | Accepted; support confirmation pending | Recommended Operating Systems | 2026-08-28 |
| GD-003 | Recommend Linux kernel 6.1 or later | Addition | Accepted field recommendation | Recommended Operating Systems | 2026-08-28 |
| GD-004 | Use separate `/boot`, `/`, and `/var/lib` filesystems with project-specific sizing | Addition | Accepted field recommendation | Recommended Disk Layout | 2026-08-28 |
| GD-005 | Disable SELinux for the Rocky Linux quick-start path | Modification | Accepted field recommendation | SELinux Recommendation | 2026-08-28 |
| GD-006 | Disable host swap | Addition | Accepted field recommendation | Swap Configuration | 2026-08-28 |
| GD-007 | Require a static Chef 360 server address | Addition | Accepted field recommendation | Plan Hostname, IP Address, and DNS | 2026-08-28 |
| GD-008 | Include FQDN, short hostname, and IP address in certificate SANs | Addition | Accepted field recommendation | TLS Certificate Planning | 2026-08-28 |
| GD-009 | Use IP-based Admin Console access immediately after installation | Modification | Retired | Access the Admin Console | 2026-08-28 |
| GD-010 | Map an existing single-node non-HA Chef Infra architecture to the closest Chef 360 topology | Interpretation | Accepted field recommendation | Overview | 2026-08-28 |
| GD-011 | Clarify the Chef Compliance entitlement and Chef 360 authorization-specific license artifact flow | Interpretation | Accepted field guidance | Obtain the Chef 360 Authorization Code | 2026-08-28 |

## GD-001: Prefer ext4 for `/var/lib` on KVM

- **Type:** Modification
- **Status:** Accepted; further comparative testing pending
- **Guide section:** `10. Recommended Disk Layout`
- **Published guidance:** Chef 360 Platform 1.7 specifies a mounted XFS filesystem with `ftype=1` but does not assign that filesystem to `/`, `/var/lib`, or `/boot`.
- **Project guidance:** Prefer ext4 for `/var/lib` on KVM-based deployments. XFS with `ftype=1` is also allowed for `/var/lib`.
- **Rationale:** The project prioritizes predictable disk-I/O latency for the embedded k0s environment on its KVM hypervisor.
- **Evidence:** Current KVM deployment experience. Comparative ext4 and XFS testing has not been completed.
- **Risk:** The preferred layout differs from the literal published filesystem requirement and may affect support handling.
- **Source:** https://docs.chef.io/360/1.7/install/server/implicit/requirements/
- **Owner:** Project maintainer
- **Review trigger:** KVM filesystem benchmark, Progress Support guidance, installation preflight behavior, or Chef 360 version upgrade

## GD-002: Recommend specific Linux distributions

- **Type:** Addition
- **Status:** Accepted; support confirmation pending
- **Guide section:** `8. Recommended Operating Systems`
- **Published guidance:** The reviewed Chef 360 Platform 1.7 requirements describe Linux kernel and runtime requirements but do not publish an explicit server operating-system matrix naming Ubuntu Server 24.04 LTS or Rocky Linux 10.
- **Project guidance:** Prefer Ubuntu Server 24.04 LTS or Rocky Linux 10 for new deployments.
- **Rationale:** Both are long-lived Linux distributions with modern kernels.
- **Evidence:** Distribution lifecycle information and project deployment preferences.
- **Risk:** A recommended distribution may not be included in the product's supported platform set.
- **Source:** https://docs.chef.io/360/1.7/install/server/implicit/requirements/
- **Owner:** Project maintainer
- **Review trigger:** Published platform matrix, Progress Support guidance, failed preflight check, or distribution lifecycle change

## GD-003: Recommend Linux kernel 6.1 or later

- **Type:** Addition
- **Status:** Accepted field recommendation
- **Guide section:** `8. Recommended Operating Systems`
- **Published guidance:** The implicit Kubernetes requirements state that Linux kernel 4.3 and later include the required configurations. Chef 360 skills require Linux kernel 5.4 or later.
- **Project guidance:** Use Linux kernel 6.1 or later whenever possible.
- **Rationale:** Newer long-term kernel families have produced more predictable field installations.
- **Evidence:** Observed minor, non-impactful errors on some older kernels.
- **Risk:** Readers may interpret the recommendation as a product support minimum.
- **Source:** https://docs.chef.io/360/1.7/install/server/implicit/requirements/
- **Owner:** Project maintainer
- **Review trigger:** Kernel-related installation issue, updated Chef requirements, or new long-term-support kernel

## GD-004: Use separate filesystems and project-specific sizing

- **Type:** Addition
- **Status:** Accepted field recommendation
- **Guide section:** `10. Recommended Disk Layout`
- **Published guidance:** Chef 360 documents a 200 GB total minimum and identifies `/var/lib/k0s/`, `/run/k0s/`, `/var/lib/embedded-cluster`, and `/etc/k0s/` as mount candidates when root space is restricted. It does not prescribe this project's partition sizes.
- **Project guidance:** Create separate `/boot`, `/`, and `/var/lib` filesystems; allocate 200 GB minimum and 500 GB preferred to `/var/lib`.
- **Rationale:** Isolate platform growth and reduce future filesystem expansion work.
- **Evidence:** Conservative capacity planning for images, persistent data, and logs.
- **Risk:** The layout may over-allocate storage for small evaluations or fail to account for a workload that needs more capacity.
- **Source:** https://docs.chef.io/360/1.7/system_requirements/
- **Owner:** Project maintainer
- **Review trigger:** Capacity benchmark, disk-pressure event, or changed Chef minimums

## GD-005: Disable SELinux for the Rocky Linux quick-start path

- **Type:** Modification
- **Status:** Accepted field recommendation
- **Guide section:** `18. SELinux Recommendation`
- **Published guidance:** Chef documents experimental SELinux operation on CentOS and RHEL using permissive mode, `container-selinux`, required labels, and containerd configuration. The published procedure states that Chef 360 requires permissive mode when SELinux is enabled.
- **Project guidance:** Disable SELinux for the Rocky Linux quick-start path and contact Progress Support before using enforcing, permissive, or custom-policy configurations.
- **Rationale:** Minimize policy troubleshooting during an initial installation.
- **Evidence:** Operational preference; no project comparison of disabled and permissive modes is recorded.
- **Risk:** Disabling a mandatory access control layer may conflict with organizational security policy.
- **Source:** https://docs.chef.io/360/1.7/install/server/implicit/selinux/
- **Owner:** Project maintainer
- **Review trigger:** Security review, Progress Support guidance, or successful permissive-mode validation

## GD-006: Disable host swap

- **Type:** Addition
- **Status:** Accepted field recommendation
- **Guide section:** `19. Swap Configuration`
- **Published guidance:** The reviewed Chef 360 Platform 1.7 requirements do not explicitly prescribe a swap configuration.
- **Project guidance:** Disable all host swap, including swap partitions, swap files on `/` or `/var/lib`, and systemd-managed swap units; verify that swap remains inactive after reboot.
- **Rationale:** Avoid paging latency and disk-I/O contention for embedded Kubernetes, databases, messaging, and platform services.
- **Evidence:** Kubernetes and field operational practice; project-specific benchmark pending.
- **Risk:** Memory pressure can invoke the OOM killer rather than paging, so sufficient RAM and monitoring are required.
- **Source:** https://docs.chef.io/360/1.7/install/server/implicit/requirements/
- **Owner:** Project maintainer
- **Review trigger:** Memory-pressure event, performance benchmark, or updated Chef requirements

## GD-007: Require a static server address

- **Type:** Addition
- **Status:** Accepted field recommendation
- **Guide section:** `7. Plan Hostname, IP Address, and DNS`
- **Published guidance:** Chef requires an RFC 1123-compliant FQDN registered in DNS. The reviewed requirement does not explicitly require static IP configuration.
- **Project guidance:** Do not rely on a DHCP-assigned address for the Chef 360 server.
- **Rationale:** Keep DNS, certificates, firewall rules, node enrollment, and administrative access stable.
- **Evidence:** Standard infrastructure service practice.
- **Risk:** Environments using stable DHCP reservations may satisfy the operational objective but be excluded by the wording.
- **Source:** https://docs.chef.io/360/1.7/system_requirements/
- **Owner:** Project maintainer
- **Review trigger:** Network architecture review or deployment in an environment using reserved DHCP

## GD-008: Expand certificate SAN coverage

- **Type:** Addition
- **Status:** Accepted field recommendation
- **Guide section:** `11. TLS Certificate Planning`
- **Published guidance:** The reviewed installation guidance supports system-generated and custom certificates but does not prescribe this SAN combination.
- **Project guidance:** Include the FQDN, short hostname, and server IP address as SANs whenever PKI policy permits.
- **Rationale:** Support initial IP access and later hostname-based access without certificate-name errors.
- **Evidence:** Certificate validation and operational-access requirements.
- **Risk:** Enterprise PKI policy may reject short-name or IP SAN requests.
- **Source:** https://docs.chef.io/360/1.7/install/server/implicit/install/
- **Owner:** Project maintainer
- **Review trigger:** PKI review, Admin Console access change, or certificate renewal

## GD-009: Use IP-based Admin Console access after installation

- **Type:** Modification
- **Status:** Retired
- **Guide section:** `25. Access the Admin Console`
- **Published guidance:** Use the link returned by the installer. If the address in that link is inaccessible, replace it with the public FQDN.
- **Project guidance:** The former procedure required IP-based access on TCP 30000 immediately after installation.
- **Rationale:** The current project workflow uses direct access before final tenant DNS configuration.
- **Evidence:** Existing project procedure and companion shell-script notes.
- **Risk:** IP access can cause routing or certificate-name problems and may not match the installer-returned endpoint.
- **Source:** https://docs.chef.io/360/1.7/install/server/implicit/install/
- **Owner:** Project maintainer
- **Resolution:** The guide now follows published guidance: use the complete installer-returned link and substitute the public FQDN only when the returned host is inaccessible.
- **Review trigger:** Installer link behavior change

## GD-010: Map a single-node non-HA Chef Infra architecture to Chef 360

- **Type:** Interpretation
- **Status:** Accepted field recommendation
- **Guide section:** `1. Overview`
- **Published guidance:** Select a Chef 360 topology based on availability and scalability requirements. Published Chef 360 guidance identifies hyperconverged non-HA as the single-node topology but does not explicitly map existing Chef Infra deployment architectures to Chef 360 topologies.
- **Project guidance:** When a customer operates a single-node, non-HA Chef Infra environment and intends to retain that availability model, use a single-node, hyperconverged non-HA Chef 360 deployment as the closest architectural match.
- **Rationale:** Existing architecture and availability expectations strongly influence the appropriate starting topology for a Chef Infra customer moving to Chef 360.
- **Evidence:** Field migration-planning practice and the published Chef 360 topology characteristics.
- **Risk:** Readers may incorrectly assume that matching the topology also preserves capacity or hardware sizing. Chef 360 must be sized independently for its documented requirements and expected workload.
- **Source:** https://docs.chef.io/360/1.7/admin_console/cluster_management/
- **Owner:** Project maintainer
- **Review trigger:** Published migration-topology guidance, workload benchmark, availability-requirement change, or Progress Architect recommendation

## GD-011: Clarify Chef 360 entitlement and license artifacts

- **Type:** Interpretation
- **Status:** Accepted field guidance
- **Guide section:** `12. Obtain the Chef 360 Authorization Code`
- **Published guidance:** The Chef 360 installation page lists a Chef 360 authorization code, Chef 360 license, and distribution download URL as separate prerequisites, and the installation command consumes `license.yaml`. It does not explain the commercial Chef Compliance managed-endpoint entitlement or how the downloaded package's `license.yaml` relates to the authorization code.
- **Project guidance:** Confirm an active Chef Compliance managed-endpoint license, separately request the Chef 360 download authorization code based on that license, and use the code to download the online or air-gapped compressed package. The package contains the authorization-specific `license.yaml`, which is the only license file passed to the Chef 360 installer. Existing Chef Automate, Chef Workstation, Chef Infra Client, or other traditional Chef product license files do not license the Chef 360 cluster.
- **Rationale:** Distinguish the commercial entitlement, download credential, distribution location, and installer license artifact so operators do not use an unrelated Chef license file or assume that Chef 360 download access is automatic.
- **Evidence:** Project maintainer licensing-process clarification and observed distribution-package contents.
- **Risk:** Commercial entitlement and fulfillment processes can change independently of product documentation.
- **Source:** https://docs.chef.io/360/1.7/install/server/implicit/install/
- **Owner:** Project maintainer
- **Review trigger:** Progress licensing-process change, revised download fulfillment, changed distribution-package contents, or updated published prerequisites

## Review Process

Review this register when any of the following occurs:

- The target Chef 360 Platform release changes.
- A cited documentation page changes materially.
- Progress Support provides guidance related to a registered difference.
- A clean-room installation or benchmark produces new evidence.
- A difference causes an installation, support, security, or operational issue.

When a difference is removed from the guide, mark it **Retired** and retain the record for historical context.
