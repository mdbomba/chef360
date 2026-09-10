# Chef 360 Platform 1.7.3 Quick Start Installation Guide

## Single-Node Hyperconverged (Non-HA) Deployment

**Document status:** Reconstructed working guide  
**Target release:** Chef 360 Platform 1.7.3  
**Audience:** Linux administrators, existing Chef customers, evaluators, Solutions Engineers, and Professional Services consultants

## 1. Overview

This guide provides an operator-focused procedure for installing Chef 360 Platform 1.7.3 on a single Linux server by using the integrated Replicated-based installer. It ends after the initial tenant configuration is applied and the tenant administrator signs in to the Chef 360 Apps Console at `https://<FQDN>:31000`.

The intended reader is an experienced Linux administrator who may have minimal Kubernetes experience. The integrated installer provisions and manages the embedded Kubernetes environment used by Chef 360.

### Scope

This guide covers a single-node, hyperconverged, non-high-availability deployment.

<!-- GUIDANCE-DIFFERENCE: GD-010 -->

For existing Chef Infra customers, the current Chef Infra deployment architecture strongly influences the initial Chef 360 topology selection. If the customer operates a single-node, non-HA Chef Infra environment and intends to retain that availability model, the closest matching Chef 360 topology is a single-node, hyperconverged non-HA deployment.

This is an architectural match, not a sizing equivalence. Size the Chef 360 host according to Chef 360 requirements and the expected node count, job frequency, output size, job duration, check-in frequency, and other workload characteristics.

In this deployment model:

- All Chef 360 platform services run on one Linux server.
- Embedded Kubernetes is installed and managed automatically.
- No external Kubernetes cluster is required.
- No external load balancer is required.
- No external shared storage is required.
- No high-availability components are deployed.

This deployment model is appropriate for:

- Evaluations and demonstrations
- Proofs of concept
- Lab and training environments
- Small deployments
- Initial migration testing

This guide does not cover:

- Hyperscale HA deployments
- Multi-node deployments
- High-availability deployments
- External Kubernetes deployments
- Multi-controller configurations
- Dedicated frontend or backend cluster nodes
- Chef Workstation installation or configuration
- Chef 360 CLI installation or device registration
- Registration of a management workstation or management node
- Managed-node enrollment or cohort operations
- Chef Courier job creation or execution
- Chef Automate integration
- Ongoing configuration, backup, upgrade, maintenance, or operational procedures

Those topics belong in the companion Chef 360 configuration and operations guide.

## 2. Kubernetes Knowledge Is Not Required

The Replicated-based Chef 360 integrated installer installs and manages the embedded Kubernetes environment.

For this single-node deployment, the administrator does not need to:

- Install Kubernetes separately
- Build a Kubernetes cluster
- Deploy Helm charts
- Configure Kubernetes networking
- Configure Kubernetes storage classes
- Manage Kubernetes control-plane services
- Manually expose internal Kubernetes service ports

Focus on Linux administration, networking, DNS, certificates, firewall policy, storage, and Chef 360 configuration.

> Do not modify embedded Kubernetes manifests, networking, databases, RabbitMQ configuration, or internal platform services unless directed by Progress Support.

## 3. Deployment Architecture

```text
+------------------------------------------------------+
| Single Linux Server                                  |
|                                                      |
|  Chef 360 Integrated Installer                       |
|      +-- Embedded Kubernetes                         |
|             +-- Chef 360 Platform Services           |
|                    +-- Admin Console                 |
|                    +-- Workflow Engine               |
|                    +-- Compliance Services           |
|                    +-- Asset Management              |
|                    +-- Declarative State Management  |
|                    +-- Courier                       |
|                    +-- Platform APIs                 |
+------------------------------------------------------+
```

## 4. Terminology

Throughout this guide, **Admin Console** means the Replicated Platform Services web interface installed as part of Chef 360.

**Apps Console** means the tenant-facing Chef 360 Platform web interface available after initial configuration:

```text
https://<FQDN>:31000
```

The Admin Console and Apps Console use separate credentials and serve different purposes. The Admin Console password is created by the installer. The initial Apps Console tenant administrator activates the account using the one-time password sent to the configured administrator email address.

The Admin Console is used to:

- Install custom TLS certificates
- Configure Chef 360 platform settings
- Configure tenants
- Configure email services
- Review platform health
- Apply configuration changes
- Perform upgrades and maintenance

After installation, use the Admin Console link returned by the installer. The Admin Console listens on TCP port `30000`:

```text
https://<INSTALLER-RETURNED-HOST>:30000
```

If the host in that link is inaccessible from the administrator workstation, replace only the host portion with the public FQDN. Retain the scheme, port, and path returned by the installer.

## 5. Information Required Before Starting

Gather and record the following before building the server:

- [ ] Active Chef Compliance managed-endpoint license
- [ ] Chef 360 authorization code
- [ ] Chef 360 Platform distribution download URL
- [ ] Static IP address
- [ ] Subnet prefix or subnet mask
- [ ] Default gateway
- [ ] DNS server addresses
- [ ] Short hostname
- [ ] Fully qualified domain name (FQDN)
- [ ] Server TLS certificate, if used
- [ ] Unencrypted TLS private key, if used
- [ ] CA chain file, if used
- [ ] Email decision: organization SMTP service or Mailpit
- [ ] Default organizational unit name and optional description
- [ ] Tenant administrator first name, last name, and email address
- [ ] Required firewall flows

