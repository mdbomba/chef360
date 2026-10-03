# Chef 360 CLI Help Snapshots

This directory preserves the command hierarchy, flags, and built-in examples
reported by the Chef 360 CLIs installed on the management workstation. The
snapshots make the exact command forms searchable without requiring each CLI to
be installed or querying a Chef 360 server.

Regenerate all snapshots from the repository root after installing or upgrading
the CLIs:

```bash
scripts/content/capture-chef360-cli-help.sh
```

The generator recursively runs only local `version` and `--help` operations. It
does not inspect authentication profiles, contact the configured Chef 360
endpoint, or perform mutations. Generic `completion` and `help` subtrees are
omitted, and private-key delimiters in vendor-provided examples are redacted.

The snapshots describe the locally installed CLI builds and may differ from
other Chef 360 Platform releases. Check the captured version at the start of
each file and regenerate rather than assuming a command is unchanged.

## Which CLI Answers What

`chef-platform-auth-cli` and `chef-node-management-cli` answer different
questions and are not interchangeable. Choose the CLI by the object being
asked about, not by which one seems related to "Chef 360" broadly.

| Question | CLI | Example read-only command |
|---|---|---|
| Is this workstation registered? | Platform Auth | `chef-platform-auth-cli list-profile-names` |
| Which org, tenant, and role am I using? | Platform Auth | `chef-platform-auth-cli system organization my-organization` |
| What role does this profile carry? | Platform Auth | `chef-platform-auth-cli user-account self get-role --profile NAME` |
| Which nodes are enrolled? | Node Management | `chef-node-management-cli management node find-all-nodes --profile NAME` |
| What happened to this enrollment? | Node Management | `chef-node-management-cli status get-enrollmentId-status --enrollmentId ID` |
| Which cohorts exist? | Node Management | `chef-node-management-cli management cohort find-all-cohorts --profile NAME` |

Platform Auth describes the **local device and the authenticated identity**.
Node Management describes **managed nodes and the objects that govern them**.
A registered workstation is not an enrolled node, and an enrolled node is not
an authenticated identity. Never run a Node Management command to answer a
Platform Auth question, or the reverse.

## Ordering

After Chef 360 is stood up and the CLIs are installed, **Platform Auth comes
first**. Registration of the management workstation must succeed before any
Node Management work, because every Node Management command authenticates
through that device profile. See `docs/chef360-operations-assistant.md` for the
full lifecycle.

## Included CLIs

- `chef-platform-auth-cli`: authentication, authorization, accounts, tenants,
  organizations, licensing, notifications, and logs
- `chef-node-management-cli`: enrollment, nodes, cohorts, skills, settings,
  assemblies, filters, lists, and enrollment status
- `chef-courier-cli`: job scheduling, exceptions, instances, runs, and results
- `chef-node-enrollment-cli`: node-side signed-configuration enrollment
- `chef-dsm-cli`: Declarative State Management objects and search
- `chef-import-cli`: DSM import-process creation, tracking, and completion

## Credential Safety

Two command forms must not be used for routine verification or diagnostic
collection, on either CLI:

- **`get-default-profile`** prints the stored access and secret keys in
  plaintext. Use `list-profile-names` to enumerate profiles, and a scoped read
  such as `user-account self get-role --profile NAME` to verify one.
  `scripts/chef360/register-chef360-workstation.sh` uses that scoped read.
- **Any command with `--verbose` / `-v`** enables debug logging that can
  include request and response payloads. Note the asymmetry:
  `chef-node-management-cli` accepts `-v/--verbose` globally, so it applies to
  any subcommand, while `chef-platform-auth-cli` exposes it only per
  subcommand. No checked-in script uses it.

Do not capture or paste either output into documentation, issue text, or a
transcript. Once credentials have been emitted they cannot be withdrawn from a
record that already exists, so rotation is the only remaining remedy.

The `--help` output of these commands is safe and is included in the snapshots.
`scripts/content/capture-chef360-cli-help.sh` never invokes `get-default-profile`,
which is why these references are safe to commit.
