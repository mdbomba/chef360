# Security

## Credentials

Do not commit Chef credentials, GitHub tokens, Azure CLI state, SSH private keys,
signed enrollment configurations, generated Courier credentials, or runtime
response files.

Use checked-in `*.example` files as templates and keep populated copies local.
The root `.gitignore` excludes common credential and runtime-state paths.

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