## 6. Select the Deployment Method

| Environment | Deployment method |
|---|---|
| Internet-connected server | Online installation |
| Lab without outbound Internet access | Air-gapped installation |
| Secure enclave | Air-gapped installation |
| Restricted or disconnected environment | Air-gapped installation |

## 7. Plan Hostname, IP Address, and DNS

<!-- GUIDANCE-DIFFERENCE: GD-007 -->

Example planning values:

| Setting | Example |
|---|---|
| Short hostname | `chef360` |
| FQDN | `chef360.lab.example.com` |
| Static IP address | `192.168.1.10` |
| Prefix or subnet mask | `/24` or `255.255.255.0` |
| Default gateway | `192.168.1.1` |
| DNS server | `192.168.1.5` |

Chef 360 is a core infrastructure service. Do not rely on a DHCP-assigned address for the Chef 360 server.

## 8. Recommended Operating Systems

<!-- GUIDANCE-DIFFERENCE: GD-002, GD-003 -->

Use an operating system and release supported by the target Chef 360 release. For a new deployment, the following are recommended stable, long-lived choices:

### Ubuntu Server 24.04 LTS

- General Availability kernel family: Linux 6.8
- Standard LTS support through May 2029
- Mainstream distribution with broad Linux, container, and Kubernetes adoption

### Rocky Linux 10

- Kernel family: Linux 6.12
- Active support through May 2030
- Security support through May 2035
- Enterprise-focused RHEL-compatible distribution

These choices provide modern kernels and long support lifecycles without selecting a short-lived or newly introduced interim distribution.

### Kernel Recommendation

For new Chef 360 systems, use Linux kernel `6.1` or later whenever possible.

This is a field best-practice recommendation rather than a statement that every older kernel is unsupported. Older kernels have occasionally produced minor, non-impactful errors during field installations.

Verify the operating system and kernel:

```bash
cat /etc/os-release
uname -r
```

Before deployment, confirm that the selected operating system is supported by the Chef 360 1.7 system requirements.

## 9. Single-Node Hyperconverged Requirements

A single-node Chef 360 Platform deployment has the following documented minimum requirements. Adjust these values for workload and usage. For tailored sizing, contact your Customer Architect or Customer Success Manager.

| Resource | Minimum requirement |
|---|---:|
| vCPU | 16 |
| Memory | 32 GB |
| Storage | 200 GB |

## 10. Recommended Disk Layout

<!-- GUIDANCE-DIFFERENCE: GD-001, GD-004 -->

Use separate filesystems for `/boot`, `/`, and `/var/lib`. Allocate the majority of disk capacity to `/var/lib` because Chef 360 platform data, container images, persistent volumes, logs, and embedded Kubernetes data use this filesystem.

| Mount point | Purpose | Guidance |
|---|---|---:|
| `/boot` | Boot files | 1 GB recommended |
| `/` | Operating system and application binaries | 50 to 100 GB recommended |
| `/var/lib` | Chef 360 and embedded platform data | 200 GB minimum; 500 GB preferred |

### Example Minimum Layout

| Mount point | Example size |
|---|---:|
| `/boot` | 1 GB |
| `/` | 50 GB |
| `/var/lib` | 200 GB |

### Example Preferred Layout

| Mount point | Example size |
|---|---:|
| `/boot` | 5 GB |
| `/` | 100 GB |
| `/var/lib` | 500 GB |

The documented platform minimum is 200 GB total storage. The 200 GB minimum and 500 GB preferred figures for `/var/lib` are conservative field recommendations intended to reduce disk-pressure problems and future filesystem expansion work.

Use fast local SSD or NVMe storage when possible. For virtual machines, use fully allocated or thick-provisioned storage when practical so advertised capacity and I/O performance are available to the platform.

Verify the resulting layout:

```bash
lsblk
findmnt /boot
findmnt /
findmnt /var/lib
df -h /boot / /var/lib
```

This guide recommends ext4 for `/var/lib` on KVM-based deployments to prioritize predictable disk-I/O latency. XFS with `ftype=1` is also acceptable for the `/var/lib` partition. In either case, verify the filesystem and confirm that `/var` is not mounted with the `noexec` option:

```bash
findmnt -T /var/lib -no FSTYPE,OPTIONS
findmnt -T /var -no OPTIONS
```

If `/var/lib` uses XFS, verify `ftype=1`:

```bash
xfs_info "$(findmnt -T /var/lib -no SOURCE)" | grep 'ftype=1'
```

If `/var/lib` is not a separate mount, validate the filesystem that contains it. Do not proceed if an XFS filesystem does not report `ftype=1` or if `/var` is mounted with `noexec`.

## 11. TLS Certificate Planning

Chef 360 can operate without a custom certificate, but using a certificate issued by a trusted public or enterprise certificate authority is a security best practice.

Request the certificate before installing Chef 360 so it is available during the initial Admin Console configuration.

### Required Certificate Files

Prepare:

- Server certificate in Base64-encoded PEM format with a `.crt` extension
- Matching unencrypted private key in PEM format with a `.key` extension
- CA chain in Base64-encoded PEM format with a `.crt` extension

