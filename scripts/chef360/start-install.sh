#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat <<'EOF'
Choose a Chef 360 deployment architecture.

  1. Integrated Install - Non-AirGap   Automated download and install
  2. Integrated Install - AirGap       Manual download, automated install
  3. BYOK - Non-AirGap                 BYOK Kubernetes, manual download
  4. BYOK - AirGap                     BYOK Kubernetes, manual download

This repository automates the acquisition of installation material only for
architecture 1. For the others it can advise, but the material must be obtained
by the customer.

Details: knowledge-set/chef360-1.7.3/architecture/deployment-architectures.md
EOF
read -r -p 'Architecture [1-4]: ' architecture

case "${architecture}" in
  1)
    cat <<'EOF'

Integrated Install - Non-AirGap is the automated path.

EOF
    cat <<'EOF'
Choose an installation path:
  1. Traditional: download the package, install, then configure in the Admin Console.
  2. Recovery/repeatable: use protected local ConfigValues and optional TLS inputs.
EOF
    read -r -p 'Selection [1-2]: ' selection

    case "${selection}" in
      1)
        "${SCRIPT_DIR}/download-install-server.sh"
        printf 'Run the installer from the extracted package directory. Add --interactive for guided prompts.\n'
        ;;
      2)
        printf 'Run install-server.sh with --installer, --license, and your protected --config-values path.\n'
        printf 'Optional matching --tls-cert/--tls-key inputs make the Admin Console setup repeatable.\n'
        ;;
      *) printf 'Selection must be 1 or 2.\n' >&2; exit 2 ;;
    esac
    ;;
  2)
    cat <<'EOF'
Integrated Install - AirGap is not automated for acquisition of installation
material. Obtain the package on an Internet-connected workstation, then transfer
it to the Chef 360 host.

Obtain the air-gap variant by appending &airgap=true to the end of the download
URL from the portal-issued download.sh. Confirm the license permits air-gap by
checking whether the downloaded archive contains chef-360.airgap:

  tar -tzf chef-360.tar.gz | grep -x '.*chef-360.airgap'

No match means the license must be updated by Support or Sales first.

An air-gapped host also requires the Velero plugin images, pulled and saved on
an Internet-connected jump host with Docker, then preloaded into the embedded
cluster image store before installation:

  docker.io/progressofficial/chef360:1.0.3
  docker.io/velero/velero-plugin-for-aws:v1.12.1

Once chef-360, chef-360.airgap, license.yaml, and the plugin archives are on the
Chef 360 host, installation is automated. Run install-server.sh with the
--airgap-bundle option.

Authoritative documentation:
  https://docs.chef.io/360/1.7/get_started/install_server/#install-velero-plugins
  https://docs.chef.io/360/1.7/get_started/install_server/#download-curl-panel
EOF
    ;;
  3|4)
    cat <<EOF
Architecture ${architecture} is BYOK (Bring-Your-Own-Kubernetes), which is not
automated for acquisition of installation material. You provide the Kubernetes
cluster; this repository cannot obtain the Chef 360 distribution package for
you.

Before proceeding:

  - Confirm your cluster meets the Chef 360 prerequisites for your chosen
    Kubernetes distribution and version.
  - Confirm your network topology for this deployment type.
  - Obtain the Chef 360 distribution package and any required plugins by your
    approved process.

Installation material for BYOK is not available through the standard portal
download flow. Contact Progress to confirm the correct route for your license.

Authoritative documentation:
  https://docs.chef.io/360/1.7/install/server/implicit/install/
EOF
    ;;
  *) printf 'Architecture must be 1, 2, 3, or 4.\n' >&2; exit 2 ;;
esac
