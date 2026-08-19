# Legacy Chef 360 Scripts

The numbered scripts in the repository root are retained from the original lab workflow for historical reference. They use older Chef 360 patterns, environment-specific assumptions, permissive TLS options, and generated local state.

Prefer the current reusable workflows under:

- `scripts/chef360/`
- `scripts/azure/`

Before running a legacy script:

1. Copy `chef360.vars.example` to the gitignored `chef360.vars` when required.
2. Review every endpoint, profile, cohort, node, and skill version.
3. Do not pipe remote installers into a shell without independently verifying the source.
4. Never commit generated credentials, private keys, enrollment payloads, or response files.
