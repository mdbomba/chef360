# Project TODO

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

- [ ] Create the companion guide and define its audience, prerequisites, and operational scope.
- [ ] Install Chef Workstation where required by the selected management workflow.
- [ ] Download and verify the Chef 360 Platform CLIs from **Download Centre**.
- [ ] Obtain and trust the Chef 360 root CA where required.
- [ ] Register the management computer with `chef-platform-auth-cli register-device`.
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
- [ ] Add security and credential-management guidance for CLI profiles, API tokens, enrollment keys, and administrator access.
- [ ] Run a clean-room configuration and operations walkthrough after the companion guide is drafted.
