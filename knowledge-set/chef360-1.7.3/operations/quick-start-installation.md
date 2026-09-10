# Chef 360 1.7.3 Single-Node Hyperconverged Quick Start

The current quick-start workflow installs Chef 360 Platform 1.7.3 on a single
Linux server with the integrated Replicated-based installer and ends when the
initial tenant administrator signs in to the Chef 360 Apps Console. The
Replicated installer provisions and manages the embedded Kubernetes
environment; the administrator does not install Kubernetes, deploy Helm charts,
or configure a load balancer or shared storage.

## Scope and Topology

This workflow covers a single-node, hyperconverged, non-high-availability
deployment. It does not cover multi-node or HA clusters, Chef Workstation setup,
Chef 360 CLI registration, managed-node enrollment, Chef Courier jobs, Chef
Automate integration, backup, upgrades, or routine operations.

For an existing single-node, non-HA Chef Infra customer retaining that
availability model, single-node hyperconverged non-HA is the closest Chef 360
architectural match. It is not a hardware-sizing equivalence; size Chef 360
independently for its documented requirements and expected workload.

## Terminology and Ports

- **Admin Console:** the Replicated-based installation and cluster-management
  interface on TCP `30000`.
- **Apps Console:** the tenant-facing Chef 360 Platform interface at
  `https://<FQDN>:31000`.
- **Mailpit:** optional non-production email catcher with an HTTP web
  interface on TCP `31101`.

The Admin Console password created during installation and the Apps Console
tenant administrator credentials are separate.

Permit these initial flows:

| Source | Destination | Port | Purpose |
|---|---|---:|---|
| Approved administrators | Chef 360 host | TCP 22 | Linux administration |
| Platform administrators | Chef 360 host | TCP 30000 | Admin Console |
| Tenant administrator | Chef 360 host | TCP 31000 | Apps Console |
| Platform administrators | Chef 360 host | TCP 31101 | Mailpit HTTP UI, if enabled |
| Chef 360 host | Internet services | TCP 443 | Online installation downloads |

For an online installation, permit outbound TCP `443` to
`registry.chef360.chef.io`, `download.chef360.chef.io`,
`proxy.chef360.chef.io`, `appservice.chef360.chef.io`, `index.docker.io`,
`cdn.auth0.com`, and the required `docker.io` and `docker.com` subdomains. An
air-gapped installation does not require these outbound flows from the Chef 360
host.

## Licensing and Downloads

Chef Compliance is the managed-endpoint entitlement. The Chef 360 download
authorization code is a separate download credential and is not automatically
supplied with the entitlement. Request the authorization code and distribution
URL from Progress based on an active Chef Compliance license.

Both the online and air-gapped compressed packages contain the
authorization-specific `license.yaml` used to license the Chef 360 cluster:

```bash
sudo ./chef-360 install --license license.yaml
```

Do not substitute a Chef Automate, Chef Workstation, Chef Infra Client, or
other traditional Chef product license file. Treat the authorization code as
sensitive: do not commit it, include it in support bundles, place it in shared
documentation, or leave it in shell history. The maintained helper passes the
authorization header to `curl` through standard input so it is not present in
the `curl` process arguments.

## Host Preparation

Confirm the operating system is supported by Chef 360 1.7.3. For new
deployments, prefer Ubuntu Server 24.04 LTS or Rocky Linux 10 with Linux kernel
6.1 or later. Minimum resources are 16 vCPUs, 32 GB memory, and 200 GB total
storage.

Use separate `/boot`, `/`, and `/var/lib` filesystems. Allocate 1 GB to
`/boot`, 50 to 100 GB to `/`, and at least 200 GB to `/var/lib`; 500 GB for
`/var/lib` is preferred. On KVM, prefer ext4 for `/var/lib`; XFS with `ftype=1`
is also allowed. Do not mount `/var` with the `noexec` option.

Use a static server address and a permanent RFC 1123-compliant FQDN registered
in DNS or in consistent lab host-file entries. Set and verify the hostname:

