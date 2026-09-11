# KVM Chef 360 Project Plan

Every Chef 360 build starts from an approved plan. The plan is a per-build
artifact (`.kvm/<VM_NAME>/<VM_NAME>-PLAN.md` plus machine-readable
`<VM_NAME>-PLAN.env`) generated interactively with the operator, reviewed, and
approved **before** any VM or install step runs. It is the single source of
truth that drives the VM build, the Chef 360 install, and the generated
`config.yaml`.

## Naming convention

All project-specific content created for a build is prefixed with the target
VM name (e.g. `20_chef360`). This keeps simultaneous or successive builds
collision-free on the KVM host and makes ownership self-describing.

| Artifact | Example name |
|---|---|
| Build work directory | `.kvm/20_chef360/` |
| Plan (machine + human) | `.kvm/20_chef360/20_chef360-PLAN.env`, `20_chef360-PLAN.md` |
| ConfigValues + secrets | `.kvm/20_chef360/20_chef360-config.yaml`, `20_chef360-secrets.env` |
| Autoinstall files | `.kvm/20_chef360/20_chef360-user-data`, `20_chef360-meta-data`, `20_chef360-vmlinuz`, `20_chef360-initrd`, `20_chef360-seed.iso` |
| Disks | `/var/lib/libvirt/images/20_chef360-os.qcow2`, `20_chef360-data.qcow2` |
| TLS/CA material | `~/certs/20_chef360.crt`, `20_chef360.key`, `20_chef360_chain.crt`, `20_chef360_ica.crt`, `20_chef360_rca.crt` |
| CA workspace | `.kvm/20_chef360/20_chef360-ca/` (`20_chef360-rca.key`, `20_chef360-ica.key`, ...) |
| Staging tree | `.kvm/20_chef360/20_chef360-stage/` (`chef-360`, `license.yaml`, `20_chef360-config.yaml`, `tls/20_chef360.*`, `ca/20_chef360-ica.crt`) |
| Staging manifest | `.kvm/20_chef360/20_chef360-stage/20_chef360-MANIFEST.txt` |

For `os_iso` and `clone` builds the disk, CA, and staging paths follow the
convention above exactly. For `existing` builds (a VM built outside this
workflow) the live libvirt sources are read with `virsh dumpxml` and recorded
verbatim as `OS_DISK` / `DATA_DISK` in the plan, because a hand-built VM is not
guaranteed to follow the naming convention.

Guest-side runtime paths (`/opt/chef360/...`, including
`/opt/chef360/tls/chef360-2.crt` and `/opt/chef360/chef-config.yaml`) are NOT
VM-prefixed; each guest already runs a single build, so its filesystem is
inherently isolated and product-conventional names stay stable across builds.

## Workflow

1. **Draft** — run `scripts/kvm/create-chef360-plan.sh` (dry-run, no
   `--execute`). It prints the resolved plan and runs structural validation,
   failing on mismatches such as a tenant portal that does not equal
   `VM_HOSTNAME`.
2. **Adjust** — override values on the command line, e.g.
   `VM_NAME=20_chef360 VM_HOSTNAME=chef360.demo.lab TENANT_ADMIN_EMAIL=admin@demo.lab \
   scripts/kvm/create-chef360-plan.sh`. Repeat the dry-run until it passes.
3. **Approve** — run `scripts/kvm/create-chef360-plan.sh --execute` to write
   `.kvm/<VM_NAME>/<VM_NAME>-PLAN.env` and `<VM_NAME>-PLAN.md` (mode 0600).
   Review `PLAN.md` and tick its approval checklist.
4. **Build or reuse** — `lib-chef360-kvm.sh` sources `<VM_NAME>-PLAN.env`
   automatically when it exists, so `deploy-chef360-vm.sh`,
   `install-chef360.sh`, and `generate-chef360-config.sh` all use the approved
   values. For an `existing` plan the VM/disk/autoinstall steps are skipped
   entirely (see below); for a fresh build do not build or reinstall until the
   file exists and the checklist is complete.

