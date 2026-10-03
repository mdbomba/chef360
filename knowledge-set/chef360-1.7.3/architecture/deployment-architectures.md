# Chef 360 Deployment Architectures

Chef 360 supports four distinct deployment architectures. This document defines
them, states which installation material this repository can acquire
automatically, and points to the authoritative documentation for the paths
that require manual steps.

## The Four Architectures

Two independent axes determine an installation:

- **Kubernetes provider** — does Chef 360 install and manage its own embedded
  Kubernetes cluster (Integrated), or does it connect to a cluster the customer
  provides (BYOK, Bring-Your-Own-Kubernetes)?
- **Network** — can the Chef 360 host reach the Internet and container
  registries (Non-AirGap), or is it installed inside a closed network
  (AirGap)?

| Architecture | Acquisition of installation material | Installation |
|---|---|---|
| **Integrated Install - Non-AirGap** | Automated | Automated |
| Integrated Install - AirGap | Manual | Automated |
| BYOK - Non-AirGap | Manual | Automated |
| BYOK - AirGap | Manual | Automated |

## Automation Boundary

**Only Integrated Install - Non-AirGap is automated for acquisition of
installation material.**

This repository automates the download and installation of installation
material only for that architecture. For the other three, automation can advise
on the required steps and cite the authoritative documentation, but it cannot
acquire the material. The material must be obtained by the customer.

Installation is available in all four architectures. When material has already
been obtained, the same installer path applies. For BYOK architectures the
customer additionally supplies their own Kubernetes cluster, which changes the
platform prerequisites rather than the Chef 360 installation steps.

## Terminology

| Term | Meaning |
|---|---|
| Integrated Install | The Replicated-based installer provisions and manages the embedded Kubernetes environment. Also referred to as an implicit Kubernetes installation. |
| BYOK | Bring-Your-Own-Kubernetes. The customer provides an existing Kubernetes cluster. Not to be confused with bring-your-own-key, which is a separate licensing arrangement. |
| AirGap | Installation inside a closed network with no outbound Internet access. |
| Non-AirGap | Installation on a host with outbound Internet access. |

BYOK is an architecture, not a licensing term. Licensing questions such as
whether a bring-your-own-key arrangement requires Chef Sales are covered in
`operations/download-licensing-journey.md`.

## Acquisition for the Automated Path

For Integrated Install - Non-AirGap, customers obtain the distribution package
through the download script supplied by the licensing portal. That script
resolves the license, downloads the package, and verifies SHA1 and SHA256
checksums before extraction. This repository does not duplicate that logic;
where verification matters, refer to the portal-issued script.

See `operations/download-licensing-journey.md` for the licensing routes and how
customers obtain the download.

## Determining AirGap Entitlement

For Integrated Install - AirGap, append `&airgap=true` to the end of the
download URL to request the air-gap variant. The resulting archive is a
`.tar.gz`:

- **Contains `chef-360.airgap`** — the license supports air-gap. The customer
  can self-service this architecture.
- **Does not contain `chef-360.airgap`** — the license does not cover air-gap
  installs. The customer must contact Support or Sales to have the license
  updated before proceeding.

Verifying the archive contents before installation:

```bash
tar -tzf <downloaded-package>.tar.gz | grep -x '.*chef-360.airgap'
```

A match confirms air-gap entitlement. No output means the license must be
updated first. Do not attempt an air-gap installation in that case; the
installer requires the bundle and will fail.

## AirGap-Specific Prerequisites

An air-gapped installation additionally requires the Velero plugin images,
which an air-gapped cluster cannot pull itself:

| Image | Purpose |
|---|---|
| `docker.io/progressofficial/chef360:1.0.3` | PostgreSQL backup and restore plugin for Velero |
| `docker.io/velero/velero-plugin-for-aws:v1.12.1` | AWS S3 storage plugin for Velero |

These are pulled and saved on an Internet-connected jump host with Docker, then
transferred to the Chef 360 host and preloaded into the embedded cluster image
store before installation. An air-gap entitlement grants access to the bundle;
it does not remove this image-transfer step.

See `operations/quick-start-installation.md` for the transfer and preload
commands.

## Authoritative Documentation

For the architectures this repository does not automate, consult:

- Chef 360 Platform 1.7 server installation, including the Velero plugin
  downloads: https://docs.chef.io/360/1.7/get_started/install_server/#install-velero-plugins
- Chef 360 Platform 1.7 server download: https://docs.chef.io/360/1.7/get_started/install_server/#download-curl-panel
- Chef 360 Platform 1.7 implicit Kubernetes installation:
  https://docs.chef.io/360/1.7/install/server/implicit/install/

## Related Knowledge

- `architecture/overview.md` for platform services and deployment options
- `operations/download-licensing-journey.md` for licensing and portal access
- `operations/quick-start-installation.md` for the integrated install procedure
- `operations/infrastructure-requirements.md` for host and network prerequisites