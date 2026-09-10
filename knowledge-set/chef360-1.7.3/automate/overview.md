# Chef Automate

Chef Automate is an enterprise visibility and reporting platform for Chef
infrastructure, compliance, and application automation. It collects Chef Infra
Client run data, Chef Infra Server actions, and Chef InSpec scan results, then
presents current state, history, trends, failures, and audit evidence through a
web UI and APIs.

For Chef 360 1.7.3, Chef Automate is a separate product from Chef 360 Platform.
The Automate Connector is new in Chef 360 1.7.3 and bridges selected Chef 360
data into that separate Automate deployment. In this lab the declared Automate
endpoint is `https://10.0.0.21`, but availability must be checked before use
because the VM may be powered off.

Progress Chef has stated an intent to bring Automate capabilities into Chef 360.
If and when a release delivers those integrated capabilities, the separate
Automate Connector might no longer be required. This is product direction, not
a guarantee about a particular future release. Review the target Chef 360
release notes, upgrade documentation, data migration requirements, and supported
architecture before removing an existing connector or Automate deployment.

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

## Configure the Chef 360 Automate Connector

The Chef 360 **Automate Connector**, introduced in Chef 360 1.7.3, requires two
values:

| Chef 360 field | Value |
|---|---|
| Data Collector URL | The Automate HTTPS origin plus `/data-collector/v0/` |
| API Key | An API token generated on the Chef Automate server |

On the Automate server, create a dedicated token for the connector:

```bash
sudo chef-automate iam token create chef360-data-collector --admin
```

The command returns the token value. Capture it at creation time and place that
value in the Chef 360 connector's **API Key** field. Although Chef 360 labels the
field **API Key**, the supplied credential is a Chef Automate API token.

For the KVM lab, configure:

```text
Data Collector URL: https://10.0.0.21/data-collector/v0/
API Key:            <token returned by chef-automate>
```

The API key is secret. Do not add it to `chef360.parameters.env`, Terraform
variables files, the knowledge set, shell history, or command output retained in
logs. Store it in a secret manager or protected environment variable when the
connector is configured through automation. Use a dedicated token so it can be
rotated or revoked without affecting unrelated Automate integrations.

An admin token is the direct setup method shown here. If the installed Automate
release supports a narrower policy for data ingestion, prefer a dedicated
least-privilege token after validating the required permissions for that
release.

## Connector Lifecycle and Upgrades

Treat this connector configuration as specific to Chef 360 1.7.3 and other
releases that explicitly document support for the external Automate Connector.
Do not assume the connector remains necessary or compatible after an upgrade.

Before upgrading Chef 360:

1. Review the target release notes for integrated Automate, reporting,
   compliance, and data-ingestion capabilities.
2. Confirm whether the external Automate Connector remains supported, optional,
   deprecated, or replaced.
3. Identify any migration requirements for historical Automate data, API tokens,
   certificates, dashboards, reports, and retention policies.
4. Keep the existing Automate deployment and connector operational until the
   replacement path has been validated and required historical data is
   preserved.
5. Revoke the dedicated connector token only after Chef 360 no longer sends data
   to the external Automate data collector.

Do not infer from the stated product direction that a specific release contains
the replacement. The documentation for the installed and target releases is
authoritative.

## Data Flow

Chef Infra Client run data and Chef Infra Server actions are submitted to
Automate's data collector. InSpec results may arrive from direct scans, scan
jobs, or integrated Chef workflows. Automate indexes and retains the submitted
data according to its lifecycle configuration, making it available to reports,
dashboards, notifications, feeds, and APIs.

Construct the **Data Collector URL** by appending `/data-collector/v0/` to a
Chef Automate HTTPS address that resolves and is reachable from the Chef 360
application pods:

```text
https://<automate-host>/data-collector/v0/
```

For the KVM lab, the complete value is:

```text
https://10.0.0.21/data-collector/v0/
```

Use the Data Collector URL, including the trailing slash, rather than the
Automate UI base URL `https://10.0.0.21`.

### Private lab DNS behavior

An `/etc/hosts` entry on the Chef 360 node affects host processes but is not
automatically inherited by Kubernetes pods. CoreDNS forwards non-cluster names
to the node resolver. In the reviewed KVM lab, that resolver should be the
libvirt-managed dnsmasq service at `10.0.0.1`, which reads the KVM host's
`/etc/hosts` and forwards public queries upstream.

The IP-based connector URL was verified before pod-visible private DNS was
configured:

```text
https://10.0.0.21/data-collector/v0/
```

A request without an API token returns HTTP `401`, confirming network
reachability. To use `https://automate.demo.lab/data-collector/v0/`, configure
the Chef 360 node to use `10.0.0.1` for DNS and verify the name from a pod. A
node-only hosts entry with a public upstream resolver is insufficient.

In the completed KVM lab, a 500-query pod-level CoreDNS burn test completed with
zero failures, and the Automate data-collector endpoint returned the expected
unauthenticated HTTP `401` by FQDN. The connector was then successfully
configured with:

```text
https://automate.demo.lab/data-collector/v0/
```

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