A CA chain file is a concatenation of the intermediate and root public certificates. Arrange the certificates in the order required by the issuing certificate authority.

Example package:

```text
chef360.lab.example.com.crt
chef360.lab.example.com.key
ca-chain.crt
```

Protect the private key according to organizational security policy.

### Subject Alternative Name Recommendations

<!-- GUIDANCE-DIFFERENCE: GD-008 -->

For a durable certificate, request these Subject Alternative Name entries whenever permitted by PKI policy:

```text
DNS:<FQDN>
DNS:<HOSTNAME>
IP:<IP-ADDRESS>
```

Example:

```text
DNS:chef360.lab.example.com
DNS:chef360
IP:192.168.1.10
```

This combination supports initial IP-based Admin Console access and later access by FQDN or short hostname.

### Validate the Certificate

Display the certificate subject, issuer, validity, and SAN entries:

```bash
openssl x509 -in chef360.lab.example.com.crt -text -noout
```

Quick SAN check:

```bash
openssl x509 -in chef360.lab.example.com.crt -noout -ext subjectAltName
```

Check the certificate expiration dates:

```bash
openssl x509 -in chef360.lab.example.com.crt -noout -dates
```

Validate the unencrypted private key:

```bash
openssl rsa -in chef360.lab.example.com.key -check -noout
```

For an EC private key, use:

```bash
openssl ec -in chef360.lab.example.com.key -check -noout
```

Confirm that the certificate and key match by comparing their public keys:

```bash
openssl x509 -in chef360.lab.example.com.crt -pubkey -noout | openssl sha256
openssl pkey -in chef360.lab.example.com.key -pubout | openssl sha256
```

The two SHA-256 values should match.

## 12. Obtain the Chef 360 Authorization Code

<!-- GUIDANCE-DIFFERENCE: GD-011 -->

Chef licensing is based on the customer's Chef Compliance managed-endpoint entitlement. An active Chef Compliance license provides the applicable entitlements to install or activate products such as Chef Automate, Chef Workstation, and Chef Infra Client, but it does not currently provide the Chef 360 download authorization code automatically.

Request a Chef 360 authorization code based on the customer's active Chef Compliance license. The authorization code is a download credential, not an existing Chef product license or license file. Do not attempt to use a Chef Automate, Chef Workstation, Chef Infra Client, or other traditional Chef license file to install Chef 360 Platform.

The online and air-gapped downloads are compressed Chef 360 distribution packages. Each downloaded package contains the `license.yaml` associated with the authorization code used for that download. The installer uses that `license.yaml` file to license the Chef 360 cluster. No additional traditional Chef product license file is passed to the Chef 360 installer.

Typical process:

1. Confirm that the customer has an active Chef Compliance managed-endpoint license.
2. Contact the assigned Progress account team or Progress Support to request Chef 360 access based on that license.
3. Obtain the Chef 360 authorization code and distribution download URL supplied by Progress.
4. Use the authorization code only to download the Chef 360 distribution package.
5. Extract and retain the package's `license.yaml` for the installation.

Treat the authorization code as sensitive:

- Do not commit it to Git or another source repository.
- Do not place it in broadly distributed documentation.
- Do not include it in support bundles.
- Avoid leaving it in shared shell-history files.

## 13. Firewall and Network Security Planning

For this quick start, Chef 360 requires network connectivity between administrators, the Chef 360 host, the configured email service, and online installation services when applicable.

Chef 360 does not require a particular firewall implementation. Customers may enforce policy with:

- Network firewalls
- Router ACLs
- Micro-segmentation platforms
- Cloud security groups or network security groups
- Host firewalls such as UFW or firewalld
- A combination of network and host controls

The important requirement is that the necessary communication paths are permitted.

### Recommended Allow List

| Source | Destination | Port | Direction from source | Purpose |
|---|---|---:|---|---|
| Approved management systems | Chef 360 | TCP 22 | Outbound | Linux administration |
| Platform administrators | Chef 360 | TCP 30000 | Outbound | Admin Console |
| Tenant administrator | Chef 360 | TCP 31000 | Outbound | Apps Console access |
| Platform administrators | Chef 360 | TCP 31101 | Outbound | Mailpit web UI, if enabled |
| Chef 360 | Organization SMTP server | Organization-defined SMTP port | Outbound | Tenant administrator OTP and platform email |
| Chef 360 | Required online installation domains | TCP 443 | Outbound | Download Chef 360 artifacts and container images |

### Online Installation Egress

For an online installation, allow the Chef 360 host to make outbound TCP `443` connections to:

- `registry.chef360.chef.io`
- `download.chef360.chef.io`
- `proxy.chef360.chef.io`
- `appservice.chef360.chef.io`
- `index.docker.io`
- `cdn.auth0.com`
- `*docker.io`
- `*docker.com`

Wildcard handling differs among firewall and proxy products. If the selected control cannot use wildcard domain rules, determine and permit the required Docker subdomains by using the organization's approved method. An air-gapped installation does not require these Internet egress flows from the Chef 360 host.

### Administrative SSH

Allow inbound TCP 22 to Chef 360 only from approved administrator workstations, jump hosts, or management networks.