### Provisioning an already-built VM (`existing`)

When the VM already exists in libvirt (built outside this workflow), select
`existing` as the provisioning source during the interactive run:

```bash
scripts/kvm/create-chef360-plan.sh --interactive --execute
```

The generator records the live domain facts as authoritative values instead of
deriving them from the naming convention:

- **MAC**: read from `virsh dumpxml <VM_NAME>` and stored as `VM_MAC`.
- **Disks**: the actual `<source file=...>` paths are parsed from each
  `<disk>` block and stored as `OS_DISK` / `DATA_DISK`, so validators compare
  against the files the domain really uses.

The build-time guards honor this mode:

- `deploy-chef360-vm.sh` refuses to run (`deploy-chef360-checkpoint.sh` skips
  the autoinstall/VM creation/boot steps and waits only for SSH).
- `stage-chef360-install-inputs.sh` and `install-chef360.sh` skip the
  autoinstall-readiness marker check (the VM was never autoinstalled by this
  project), but still require the staged-inputs marker and passwordless sudo.
- CPU shares, swap, XFS `ftype=1`, and the data-drive layout are still validated
  against the running guest and enforced to match the plan where possible
  (see `virsh schedinfo --config --set cpu_shares=...` below).

To see defaults at any time:

```bash
scripts/kvm/create-chef360-plan.sh              # dry-run of current defaults
scripts/kvm/generate-chef360-config.sh          # prints tenant/config and warnings
```

## Parameter reference

The sections below document each decision that can change from one Chef 360
installation to the next. Defaults reflect the current lab. Changing a value
here (or with an `ENV=value` override) is how you deviate from a default
without editing scripts.

### 1. Provisioning source

| Setting | Why it is here | Default | Plan |
|---|---|---|---|
| VM_NAME | Unique libvirt domain and disk prefix | `20_chef360` | `20_chef360` |
| Provision method | `os_iso` fresh autoinstall, `clone` base image reuse, or `existing` for a VM already in libvirt | `os_iso` | `existing` |
| Clone source image | Path of an already-provisioned base when using `clone` | `-` (see `.kvm/`/libvirt images) | `-` |
| UBUNTU_ISO | OS install media for `os_iso` only | `~/install/linux/ubuntu-24.04_server_amd64.iso` | `-` |
| UBUNTU_MIRROR | Apt mirror used during autoinstall and apt upgrade | `http://mirror.arizona.edu/ubuntu` | `-` |
| VM_INITIAL_PASSWORD | Temporary password for the initial autoinstall user | `devsecops` | `-` |

For `existing` plans the generator reads `VM_MAC`, `OS_DISK`, and `DATA_DISK`
from `virsh dumpxml` and persists them, and the ISO/mirror/password settings are
unused.

### 2. Guest identity and network

These values end up in `/etc/hosts`, Netplan, and the certificate hostname
checks. The tenant portal (3.x) must match the gateway hostname here.

| Setting | Why it is here | Default | Plan |
|---|---|---|---|
| VM_SHORT_HOSTNAME | `/etc/hostname`, prompt label | `chef360` | |
| VM_HOSTNAME | FQDN used by TLS, gateway, and tenant | `chef360.demo.lab` | |
| VM_IP | Static address in `/24` | `10.0.0.20` | |
| VM_PREFIX | Netplan mask | `24` | |
| VM_GATEWAY | Default route (VyOS router) | `10.0.0.2` | |
| VM_DNS | Resolver (libvirt dnsmasq) | `10.0.0.1` | |
| VM_MAC | Must match the DHCP-side static mapping; `existing` reads it live | `52:54:00:20:00:20` | `52:54:00:1f:c2:eb` |
| VM_USER | First sudo user created by autoinstall | `chef` | |
| SSH_PRIVATE_KEY / SSH_PUBLIC_KEY | Key authorized for `VM_USER` | `~/.ssh/mbomba_firefly(.pub)` | |

### 3. Compute and storage

