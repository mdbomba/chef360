# Provider-Neutral Chef 360 Installation

This repository separates VM provisioning from Chef 360 installation. AWS,
Azure, KVM, Hyper-V, and Proxmox implementations should all create a Linux guest
that satisfies the same contract, then invoke the scripts in `scripts/chef360/`.

## Choose an Installation Style

Use the concise interactive entry point when a human is installing Chef 360 on
a prepared Linux host:

```bash
scripts/chef360/start-install.sh
```

Choose **traditional** to download the authorized package and configure Chef
360 through the Admin Console. Choose **recovery/repeatable** when a protected
ConfigValues export from a working installation is available. The MCP can
explain these choices, but remains read-only and does not run installation
commands.

## Inputs

Prepare these files on the target guest:

- The Chef 360 installer matching the intended release.
- A valid Chef 360 license.
- An optional `ConfigValues` file generated for the same Chef 360 release.

`knowledge-set/chef360-1.7.3/examples/kots-config.yaml` is an isolated-lab
example exported from Chef 360 1.7.3. It contains environment-specific settings
and must be reviewed before it is used in another environment.

## Traditional Installation

The package contains the authorization-specific `license.yaml`; do not commit
it or the downloaded installer. Edit the three obvious parameters near the top
of `scripts/chef360/download-install-server.sh` when needed:

```bash
VERSION="1.7.3"
AIRGAP=false
CHECK_LATEST=true
```

The helper checks the public release notes and warns when the pinned version is
not the latest documented release. It never changes the selected version
automatically. It downloads and extracts only, leaving a review point before
the installer changes the host. Set `AIRGAP=true` to obtain the air-gapped
bundle.

Optional local inputs make a traditional installation more complete:

- A matching Admin Console TLS certificate and private key.
- An Admin Console FQDN.
- A 12-or-more-character `CHEF360_ADMIN_CONSOLE_PASSWORD`.

Without ConfigValues, complete application configuration through the Admin
Console. After a successful configuration, use the Admin Console **View files**
menu to export `config.yaml`. Store that export, the entitlement-specific
license, and private TLS material securely outside Git as a recovery package.

## Recovery Or Repeatable Installation

Run the preliminary check:

```bash
sudo scripts/chef360/check-host-requirements.sh
```

Install Chef 360:

```bash
export CHEF360_ADMIN_CONSOLE_PASSWORD='set-from-a-local-secret-source'
sudo --preserve-env=CHEF360_ADMIN_CONSOLE_PASSWORD \
  scripts/chef360/install-server.sh \
  --installer /path/to/chef-360 \
  --license /path/to/license.yaml \
  --config-values /path/to/config.yaml \
  --tls-cert /path/to/chef360.crt \
  --tls-key /path/to/chef360.key \
  --hostname chef360.example.test \
  --ignore-host-preflights \
  --ignore-app-preflights
```

Validate the installation:

```bash
sudo scripts/chef360/validate-installation.sh \
  --admin-url https://chef360.example.test:30000 \
  --tenant-url https://tenant.example.test:31000
```

`install-server.sh` is noninteractive by default. It requires a 12-or-more
character password in `CHEF360_ADMIN_CONSOLE_PASSWORD` and fails rather than
prompting when the value is absent or short. Add `--interactive` for private
password/FQDN prompts and confirmation. ConfigValues and the TLS pair are each
optional; a supplied certificate requires a supplied key and vice versa.

The preflight bypasses are explicit because this lab has a reviewed
private-address DNS warning that the vendor installer treats as blocking. Run
`check-host-requirements.sh` unless there is a separately reviewed reason to
use `--skip-host-check`.

The endpoint checks allow self-signed TLS because new lab installations commonly
use it. This does not change the application's TLS configuration.

## Provisioner Integration

Terraform and other provisioners should:

1. Create the guest, storage, network rules, and DNS.
2. Place the installer inputs on the guest through an environment-appropriate
   secure delivery mechanism.
3. Invoke the provider-neutral scripts instead of embedding a second installer
   implementation.
4. Capture script exit status and preserve installation logs.
5. Return the Admin Console and tenant URLs as outputs.

Do not put AWS or Azure credentials in templates, Terraform variables files, VM
user data, or the Chef 360 ConfigValues file. Use each provider's standard
credential chain and protect Terraform state.

## Platform Notes

### AWS

Use security groups to restrict management and application ports, encrypted EBS
volumes with sufficient write performance, and IMDSv2. Public addresses are not
required when private routing and DNS provide access.

### Azure

Use NSGs to restrict management and application ports and select a managed-disk
tier that satisfies etcd latency requirements. Public IPs are optional when
private routing, Bastion, VPN, or Run Command provides access.

### KVM

Use a persistent libvirt storage pool and a bridge or routed network that
provides stable addressing and name resolution. Review host caching and thin
provisioning because host storage behavior directly affects etcd latency.

### Hyper-V

Use a Generation 2 Linux guest where supported, a stable virtual-switch/VLAN
configuration, and fixed resource allocations appropriate for the workload.
Confirm secure-boot compatibility with the selected Linux image.

### Proxmox VE

Use a maintained cloud-init template, stable bridge/VLAN configuration, and a
storage backend with predictable latency. Enable the guest agent when it is part
of the provisioning workflow, but do not make it a Chef 360 requirement.

## Version Updates

When Chef 360 changes version:

1. Obtain the installer and release documentation for the target version.
2. Perform a manual configuration in a disposable environment.
3. Export `upstream/userdata/config.yaml` from the Admin Console's **View files**
   page.
4. Compare configuration keys and defaults with the previous version.
5. Add a new versioned sample instead of silently treating a 1.7.3 export as a
   universal template.
6. Re-run host, installation, and endpoint validation on each claimed platform.
