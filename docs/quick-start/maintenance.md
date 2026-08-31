# Quick-Start Maintenance

Use these rules when maintaining the Chef 360 Platform quick-start content.

## Context Loading

Load only the context needed for the task:

1. Read the relevant scope and file-map sections of `README.md`.
2. Read the target file before changing it. For a focused change, read the affected section and enough surrounding context to understand it. Read the complete target for broad reviews, restructuring, or changes that affect multiple sections.
3. Read `sources.md` when verifying product requirements, commands, ports, paths, prerequisites, or behavior.
4. Read `todo.md` for planning, status, scope-boundary, or companion-guide work.
5. Read the relevant `GD-*` entries in `guidance-differences.md` before changing project-specific recommendations. Read the full register for broad guidance reviews.
6. Read `changelog.md` before adding a material history entry.

Do not reread every quick-start file for a small, isolated edit when the relevant context is already clear.

## Source Hierarchy

- Use the versioned Chef 360 Platform 1.7.3 documentation identified in `sources.md` as the primary published product source.
- Prefer the checked-in `../../knowledge-set/chef360-1.7.3/` content for local search and retrieval.
- Use other product sources only when their products or tools are relevant.
- Inspect the Chef web documentation repository only when source-level detail is needed.
- Treat local shell scripts, field notes, and Chef CFT assets as supplemental implementation evidence, not authoritative product documentation.
- Do not infer support status from underlying k0s, Kubernetes, Linux, or third-party documentation when Chef 360 guidance is available.

Chef CFT assets, including BYOK examples, may target older releases or contain unsupported workarounds. Do not treat them as published support guidance.

## Scope and Terminology

- The quick start covers a single-node, hyperconverged non-HA deployment through successful tenant administrator sign-in to the Apps Console and validation of the initial tenant and organizational unit.
- The Admin Console is the Replicated-based installation and cluster-management interface on TCP `30000`.
- The Apps Console is the tenant-facing interface at `https://<FQDN>:31000`.
- Chef Workstation, Chef 360 CLI registration, managed-node enrollment, Courier, Automate, backup, upgrades, and routine operations belong in the planned companion guide.

## Canonical Content

- `chef360-1.7.3-quick-start.md` is the canonical quick-start procedure.
- `chef360-1.7.3-exportable-quick-start.md` is a self-contained derivative for distribution and embeds the maintained helper script.
- `Chef_360_Platform_1.7.3_Quick_Start.pdf` is the customer-facing export generated from the self-contained derivative.
- `checklist.md` is a condensed derivative of the canonical guide.
- `../../scripts/chef360/download-install-server.sh` is a supplemental implementation helper.
- `guidance-differences.md` is the canonical register of intentional additions, interpretations, and deviations.
- `changelog.md` records history and is not a source of current guidance.

## Tracking and Security

- Add or update a `GD-*` record when project guidance adds to, interprets, or modifies published guidance.
- Add an invisible `<!-- GUIDANCE-DIFFERENCE: GD-### -->` marker to affected guide and checklist sections.
- Update `changelog.md` for material content, scope, command, requirement, or workflow changes.
- Update `todo.md` when work is completed, added, deferred, or moved between guides.
- Keep `sources.md` current when a new authoritative source is used.
- Never store authorization codes, license secrets, passwords, tokens, enrollment keys, private keys, protected Chef CFT data, or customer-specific exports in the repository.
- Use obvious placeholders and redact secrets from diagnostics and support material.

## Verification

Run from the repository root after material quick-start documentation or helper changes:

```bash
bash scripts/ci/check-quick-start.sh
```

The verifier confirms that the script embedded in the export exactly matches `../../scripts/chef360/download-install-server.sh`. Verify commands, ports, paths, prerequisites, and product behavior against `sources.md`. Confirm that Markdown structure and internal references remain valid.

Rebuild the PDF with `../../scripts/content/build-quick-start-pdf.py` after changing the export or `customer-pdf.css`. Use the pinned packages in `../../scripts/content/requirements-quick-start-pdf.txt`.
