# KVM Chef 360 1.7.3 Lab

This runbook documents the reviewed KVM/libvirt workflow for a single-node Chef
360 1.7.3 lab. The workflow separates Ubuntu provisioning, Chef 360 input
staging, product installation, and final validation so an operator can inspect
the VM before Chef 360 changes the guest.

## Tested Topology

| Setting | Value |
|---|---|
| Libvirt domain | `20_chef360` |
| Hostname | `chef360.demo.lab` |
| Address | `10.0.0.20/24` |
| Gateway | `10.0.0.2` |
| DNS resolver | `10.0.0.1` (libvirt dnsmasq) |
| Network | libvirt `default`, NAT |
| Guest | Ubuntu Server 24.04, upgraded during installation |
| Compute | 16 vCPUs, 2048 CPU shares, 32 GiB RAM |
| OS disk | 50 GiB QCOW2, EFI plus ext4 `/` |
| Data disk | 250 GiB, XFS `/var/lib/embedded-cluster` |
| Guest user | `chef` |
| SSH key | Host `~/.ssh/mbomba_firefly.pub` in guest `authorized_keys` |
| Provisioning source | `existing` (VM built outside this workflow) |

Two deployment variants are supported:

- **`os_iso`** fresh builds: the two virtual disks use explicit serials,
  `CHEF360_OS` and `CHEF360_DATA`, so autoinstall does not depend on `/dev/vdX`
  discovery order, and the XFS filesystem is verified to have `ftype=1`. Swap is
  not created and any swap entries are disabled.
- **`existing`** builds: the VM already exists in libvirt; disks may have been
  created manually with no serials and arbitrary filenames, but the same
  host-level guarantees (XFS `ftype=1`, swap off, correct CPU shares, live disk
  paths) are enforced.

## Workflow Boundaries

The scripts in `scripts/kvm/` default to dry-run where an operation would modify
the host, libvirt, or guest. Mutating entry points require `--execute`.

### Prepare the KVM host and assets

Run these once on the libvirt host. Each mutating script prints a plan
unless `--execute` is passed.

```bash
scripts/kvm/bootstrap-kvm-host.sh --execute
scripts/kvm/fetch-ubuntu-iso.sh --execute
scripts/kvm/issue-chef360-certs.sh --execute
AUTH_TOKEN='<authorization-code>' scripts/kvm/acquire-chef360-assets.sh --execute
```

- `bootstrap-kvm-host.sh` installs the libvirt/QEMU tooling (including
  `genisoimage` and `xorriso`), enables `libvirtd`, starts/autostarts the
  `default` network, creates the staging directories, and generates
  `~/.ssh/fury_rsa` when absent.
- `fetch-ubuntu-iso.sh` downloads `ubuntu-24.04.4-live-server-amd64.iso` from
  `releases.ubuntu.com` and installs it only after its SHA-256 matches the
  published `SHA256SUMS`. Override with `UBUNTU_RELEASE` / `ISO_NAME`.
- `issue-chef360-certs.sh` issues the root CA, issuing CA, and leaf certificate
  into `~/certs` for `{VM_HOSTNAME}` / `{VM_IP}`. The CA signing keys stay under
  `.kvm/<VM_NAME>/ca/` (mode 0700) and are never copied to the guest.
- `acquire-chef360-assets.sh` downloads the `chef-360` installer and
  `license.yaml` from the Chef 360 distribution endpoint (online by default,
  `--airgap` for the full bundle), verifies the 1.7.3 version, and stages both
  files under `/install/chef-360/1.7/`. The authorization code must be supplied
  through `AUTH_TOKEN` (or `--auth-token`) so it is never placed in curl's
  arguments.

When `KVM_SOURCE_DIR` points at a maintained cache such as `~/repos/sources`
(containing `chef360/chef-360`, `chef360/license.yaml`, `chef360/tls/*`, and
`ubuntu/<iso>`), the scripts prefer the cached artifacts over the `/install`
defaults. Explicit environment values always win, and the selected paths are
persisted to the generated state file.

Host, certificate, and asset syntax checks run in CI via
`bash scripts/ci/check-kvm-scripts.sh`.