Do not expose administrative SSH broadly to user or managed-node networks.

### Admin Console

Allow inbound TCP 30000 to Chef 360 from the address or address range associated with platform administrators.

Use the Admin Console link returned by the installer. If its host is inaccessible, substitute the public FQDN while retaining TCP `30000` and the returned path.

```text
https://<INSTALLER-RETURNED-HOST>:30000
```

### Apps Console

Allow inbound TCP `31000` to Chef 360 from the tenant administrator workstation. The initial Apps Console URL is `https://<FQDN>:31000`.

### Mailpit

If the optional Mailpit add-on is enabled, allow approved platform administrators to access its web UI on TCP `31101` by default. Mailpit uses HTTP rather than HTTPS and is intended only for evaluation or testing.

### Host Firewall Strategy

All of these approaches are valid:

- Enforce policy at the network firewall and disable the host firewall.
- Retain UFW or firewalld and explicitly allow required flows.
- Enforce equivalent rules at both network and host layers.

This guide defines required communication paths rather than mandating a particular firewall product or policy model.

### Internal Kubernetes Ports

Chef documentation discusses additional Kubernetes and platform-service ports. For a single-node hyperconverged non-HA deployment installed with the integrated Replicated installer, administrators normally do not need to create manual firewall rules for internal Kubernetes service communication.

Do not expose internal Kubernetes or RabbitMQ management ports merely because they appear in a general Kubernetes port list. Ports needed later for node enrollment, Chef Courier, Chef Automate, or other operational integrations belong in the companion configuration and operations guide.

Multi-node deployments have additional Kubernetes port and protocol requirements and are outside this guide's scope.

## 14. Build the Linux Server

During operating system installation:

- Configure the planned static IPv4 address.
- Configure the subnet prefix or subnet mask.
- Configure the default gateway.
- Configure DNS server addresses.
- Create or identify the administrative installation account.
- Create separate `/boot`, `/`, and `/var/lib` filesystems. This guide recommends /var/lib use XFS with `ftype=1` for `/var/lib`; ext4 is also acceptable.
- Ensure `/var` is not mounted with the `noexec` option.
- Do not configure a swap partition. Remove swap partitions from /etc/fstab.

After installation, verify the network configuration:

```bash
ip addr
ip route
```

## 15. Configure Passwordless Sudo

The account used to install Chef 360 must be able to perform privileged operations without an interactive password prompt.

The following example uses an account named `admin`:

```bash
sudo su

echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
chmod 440 /etc/sudoers.d/admin
visudo -cf /etc/sudoers.d/admin
exit
```

Replace `admin` with the actual installation account name.

Verify the configuration from that account:

```bash
sudo -n true && echo "Passwordless sudo is configured"
sudo -l
```

Confirm that passwordless sudo is permitted by organizational security policy.

## 16. Configure the System Hostname

Assign the planned FQDN:

```bash
sudo hostnamectl set-hostname chef360.lab.example.com
```

Verify:

```bash
hostname
hostname -f
hostnamectl status
```

Use a permanent FQDN that remains assigned throughout the system lifecycle.

## 17. Configure Name Resolution

Reliable name resolution is required between Chef 360 and the systems used during initial installation, including:

- Administrator workstations
- The configured SMTP service, when used
- The Internet-connected jump host for an air-gapped installation

### DNS-Enabled Environments

Register the Chef 360 FQDN in DNS and ensure the administrator workstation can resolve it.

| System | FQDN | Address |
|---|---|---:|
| Chef 360 | `chef360.lab.example.com` | `192.168.1.10` |

### Lab Environments Without DNS

If lab DNS is unavailable, populate `/etc/hosts` on every participating Linux system with the IP address, short hostname, and FQDN of each participating system.

```text
192.168.1.10 chef360 chef360.lab.example.com
```

Ensure equivalent host mappings exist on the administrator workstation when DNS is not available.

Avoid mixing inconsistent short names and FQDNs during installation, certificate validation, and initial configuration.

## 18. SELinux Recommendation

<!-- GUIDANCE-DIFFERENCE: GD-005 -->

### Recommended Configuration

For Rocky Linux deployments, this guide recommends disabling SELinux before installing Chef 360.

SELinux can be made to work with many enterprise and containerized applications, but Enforcing mode may require policy development, troubleshooting, validation, and continuing maintenance. This guide optimizes for a predictable first installation.

Verify the current mode:

```bash
getenforce
```

Expected result:

```text
Disabled
```

Temporarily enter permissive mode until reboot:

```bash
sudo setenforce 0
```

Permanently disable SELinux by editing `/etc/selinux/config` and setting:

```text
SELINUX=disabled
```

Reboot:

```bash
sudo reboot
```

Verify after reconnecting:

```bash
getenforce
```

> Contact Progress Support before attempting installation with SELinux Enforcing, SELinux Permissive as the permanent posture, or custom SELinux policies. These configurations may require additional policy work and validation.

## 19. Swap Configuration

<!-- GUIDANCE-DIFFERENCE: GD-006 -->

### Recommended Configuration

For Chef 360 deployments, this guide recommends operating with swap disabled at the host level. Do not use a swap partition or a swap file, including swap files stored on `/` or `/var/lib`.