| Setting | Why it is here | Default | Plan |
|---|---|---|---|
| VM_VCPUS | App preflight requires >= 15 cores | `16` | |
| VM_CPU_SHARES | Relative host CPU weight | `2048` | |
| VM_MEMORY_MIB | App preflight requires >= 32 GiB | `32768` | |
| VM_OS_DISK_GIB | OS disk size | `50` | |
| VM_DATA_DISK_GIB | Size of the `/var/lib/embedded-cluster` data drive; app preflight per-node >= 200 GiB | `250` | |
| VM_DISK_PREALLOCATION | `falloc` avoids store-size warning on thin qcow2 | `falloc` | |
| VM_OS_DISK_SERIAL / VM_DATA_DISK_SERIAL | Deterministic `/dev/vdX` mapping | `CHEF360_OS` / `CHEF360_DATA` | `-` for `existing` (hand-built disks have no serial) |
| Data filesystem | Must be XFS with `ftype=1` | `xfs ftype=1` | `xfs ftype=1` |

### 4. Certificates (gateway + Admin Console)

`CHEF360_TLS_*` feed the Admin Console TLS and are embedded into the generated
ConfigValues. Replace these paths if a build needs different certs.

| Setting | Why it is here | Default | Plan |
|---|---|---|---|
| CHEF360_TLS_CERT | Leaf certificate (must cover VM_HOSTNAME and VM_IP) | `~/certs/${VM_NAME}.crt` | |
| CHEF360_TLS_KEY | Leaf private key (mode 0600 on guest) | `~/certs/${VM_NAME}.key` | |
| CHEF360_TLS_CHAIN | Issuing plus root CA bundle (served as trust anchor) | `~/certs/${VM_NAME}_chain.crt` | |
| CHEF360_ISSUING_CA / CHEF360_ROOT_CA | For validation and guest trust install | `~/certs/${VM_NAME}_ica.crt` / `${VM_NAME}_rca.crt` | |
| Admin Console cert files | Filenames staged under `/opt/chef360/tls/` | `chef360-2.crt` / `chef360-2.key` | |

### 5. Chef 360 application source

| Setting | Why it is here | Default | Plan |
|---|---|---|---|
| CHEF360_INSTALLER_SOURCE | `chef-360` binary used by the installer | `~/install/chef/chef-360/1.7/chef-360` | |
| CHEF360_LICENSE_SOURCE | License YAML validated before install | `~/install/chef/chef-360/1.7/license.yaml` | |
| CHEF360_CONFIG_TEMPLATE | ConfigValues template the generator starts from | `knowledge-set/chef360-1.7.3/examples/kots-config.yaml` | |
| App version | Locked by the pinned installer bundle | `1.7.3` | |
| CHEF360_ADMIN_CONSOLE_PASSWORD | Initial Admin Console password (min 6 chars) | `devsecops` | |

### 6. Tenant and endpoint configuration

These are the values the interactive generator prompts for. `tenant subdomain`
+ `tenant tld` must reconstruct `VM_HOSTNAME` or converted email links point
at an unreachable name.

| Setting | Why it is here | Default | Plan |
|---|---|---|---|
| TENANT_NAME | Logical tenant label (e.g. `demolab`) | `demolab` | |
| TENANT_SUBDOMAIN | First DNS label of the tenant portal | `chef360` | |
| TENANT_TLD | DNS domain (`demo.lab`) | `demo.lab` | |
| TENANT_OU | Organization unit name | `lab` | |
| TENANT_OU_DESCRIPTION | OU description | `Lab organization` | |
| TENANT_ADMIN_FIRST_NAME / LAST_NAME | Admin display name | `Chef` / `Admin` | |
| TENANT_ADMIN_EMAIL | Receives set-password and activation mail | `admin@demo.lab` | |
| GATEWAY_NODEPORT | HTTPS port exposed by the gateway | `31000` | |
| MAILPIT_NODEPORT | Mailpit UI/API port | `31101` | |
| RABBITMQ_AMQP_NODEPORT | AMQP port | `31050` | |
| preflight::strict::mode | `0` tolerates the two reviewed lab warnings | `0` | |

