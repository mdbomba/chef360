# Chef 360 Platform Quick-Start Project

This project contains an operator-focused quick-start guide and supporting material for deploying Chef 360 Platform 1.7.3 as a single-node, hyperconverged, non-high-availability cluster.

## Quick-Start Outcome

The quick start begins with deployment planning and Linux host preparation. It ends when the initial tenant administrator:

1. Receives the one-time password through the configured SMTP service or Mailpit.
2. Sets a permanent password.
3. Signs in to the Chef 360 Apps Console at `https://<FQDN>:31000`.
4. Confirms that the expected tenant and default organizational unit are visible.

## Deployment Scope

The guide covers:

- Chef 360 Platform 1.7.3
- Single-node, hyperconverged non-HA topology
- Online and air-gapped installation
- Linux host, storage, network, DNS, firewall, certificate, SELinux, and swap preparation
- Admin Console access on TCP `30000`
- Initial tenant, organizational unit, email, and administrator configuration
- Apps Console access on TCP `31000`

For customers retaining an existing single-node, non-HA Chef Infra availability model, this topology is the closest Chef 360 architectural match. It is not a hardware-sizing equivalence; size Chef 360 independently for its documented requirements and expected workload.

## Out of Scope

The quick start does not cover:

- Chef Workstation or Chef 360 CLI setup
- Management-device registration
- Managed-node enrollment
- Chef Courier jobs
- Chef Infra Client or Chef InSpec operations
- Chef Automate integration
- Backup and disaster recovery configuration
- Upgrades and routine operations

These subjects are planned for a separate configuration and operations companion guide tracked in `todo.md`.

## Project Files

| File | Purpose |
|---|---|
| `chef360-1.7.3-quick-start.md` | Canonical installation and initial-configuration guide |
| `checklist.md` | Condensed derivative planning, installation, and validation checklist |
| `sources.md` | Authoritative and supporting references |
| `guidance-differences.md` | Accepted additions, interpretations, and deviations from published guidance |
| `todo.md` | Completed and outstanding work for the quick start and companion guide |
| `changelog.md` | Material quick-start history |
| `maintenance.md` | Maintenance, source, tracking, security, and verification rules |
| `../../scripts/chef360/download-install-server.sh` | Supplemental online or air-gapped package download and installation helper |
| `../../scripts/ci/check-quick-start.sh` | Automated terminology, version, scope, marker, and shell-syntax checks |

## Licensing And Downloads

Chef Compliance is the managed-endpoint entitlement. A customer with an active Chef Compliance license must separately request a Chef 360 download authorization code from Progress.

The authorization code is a download credential, not a product license file. Both the online and air-gapped compressed Chef 360 packages contain the `license.yaml` associated with the authorization code. That extracted file is passed to the Chef 360 installer to license the cluster:

```bash
sudo ./chef-360 install --license license.yaml
```

Do not substitute a Chef Automate, Chef Workstation, Chef Infra Client, or other traditional Chef product license file.

Never store real authorization codes, passwords, private keys, tokens, or other credentials in this directory.

## Source And Guidance Policy

Chef 360 Platform 1.7.3 documentation listed in `sources.md` is the primary published product source. Project-specific field recommendations are identified by invisible `GUIDANCE-DIFFERENCE` markers in the guide and corresponding `GD-*` records in `guidance-differences.md`.

Review the difference register before changing guidance about operating systems, filesystems, disk layout, SELinux, swap, static addressing, certificate SANs, topology selection, or licensing fulfillment.

## Current Status

The quick-start documentation tasks are complete except for a clean-room walkthrough on a disposable Chef 360 host. That walkthrough requires suitable infrastructure, an active entitlement, a Chef 360 authorization code, and installation through successful Apps Console sign-in.

The companion configuration and operations guide has not yet been created.

## Validation

After changing the shell helper, run:

```bash
bash -n scripts/chef360/download-install-server.sh
```

After material documentation or helper-script changes, run:

```bash
bash scripts/ci/check-quick-start.sh
```

For material documentation changes:

- Verify commands, ports, paths, requirements, and behavior against `sources.md`.
- Check Admin Console and Apps Console terminology.
- Confirm that examples consistently use Chef 360 Platform 1.7.3.
- Check Markdown headings, tables, lists, links, and fenced blocks.
- Update `todo.md`, `changelog.md`, and `guidance-differences.md` when applicable.

## Start Here

Follow the task-specific context-loading order in `maintenance.md`. Use `sources.md`, `todo.md`, `guidance-differences.md`, and `changelog.md` when the task requires them rather than rereading every file for each focused edit.
