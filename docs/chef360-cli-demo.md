# Chef 360 CLI Demo Scripts

This project includes CLI-first demo scripts in `scripts/chef360/` that are structured for repeatable use.

## Scripts

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
- Authenticated Chef 360 CLI profile (default profile by default).
- Installed CLIs in PATH:
  - `chef-node-management-cli`
  - `chef-courier-cli`
  - `jq`
- For enrollment script: SSH access to target nodes.

## Quick Demo Flow

1) Create or get cohort (`all-nodes`):

```bash
scripts/chef360/create-or-get-cohort.sh all-nodes <setting-id> <skill-assembly-id>
```

Copy the printed `COHORT_ID`.

2) Enroll node(s):

```bash
scripts/chef360/enroll-node-linux-cli.sh node1 chef "$HOME/.ssh/id_ed25519" <cohort-id>
scripts/chef360/enroll-node-linux-cli.sh node2 chef "$HOME/.ssh/id_ed25519" <cohort-id>
```

3) Create/run demo job against a node ID:

```bash
scripts/chef360/run-demo-job-sleep.sh <node-id> chef360-demo-sleep 10
```

4) Watch job state:

```bash
scripts/chef360/job-status.sh <job-id>
```

## Notes

- Scripts intentionally emit parse-friendly output (`KEY=value`) for easy chaining.
- Use `CHEF360_PARAMETERS_FILE=<path>` to select another shared parameter file.
- Explicit environment variables and command-line arguments override shared parameters.