```bash
sudo hostnamectl set-hostname chef360.lab.example.com
hostname -f
```

Fully update the operating system and reboot if the kernel or core components
change:

```bash
# Ubuntu
sudo apt update && sudo apt upgrade -y

# Rocky Linux
sudo dnf update -y
```

Disable all host swap, remove or comment out persistent swap entries in
`/etc/fstab`, and check for systemd-managed swap. Both checks must show no
active swap, including after reboot:

```bash
sudo swapoff -a
swapon --show=NAME,TYPE,SIZE,USED,PRIO
systemctl list-units --type=swap --state=active
```

For the Rocky Linux path, disable SELinux before installation. Contact Progress
Support before using Enforcing, permanent Permissive, or custom-policy
configurations. Validate resources, storage, and mount options:

```bash
uname -r
nproc
free -h
lsblk
findmnt /var/lib
findmnt -T /var/lib -no FSTYPE,OPTIONS
findmnt -T /var -no OPTIONS
df -h / /var/lib
```

The installation account must run privileged operations without an interactive
sudo password prompt. Confirm this is permitted by organizational security
policy.

## TLS Certificate Planning

Custom certificates are optional but recommended. Prepare a server certificate
in Base64-encoded PEM format with a `.crt` extension, a matching unencrypted
private key in PEM format with a `.key` extension, and a CA chain in
Base64-encoded PEM format with a `.crt` extension. When PKI policy permits,
include the FQDN, short hostname, and server IP address as Subject Alternative
Names.

## Download and Install

The maintained helper `scripts/chef360/download-install-server.sh` downloads,
extracts, and validates the package in online mode, then runs the installer. In
air-gap mode it downloads and validates the package and stops so the artifacts
and required Velero plugin images can be transferred to the disconnected host.

```bash
chmod 700 download-install-server.sh
./download-install-server.sh
```

Answer `N` or press Enter for the online package, then enter the authorization
code when prompted. Do not proceed if `chef-360` or a non-empty `license.yaml`
is missing after extraction. During installation, resolve preflight failures
instead of bypassing them, create and confirm the Admin Console password,
store it in the approved credential manager, and record the complete `Admin
Console accessible at:` link returned by the installer.

### Online Installation

From the directory containing `chef-360` and `license.yaml`:

```bash
sudo ./chef-360 install --license license.yaml
```

### Air-Gapped Installation

In addition to the Chef 360 air-gap bundle, Chef 360 Platform 1.7.3 requires
these Velero plugin container images, which an air-gapped embedded cluster
cannot pull from the Internet:

| Image | Purpose |
|---|---|
| `docker.io/progressofficial/chef360:1.0.3` | PostgreSQL backup and restore plugin for Velero |
| `docker.io/velero/velero-plugin-for-aws:v1.12.1` | AWS S3 storage plugin for Velero |

Pull and save the images on an Internet-connected jump host with Docker:

```bash
sudo docker pull --platform linux/amd64 docker.io/progressofficial/chef360:1.0.3
sudo docker save docker.io/progressofficial/chef360:1.0.3 -o velero-plugin-cnpg-restore.tar

sudo docker pull --platform linux/amd64 docker.io/velero/velero-plugin-for-aws:v1.12.1
sudo docker save docker.io/velero/velero-plugin-for-aws:v1.12.1 -o velero-plugin-for-aws.tar
```

Transfer the installer, air-gap bundle, `license.yaml`, and both plugin
archives to the disconnected Chef 360 host through the approved process. Copy
the image archives into the embedded k0s image store before running the
installer:

```bash
sudo mkdir -p /var/lib/embedded-cluster/k0s/images/
sudo cp velero-plugin-cnpg-restore.tar /var/lib/embedded-cluster/k0s/images/
sudo cp velero-plugin-for-aws.tar /var/lib/embedded-cluster/k0s/images/
```

From the directory containing `chef-360`, `chef-360.airgap`, and `license.yaml`:

```bash
sudo ./chef-360 install \
  --license license.yaml \
  --airgap-bundle chef-360.airgap
```