Chef 360 deploys an embedded Kubernetes environment. Paging adds disk I/O and latency to a platform that includes container workloads, databases, messaging, and control-plane services. Disabling swap provides more predictable memory and disk-I/O behavior.

Verify active swap:

```bash
swapon --show=NAME,TYPE,SIZE,USED,PRIO
free -h
```

The required result from `swapon --show` is no output. If it lists a path such as `/swapfile` or `/var/lib/swapfile`, that filesystem is supplying active swap and the swap file must be disabled.

Temporarily disable swap:

```bash
sudo swapoff -a
```

Permanently disable swap by commenting out swap entries in `/etc/fstab`. Also check for swap units or generators managed outside `/etc/fstab`:

```bash
systemctl list-units --type=swap --all
systemctl list-unit-files --type=swap
```

Disable the underlying swap configuration according to the operating system or image-build method. Do not assume that editing `/etc/fstab` disables a separately configured systemd swap unit.

Examples:

```text
#/swapfile swap swap defaults 0 0
#/var/lib/swapfile swap swap defaults 0 0
#/dev/mapper/rl-swap swap swap defaults 0 0
```

Apply and verify:

```bash
sudo swapoff -a
swapon --show=NAME,TYPE,SIZE,USED,PRIO
free -h
```

This guide assumes sufficient physical memory is provisioned and swap is disabled.

## 20. Update the Operating System

### Ubuntu

```bash
sudo apt update && sudo apt upgrade -y
```

### Rocky Linux

```bash
sudo dnf update -y
```

If a kernel or core system component was updated, reboot:

```bash
sudo reboot
```

After reconnecting, verify the active kernel and system state:

```bash
uname -r
cat /etc/os-release
swapon --show=NAME,TYPE,SIZE,USED,PRIO
systemctl list-units --type=swap --state=active
```

Both swap commands must show no active swap. Resolve any active swap before continuing.

## 21. Validate Networking, DNS, Time, and Resources

Resolve basic host problems before introducing Chef 360.

### Confirm the Default Route

```bash
ip route
```

### Ping the Router or Default Gateway

```bash
ping -c 4 192.168.1.1
```

### Ping Another Device on the Network

```bash
ping -c 4 192.168.1.5
```

### Validate Name Resolution

```bash
ping -c 4 chef360.lab.example.com
getent hosts chef360.lab.example.com
```

If installed:

```bash
nslookup chef360.lab.example.com
dig chef360.lab.example.com
```

### Validate Time and Resources

```bash
timedatectl
nproc
free -h
lsblk
df -h
findmnt /var/lib
swapon --show=NAME,TYPE,SIZE,USED,PRIO
```

Confirm:

- System time is synchronized.
- At least 16 vCPUs are available.
- At least 32 GB of memory is available.
- `/var/lib` is mounted on the intended filesystem.
- `/var/lib` has the planned capacity.
- Swap is disabled.

### Validate Planned Firewall Rules

Before installation, confirm that firewall policy permits administrator access to TCP `30000` and `31000`, plus TCP `31101` if Mailpit will be used. The services do not listen until the applicable installation stage is complete, so active connection tests belong in final validation.

Review each rule from the source system that will use the flow. A local check on the Chef 360 host does not validate an intervening network firewall.

## 22. Pre-Installation Checklist

- [ ] Chef 360 1.7.3 supports the selected operating system
- [ ] Ubuntu Server 24.04 LTS or Rocky Linux 10 selected where appropriate
- [ ] Kernel 6.1 or later active where possible
- [ ] At least 16 vCPU available
- [ ] At least 32 GB RAM available
- [ ] Static IP address configured
- [ ] Default route and local connectivity validated
- [ ] Passwordless sudo configured for the installation account
- [ ] Permanent FQDN assigned
- [ ] DNS records or host-file entries configured
- [ ] Forward name resolution tested
- [ ] Operating system fully updated and rebooted if required
- [ ] `/boot`, `/`, and `/var/lib` filesystems verified
- [ ] `/var/lib` has at least 200 GB; 500 GB preferred
- [ ] `/var/lib` uses ext4, or XFS with `ftype=1`
- [ ] `/var` is not mounted with the `noexec` option
- [ ] Time synchronization verified
- [ ] SELinux disabled for this guide's Rocky Linux path
- [ ] Host swap disabled, with no swap partition or swap file on `/` or `/var/lib`
- [ ] No active swap remains after reboot, including systemd-managed swap units
- [ ] Firewall design reviewed and required flows approved
- [ ] Online installation permits outbound TCP 443 to all required Chef 360 and Docker domains
- [ ] Active Chef Compliance managed-endpoint license confirmed
- [ ] Chef 360 authorization code obtained
- [ ] Chef 360 Platform distribution download URL confirmed
- [ ] Custom certificate, unencrypted key, and CA chain available if used
- [ ] SMTP or Mailpit decision made
- [ ] Default organizational unit name selected
- [ ] Tenant administrator first name, last name, and email address recorded
- [ ] Internet-connected jump host with Docker available for an air-gapped installation
- [ ] Required Velero plugin images downloaded and transferred for an air-gapped installation
- [ ] Velero plugin image archives preloaded in `/var/lib/embedded-cluster/k0s/images/` for an air-gapped installation

