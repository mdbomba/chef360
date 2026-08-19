# Security

## Credentials

Do not commit Chef credentials, GitHub tokens, Azure CLI state, SSH private keys, signed enrollment configurations, generated Courier credentials, or runtime response files.

Use the checked-in `*.example` files as templates and keep populated copies local. The root `.gitignore` excludes common credential and runtime-state paths.

## Public Repository Scope

This repository contains public-safe automation and documentation. Private/internal `chef-cft` metadata, downloaded source corpora, generated SQLite indexes, and organization-specific knowledge are intentionally excluded.

## Reporting

If a credential is committed, revoke or rotate it immediately before removing it from the repository. Git history removal alone does not invalidate an exposed secret.
