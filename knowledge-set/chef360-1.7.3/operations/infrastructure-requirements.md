# Chef 360 Infrastructure Requirements

Chef 360 is installed into a Linux guest by the Replicated Embedded Cluster
installer. The product requirements are therefore a guest contract, independent
of whether the guest runs on AWS, Azure, KVM, Hyper-V, Proxmox, or another
virtualization platform.

## Supported Automation Boundary

Infrastructure automation is responsible for providing the guest, networking,
storage, DNS, and access needed to run the installer. The in-guest installation
workflow should remain the same across platforms.

Do not infer that a platform is supported merely because a Terraform provider
can create a VM. Validate the guest operating system and the Chef 360 and
Embedded Cluster requirements for the intended release.

## Baseline Guest Contract

For the Embedded Cluster version bundled with Chef 360 1.7.3, provide:

- A supported x86-64 Linux operating system with systemd.
- Root access, directly or through `sudo`.
- A stable, unique hostname that resolves consistently on every cluster node.
- Synchronized system time.
- At least 2 CPU cores and 2 GiB of memory for the Embedded Cluster platform
  minimum. Size the VM substantially above this minimum for Chef 360 services
  and the expected workload.
- At least 40 GiB total space in the Embedded Cluster data filesystem, with the
  filesystem less than 80 percent full before installation.
- Storage with a maximum P99 write latency of 10 ms for etcd stability.
- A dedicated host without a conflicting Kubernetes installation or container
  runtime configuration.

The default data directory is `/var/lib/embedded-cluster`. It can be changed
with the installer's `--data-dir` option. Application PersistentVolumes are
provided by OpenEBS and commonly appear below:

```text
/var/lib/embedded-cluster/openebs-local
```

The exact PersistentVolume path is authoritative and can be viewed with:

```bash
sudo env KUBECONFIG=/var/lib/embedded-cluster/k0s/pki/admin.conf \
  /var/lib/embedded-cluster/bin/kubectl get pv \
  -o custom-columns='PV:.metadata.name,PVC:.spec.claimRef.name,PATH:.spec.local.path'
```

## Network Contract

Reserve the following ports for Embedded Cluster. For a multi-node cluster,
allow the inter-node ports bidirectionally between cluster nodes.

| Scope | Protocol and ports |
|---|---|
| Local processes | TCP 2379, 7443, 9099, 10248, 10257, 10259 |
| Between cluster nodes | TCP 2380, 6443, 9091, 9443, 10249, 10250, 10256; UDP 4789 |
| Admin Console | TCP 30000 by default |
| Local Artifact Mirror | TCP 50000 by default |

Common Chef 360 1.7.3 `ConfigValues` expose these application ports:

| Service | Default sample port |
|---|---:|
| API gateway and tenant endpoint | TCP 31000 |
| RabbitMQ AMQP | TCP 31050 |
| Mailpit HTTP, when enabled | TCP 31101 |

Only expose ports to the networks that require them. Keep cluster-control and
data-service ports private. The selected `ConfigValues` and installer options,
not this sample table, are authoritative for configurable ports.

Online installations require outbound HTTPS access to the Chef and Replicated
artifact endpoints used by the selected release. Air-gap installations require
the release-specific air-gap bundle and local artifact workflow instead.

## DNS and Addressing

- Assign addresses that remain stable for the life of the installation.
- Ensure every cluster node can resolve every other node's hostname and address.
- Ensure the tenant FQDN resolves to the address used to reach TCP 31000.
- Ensure the Admin Console address resolves or document its direct address and
  port.
- Avoid overlapping the host network with the Kubernetes pod or service CIDRs.
- For TLS, issue certificates for the names users and nodes actually resolve.

Cloud public addresses and public DNS are implementation choices, not Chef 360
requirements. Private addressing, VPN access, routed lab networks, and internal
DNS are valid when all clients and nodes can reach the required endpoints.

## Storage and Recovery

The infrastructure layer must preserve the Embedded Cluster data disk across
routine guest reboots. Hypervisor snapshots are not a substitute for an
application-consistent backup. Coordinate snapshots with Chef 360 and Embedded
Cluster backup procedures, especially for databases and multi-node clusters.

For production infrastructure:

- Use durable, encrypted storage.
- Monitor capacity, latency, and filesystem health.
- Avoid thin-provisioning or cache modes that cannot sustain etcd writes.
- Define backup retention and restore testing separately from VM provisioning.

## Preliminary Check

The repository includes a provider-neutral preliminary check:

```bash
sudo scripts/chef360/check-host-requirements.sh
```

This check catches common guest problems but does not replace the authoritative
preflight checks run by the Chef 360 installer. Do not bypass installer
preflights merely to make automation succeed.

## Sources

- Chef 360 1.7 documentation: https://docs.chef.io/360/1.7/
- Replicated Embedded Cluster installation requirements:
  https://docs.replicated.com/embedded-cluster/v2/installing-embedded-requirements
