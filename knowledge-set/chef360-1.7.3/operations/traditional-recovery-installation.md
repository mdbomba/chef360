# Traditional And Recovery Installation

Chef 360 installation starts with a prepared Linux host and the authorized
distribution package. The downloaded package contains the entitlement-specific
`license.yaml`; do not store that file, the installer, an exported ConfigValues
file, or private TLS material in source control.

## Traditional Installation

Use traditional installation when no ConfigValues export exists. Download the
online or air-gapped package, install Chef 360, and complete configuration in
the Admin Console. A hostname, an Admin Console password, and a matching TLS
certificate/key pair are optional installation inputs that make this initial
setup more complete.

## Recovery Or Repeatable Installation

After a working installation is configured, use the Admin Console **View files**
menu to export `config.yaml`. Keep the export with the authorization-specific
license and any private TLS material in protected storage. Use those local
inputs during a replacement-host rebuild to pass ConfigValues to the installer
and reproduce the configuration.

The ConfigValues export is environment-specific. Do not treat it as a public
generic template or commit it to a repository.

## Preflight Warnings

The Chef 360 installer can treat warnings as blocking. In the reviewed private
address-space lab, DNS produces a known warning even after independent host and
DNS validation succeeds. Use any host or application preflight bypass only when
the warning is understood and the underlying requirements have been checked.
