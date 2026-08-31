# Chef 360 Platform 1.7.3 Quick-Start Checklist

Use this checklist with `chef360-1.7.3-quick-start.md` for a single-node, hyperconverged, non-HA deployment. The quick start ends after the tenant administrator signs in to the Apps Console and confirms the expected tenant and default organizational unit.

## 1. Plan the Deployment

- [ ] Confirm that a single-node, hyperconverged non-HA topology meets the availability requirements.
- [ ] Size the Chef 360 host independently of any existing Chef Infra deployment.
- [ ] Provide at least 16 vCPUs, 32 GB RAM, and 200 GB total storage.
- [ ] Select an online or air-gapped installation method.
- [ ] Record the static IP address, subnet, gateway, DNS servers, short hostname, and FQDN.
- [ ] Select the tenant name, tenant TLD, tenant subdomain, and default organizational unit name.
- [ ] Record the initial tenant administrator's first name, last name, and email address.
- [ ] Select the organization's SMTP service or Mailpit for email delivery.

<!-- GUIDANCE-DIFFERENCE: GD-010 -->

For a customer retaining an existing single-node, non-HA Chef Infra availability model, this topology is the closest Chef 360 architectural match. It is not a hardware-sizing equivalence.

The integrated installer provisions and manages the embedded Kubernetes environment. Do not separately install Kubernetes, configure Helm, or modify internal Kubernetes services for this quick start.

## 2. Confirm Licensing and Download Access

<!-- GUIDANCE-DIFFERENCE: GD-011 -->

- [ ] Confirm an active Chef Compliance managed-endpoint license.
- [ ] Request the separate Chef 360 download authorization code from Progress.
- [ ] Confirm the Chef 360 Platform distribution download URL.
- [ ] Plan to use the authorization-specific `license.yaml` extracted from the downloaded package.
- [ ] Do not substitute a Chef Automate, Chef Workstation, Chef Infra Client, or other traditional Chef product license file.
- [ ] Protect the authorization code, `license.yaml`, passwords, private keys, and other credentials.

## 3. Prepare the Linux Host

<!-- GUIDANCE-DIFFERENCE: GD-002, GD-003 -->

- [ ] Confirm that Chef 360 Platform 1.7.3 supports the selected operating system.
- [ ] Prefer Ubuntu Server 24.04 LTS or Rocky Linux 10 for a new deployment where appropriate.
- [ ] Use Linux kernel 6.1 or later where possible.
- [ ] Fully update the operating system and reboot after kernel or core system updates.
- [ ] Verify the active operating system and kernel with `cat /etc/os-release` and `uname -r`.
- [ ] Configure passwordless sudo for the installation account if organizational policy permits it.
- [ ] Assign the permanent FQDN with `hostnamectl`.
- [ ] Confirm that system time is synchronized with `timedatectl`.

## 4. Configure Storage

<!-- GUIDANCE-DIFFERENCE: GD-001, GD-004 -->

- [ ] Create separate `/boot`, `/`, and `/var/lib` filesystems.
- [ ] Allocate approximately 1 GB to `/boot`.
- [ ] Allocate 50 to 100 GB to `/`.
- [ ] Allocate at least 200 GB to `/var/lib`; 500 GB is preferred.
- [ ] Prefer ext4 for `/var/lib` on KVM; XFS with `ftype=1` is also allowed.
- [ ] Confirm that `/var` is not mounted with `noexec`.
- [ ] Prefer fast local SSD or NVMe and fully allocated storage where practical.
- [ ] Verify the layout with `lsblk`, `findmnt`, and `df -h`.

## 5. Configure Addressing and DNS

<!-- GUIDANCE-DIFFERENCE: GD-007 -->

- [ ] Configure a static server address rather than relying on a DHCP-assigned address.
- [ ] Register the Chef 360 FQDN in DNS or configure consistent host-file entries for a lab.
- [ ] Confirm the default route and local network connectivity.
- [ ] Confirm forward name resolution from the Chef 360 host and administrator workstation.
- [ ] Keep the hostname, FQDN, tenant FQDN, DNS records, and certificate names consistent.

## 6. Plan Firewall and Network Access

- [ ] Permit approved administrators to reach SSH on TCP `22`.
- [ ] Permit platform administrators to reach the Admin Console on TCP `30000`.
- [ ] Permit the tenant administrator to reach the Apps Console on TCP `31000`.
- [ ] If Mailpit is enabled, permit approved administrators to reach its HTTP UI on TCP `31101`.
- [ ] Permit Chef 360 to reach the organization-defined SMTP destination and port when SMTP is used.
- [ ] For an online installation, permit outbound TCP `443` to the required Chef 360, Auth0, and Docker domains documented in the guide.
- [ ] Validate each path from the system that will use it; a local host test does not validate an intervening firewall.
- [ ] Do not expose internal Kubernetes or RabbitMQ management ports for this single-node quick start.

Chef Automate, WinRM, managed-node enrollment, node management, and Courier network flows belong in the companion configuration and operations guide.

## 7. Prepare and Validate TLS Certificates

<!-- GUIDANCE-DIFFERENCE: GD-008 -->

- [ ] Prepare the server certificate in Base64-encoded PEM format with a `.crt` extension.
- [ ] Prepare the matching unencrypted private key in PEM format with a `.key` extension.
- [ ] Prepare the CA chain in Base64-encoded PEM format with a `.crt` extension.
- [ ] Include the FQDN, short hostname, and server IP address as SANs when PKI policy permits.
- [ ] Inspect the certificate with `openssl x509 -in <CERTIFICATE>.crt -text -noout`.
- [ ] Check SANs with `openssl x509 -in <CERTIFICATE>.crt -noout -ext subjectAltName`.
- [ ] Validate the private key and confirm that the certificate and key public-key hashes match.
- [ ] Protect the private key according to organizational security policy.

