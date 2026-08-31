# Chef Automate

Chef Automate is an enterprise visibility and reporting platform for Chef
infrastructure, compliance, and application automation. It collects Chef Infra
Client run data, Chef Infra Server actions, and Chef InSpec scan results, then
presents current state, history, trends, failures, and audit evidence through a
web UI and APIs.

Chef Automate is a separate product from Chef 360 Platform. In this lab the
declared Automate endpoint is `https://10.0.0.21`, but availability must be
checked before use because the VM may be powered off.

## Primary Capabilities

- Infrastructure dashboards for nodes, Chef Infra Client runs, cookbooks,
  policy groups, and Chef Infra Servers
- Compliance profiles, scan jobs, reports, trends, and historical audit data
- Event feed and notifications for configuration and compliance failures
- Data feeds to services such as ServiceNow, Splunk, and ELK/Kibana
- Local users and teams, external SAML or LDAP authentication, and IAM policies
- API access for compliance, nodes, events, secrets, users, and administration
- Backup, restore, monitoring, data lifecycle, and high-availability options

Automate is primarily an observability, compliance, and governance plane. It
does not replace the Chef 360 node enrollment and Courier job lifecycle.

## Architecture

Public requests pass through the Automate Gateway, where authentication and
authorization are enforced. Important internal services include:

- Deployment Service for initial setup and configuration patches
- Configuration Management Service for Infra Client and Infra Server data
- Ingest Service for configuration event ingestion and data lifecycle
- Compliance Service for InSpec profiles, scan jobs, results, and reports
- Notification Service for event-driven notifications
- AuthN, AuthZ, Users, Teams, and Session services for identity and access
- Secrets Service for credentials used by other services
- OpenSearch for indexed operational and compliance data
- PostgreSQL for relational application data
- Dex as an OIDC provider and bridge to LDAP, SAML, or OIDC identity providers

The documented architecture supports a standalone deployment and a separate
high-availability topology. Select sizing, database, storage, load-balancer,
certificate, backup, and disaster-recovery designs from the official
requirements for the exact Automate release being deployed.

## Installation and Administration

The `chef-automate` CLI installs and administers Automate. A typical standalone
installation uses a deployment configuration generated or supplied to the CLI;
the exact flags and prerequisites vary by Automate release.

Common administrative operations include:

```bash
chef-automate status
chef-automate config show
chef-automate config patch config.toml
chef-automate backup create
chef-automate upgrade run
```

Do not run installation, configuration, upgrade, or restore commands until the
target release, system requirements, backup status, and configuration have been
confirmed. Configuration patches are operational changes and should be reviewed
before execution.

## API Authentication

Chef Automate API requests authenticate with API tokens. Tokens receive
permissions through IAM policies and projects; a newly created token has no
permissions unless a policy grants them. Admin tokens have full access and
should be reserved for controlled administration.

An admin token can be created on the Automate host:

```bash
chef-automate iam token create <TOKEN_NAME> --admin
```

Clients send the token in the `api-token` header:

```bash
curl --header "api-token: $AUTOMATE_TOKEN" \
  https://automate.example.test/apis/iam/v2/policies
```

Store tokens in a secret manager or protected environment variable. Never add
token values to this knowledge set, source control, command output captured in
logs, or AI prompts. Trust the deployment CA instead of disabling TLS checks.

## Data Flow

Chef Infra Client run data and Chef Infra Server actions are submitted to
Automate's data collector. InSpec results may arrive from direct scans, scan
jobs, or integrated Chef workflows. Automate indexes and retains the submitted
data according to its lifecycle configuration, making it available to reports,
dashboards, notifications, feeds, and APIs.

For node automation, a useful validation sequence is:

1. Provision and enroll the node in Chef 360.
2. Verify Chef 360 check-in and required skills.
3. Run configuration or compliance work.
4. Verify the expected InSpec result or Infra Client run reaches Automate.
5. Return Chef 360 management status and Automate evidence as separate results.

Do not infer that a node is enrolled in Chef 360 merely because historical data
for a similarly named node exists in Automate.

## Operational Safety

- Check DNS or IP reachability and HTTPS health before API operations.
- Use least-privilege API tokens and project-scoped IAM policies.
- Validate certificates and rotate tokens and certificates through controlled
  procedures.
- Back up before upgrades or material configuration changes and test restores.
- Monitor disk usage, data retention, service status, ingestion failures, and
  clock synchronization.
- Treat node credentials in Automate's Secrets Service as secrets, not inventory.

## Official Sources

- Overview: https://docs.chef.io/automate/
- Architecture: https://docs.chef.io/automate/architectural_overview/
- Installation: https://docs.chef.io/automate/install/
- System requirements: https://docs.chef.io/automate/system_requirements/
- CLI: https://docs.chef.io/automate/cli/
- API: https://docs.chef.io/automate/api/
- API tokens: https://docs.chef.io/automate/api_tokens/
- Data collection: https://docs.chef.io/automate/data_collection/
- Backup and restore: https://docs.chef.io/automate/backup/

The Automate documentation is not tied to Chef 360 version 1.7.3. Confirm the
installed Automate version before using release-sensitive commands or settings.
