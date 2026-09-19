# Chef 360 Operations Assistant

This repository supports the complete operator path from installing Chef 360 to
administering it through an authenticated management workstation:

1. Install and validate a Chef 360 server.
2. Install the Chef 360 CLIs and register the management workstation.
3. Create or select a node cohort and enroll managed nodes.
4. Inspect and operate Chef 360 using repository scripts, exact CLI references,
   and an interactive workspace assistant.

The knowledge MCP remains read-only. An assistant with terminal access to this
repository can run the checked-in scripts and installed CLIs on the operator's
behalf. Those are separate capabilities: MCP search supplies guidance, while
CLI execution uses the workstation's local authentication profile.

## Local Configuration

Create the ignored local parameter file on each management workstation:

```bash
cp config/chef360.parameters.example.env config/chef360.parameters.env
```

Set at least:

```bash
CHEF360_ENDPOINT=https://chef360.example.com:31000
CHEF360_PROFILE=chef360-lab
CHEF360_DEVICE_NAME=management-workstation
CHEF360_CA_FILE=/home/user/.secrets/chef360/root-ca.crt
CHEF360_INSECURE=false
CHEF360_COHORT_NAME=all-nodes
CHEF_NODE_USER=chef
```

Use `$HOME` in shell commands and per-machine absolute paths in the ignored
parameter file. Keep passwords, private keys, signed enrollment configurations,
licenses, and tokens under `$HOME/.secrets`, `$HOME/.ssh`, or another protected
external store. Do not put them in the parameter file or repository.

Repository scripts load this file automatically. Before running the direct CLI
examples in the same shell, import its simple `KEY=value` entries:

```bash
set -a
source config/chef360.parameters.env
set +a
```

## 1. Install Chef 360

For a prepared Linux server, start with:

```bash
scripts/chef360/start-install.sh
```

Use `docs/provider-neutral-chef360-installation.md` for traditional and
repeatable installation paths. Use `docs/kvm-chef360-lab.md` or
`docs/azure-two-linux-vms.md` when the repository must also provision the
infrastructure.

After installation, validate both the Admin Console and tenant endpoint:

```bash
sudo scripts/chef360/validate-installation.sh \
  --admin-url https://chef360.example.com:30000 \
  --tenant-url "$CHEF360_ENDPOINT"
```

## 2. Register the Management Workstation

Install the six Chef 360 CLIs from the server's bundled-tools endpoint when
they are not already available. The reviewed KVM workflow automates this with
`scripts/kvm/install-chef360-workstation-clis.sh`.

Register a local profile through browser authorization:

```bash
scripts/chef360/register-chef360-workstation.sh --set-default
```

Registration creates a local device profile. It does not create or grant a
tenant or organization role. Authorize the device as an existing user with the
intended tenant, organization, and role. Use a distinct profile name for each
context that must remain available locally.

For a lab with untrusted TLS, explicitly set `CHEF360_INSECURE=true` or pass
`--insecure`. Prefer `CHEF360_CA_FILE` or `--cafile` whenever the CA is
available.

## 3. Add Nodes to Node Management

A cohort associates a skill assembly and override settings with enrolled nodes.
Chef 360 1.7.3 normally creates built-in skill definitions and defaults during
platform setup. Inspect existing objects before creating replacements:

```bash
chef-node-management-cli management skill find-all-skills \
  --pagination.size 1000 --profile "$CHEF360_PROFILE"
chef-node-management-cli management assembly find-all-assemblies \
  --pagination.size 1000 --profile "$CHEF360_PROFILE"
chef-node-management-cli management setting find-all-settings \
  --pagination.size 1000 --profile "$CHEF360_PROFILE"
chef-node-management-cli management cohort find-all-cohorts \
  --pagination.size 1000 --profile "$CHEF360_PROFILE"
```

Create the named cohort only when it is absent:

```bash
scripts/chef360/create-or-get-cohort.sh \
  "$CHEF360_COHORT_NAME" <setting-id> <skill-assembly-id>
```

Enroll a reachable Linux node from the management workstation:

```bash
scripts/chef360/enroll-node-linux-cli.sh \
  node1 "$CHEF_NODE_USER" "$HOME/.ssh/id_ed25519" \
  <cohort-id> "$CHEF360_PROFILE"
```

The script checks SSH, avoids duplicate enrollment, submits the enrollment, and
prints an enrollment ID. Its temporary request contains the SSH private key and
is deleted on exit; the enrollment API necessarily receives that credential for
controller-initiated SSH enrollment. Prefer the node-side signed-configuration
flow in `scripts/azure/register-chef360-nodes.sh` when private-key transmission
to the enrollment API is not appropriate.

Check progress and inspect the resulting node:

```bash
chef-node-management-cli status get-enrollmentId-status \
  --enrollmentId <enrollment-id> --profile "$CHEF360_PROFILE"
chef-node-management-cli management node find-all-nodes \
  --pagination.size 1000 --profile "$CHEF360_PROFILE"
chef-node-management-cli status get-status \
  --nodeId <node-id> --profile "$CHEF360_PROFILE"
```

If a cohort requires approval and the node reaches `admitted`, approve the
reviewed node explicitly:

```bash
chef-node-management-cli management node approve-node \
  --nodeId <node-id> --profile "$CHEF360_PROFILE"
```

## 4. Interactive Operations

Ask the workspace assistant for an outcome and provide the target endpoint,
profile, and object identifiers when they are not already in the local
parameter file. Useful requests include:

- "Using profile `chef360-lab`, list cohorts and summarize their assemblies."
- "Show the exact options for creating a node filter; do not execute it."
- "Check enrollment status for this enrollment ID."
- "Create a Courier sleep job for this node and wait for its result."
- "Explain this CLI error and inspect related read-only status."

For an operational request, the assistant should:

1. Load the shared parameters and identify the endpoint and profile.
2. Consult `docs/chef360-cli-help/` for the installed command form and flags.
3. Run read-only list, get, or status commands to establish current state.
4. Describe the target and effect before a consequential or destructive change.
5. Execute only the requested mutation and parse JSON output where available.
6. Verify resulting state and report IDs without printing credentials.

Routine creates, updates, enrollment, approvals, job activation, and assignment
operations mutate Chef 360. Deletes, archival, credential rotation, role or
policy changes, license changes, and bulk operations warrant explicit
confirmation when the request does not already clearly authorize them.

## Command Reference

Exact local help snapshots for all installed Chef 360 CLIs are under
`docs/chef360-cli-help/`. Regenerate them after a CLI upgrade:

```bash
scripts/content/capture-chef360-cli-help.sh
```

Do not run `chef-platform-auth-cli get-default-profile` for routine inspection;
some versions print stored access and secret keys. Use `list-profile-names` and
a scoped read command such as `user-account self get-role --profile NAME`.
