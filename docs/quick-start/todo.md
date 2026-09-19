# Project TODO

## Required First Step

Before starting any TODO item, fetch the remote refs and verify that the local
checkout contains the latest repository files. If the current branch is behind
or has diverged from its upstream, stop and ask the operator whether to sync
before making changes. Do not pull, rebase, merge, reset, or otherwise sync
without that approval. Preserve uncommitted local work during this check.

This project contains two documentation tracks:

- `chef360-1.7.3-quick-start.md` targets Chef 360 Platform 1.7.3 and covers a single-node, hyperconverged non-HA installation through successful tenant administrator sign-in to the Apps Console at `https://<FQDN>:31000`.
- A future companion configuration and operations guide will cover Chef Workstation, Chef 360 CLIs, management-device registration, nodes, Courier, Automate, backup, upgrades, and ongoing administration.

## Quick Start Guide

### High Priority

- [x] Add the online installation egress allowlist.
  Documented outbound TCP 443 access to the required Chef 360 and Docker domains.

### Medium Priority

- [x] Resolve the target-version mismatch.
  The guide now targets Chef 360 Platform 1.7.3 consistently and pins `1.7.3` in the example distribution URLs.

- [x] Document the Chef Infra-to-Chef 360 topology-selection rationale.
  The guide now identifies single-node, hyperconverged non-HA as the closest architectural match when a customer retains an existing single-node, non-HA Chef Infra availability model, without treating the architectures as sizing equivalents.

- [x] Add an explicit installed-version verification step.
  The final validation now requires recording the Admin Console current version and confirming that it is exactly `1.7.3`.

- [x] Clarify the Chef Compliance entitlement and Chef 360 licensing workflow.
  The guide now distinguishes the active Chef Compliance managed-endpoint license, separately requested Chef 360 download authorization code, distribution URL, and authorization-specific `license.yaml` extracted from the online or air-gapped package. Installation verifies and uses that file to license the Chef 360 cluster.

- [x] Align Admin Console access with installer output.
  The guide now uses the complete installer-returned link and substitutes the public FQDN only when its returned host is inaccessible. `GD-009` is retired.

- [x] Verify that swap remains disabled after reboot.
  Added post-reboot active-swap checks and systemd swap-unit discovery guidance.

### Low Priority

- [x] Expand the quick-start References section.
  Added direct links for installation requirements, installation, cluster topology, Admin Console, Mailpit, tenant configuration, initial login, and Chef 360 Platform 1.7 release notes.

- [x] Perform a final editorial and consistency pass.
  Checked product naming, console terminology, headings, placeholders, optional steps, version references, and cross-file consistency.

- [ ] Run a clean-room quick-start walkthrough.
  Follow the guide on a disposable single-node KVM VM through Apps Console sign-in. Record ambiguous steps, missing prerequisites, actual installer prompts, elapsed times, email delivery, and observed validation output.

## Companion Configuration and Operations Guide

- [x] Create the companion guide and define its audience, prerequisites, and operational scope.
  Added `docs/chef360-operations-assistant.md` as the canonical install-to-operations workflow.
- [ ] Install Chef Workstation where required by the selected management workflow.
- [ ] Download and verify the Chef 360 Platform CLIs from **Download Centre**.
- [ ] Obtain and trust the Chef 360 root CA where required.
- [x] Add a supported management-workstation registration workflow.
  Added `scripts/chef360/register-chef360-workstation.sh` with profile protection, CA support, explicit lab-only insecure mode, role verification, and shared parameter loading.
- [ ] Register and validate both management computers with `chef-platform-auth-cli register-device`.
- [ ] Document role and profile setup, including `node-manager` and `courier-operator`.
- [ ] Document the default `sample-node-cohort`, `sample-skill-assembly`, and node-management settings.
- [ ] Validate managed-node networks against service CIDRs `10.244.0.0/16` and `10.96.0.0/12`.
- [ ] Document Linux and Windows node prerequisites, SSH, WinRM, and enrollment methods.
- [ ] Enroll and validate the first managed node.
- [ ] Define, run, and validate the first Chef Courier job.
- [ ] Document Chef Infra Client and Chef InSpec interpreter prerequisites and workflows.
- [ ] Configure the optional Chef Automate connector, including data collector URL, API token, root CA, status, report forwarding, and InSpec profile retrieval.
- [ ] Document backup and disaster recovery configuration, schedules, retention, manual backup, and restore testing.
- [ ] Document upgrades, maintenance, health monitoring, troubleshooting, and support-data collection.
- [x] Add initial security and credential-management guidance for CLI profiles and node enrollment.
  Documented external secret storage, profile-output risks, controller-side SSH credential transfer, and node-side signed-configuration enrollment. API token and enrollment-key lifecycle details remain part of role/profile and enrollment documentation.
- [ ] Run a clean-room configuration and operations walkthrough after the companion guide is drafted.

### Next Session Priorities

- [ ] Rotate the previously displayed default Chef 360 profile credentials.
  Deregister and re-register the affected profile without capturing `get-default-profile` output.
- [ ] Register this management workstation against `https://10.0.0.7:31000` using a distinct profile.
  Prefer a trusted CA and FQDN; use `--insecure` only if the isolated lab certificate cannot yet be verified. Confirm the selected tenant, organization, and role.
- [ ] Inventory Chef 360 1.7.3 Node Management defaults.
  Record existing skills, assemblies, settings, cohorts, approval requirements, and installed package versions before creating or changing objects.
- [ ] Select or create a test cohort for a disposable Linux node.
  Reuse the platform defaults where suitable and record the setting, assembly, and cohort IDs.
- [ ] Enroll one disposable Linux node and validate its complete lifecycle.
  Verify SSH trust and reachability, enrollment submission, admission and approval when required, final `enrolled` state, Node Management Agent, Gohai, Courier Runner, and interpreters.
- [ ] Run and verify one harmless Courier job on the enrolled node.
  Use the sleep-job workflow, wait for completion, and inspect instance, run, and step status.
- [ ] Exercise the operational-assistant safeguards with live CLI requests.
  Start with read-only inventory, perform one explicitly authorized mutation, verify resulting state, and capture any CLI response-shape or parsing corrections.
- [ ] Add isolated tests for `register-chef360-workstation.sh` using a fake CLI.
  Cover existing-profile detection, overwrite behavior, CA/insecure exclusivity, argument validation, generated registration arguments, role verification, and default-profile selection.
