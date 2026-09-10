# Changelog

This file records material changes to the Chef 360 quick-start project. It does not replace `guidance-differences.md`, which explains how and why project guidance differs from published guidance.

## 2026-08-31

### Added

- Migrated the public-safe quick-start documentation and helper into the Chef 360 project of record under `docs/quick-start/` and `scripts/`.
- Added repository CI coverage for quick-start consistency checks.
- Added a self-contained exportable quick-start guide with the maintained download and installation script embedded and Mailpit account activation through Apps Console sign-in.
- Added a styled customer-facing PDF, print stylesheet, and reproducible PDF build script.

### Changed

- Added an interactive air-gap package selection to the download helper.
- Reworked `CHECKLIST.md` as a Chef 360 Platform 1.7.3 quick-start checklist aligned with the current scope, terminology, accepted field guidance, installation methods, and success criteria.
- Added task-specific context loading, a local-first research order, scoped source groups, canonical-content roles, and `verify-project.sh` consistency checks.
- Updated the helper to pass `--airgap-bundle chef-360.airgap` when the air-gapped package is selected and aligned its storage comment with the ext4-on-KVM preference.
- Updated the helper so online mode installs on the Chef 360 host while air-gap mode validates staged artifacts and stops for required transfer and image-preload steps.
- Passed the authorization header to `curl` through standard input so the authorization code is not exposed in process arguments.
- Expanded the exportable guide and customer PDF with the complete air-gapped Velero plugin workflow: pull, save, transfer, preload, verify, and install.

> Entries before this repository migration retain the filenames used by the original standalone documentation project.

## 2026-08-28

### Added

- Created `README.md` with the project purpose, deployment scope, file map, licensing flow, source policy, status, and validation workflow.
- Created `AGENTS.md` with persistent project scope, source hierarchy, terminology, editing, tracking, security, and verification instructions for future OpenCode sessions.
- Created `SOURCES.md` with authoritative Chef 360 Platform, Chef Workstation, Chef Automate, Chef Infra Client, Chef Habitat, and documentation-source references.
- Added direct Chef 360 Platform references for implicit Kubernetes requirements, installation, and disaster recovery.
- Created `TODO.md` to track unresolved accuracy, sufficiency, testing, and editorial work.
- Created `GUIDANCE_DIFFERENCES.md` to register project additions, modifications, interpretations, evidence, risk, ownership, and review triggers.
- Added an air-gapped installation workflow using a Docker-equipped jump host.
- Added documented Velero plugin image download, export, transfer, and preload steps for air-gapped installations.
- Added explicit network flows for the Admin Console, API gateway, RabbitMQ, Mailpit, SSH, WinRM, and Chef Automate.
- Added filesystem-layout, mount-option, disk-capacity, and KVM storage recommendations.
- Added host-level swap disablement, `/etc/fstab` examples, and detailed verification commands.
- Added certificate SAN and certificate/private-key validation guidance.
- Added SELinux, operating-system update, reboot, first-day validation, troubleshooting, support collection, and installation success criteria.

### Changed

- Clarified that the quick-start scope ends after initial configuration and successful tenant administrator sign-in to the Apps Console at `https://<FQDN>:31000`.
- Distinguished the Replicated-based Admin Console on TCP 30000 from the tenant-facing Apps Console on TCP 31000.
- Added default organizational unit, tenant administrator, one-time password activation, and Apps Console validation steps.
- Removed node enrollment, Chef Courier execution, compliance scanning, Chef Automate integration, backup planning, Chef Workstation, and Chef 360 CLI registration from the quick-start completion criteria.
- Reorganized `TODO.md` into quick-start work and companion configuration-and-operations work.
- Corrected RabbitMQ connectivity from TCP 5671 to the Chef 360 Platform default TCP 31050.
- Standardized the optional email-testing add-on as Mailpit and documented its default HTTP NodePort 31101.
- Updated `/var/lib` project guidance to prefer ext4 on KVM while allowing XFS with `ftype=1`.
- Clarified that the Replicated-based installer manages the embedded Kubernetes environment.
- Corrected companion script examples for `NOPASSWD`, `apt`, `hostnamectl set-hostname`, sudoers permissions, and Declarative State Management terminology.
- Standardized swap checks as `swapon --show=NAME,TYPE,SIZE,USED,PRIO`.
- Updated the quick-start target from Chef 360 Platform 1.7.2 to 1.7.3 and pinned 1.7.3 in the example distribution URLs.
- Aligned Section 1 topology and role terminology with the published Chef 360 Platform names and clarified that no external load balancer or shared storage is required.
- Added the project topology-selection rule that maps an existing single-node, non-HA Chef Infra environment to the closest Chef 360 topology while requiring independent Chef 360 capacity sizing.
- Synchronized all project files with the Chef 360 Platform 1.7.3 target and single-node, hyperconverged non-HA scope.
- Pinned the online helper script to Chef 360 Platform 1.7.3, protected authorization-code input from terminal display, and corrected Mailpit terminology.
- Expanded authoritative source and guide reference links for topology selection, tenant configuration, initial login, the Admin Console, and release notes.
- Clarified that Chef Compliance is the managed-endpoint entitlement, while the Chef 360 download authorization code must be requested separately based on an active Chef Compliance license.
- Documented that both online and air-gapped packages contain the authorization-specific `license.yaml` used to license the Chef 360 cluster and that traditional Chef product license files must not be substituted.
- Added non-empty `license.yaml` verification before installation in the guide and online helper script.
- Added the required online-installation outbound TCP 443 domain allowlist.
- Aligned Admin Console access with the installer-returned link and retired the IP-first `GD-009` procedure.
- Added explicit Admin Console current-version verification for Chef 360 Platform 1.7.3.
- Added post-reboot and systemd-managed swap verification to the host preparation workflow.
- Completed the quick-start editorial and cross-file consistency pass; clean-room testing remains outstanding.

### Verified

- Verified the Chef 360 online and air-gapped installer commands against the Chef 360 Platform 1.7 documentation.
- Verified the documented service ports and Mailpit behavior.
- Verified `chef360-download-install-sharable.sh` with `bash -n` after edits.

### Outstanding

- See `todo.md` for the remaining quick-start work and the planned companion configuration and operations guide.