## 23. Download Chef 360

The authorization code authenticates the download of the compressed Chef 360 distribution package. Whether the online or air-gapped option is selected, extracting the downloaded package produces the installer artifacts and the `license.yaml` associated with that authorization code. Use that extracted `license.yaml` to license the Chef 360 cluster during installation.

Do not replace this file with a license file for Chef Automate, Chef Workstation, Chef Infra Client, or another Chef product.

### Online Download

Run on the Internet-connected Chef 360 server. Replace the obfuscated value with the authorization code supplied by Progress.

```bash
curl -f "https://appservice.chef360.chef.io/embedded/chef-360/stable/1.7.3" \
  -H "Authorization: xxxxxxxxxxxxxxxx" \
  -o chef-360-1.7.3.tgz
```

Extract:

```bash
tar -xvzf chef-360-1.7.3.tgz
```

Verify:

```bash
ls -l chef-360 license.yaml
test -s license.yaml
```

Do not proceed unless the extracted `license.yaml` exists and is non-empty.

### Air-Gapped Download

Use two systems:

- An Internet-connected jump host with Docker installed, used to download the Chef 360 bundle and required container images
- The air-gapped Chef 360 host, which can receive files through the organization's approved transfer process

Run on the Internet-connected jump host:

```bash
curl -f "https://appservice.chef360.chef.io/embedded/chef-360/stable/1.7.3?airgap=true" \
  -H "Authorization: xxxxxxxxxxxxxxxx" \
  -o chef-360-1.7.3-airgap.tgz
```

Extract:

```bash
tar -xvzf chef-360-1.7.3-airgap.tgz
```

Verify:

```bash
ls -l chef-360 chef-360.airgap license.yaml
test -s license.yaml
```

Do not proceed unless the extracted `license.yaml` exists and is non-empty.

#### Download the Velero Plugin Images

Chef 360 uses Velero plugins to back up and restore PostgreSQL data and to access S3-compatible object storage. An air-gapped embedded Kubernetes cluster cannot pull these plugin images from the Internet, so preload them before installing Chef 360.

On the Internet-connected jump host, pull and save the plugin images documented for this release:

```bash
sudo docker pull --platform linux/amd64 docker.io/progressofficial/chef360:1.0.3
sudo docker save docker.io/progressofficial/chef360:1.0.3 \
  -o velero-plugin-cnpg-restore.tar

sudo docker pull --platform linux/amd64 docker.io/velero/velero-plugin-for-aws:v1.12.1
sudo docker save docker.io/velero/velero-plugin-for-aws:v1.12.1 \
  -o velero-plugin-for-aws.tar
```

Verify that the image archives were created:

```bash
ls -lh velero-plugin-cnpg-restore.tar velero-plugin-for-aws.tar
```

These image versions are documented for the current Chef 360 Platform 1.7 installation procedure. Confirm the required image versions in the documentation before installing a different Chef 360 release.

#### Transfer the Installation Files

Transfer the installer, air-gap bundle, extracted `license.yaml`, and plugin images through the organization's approved process. Example:

```bash
scp chef-360 chef-360.airgap license.yaml \
  velero-plugin-cnpg-restore.tar velero-plugin-for-aws.tar \
  admin@chef360.lab.example.com:
```

#### Preload the Velero Plugin Images

On the air-gapped Chef 360 host, create the k0s image preload directory and copy both image archives into it:

```bash
sudo mkdir -p /var/lib/embedded-cluster/k0s/images/
sudo cp velero-plugin-cnpg-restore.tar \
  /var/lib/embedded-cluster/k0s/images/
sudo cp velero-plugin-for-aws.tar \
  /var/lib/embedded-cluster/k0s/images/
```

Verify the preloaded image archives before installation:

```bash
sudo ls -lh /var/lib/embedded-cluster/k0s/images/
```

Confirm that both `velero-plugin-cnpg-restore.tar` and `velero-plugin-for-aws.tar` are present. If these images are not preloaded, Velero cannot pull its initialization images and will fail to start in the air-gapped cluster.

### Version Selection Warning

The example commands pin version `1.7.3` in the `stable` channel. Confirm the download domain, release channel, and version-specific distribution URL with the information supplied by Progress, and verify the installed version before declaring the quick start complete.

## 24. Install Chef 360

The `--license license.yaml` argument licenses the Chef 360 cluster with the file extracted from the distribution package. It does not use an existing license file from another Chef product.

### Online Installation

From the directory containing `chef-360` and `license.yaml`:

```bash
sudo ./chef-360 install --license license.yaml
```

### Air-Gapped Installation

After preloading the Velero plugin images, run the installer from the directory containing `chef-360`, `chef-360.airgap`, and `license.yaml`:

```bash
sudo ./chef-360 install \
  --license license.yaml \
  --airgap-bundle chef-360.airgap
```

Do not skip host preflight checks during a normal quick-start deployment. Resolve preflight failures rather than bypassing them.

During installation, create and confirm the Admin Console password when prompted. Store it in the organization's approved credential-management system.

Record the `Admin Console accessible at:` link returned by the installer.

## 25. Access the Admin Console

Use the complete link returned by the installer:

```text
https://<INSTALLER-RETURNED-HOST>:30000
```

