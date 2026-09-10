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