Custom certificates are recommended but are not required for Chef 360 to operate.

## 8. Configure SELinux for Rocky Linux

<!-- GUIDANCE-DIFFERENCE: GD-005 -->

- [ ] Disable SELinux for this guide's Rocky Linux quick-start path.
- [ ] Check the current state with `getenforce`.
- [ ] Set `SELINUX=disabled` in `/etc/selinux/config` and reboot.
- [ ] Confirm that `getenforce` reports `Disabled` after reboot.
- [ ] Contact Progress Support before using Enforcing, permanent Permissive, or custom-policy configurations.

## 9. Disable Swap

<!-- GUIDANCE-DIFFERENCE: GD-006 -->

- [ ] Disable all active swap with `sudo swapoff -a`.
- [ ] Remove or comment out swap entries in `/etc/fstab`.
- [ ] Check for swap units or generators managed outside `/etc/fstab`.
- [ ] Do not configure a swap partition or swap file on `/` or `/var/lib`.
- [ ] Reboot and verify that `swapon --show=NAME,TYPE,SIZE,USED,PRIO` produces no output.
- [ ] Verify that `systemctl list-units --type=swap --state=active` shows no active swap units.

## 10. Complete Pre-Installation Validation

- [ ] Confirm at least 16 vCPUs and 32 GB RAM are available.
- [ ] Confirm `/var/lib` has the planned filesystem, mount options, and capacity.
- [ ] Confirm DNS, routing, time synchronization, and required firewall policy.
- [ ] Confirm no active swap remains after reboot.
- [ ] Confirm SELinux is disabled when following the Rocky Linux path.
- [ ] Confirm the authorization code and installation method are ready.
- [ ] Confirm custom certificate files are ready if they will be used.
- [ ] Confirm the SMTP or Mailpit decision and tenant configuration values.
- [ ] Do not bypass normal installer preflight failures; resolve them before proceeding.

## 11. Download and Install

- [ ] Download the version-pinned Chef 360 Platform `1.7.3` package.
- [ ] Add `?airgap=true` to the distribution URL when the air-gapped package is required.
- [ ] Extract the package and confirm that `license.yaml` exists and is non-empty.
- [ ] For an air-gapped installation, export `docker.io/progressofficial/chef360:1.0.3` and `docker.io/velero/velero-plugin-for-aws:v1.12.1` as `.tar` archives on the Internet-connected jump host.
- [ ] Transfer and preload both Velero plugin archives in `/var/lib/embedded-cluster/k0s/images/` on the air-gapped Chef 360 host before installation.
- [ ] Run `sudo ./chef-360 install --license license.yaml` for an online installation.
- [ ] Add `--airgap-bundle chef-360.airgap` for an air-gapped installation.
- [ ] Create and securely store the Admin Console password.
- [ ] Record the complete `Admin Console accessible at:` link returned by the installer.

## 12. Configure Chef 360

- [ ] Open the complete installer-returned Admin Console link on TCP `30000`.
- [ ] If its host is inaccessible, replace only the host with the public FQDN and retain the returned scheme, port, path, and query string.
- [ ] Sign in with the Admin Console password created during installation.
- [ ] Install the custom TLS certificate, private key, and CA chain if used.
- [ ] Select **Advanced Configuration** and accept the terms and conditions.
- [ ] Configure the tenant name, TLD, subdomain, and generated FQDN.
- [ ] Configure the default organizational unit.
- [ ] Configure the initial tenant administrator.
- [ ] Configure the organization's SMTP service or Mailpit.
- [ ] Review preflight results and apply the initial configuration.

## 13. Activate and Validate the Tenant Administrator

- [ ] Retrieve the one-time password from the configured email account or Mailpit.
- [ ] If using Mailpit, access it with HTTP on TCP `31101`, not HTTPS.
- [ ] Open the Apps Console at `https://<FQDN>:31000`.
- [ ] Sign in with the tenant administrator email address and one-time password.
- [ ] Set the permanent tenant administrator password.
- [ ] Confirm that the expected tenant and default organizational unit are visible.

The Admin Console password and Apps Console tenant administrator credentials are separate.

## 14. Installation Success Criteria

- [ ] The single-node, hyperconverged Chef 360 deployment is installed.
- [ ] The Admin Console is reachable using the installer-returned link or public-FQDN substitution on TCP `30000`.
- [ ] Chef 360 services report a healthy state.
- [ ] The Admin Console Dashboard reports current version `1.7.3`; record it with the installation record.
- [ ] The configured email service delivered the tenant administrator one-time password.
- [ ] The Apps Console is reachable at `https://<FQDN>:31000`.
- [ ] The tenant administrator signed in and set a permanent password.
- [ ] The expected tenant and default organizational unit are visible.

Generating enrollment keys, creating cohorts, enrolling nodes, running Courier jobs, integrating Chef Automate, configuring backup, and performing upgrades are outside this quick start.

## 15. Support Information

- [ ] Collect operating-system, kernel, hostname, IP, route, DNS, storage, memory, swap, time, and SELinux information.
- [ ] Record the Chef 360 version, installer errors, preflight results, health status, and approximate failure time with timezone.
- [ ] Record the source and destination of failed connection tests and whether the deployment is online or air-gapped.
- [ ] Redact authorization codes, passwords, private keys, tokens, and other secrets before sharing diagnostics.
