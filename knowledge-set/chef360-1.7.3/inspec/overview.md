# Chef InSpec 5.24

Chef InSpec is an executable compliance-as-code framework. It evaluates the
actual state of local or remote systems against human-readable controls written
in a Ruby-based DSL and returns pass, fail, skip, and error results. Tests are
read-only by design: InSpec detects drift and noncompliance but does not remediate
the target.

The lab inventory declares Chef InSpec 5.24.7 as part of Chef Workstation. This
guide therefore uses the InSpec 5.24 documentation. Newer InSpec releases are
available and may change supported platforms, plugins, licensing, or CLI flags.

## Core Model

- A **resource** retrieves target state, such as `file`, `package`, `service`,
  `port`, `command`, `user`, `sshd_config`, or a cloud resource.
- A **control** groups one or more expectations and carries an ID, title,
  description, impact, tags, and references.
- A **profile** is a versioned, distributable collection of controls, metadata,
  optional inputs, dependencies, libraries, and files.
- An **input** supplies environment-specific values without changing controls.
- A **waiver** marks a control as waived, optionally with justification and an
  expiration date.
- A **reporter** formats results for humans, files, CI systems, or services.
- A **transport** connects to a target such as local, SSH, WinRM, Docker, or a
  supported cloud platform.

## Profile Structure

```text
example-profile/
  inspec.yml
  controls/
    example.rb
  libraries/       # optional custom resources
  files/           # optional profile files
  README.md         # optional documentation
```

`inspec.yml` identifies the profile and can declare version, maintainer,
supported platforms, inputs, and dependencies. The `controls` directory and
`inspec.yml` are required.

Example control:

```ruby
control 'ssh-1' do
  impact 1.0
  title 'SSH root login is disabled'

  describe sshd_config do
    its('PermitRootLogin') { should cmp 'no' }
  end
end
```

Impact is conventionally between `0.0` and `1.0`. A failed high-impact control
is more significant than a failed low-impact control; impact is not the number
of failed tests.

## Authoring and Validation

Create and verify a profile:

```bash
inspec init profile <PROFILE_NAME>
inspec check <PROFILE_PATH>
```

Cloud-focused profile initialization supports `aws`, `azure`, and `gcp` through
the `--platform` option. Profile dependencies should be resolved and locked
before controlled distribution. Use version constraints and trusted sources to
avoid silently changing the controls being executed.

## Executing Profiles

Run locally:

```bash
inspec exec <PROFILE_PATH>
```

Run against Linux over SSH:

```bash
inspec exec <PROFILE_PATH> \
  --target ssh://<USER>@<HOST> \
  --key-files <PRIVATE_KEY_PATH>
```

Run against Windows using WinRM:

```bash
inspec exec <PROFILE_PATH> --target winrm://<USER>@<HOST>
```

Profiles may come from local directories, Git repositories, archives, and other
supported sources. Inputs can be supplied using profile input files or CLI
options, depending on the release. Credentials should be supplied through a
secret manager, protected environment, or secure transport configuration rather
than committed files or command history.

Common automation reporters include JSON and JUnit:

```bash
inspec exec <PROFILE_PATH> --reporter json:<RESULT_PATH>
inspec exec <PROFILE_PATH> --reporter cli junit2:<JUNIT_PATH>
```

Use `inspec help exec` on the installed version as the authoritative local list
of flags and reporters.

## Result Handling

Automation must inspect both the process exit status and structured report:

- A successful process can still contain skipped or waived controls.
- A failed control is different from a profile load, transport, credential, or
  resource execution error.
- Results should retain profile name and version, control ID, impact, target
  identity, timestamp, status, message, and waiver details.
- Do not summarize errors as noncompliance; distinguish an untested target from
  a tested target that failed controls.

## Chef Automate and Chef 360

Chef Automate stores, reports, and trends InSpec compliance results. Chef 360
can orchestrate node work through skills and Courier jobs. An InSpec execution
may therefore be used as a post-deployment validation step, while Automate holds
the resulting evidence. These are separate responsibilities:

- InSpec evaluates controls.
- Chef 360 enrolls nodes and orchestrates work.
- Automate ingests and presents compliance history.

For AI-driven deployment, use an approved profile with pinned dependencies,
explicit inputs, a timeout, structured output, and a policy that defines which
failed impacts block deployment. Never allow generated controls to execute on
production targets without review.

## Security and Reliability

- Run scans with the least privilege required by the resources in the profile.
- Validate SSH host keys and TLS certificates.
- Pin profile and dependency versions and verify signed profiles when required.
- Review custom resources because they execute Ruby code in the InSpec process.
- Give every waiver an owner, justification, and expiration date.
- Avoid placing passwords, private keys, tokens, or sensitive input values in
  profiles, reports, logs, or this knowledge set.

## Official Sources

- InSpec 5.24 overview: https://docs.chef.io/inspec/5.24/
- Profiles: https://docs.chef.io/inspec/5.24/profiles/
- Controls: https://docs.chef.io/inspec/5.24/profiles/controls/
- Inputs: https://docs.chef.io/inspec/5.24/profiles/inputs/
- Resources: https://docs.chef.io/inspec/5.24/resources/
- CLI reference: https://docs.chef.io/inspec/5.24/reference/cli/
- Reporters: https://docs.chef.io/inspec/5.24/configure/reporters/
- Waivers: https://docs.chef.io/inspec/5.24/configure/waivers/
- Current version index: https://docs.chef.io/inspec/
