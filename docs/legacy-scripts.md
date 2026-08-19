# Legacy Chef 360 Scripts

The original numbered root scripts were removed after their reusable behavior
was incorporated into maintained workflows. They used older Chef 360 patterns,
environment-specific assumptions, permissive TLS options, and generated local
state.

Prefer the current reusable workflows under:

- `scripts/chef360/`
- `scripts/azure/`

Do not restore or run a legacy script without reviewing every endpoint,
profile, cohort, node, skill version, installer source, and generated artifact.
