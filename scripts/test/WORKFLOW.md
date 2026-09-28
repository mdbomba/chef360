# Chef 360 Restore Test Workflow

## Snapshot Rules

- Store every exported configuration as `config-YYYY-MM-DD[-HHMM].yaml`.
- Pair every snapshot with `config-YYYY-MM-DD[-HHMM].metadata.yaml` using the
  same timestamp.
- Snapshots are immutable. Never overwrite or rename an existing snapshot.
- Record the Chef 360 version, source host, storage design, deployment status,
  and validation results in the metadata file when they are known.

## Active Configuration

`config.yaml` is a relative symlink to the snapshot selected for installation.
`install.sh` continues to consume `/opt/chef360/config.yaml` without change.

To promote a verified snapshot, repoint the symlink only after review and
validation. Preserve the prior snapshot and metadata file.

## Sensitive Local Assets

The installer, license, TLS material, and local test scripts remain ignored.
Keep active credentials outside this repository, under `~/.secrets` with
owner-only permissions. Do not put new secret values in metadata files.

## Restore Validation

After an installation or restore, record its result in the selected snapshot's
metadata file. Validate workload readiness, Admin Console access, tenant access,
and the configured backup-storage path before setting `status: known-good`.
