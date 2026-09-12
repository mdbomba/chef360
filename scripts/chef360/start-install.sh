#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat <<'EOF'
Choose a Chef 360 installation path:
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
