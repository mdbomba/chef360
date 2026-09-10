# KVM Lab Deployment for Chef 360 1.7.3

Use the repository's KVM workflow to provision a private, single-node Chef 360
1.7.3 lab on libvirt. The implementation is a tested provider adapter for the
same Linux guest and installation contract used by other platforms.

## Reviewed Lab Shape

- Ubuntu Server 24.04 guest on a private libvirt NAT network.
- 16 vCPUs, 2048 relative CPU shares, and 32 GiB RAM.
- 50 GiB ext4 operating-system disk.
- Separate 250 GiB XFS data disk mounted at
  `/var/lib/embedded-cluster`, with `ftype=1`.
- Swap disabled.
- Stable FQDN and address, with local host mappings where private DNS is absent.
- OpenSSH and QEMU guest agent enabled.
- Host public SSH key installed in the guest; the private key remains on the
  Workstation host.

## Phased Workflow

The KVM scripts default to dry-run for mutating operations. Provision only
through the pre-Chef review checkpoint with:

```bash
scripts/kvm/deploy-chef360-checkpoint.sh --execute
```

This prepares Ubuntu, validates the VM, installs CA trust, and stages the
installer, license, ConfigValues, and TLS files. It does not run the Chef 360
installer.

After operator review:

```bash
scripts/kvm/install-chef360.sh --execute
scripts/kvm/validate-chef360-deployment.sh --execute --open-mailpit
```

For the reviewed disposable lab, set `preflight::strict::mode` to `"0"` in
ConfigValues. Strict mode set to `"1"` promotes warnings such as aggregate
storage capacity or DNS-resolution checks to deployment blockers. Disabling
strict mode does not skip preflight checks; warnings are still reported and
must be reviewed. Keep strict mode enabled for production unless the target
release documentation and deployment requirements justify otherwise.

## Autoinstall Compatibility

Treat autoinstall validation as schema and type validation, not merely YAML
parsing. Important observed cases include:

- Quote colon-delimited MAC addresses. YAML 1.1 can otherwise parse a MAC as a
  base-60 integer and Netplan receives the wrong type.
- Ensure each `late-commands` item is a string or an argv list. A colon followed
  by a space in an unquoted command can turn it into a YAML mapping.
- Use only keys supported by the Subiquity version bundled with the selected
  ISO. A key documented by a newer installer can still be rejected by an older
  image.
- For explicit UEFI storage, mark the EFI partition with both `flag: boot` and
  `grub_device: true`.

## Netplan Strategy

Install Ubuntu using the installer-generated DHCP configuration. On first boot:

1. Detect the actual interface by MAC address.
2. Find the existing `/etc/netplan/*.yaml` file that defines it.
3. Modify that existing document for the static address, route, and resolver.
4. Preserve unrelated keys and the original pathname.
5. Set every Netplan YAML file to mode `0600`.
6. Run `netplan generate` and `netplan apply`.
7. Create the automation readiness marker only after the static address is
   active.

This avoids assuming an interface name and avoids replacing Netplan during the
installer's network phase. A separate NoCloud `network-config` file is another
valid design, but it supplies the whole cloud-init network configuration rather
than editing the installed file.

## Libvirt DNS Prerequisites

Libvirt dnsmasq listens on `10.0.0.1:53` for this NAT network. It reads the KVM
host's `/etc/hosts` and forwards public DNS misses to the host's upstream
resolvers. The deployment workflow must:

1. Add the new VM name and IP address to the KVM host `/etc/hosts` before VM
   disks are allocated.
2. Query `10.0.0.1` directly to verify the new Chef 360 record and all required
   private lab records.
3. Query a public name through `10.0.0.1` to verify forwarding.
4. Configure the new VM to use `10.0.0.1` as its DNS server.

This also gives CoreDNS a pod-visible path to private `demo.lab` records because
CoreDNS forwards non-cluster names through the node resolver.

## TLS and Trust

Use separate certificate roles:

- Pass the leaf certificate and private key to `chef-360 install --tls-cert`
  and `--tls-key` for Admin Console TLS on port 30000.
- Embed the leaf certificate, private key, and intact issuing/root chain in the
  release-specific ConfigValues for gateway TLS on port 31000.
- Install issuing and root CA certificates as individual `.crt` files in the
  operating-system trust store before Chef 360 installation.
- Do not install the leaf as a CA, transfer a CA signing key, or bypass TLS
  verification.

## Readiness Sequence

For this Replicated installation, application readiness is reached when:

```bash
sudo k0s kubectl get pods -n chef-360 --no-headers \
  | grep -v Running \
  | grep -v Completed
```

returns no lines and at least one Chef 360 pod exists. After this gate:

1. Download and verify the Chef 360 Workstation CLIs from the bundled-tools
   endpoint.
2. Wait at least 60 seconds before polling Mailpit.
3. Wait for Mailpit to become reachable on port 31101.
4. Wait for the initial administrator email.
5. Extract the activation URL when possible or open Mailpit for the user.
6. Validate Kubernetes pressure, pod health, TLS identity, and application
   endpoints.

Mailpit can lag the final ready pod by more than one minute, and the email can
arrive later still. Do not treat temporary Mailpit unavailability as immediate
deployment failure.

## Detailed Runbook

See `docs/kvm-chef360-lab.md` in the project repository for the concrete tested
topology, script inventory, failure recovery, and review checkpoints.