If the Velero plugin images are not preloaded, Velero fails to start because it
cannot pull its initialization container images.

## Open the Admin Console

Use the complete link returned by the installer. It uses TCP `30000` and may
contain a required path or query string:

```text
https://<INSTALLER-RETURNED-HOST>:30000
```

If the returned host is inaccessible from the administrator workstation,
replace only the host with the public FQDN and preserve the returned scheme,
port, path, and query string. Sign in with the Admin Console password created
during installation. Install the custom certificate, private key, and CA chain
if they are being used.

## Create the Initial Configuration

In the Admin Console:

1. Select **Advanced Configuration**.
2. Review and accept the terms and conditions.
3. Configure the default tenant.
4. Configure the default organizational unit.
5. Configure the initial tenant administrator.
6. Select Mailpit for a demonstration, evaluation, training, or lab deployment.
7. Review the preflight results and apply the configuration.

Example tenant values:

```text
Tenant name:      Lab
Tenant TLD:       lab.example.com
Tenant subdomain: chef360
Generated FQDN:   chef360.lab.example.com
```

Tenant names cannot contain underscores. Ensure the generated tenant FQDN
matches DNS and the certificate SANs. Enter a unique, friendly default
organizational unit name and optional description, then the initial tenant
administrator's first name, last name, and email address. Chef 360 sends the
account-registration one-time password to that address through the configured
SMTP service or Mailpit.

## Activate the Tenant Administrator

Mailpit is intended only for non-production use. Its web UI is HTTP on TCP
`31101`:

```text
http://<CHEF360-IP>:31101
```

The Admin Console may display the Mailpit link with `https://`. Chef 360 does
not support HTTPS for Mailpit; change only the scheme to `http://`.

1. Open `http://<CHEF360-IP>:31101` from an approved administrator workstation.
2. Locate the message addressed to the tenant administrator and retrieve the
   one-time password.
3. Open the Apps Console at `https://<FQDN>:31000`.
4. Sign in with the tenant administrator email address and one-time password.
5. Set the permanent tenant administrator password when prompted.
6. Confirm the expected tenant and default organizational unit are visible.

Do not use the Admin Console password to sign in to the Apps Console.

## Validate the Installation

From an appropriate administrator workstation, test the required ports:

```bash
nc -zv <CHEF360-IP> 30000
nc -zv <CHEF360-FQDN> 31000
nc -zv <CHEF360-IP> 31101
```

Confirm that the Admin Console is reachable on TCP `30000`, Chef 360 services
report a healthy state, the Admin Console Dashboard reports current version
`1.7.3`, Mailpit received the tenant administrator message, the tenant
administrator set a permanent password, the Apps Console is reachable at
`https://<FQDN>:31000`, and the expected tenant and default organizational unit
are visible.

## Troubleshooting

- If the Admin Console does not open, verify the complete installer-returned
  link, routing, and TCP `30000`.
- If the Mailpit link does not open, use HTTP rather than HTTPS and verify TCP
  `31101`.
- If the Apps Console does not open, verify tenant FQDN resolution, certificate
  trust, initial configuration status, service health, and TCP `31000`.
- If the tenant administrator one-time password does not arrive, confirm the
  email address, check Mailpit, and verify SMTP host, port, authentication,
  sender address, TLS settings, and relay policy.

Remove or redact authorization codes, passwords, private keys, tokens, and
other secrets before sharing diagnostics.

## References

- The canonical project guide, checklist, and differences register: `docs/quick-start/`
  in this repository.
- Provider-neutral installation and validation: `docs/provider-neutral-chef360-installation.md`.
- [Chef 360 Platform 1.7 documentation](https://docs.chef.io/360/1.7/)
- [Chef 360 Platform implicit Kubernetes installation](https://docs.chef.io/360/1.7/install/server/implicit/install/)
- [Chef 360 Platform Mailpit add-on](https://docs.chef.io/360/1.7/admin_console/configure/add_ons/mailpit/)