If that host is inaccessible from the administrator workstation, replace only the host portion with the public FQDN. Retain the scheme, TCP port `30000`, and any path or query string returned by the installer.

Log in with the Admin Console password created during installation.

## 26. Install Custom Certificates

When prompted, select the option to install custom certificates.

Provide:

- Server certificate in Base64 PEM format (`.crt`)
- Matching unencrypted private key in PEM format (`.key`)
- CA chain file in Base64 PEM format (`.crt`)

Custom certificates are not required for Chef 360 to operate, but they are recommended as a security best practice.

After certificate installation, continue in the Admin Console.

## 27. Create the Initial Chef 360 Configuration

1. Select **Advanced Configuration**.
2. Review and accept the terms and conditions.
3. Complete the required configuration sections.
4. Review the preflight results.
5. Apply the configuration and deploy the platform services.

### Configure the Default Tenant

#### Tenant Name

Enter a name for the default tenant. Tenant names cannot contain underscores.

```text
Lab
```

#### Tenant TLD

Enter the DNS suffix reserved for the tenant.

```text
lab.example.com
```

#### Tenant Subdomain

Enter the tenant subdomain.

```text
chef360
```

#### Verify the Tenant FQDN

Confirm that the generated tenant FQDN matches the planned DNS name.

```text
chef360.lab.example.com
```

Ensure the DNS entries, certificate SAN entries, and tenant FQDN are consistent before deployment.

### Configure the Default Organizational Unit

Enter a unique, friendly name for the default organizational unit. Optionally, add a description that identifies its intended users or scope.

Example:

```text
Name: Lab
Description: Default organizational unit for the lab tenant
```

Choose the organizational unit name carefully because changing it later has operational implications.

### Configure the Tenant Administrator

Enter the initial tenant administrator's:

- First name
- Last name
- Email address

Chef 360 sends a one-time password to this email address after the initial configuration is applied. Confirm that the address is correct and can receive messages from the selected SMTP service or Mailpit.

## 28. Configure Email Services

During initial configuration, choose:

- The organization's SMTP service, or
- Mailpit for demonstrations, evaluations, training, or lab use

### Organization SMTP Service

For production use, configure the organization's supported SMTP relay or email service and validate outbound delivery.

### Mailpit

When Mailpit is selected, it is installed as part of the Chef 360 environment and provides a web interface for reviewing messages generated by Chef 360.

The default Mailpit web UI NodePort is TCP `31101`.

#### Known Issue: Admin Console Link Uses HTTPS

The Admin Console may display a Mailpit link beginning with `https://`. Chef 360 does not support HTTPS for Mailpit, so that link will not establish a connection as displayed.

Workaround:

1. Copy the Mailpit URL shown by the Admin Console.
2. Change `https://` to `http://`.
3. Retain the host and port shown by the Admin Console.
4. Open the modified URL.

```text
Incorrect: https://192.168.1.10:31101
Correct:   http://192.168.1.10:31101
```

Use Mailpit only for non-production deployment scenarios.

## 29. Apply the Initial Configuration

Before applying the configuration, verify:

- Tenant name, TLD, subdomain, and generated FQDN
- Default organizational unit name and description
- Tenant administrator first name, last name, and email address
- DNS or host-file entries
- Custom certificate, key, CA chain, and SAN coverage
- Email configuration
- Preflight results

Apply the configuration and allow Chef 360 services to initialize.

## 30. Activate the Tenant Administrator

After deployment completes:

1. Check the tenant administrator email account for the Chef 360 one-time password.
2. If Mailpit was selected, open `http://<CHEF360-IP>:31101` and locate the tenant administrator message.
3. Open the Apps Console:

   ```text
   https://<FQDN>:31000
   ```

4. Sign in using the configured tenant administrator email address and one-time password.
5. Set the permanent tenant administrator password when prompted.
6. Confirm that the Apps Console opens and displays the expected tenant and default organizational unit.

The Admin Console password created during installation is not the Apps Console tenant administrator password.

## 31. Initial Configuration Validation

From the appropriate administrator workstation, validate the services that complete this quick start:

```bash
nc -zv <CHEF360-IP> 30000
nc -zv <CHEF360-FQDN> 31000
```

If Mailpit is enabled, also validate:

```bash
nc -zv <CHEF360-IP> 31101
```

Confirm:

1. The Admin Console is reachable on TCP `30000`.
2. Platform services report a healthy state.
3. On the Admin Console **Dashboard**, locate the application's **current version** and confirm that it is exactly `1.7.3`. Record the displayed version with the installation record.
4. The configured email service delivered the one-time password.
5. The tenant administrator can sign in to `https://<FQDN>:31000`.
6. The expected tenant and default organizational unit are visible.

Node enrollment, Chef 360 CLI registration, Chef Courier jobs, Chef Automate integration, backup, upgrades, and ongoing administration are covered by the companion configuration and operations guide.

## 32. Installation Success Criteria

