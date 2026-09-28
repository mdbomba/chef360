# Chef 360 1.7.3 ConfigValues and Command-Line Installation

Chef 360 accepts a Replicated KOTS `ConfigValues` document through the
installer's `--config-values` option. This permits a repeatable, noninteractive
installation after infrastructure has supplied a compatible Linux guest.

## Version Scope

The available configuration keys and their behavior vary by Chef 360 release.
The file `examples/kots-config.yaml` was exported from Chef 360 1.7.3 in an
isolated KVM lab. It is a realistic 1.7.3 snapshot, not a version-neutral schema
or a configuration guaranteed to work with another release.

For a different release, configure that release through its Admin Console and
export the generated file from **View files**, `upstream/userdata/config.yaml`.
Compare the new export with the previous version before adapting automation.

## Environment-Specific Values

Review at least these categories before using an exported file elsewhere:

- Cluster topology and namespace.
- Tenant name, organizational unit, administrator identity, and tenant FQDN.
- API gateway, RabbitMQ, and Mailpit NodePorts.
- TLS selector, certificate, private key, root chain, and validation behavior.
- API authentication and generated token values.
- Embedded or external OpenSearch selection.
- Embedded CNPG or external PostgreSQL selection and backup configuration.
- Embedded MinIO or external S3-compatible storage selection.
- SMTP or Mailpit selection.
- Audit and general-log retention.
- Feature and advanced-configuration flags.

An exported file can contain generated values, application credentials, and TLS
private keys. Protect operational exports according to the environment in which
they are valid. Do not assume that a value is reusable merely because it is
encoded.

## External S3-Compatible Storage

Chef 360 has separate application configuration areas for embedded PostgreSQL
backup, DSM cookbook storage, and centralized log storage. They can use the
same S3-compatible endpoint and credentials, but require distinct destinations.

For the KVM lab, SeaweedFS on the libvirt gateway provides the endpoint
`http://10.0.0.1:8333`. Store the active credential pair only in
`~/.secrets/seaweedfs-s3.json`; do not add it to ConfigValues examples or Git.
The Chef 360 UI validates AWS-style credentials: the access key must be at
least 20 permitted characters and the secret key must be exactly 40 permitted
characters. Permitted characters are alphanumeric characters plus `+`, `/`,
and `=`.

Create required buckets before deploying the Chef 360 configuration:

| Purpose | Admin Console area | Destination |
| --- | --- | --- |
| Embedded PostgreSQL continuous backup | Application > Config > Backup Object Storage Configuration | `s3://chef360-backups/postgresql/` |
| DSM cookbook storage | Application > Config > Managed Services > S3 Configuration | `chef360-dsm` |
| Generated logs | Application > Config > centralized log storage | `chef360-general-logs` |
| Audit logs | Application > Config > centralized log storage | `chef360-audit-logs` |

For **Backup Object Storage Configuration**, enable backup and enter the
PostgreSQL destination path, region `us-east-1`, the S3 endpoint, and the
protected access/secret pair. Save the configuration and deploy it.

For **Managed Services > Storage Type**, select S3. In **S3 Configuration**,
enter the S3 endpoint, region `us-east-1`, the protected access/secret pair,
and `chef360-dsm` as the DSM Bucket Name. This bucket must exist before the
configuration is deployed.

For the generated and audit log bucket fields, use `chef360-general-logs` and
`chef360-audit-logs` respectively. Keep these separate from PostgreSQL and DSM
storage so retention, access, and recovery can be managed independently.

This application configuration is distinct from the full Chef 360 disaster
recovery location under **Disaster Recovery > Settings & Schedule**. Use a
separate DR prefix, such as `dr/`, in `chef360-backups` for full snapshots.

## Installation

The direct command shape is:

```bash
sudo ./chef-360 install \
  --license /secure/path/license.yaml \
  --no-prompt \
  --admin-console-password "$CHEF360_ADMIN_CONSOLE_PASSWORD" \
  --config-values /secure/path/kots-config.yaml
```

The repository wrapper validates inputs, runs a preliminary host check, and then
invokes the same installer interface:

```bash
export CHEF360_ADMIN_CONSOLE_PASSWORD='use-a-local-secret-source'
sudo --preserve-env=CHEF360_ADMIN_CONSOLE_PASSWORD \
  scripts/chef360/install-server.sh \
  --installer ./chef-360 \
  --license ./license.yaml \
  --config-values knowledge-set/chef360-1.7.3/examples/kots-config.yaml
```

Use `--data-dir PATH` only when the data filesystem was deliberately designed at
a non-default location. The wrapper supports `--ignore-host-preflights` for
disposable troubleshooting labs, but bypassing preflights is not recommended.

## Validation

After installation, inspect nodes and workloads and optionally test endpoints:

```bash
sudo scripts/chef360/validate-installation.sh \
  --admin-url https://chef360.example.test:30000 \
  --tenant-url https://tenant.example.test:31000
```

The validator uses the Embedded Cluster kubeconfig and `kubectl` below the data
directory. It fails when a Chef 360 pod has a not-ready container or a supplied
endpoint cannot be reached.

## Automation Guidance

- Keep the installer workflow independent of the infrastructure provider.
- Let Terraform, cloud-init, PowerShell, Ansible, or an operator place the
  installer, license, and ConfigValues on the guest.
- Invoke the same installation script on AWS, Azure, KVM, Hyper-V, and Proxmox.
- Do not maintain independent full copies of ConfigValues for every provider.
- Do maintain a release-specific ConfigValues source and explicitly render only
  known environment substitutions.
- Treat the installer preflight as authoritative.
