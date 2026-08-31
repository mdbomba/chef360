# Chef Workstation 25

Chef Workstation is the administrator and developer tool suite used to create,
test, and operate Chef content. It packages a supported set of command-line
tools and runtimes so users do not have to assemble independent Ruby gems and
dependencies.

The lab inventory declares Chef Workstation 25.14.2 on `fury.demo.lab`. It also
declares Chef Infra Client 18.10.17, Chef InSpec 5.24.7, Chef CLI 5.6.23, Chef
Habitat 1.6.1243, Test Kitchen 4.0.0, and Cookstyle 8.6.10. Those are declared
inventory values and should be rechecked with `chef --version` after the host is
available.

## Included Workflows and Tools

- `chef` generates cookbooks, policies, custom resources, and other artifacts.
- `knife` interacts with Chef Infra Server and bootstraps Infra Client nodes.
- `chef install`, `chef export`, and `chef push` manage Policyfile workflows.
- `cookstyle` performs Chef-aware Ruby linting and autocorrection.
- `kitchen` creates disposable test instances and runs converge and verification.
- `inspec` authors and executes compliance and infrastructure tests.
- `chef-client` applies Chef Infra recipes locally or as an enrolled client.
- `chef-shell` provides an interactive Chef Infra debugging environment.

This lab also installs the Chef 360-specific `chef-platform-auth-cli`,
`chef-node-management-cli`, and `chef-courier-cli`. They are separate CLIs and
may have their own release cadence, profiles, and authentication behavior.

## Installation and Version Checks

Install the package for the correct supported operating system and architecture
from Chef's package distribution. Package-manager commands and filenames vary
by platform and release. After installation, start a new shell and verify:

```bash
chef --version
chef env
knife --version
inspec version
kitchen version
cookstyle --version
```

Use the output from `chef --version` to capture the complete bundled tool set.
Do not assume two Workstation 25 installations contain identical component
versions; update releases can change the bundle.

## Chef Infra Configuration

Chef Infra Server access normally uses `~/.chef/config.rb` plus a client or user
private key. Common settings include:

```ruby
current_dir = File.dirname(__FILE__)
log_level :info
node_name '<USER_NAME>'
client_key "#{current_dir}/<USER_NAME>.pem"
chef_server_url 'https://chef.example.test/organizations/<ORG_NAME>'
trusted_certs_dir "#{current_dir}/trusted_certs"
```

Validate connectivity and trust before write operations:

```bash
knife ssl check
knife client list
```

Only fetch a certificate with `knife ssl fetch` after independently confirming
its fingerprint. Private keys under `~/.chef` should be owner-readable only and
must not be committed to source control.

## Cookbook Workflow

```bash
chef generate cookbook <COOKBOOK_NAME>
cookstyle <COOKBOOK_PATH>
kitchen list
kitchen test
```

`kitchen test` normally creates an instance, converges it, verifies it, and
destroys it. Review `.kitchen.yml` first because drivers can create billable
cloud resources or alter reachable machines. Prefer ephemeral test instances
and pin cookbook dependencies.

## Policyfile Workflow

A Policyfile defines cookbook sources and a run list. A typical workflow is:

```bash
chef install Policyfile.rb
chef export Policyfile.rb <EXPORT_DIRECTORY>
chef push <POLICY_GROUP> Policyfile.lock.json
```

`chef install` resolves dependencies and creates `Policyfile.lock.json`.
Commit the Policyfile and lock file so automation uses the reviewed dependency
set. `chef push` changes server-side policy content and requires an explicit,
reviewed policy group.

## Chef 360 Administration

Chef 360 CLIs use Chef Platform authentication profiles rather than the classic
Chef Infra `config.rb` identity model. Use the references under `../cli/` for
the project workflow, then verify commands against the installed CLI help.

Before an automated Chef 360 action:

1. Confirm the intended Chef 360 endpoint and tenant or organization context.
2. Confirm the active authentication profile without printing its secret.
3. Check the platform certificate chain.
4. Use read-only list or status commands before mutations.
5. Record object IDs returned by successful mutations rather than parsing
   display text.

Do not treat Chef Infra Server credentials, Chef Automate API tokens, and Chef
360 platform credentials as interchangeable.

## Automation Guidance

- Execute tools directly with argument arrays instead of building shell strings.
- Set noninteractive modes where supported and impose command timeouts.
- Capture stdout, stderr, exit status, tool version, and target profile.
- Parse documented JSON output when available instead of terminal tables.
- Separate read-only inspection tools from mutating tools and require approval
  for enrollment, policy upload, bootstrap, job submission, or credential
  rotation.
- Redact private keys, passwords, access tokens, refresh tokens, and enrollment
  credentials from results and logs.
- Use `chef exec <COMMAND>` when a Ruby-based tool must run in Workstation's
  packaged environment rather than the system Ruby environment.

## Official Sources

- Workstation 25 overview: https://docs.chef.io/workstation/25/
- Installation: https://docs.chef.io/workstation/25/install/
- Setup: https://docs.chef.io/workstation/25/set_up/
- Configuration: https://docs.chef.io/workstation/25/config/
- Workstation tools: https://docs.chef.io/workstation/25/tools/
- Cookstyle: https://docs.chef.io/workstation/cookstyle/
- Current version index: https://docs.chef.io/workstation/

Use documentation matching the installed Workstation major version. Confirm
CLI help locally before relying on release-sensitive flags.