- [ ] Single-node hyperconverged Chef 360 deployment installed
- [ ] Admin Console reachable using the installer-returned link or public-FQDN substitution on TCP 30000
- [ ] Custom certificate installed, if used
- [ ] Tenant configuration applied
- [ ] Default organizational unit configured
- [ ] Tenant administrator created
- [ ] Email service configured
- [ ] Mailpit accessed with HTTP when selected
- [ ] Chef 360 services healthy
- [ ] Admin Console current version recorded and verified as `1.7.3`
- [ ] Tenant administrator one-time password received
- [ ] Tenant administrator permanent password set
- [ ] Apps Console reachable at `https://<FQDN>:31000`
- [ ] Tenant administrator signed in successfully
- [ ] Expected tenant and default organizational unit visible

## 33. Troubleshooting Approach

When installation problems occur:

1. Validate static IP addressing and routing.
2. Validate DNS or `/etc/hosts` entries.
3. Validate system time.
4. Validate certificate files and SAN entries.
5. Validate firewall paths from the actual source system.
6. Review installer and Admin Console preflight failures.
7. Validate `/var/lib` capacity and disk performance.
8. Confirm SELinux and swap match this guide's assumptions.
9. Contact Progress Support before modifying embedded Kubernetes or internal platform services.

### Admin Console Does Not Open

- Confirm the complete link returned by the installer.
- Confirm TCP 30000 is reachable from the administrator network.
- Verify routing and host-firewall policy.
- If the returned host is inaccessible, replace only the host portion with the public FQDN and retain the returned scheme, port, and path.

### Mailpit Link Does Not Open

Change the scheme from `https://` to `http://` and retain the host and port shown by the Admin Console.

### Tenant Administrator OTP Does Not Arrive

- Confirm that the tenant administrator email address is correct.
- If Mailpit is enabled, open `http://<CHEF360-IP>:31101` and search for the tenant administrator message.
- If an organization SMTP service is configured, verify its host, port, authentication, sender address, TLS settings, and relay policy.
- Confirm that Chef 360 can reach the SMTP service and review the Admin Console for configuration or service errors.

### Apps Console Does Not Open

- Confirm that the tenant FQDN resolves from the administrator workstation.
- Confirm that TCP `31000` is reachable from the administrator workstation.
- Open `https://<FQDN>:31000`; do not substitute the Admin Console URL on TCP `30000`.
- Confirm that initial configuration was applied and that platform services are healthy in the Admin Console.
- Verify that the certificate covers the tenant FQDN and that the issuing CA is trusted by the administrator workstation.

### FQDN Does Not Resolve

```bash
hostname -f
getent hosts chef360.lab.example.com
```

Verify DNS records or `/etc/hosts` entries on every participating system.

### Storage Problems

```bash
lsblk
findmnt /var/lib
df -h /var/lib
```

Confirm that `/var/lib` is mounted on the intended filesystem and has sufficient capacity.

### Sudo Prompts for a Password

```bash
sudo -l
sudo -n true
sudo visudo -cf /etc/sudoers.d/admin
```

Verify the username and permissions on the sudoers fragment.

## 34. Before Opening a Support Case

Collect the following system information:

```bash
uname -r
cat /etc/os-release
hostnamectl
ip addr
ip route
cat /etc/resolv.conf
getent hosts "$(hostname -f)"
lsblk
findmnt /var/lib
df -h
free -h
swapon --show=NAME,TYPE,SIZE,USED,PRIO
timedatectl
getenforce 2>/dev/null || true
```

Also collect:

- Chef 360 version information shown by the installer or Admin Console
- Installer error messages
- Preflight results
- Admin Console health screenshots
- Approximate time of failure, including timezone
- Source and destination details for failed connection tests
- Confirmation of whether the deployment is online or air-gapped

Remove or redact authorization codes, passwords, private keys, tokens, and other secrets before sharing diagnostics.

## 35. References

- [Chef 360 Platform 1.7 documentation](https://docs.chef.io/360/1.7/)
- [Chef 360 Platform installation](https://docs.chef.io/360/1.7/install/server/implicit/install/)
- [Chef 360 Platform requirements](https://docs.chef.io/360/1.7/install/server/implicit/requirements/)
- [Chef 360 Platform cluster management and topologies](https://docs.chef.io/360/1.7/admin_console/cluster_management/)
- [Chef 360 Platform Admin Console](https://docs.chef.io/360/1.7/admin_console/)
- [Chef 360 Platform tenant configuration](https://docs.chef.io/360/1.7/admin_console/configure/tenant/)
- [Chef 360 Platform Mailpit add-on](https://docs.chef.io/360/1.7/admin_console/configure/add_ons/mailpit/)
- [Chef 360 Platform initial login](https://docs.chef.io/360/1.7/chef_360_ui/login/)
- [Chef 360 Platform 1.7 release notes](https://docs.chef.io/360/1.7/release_notes/)
- [Chef documentation source repository](https://github.com/chef/chef-web-docs)

## 36. Document Notes

This guide combines published Chef 360 installation concepts with field recommendations and observed operational behavior. Field recommendations, known workarounds, and security choices should be validated against the target Chef 360 release and the customer's security and support policies before external publication.

 This document has been prepared by a Progress Solutions Architect for informational and educational purposes only. It reflects the author's understanding of the subject matter as of the date of publication and is not a product specification, statement of warranty, commitment, or legal advice. Product capabilities, requirements, and recommendations may change without notice. Customers should validate all architectural, operational, security, compliance, and deployment decisions within their own environments and in accordance with official Progress product documentation and support guidance