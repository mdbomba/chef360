# Chef Platform Download and Licensing Journey

Chef Platform is the distribution name for Chef 360. This document describes
where customers obtain the Chef 360 installer, which licensing routes are
available, and how each route determines whether a non-air-gapped or
air-gapped install is supported.

The customer journey historically began with a call to Sales to obtain a
download authorization code. That remains required for evaluation licenses.
Customers with a supported production license who have previously installed
Chef Infra Server or Chef Automate can now self-serve the download instead.

## Download Location

Existing customers download Chef Platform from the Progress Community site:

```
https://community.progress.com/s/downloads-chef
```

Downloads are organized per serial number. The serial number is the Chef
Infra Server or Chef Automate license. Under a qualifying serial number, a
download named **Chef Platform** is available. Chef Platform is Chef 360.

## Obtaining the Download Script

The site requires sign-in. The customer obtains a customer-specific download
script as follows.

1. Go to `https://community.progress.com/s/downloads-chef`. The site requires
   sign-in, so connect and sign in first using the customer's Progress
   Community account.
2. Locate the license to download under. Look for the **Chef Infra Server** or
   **Chef Automate** license. Either one is a valid basis for the Chef
   Platform download; a Chef Infra Client or Workstation license is not.
3. Open the **Downloads** section for that license.
4. Download the install script for **Chef Platform**. The download is a script,
   not the Chef 360 package itself.
5. Paste the script contents into an input window. A customer-specific
   `download.sh` can then be created from it and reused for later downloads,
   including air-gap attempts.

Because the script is tied to one license, it is customer-specific. Save it
under access-controlled storage with the same handling as the authorization
code described in `Handling Credentials` below.

Confirm the script before running it. It is expected to download and extract
the Chef 360 package for the license it was generated from. If the license does
not cover the intended deployment type, stop and use the route table below
rather than working around the failure.

## Choosing a Route

| Customer situation | Route |
|---|---|
| Evaluation license | Call Sales for a download authorization code |
| Supported production license, previously installed Chef Infra Server or Chef Automate | Self-serve from the Progress Community downloads page |
| Bring-your-own-key arrangement | Contact Chef Sales to begin the process |

A bring-your-own-key arrangement is not available through self-service under
any license state. Note this is a licensing arrangement and is unrelated to
BYOK (Bring-Your-Own-Kubernetes), which is a deployment architecture covered in
`architecture/deployment-architectures.md`.

## Self-Service Scope

The self-service download supports **use case 1a**, Replicated Install,
non-air-gap. Attempting an air-gap install requires confirming the license
permits it.

## Air-Gap Self-Service Test

The `download.sh` created from the portal embeds the download URL for that
license. To determine whether the serial number supports air-gap installation,
append the `&airgap=true` tag to the end of that URL. The portal offers the
install script as one option on the license page, and adding the tag to the
script's URL requests the air-gap variant.

Inspect the resulting archive. It is a `tar.gz`:

- **Contains `chef-360.airgap`** — the license supports air-gap. The customer
  can self-service **use case 1b**, Replicated Install, air-gap.
- **Does not contain `chef-360.airgap`** — the license does not cover air-gap
  installs. The customer must contact Support or Sales to have the license
  updated.

Verifying before installing:

```bash
tar -tzf <downloaded-package>.tar.gz | grep -x '.*chef-360.airgap'
```

A match confirms air-gap entitlement. No output means the license must be
updated first. Do not attempt an air-gap install in that case; the installer
requires the bundle and will fail.

## Entitlement Summary

| Route | Non-air-gap (1a) | Air-gap (1b) |
|---|---|---|
| Evaluation license via Sales | Yes | No |
| Production license, self-service | Yes | Only when the archive contains `chef-360.airgap` |
| Bring-your-own-key via Sales | Arranged with Sales | Arranged with Sales |

## Relationship to Installation

This document covers obtaining and licensing the package. For prerequisites and
the installation procedure itself, see:

- `operations/quick-start-installation.md` for the single-node hyperconverged
  Replicated install, including online and air-gapped commands
- `operations/infrastructure-requirements.md` for host and network prerequisites
- `operations/traditional-recovery-installation.md` for traditional and
  recovery deployment types

Both online and air-gapped packages contain the authorization-specific
`license.yaml` used to license the cluster:

```bash
sudo ./chef-360 install --license license.yaml
```

Air-gapped installs additionally require the Velero plugin container images
described in `operations/quick-start-installation.md`. An air-gap entitlement
grants access to the bundle; it does not remove the image-transfer step.

## Handling Credentials

Treat the authorization code, the download URL, and the customer-specific
`download.sh` as sensitive. The script embeds the license-specific URL, so it
is a credential artifact even though it looks like an ordinary shell script. Do
not commit it, include it in support bundles, or place it in shared
documentation.

The portal-issued `download.sh` verifies SHA1 and SHA256 checksums of the
downloaded archive before extracting it. Treat a checksum mismatch as a failed
download rather than retrying with a modified URL.

The maintained helper `scripts/chef360/download-install-server.sh` passes the
authorization header to `curl` through standard input so it does not appear in
the `curl` process arguments.

## Related Knowledge

- `architecture/deployment-architectures.md` for the four deployment
  architectures and which one is automated
- `operations/quick-start-installation.md` for the integrated install procedure
- `operations/infrastructure-requirements.md` for host and network prerequisites