### Prepare reviewed inputs

```bash
scripts/kvm/create-chef360-plan.sh --interactive --execute   # approved plan
scripts/kvm/generate-chef360-config.sh
scripts/kvm/prepare-chef360-install-inputs.sh
```

Generated runtime state is stored under `.kvm/<VM_NAME>/` and excluded from
Git. It contains password hashes, a generated API token, the license, the
ConfigValues file, and a private TLS key. Keep the directory owner-readable.
See `docs/kvm-chef360-project-plan.md` for the full plan parameter reference,
including the `existing` provisioning source. Use `--interactive --execute`
(not bare `--execute`) when the plan must not fall back to stale state
defaults.

### Onboarding an already-built VM (`existing`)

When the VM was created outside this workflow (for example manually in
Virtual Machine Manager), run the plan generator with `existing`:

```bash
scripts/kvm/create-chef360-plan.sh --interactive --execute   # pick: existing
```

The generator records the live libvirt facts (`VM_MAC`, `OS_DISK`,
`DATA_DISK`) so validators check the actual domain, and the checkpoint skips
autoinstall/VM creation and waits only for SSH. Before or after the plan, bring
the guest to the same guarantees a fresh build provides:

- Set CPU shares to the plan value persistently:
  `virsh schedinfo <VM_NAME> --config --set cpu_shares=2048` (the live-only
  change does not appear in `virsh dumpxml`).
- Ensure swap is off (`/proc/swaps` empty, no swap in `/etc/fstab`).
- Make sure `/var/lib/embedded-cluster` is XFS with `ftype=1`. Manually:
  `sgdisk --new=1:0:0 --typecode=1:8300`, `mkfs.xfs -f -L chef360-data
  -n ftype=1`, mount by UUID in fstab (the data disk usually has no serial).
- Authorize the host SSH key and confirm passwordless sudo for the guest user.

### Provision to the pre-Chef checkpoint

```bash
scripts/kvm/deploy-chef360-checkpoint.sh --execute
```

The checkpoint workflow:

1. Configures the Mint host's marked `/etc/hosts` and SSH config blocks.
2. Installs the issuing and root CA certificates in the host trust store.
3. Generates the Chef 360 ConfigValues and staged inputs.
4. Creates the VM and waits for Ubuntu autoinstall to power off *(skipped for
   `existing`; an already-built VM already powers itself)*.
5. Removes direct installer kernel/initrd and all optical media from the
   persistent VM definition *(skipped for `existing`)*.
6. Starts the installed OS and waits for first-boot cloud-init *(skipped for
   `existing`; waits only for SSH instead)*.
7. Validates SSH, sudo, hostname, networking, swap, XFS, and lab name resolution.
8. Copies Chef 360 inputs to `/opt/chef360` and installs guest CA trust.
9. Stops before running `chef-360 install`.

Review the VM at this point:

```bash
ssh chef360
scripts/kvm/status-chef360-vm.sh
scripts/kvm/validate-chef360-vm.sh
```

### Install Chef 360

After review:

```bash
scripts/kvm/install-chef360.sh --execute
```

The command uses:

- `--tls-cert` and `--tls-key` for Admin Console TLS on port 30000.
- `--config-values` for Chef 360 application and gateway configuration on port
  31000, including its certificate, private key, and CA chain.
- Enforced host preflights. Application preflights run strict by default;
  set `CHEF360_IGNORE_APP_PREFLIGHTS=1` to add `--ignore-app-preflights`.

The reviewed lab ConfigValues sets `preflight::strict::mode` to `"0"`. This does
not skip preflights; it permits an operator to deploy after reviewing accepted
lab warnings. With strict mode set to `"1"`, Chef 360 1.7.3 blocks application
deployment on any preflight warning, including two warnings this topology cannot
clear:

- `Total Storage Capacity` — a capacity caution on the 250 GiB data disk; the
  per-node storage check still passes at `>= 200Gi`.
- `Cluster DNS Resolution — No matching files` — the application analyzer cannot
  find the file it globs for; guest DNS itself is healthy (systemd-resolved
  stub -> 10.0.0.1).

