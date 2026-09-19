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

Do not capture `get-default-profile` output. Some CLI builds print stored access
and secret keys in plaintext. Its `--help` output is safe and is included, but
the command itself should not be used for routine profile verification or
diagnostic collection.
