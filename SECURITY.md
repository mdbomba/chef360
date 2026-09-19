# Security

## Credentials

Do not commit Chef credentials, GitHub tokens, Azure CLI state, SSH private keys,
signed enrollment configurations, generated Courier credentials, Chef 360
authorization codes, downloaded `license.yaml` files, or runtime response files.

Use checked-in `*.example` files as templates and keep populated copies local.
The root `.gitignore` excludes common credential and runtime-state paths.

Some versions of `chef-platform-auth-cli get-default-profile` print stored
access and secret keys. Do not use that command for routine status checks or
captured diagnostics. Use `list-profile-names` and profile-scoped read commands.

Controller-initiated node enrollment may send an SSH private key or password to
the Chef 360 enrollment API. Use a temporary request file, avoid logging its
body, and prefer node-side signed-configuration enrollment when that credential
transfer is not acceptable.

## Public Repository Scope

This repository contains public-safe automation, documentation, a versioned
Chef 360 knowledge set, and MCP implementations. Private/internal `chef-cft`
metadata, downloaded source corpora, generated SQLite indexes, customer
exports, and organization-specific host context are intentionally excluded.

The Python MCP supports those protected files as an optional local overlay;
their absence must not prevent public knowledge tools from operating.

## Reporting

If a credential is committed, revoke or rotate it immediately before removing
it from the repository. Git history removal alone does not invalidate an
exposed secret.