Because only warnings (no failures) hold the deploy, `install-chef360.sh`
accepts an opt-in tolerant mode that uses the installer's own documented flag
while still enforcing host preflights:

```bash
CHEF360_IGNORE_APP_PREFLIGHTS=1 scripts/kvm/install-chef360.sh --execute
```

If an install stops partway (for example after a failed addon stage), the script
treats an already-listening port 31000 as "installed" and otherwise allows a
retry. The vendor installer itself regards any existing
`/var/lib/embedded-cluster` as an installed system and refuses to reinstall
until wiped:

```bash
sudo ./chef-360 reset --yes   # on the guest, then re-run install-chef360.sh
```

### Validate and finish administrator activation

```bash
scripts/kvm/validate-chef360-deployment.sh --execute --open-mailpit
```

The validator waits until:

```bash
sudo k0s kubectl get pods -n chef-360 --no-headers \
  | grep -v Running \
  | grep -v Completed
```

returns no lines. It then installs all seven Chef 360 Workstation CLIs, waits 60
seconds, polls Mailpit on port 31101, and waits for mail to `admin@demo.lab`. It
reports an activation URL when one can be extracted and otherwise opens Mailpit
for interactive password assignment.

## Ubuntu Autoinstall Lessons

### Validate YAML types, not only syntax

YAML can be syntactically valid but have the wrong type. Observed examples:

- An unsupported `groups` key in the ISO's `identity` implementation caused
  `Malformed autoinstall in 'identity' section`.
- An unquoted MAC address such as `52:54:00:40:00:40` was parsed by YAML 1.1 as
  a base-60 integer, causing Netplan application errors.
- A command containing `autoinstall: ` was parsed as a mapping rather than a
  string, causing `Malformed autoinstall in 'late-commands' section`.

The generator checks that every late command is a string or argv list. Values
with colons are quoted, and complex commands use argv lists where possible.

### Mark the EFI partition as a GRUB device

For the explicit GPT layout, setting `grub_device: true` only on the disk was
not sufficient for this ISO. The EFI partition also requires:

```yaml
flag: boot
grub_device: true
```

Without it, Subiquity reported that autoinstall did not create a required
bootloader partition.

### Do not replace Netplan during installer networking

The robust sequence is:

1. Let the Ubuntu installer use its generated DHCP Netplan configuration.
2. Complete installation and power off.
3. On first boot, detect the actual interface by its known MAC address.
4. Locate the existing Netplan YAML that defines that interface.
5. Edit only `dhcp4`, addresses, routes, and nameservers in that same document.
6. Preserve unrelated keys.
7. Write atomically, set every Netplan YAML to mode `0600`, run `netplan
   generate`, then `netplan apply`.
8. Create the readiness marker only after the static network is applied.

This avoids cloud-init data-source precedence problems and does not assume an
interface name. The public NoCloud `network-config` mechanism is another valid
approach for future workflows, but it replaces rather than edits the
installer-created document.

### Capture installer failures

The libvirt QEMU log shows device launch details but not Subiquity errors. Use a
VM screenshot or the serial console for the immediate failure. If Subiquity
offers a recovery shell, detailed installer logs are under `/var/log/installer`
in the live environment. After a fatal error, `/target` may already be unmounted,
so `curtin in-target` can report that it cannot find the target.

## Certificates

The runtime uses five source files:

```text
chef360-2.crt
chef360-2.key
chef360-2.chain.crt
chef360-2_ica.crt
chef360-2_rca.crt
```

- Admin Console `--tls-cert` receives the leaf certificate only.
- Admin Console `--tls-key` receives the matching private key.
- Chef 360 ConfigValues receives leaf, key, and intact chain.
- Ubuntu and Mint trust stores receive the issuing and root CA files separately.
- The CA signing key is never required or transferred.

## Troubleshooting and Cleanup

### Transient install-time conditions

Two conditions self-resolve and do not indicate a broken deployment:

- **NTP not synchronized.** A host preflight can fail with "NTP is enabled but
  the system clock is not synchronized" shortly after first boot before
  `systemd-timesyncd` completes its initial sync. Confirm
  `timedatectl` reports "System clock synchronized: yes" and re-run
  `install-chef360.sh`.