### 7. Integration endpoints (hosts file and validators)

| Setting | Why it is here | Default | Plan |
|---|---|---|---|
| KVM_HOST_IP / KVM_HOST_FQDN | `fury.demo.lab` host entry | `10.0.0.1` / `fury.demo.lab` | |
| AUTOMATE_IP / AUTOMATE_FQDN | Chef Automate peer | `10.0.0.21` / `automate.demo.lab` | |
| NODE1_IP / NODE1_FQDN | Sample node peer | `10.0.0.23` / `node1.demo.lab` | |
| NODE2_IP / NODE2_FQDN | Sample node peer | `10.0.0.24` / `node2.demo.lab` | |

### 8. Post-install behavior

| Setting | Why it is here | Default | Plan |
|---|---|---|---|
| CHEF360_IGNORE_APP_PREFLIGHTS | `1` adds `--ignore-app-preflights` for the two reviewed warnings | `1` | `1` |
| Install workstation CLIs | Download `chef-platform-auth-cli` etc. after pods are ready | `yes` | `yes` |
| Finish admin activation | Wait for Mailpit email to admin, then set password | `yes` | `yes` |

## Findings and lessons

### `local` declarations under `set -u`

With `set -u` (used by every script here), `local a b` does **not** initialize
the variables, so a later `${b}` reference aborts with
`b: unbound variable`. Declare with an explicit empty value instead:

```bash
local os_path="" data_path=""
```

Observed when adding the disk resolver for `existing` builds.

### libvirt XML: `<source>` precedes `<target>` in each `<disk>`

`virsh dumpxml` emits a disk block with `<source file=...>` on the line
*before* `<target dev=...>`. Parsing with `grep -A1 "<target..."` therefore
found nothing. A resilient parser splits on `RS="</disk>"` and pulls both
attributes with `match()`/`substr()` inside awk.

### Hand-built VMs have default CPU shares

A VM created with `virt-install` outside this workflow runs with libvirt's
default `cpu_shares=100`, while the plan expects `2048`. The plan is the
source of truth; align the live domain persistently:

```bash
virsh schedinfo <VM_NAME> --config --set cpu_shares=2048
```

`--config` (not just live) is required so `virsh dumpxml` shows
`<shares>2048</shares>` and validation passes.

### Hand-built data disks lack a serial

`provision-chef360-data-disk.sh` locates the data disk by its
`CHEF360_DATA` serial. Manually created disks (no serial) were instead
provisioned with:

```bash
sgdisk --zap-all --clear /dev/vdb
sgdisk --new=1:0:0 --typecode=1:8300 /dev/vdb
partprobe /dev/vdb
mkfs.xfs -f -L chef360-data -n ftype=1 /dev/vdb1   # ftype is a -n option, not -m
```

and mounted by UUID in `/etc/fstab` at `/var/lib/embedded-cluster`. The
validator confirms XFS + `ftype=1` regardless of how the disk was made.

### "Existing" plans persist live paths into PLAN.env

The plan template writes only the `PLAN_KEYS` list. `VM_MAC`, `OS_DISK`, and
`DATA_DISK` were added so an `existing` plan records the live domain facts and
`lib-chef360-kvm.sh` keeps them after the post-plan recompute step.

## Approval

- [ ] Reviewed sections 1-8 against this build.
- [ ] Tenant portal (`TENANT_SUBDOMAIN.TENANT_TLD`) equals `VM_HOSTNAME`.
- [ ] Certificate files exist and cover `VM_HOSTNAME` and `VM_IP`.
- [ ] Installer binary and license files exist (SHA-256 verified).
- [ ] Data drive size meets the >= 200 GiB per-node preflight.
- [ ] Plan file saved next to this build (`.kvm/<VM_NAME>/<VM_NAME>-PLAN.md`).

The environment for every build script must match the plan;
`lib-chef360-kvm.sh` sources `<VM_NAME>-PLAN.env` automatically once the plan is
approved.