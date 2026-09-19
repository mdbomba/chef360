# Chef 360 CLI Operations

This project includes CLI-first scripts in `scripts/chef360/` that are
structured for repeatable operations. See
`docs/chef360-operations-assistant.md` for the complete installation,
workstation registration, node enrollment, and assisted-operations lifecycle.

## Scripts

- `scripts/chef360/register-chef360-workstation.sh`
  - Registers the management workstation through interactive browser authorization.
  - Creates a named local Chef 360 CLI profile and verifies its active role.
  - Supports a trusted CA file and requires explicit opt-in for insecure lab TLS.

- `scripts/chef360/create-or-get-cohort.sh`
  - Looks up a cohort by name.
  - Creates it when missing (requires `settingId` and `skillAssemblyId`).
  - Prints `COHORT_ID=...` for reuse.

- `scripts/chef360/enroll-node-linux-cli.sh`
  - Enrolls a Linux node using `chef-node-management-cli enrollment enroll-node`.
  - Uses SSH key auth and cohort ID.
  - Prints `ENROLLMENT_ID=...`.

- `scripts/chef360/run-demo-job-sleep.sh`
  - Creates a simple Courier job using `chef-platform/shell-interpreter` that runs `sleep`.
  - If job name already exists, activates the existing job.
  - Prints `JOB_ID=...`.

- `scripts/chef360/job-status.sh`
  - Polls job status until success/failure.
  - Prints instance/run IDs and step statuses.

## Prerequisites

- Copy `config/chef360.parameters.example.env` to
  `config/chef360.parameters.env` and set the provider, Chef 360 HTTPS endpoint,
  profile, cohort, and node defaults.
- An existing Chef 360 user and role authorized for the intended tenant and
  organization. Workstation registration does not create or grant roles.
- Installed CLIs in PATH:
  - `chef-platform-auth-cli`
  - `chef-node-management-cli`
  - `chef-courier-cli`
  - `jq`
- For enrollment script: SSH access to target nodes.

## Quick Demo Flow

1. Register this management workstation and verify the selected role:

```bash
scripts/chef360/register-chef360-workstation.sh \
  --endpoint https://chef360.example.com:31000 \
  --profile chef360-lab \
  --device-name "$(hostname -s)" \
  --cafile "$HOME/.secrets/chef360/root-ca.crt" \
  --set-default
```

The command displays a URL and device code. Complete authorization in the
browser as the intended user. Use `--insecure` instead of `--cafile` only for a
controlled lab, and use `--overwrite` only when intentionally replacing an
existing local profile.

2. Create or get cohort (`all-nodes`):

```bash
scripts/chef360/create-or-get-cohort.sh all-nodes <setting-id> <skill-assembly-id>
```

Copy the printed `COHORT_ID`.

3. Enroll node(s):

```bash
scripts/chef360/enroll-node-linux-cli.sh node1 chef "$HOME/.ssh/id_ed25519" <cohort-id>
scripts/chef360/enroll-node-linux-cli.sh node2 chef "$HOME/.ssh/id_ed25519" <cohort-id>
```

4. Create/run demo job against a node ID:

```bash
scripts/chef360/run-demo-job-sleep.sh <node-id> chef360-demo-sleep 10
```

5. Watch job state:

```bash
scripts/chef360/job-status.sh <job-id>
```

## Notes

- Scripts intentionally emit parse-friendly output (`KEY=value`) for easy chaining.
- Use `CHEF360_PARAMETERS_FILE=<path>` to select another shared parameter file.
- Explicit environment variables and command-line arguments override shared parameters.
- Do not use `chef-platform-auth-cli get-default-profile` for routine checks;
  some builds print stored profile credentials. Use `list-profile-names` and a
  scoped read operation such as `user-account self get-role --profile NAME`.