- **Bundled tools HTTP 401.** Immediately after install, the
  `:31000/platform/bundledtools/...` CLI download endpoint can briefly return
  401 while platform initialization settles. `install-chef360-workstation-clis.sh`
  retries downloads (`CLI_DOWNLOAD_RETRIES`, default 4), and validation passes on
  a later run.

### Node `/etc/hosts` does not configure pod DNS

Kubernetes pods resolve through CoreDNS, not directly through the node's
`/etc/hosts`. The KVM host already runs libvirt-managed dnsmasq on
`10.0.0.1:53`. That resolver reads the host's `/etc/hosts` and forwards misses
to the host's public upstream resolvers. Configure new lab VMs to use
`10.0.0.1` as their DNS server so CoreDNS can resolve private `demo.lab` names
and public names through the same path.

Before switching the VM resolver from public DNS, observed behavior from a
diagnostic pod was:

```text
automate.demo.lab -> NXDOMAIN
https://10.0.0.21/data-collector/v0/ -> HTTP 401 without a token
```

After configuring the VM to use `10.0.0.1`, verify both private and public names
from a pod before using an FQDN in an integration. The IP URL remains a valid
fallback when the service certificate and connector permit it.

The final lab burn test completed 100 iterations across four private names and
one public name per iteration: 500 pod-level DNS queries with zero failures.
CoreDNS remained Ready with zero restarts and no error, failure, timeout, or loop
messages during the test. A pod request to
`https://automate.demo.lab/data-collector/v0/` returned the expected HTTP `401`
without a token, proving both private DNS resolution and network reachability.

After that validation, the Chef 360 Automate Connector was successfully changed
from the IP-based URL to:

```text
https://automate.demo.lab/data-collector/v0/
```

Before provisioning a new VM, the KVM workflow must:

1. Add the new VM's name and address to the host `/etc/hosts`.
2. Query libvirt dnsmasq directly at `10.0.0.1` for the new VM and existing lab
   hosts.
3. Verify that `10.0.0.1` also forwards a public DNS query.
4. Stop before allocating disks if any DNS check fails.

Status and validation:

```bash
scripts/kvm/status-chef360-vm.sh
scripts/kvm/validate-chef360-vm.sh
scripts/kvm/validate-chef360-deployment.sh --execute
```

Destructive cleanup requires confirmation:

```bash
scripts/kvm/destroy-chef360-vm.sh
```

It deletes only the exact `<VM_NAME>` definition, dedicated disks, generated
installer artifacts, and `.kvm/<VM_NAME>` runtime directory. For an `existing`
plan, confirm first that the disks removed are indeed only that VM's.

## Deployment observations

- **Waiting for pod readiness**: the validators treat `Running` and
  `Completed` as healthy. `kubectl get pods | grep -cv Running` counts cleanly
  finished install jobs as "not running" and can look stuck; compare against
  the actual status column instead.
- **Endpoint status codes**: the Admin Console answers HTTP `200` and the Chef
  360 gateway answers HTTP `301` on its root path; both are healthy. Do not
  treat the `301` as an error.
- **Mailpit**: the API at `http://chef360.demo.lab:31101/api/v1/messages`
  returns JSON with a `total` and `messages[]`. Polling for a new message
  `ID` (vs. an existing one) is how the validator waits for the admin
  activation email. Activation sends "Set Password" and "You are added to an
  organization: lab"; setting the password later also sends a "Reset
  password" message from `progress@platformtest.com`.
- **OOM recovery warning**: deployment validation reports
  `WARN: N container(s) recovered from an earlier OOM kill` when a pod the
  installer restarted is now Running. Monitor for recurrence; it is not a
  current failure.
- **Workstation CLIs**: seven CLIs (`chef-platform-auth-cli`,
  `chef-node-enrollment-cli`, `chef-import-cli`, `chef-node-management-cli`,
  `chef-courier-cli`, `chef-dsm-cli`, `chef-habitat-cli`) are downloaded from
  the bundled-tools endpoint and verified at `/opt/chef-360` on the guest.
