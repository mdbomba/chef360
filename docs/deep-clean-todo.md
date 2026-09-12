# Deep Clean TODO

Open items collected from a full audit of `scripts/kvm/`, the rest of `scripts/`,
the docs tree, CI, and repo conventions (Sep 2026). Each item is independent;
tackle in order of the priority groups.

## P0 — Secrets hygiene (do first)

Threat model (confirmed with operator): committed secrets are throwaway lab material —
private addressing, no inbound connections, nets destroyed/replaced weekly. This is
**hygiene, not exposure**. Goal: the repo is never the source of truth for secrets; real
material lives outside the tree in `~/certs`, `~/.ssh`, `~/.secrets` and is referenced or
sourced at runtime.

- [ ] **Strip the embedded secrets from `knowledge-set/chef360-1.7.3/examples/kots-config.yaml`**
      — remove the real `-----BEGIN PRIVATE KEY-----` blob (:43) and the admin tokens
      `devsecops_progress` (:29, :56). Keep the file as an example with placeholder values
      and a comment pointing operators to `~/certs/chef360.key` / `~/certs/chef360_chain.crt`.
      (Certs are lab-owned and regenerated; either replace or annotate as examples.)
- [ ] **Parameterize the SSH key in `kots-demo-stand-main/terraform/aws/modules/chef360/scripts/ansible-client.tpl:5-11`**
      — stop embedding the base64 ed25519 key. Inject at plan time from `~/.ssh/...` via a
      terraform variable / `file()`, or ship a placeholder the operator replaces before `apply`.
- [ ] **Document the external-secrets convention** — add a "Secrets and local files" section
      (README or docs/) codifying the contract: TLS material in `~/certs/`, SSH keys in
      `~/.ssh/`, tokens/credentials in `~/.secrets/`; everything under those paths is
      per-operator and never tracked. The KVM lib already defaults to `~/certs/${VM_NAME}.crt`
      (lib:110-114) and `~/.ssh/fury_rsa` (lib:84) — make the azure/terraform/userdata tooling
      follow the same convention instead of hardcoding.
- [ ] **Keep a secret-scan gate in CI** (gitleaks/trufflehog + pre-commit) blocking
      `BEGIN PRIVATE KEY` blobs and `ghp_`/`gho_` tokens — a guard against secrets drifting
      back in, not the cleanup itself.
- [ ] **Fix `provision-chef360-data-disk.sh` command injection risk**
      — `data_disk`/`uuid` are read back from remote `lsblk`/`blkid` and inlined into the next
      remote command (lines 61, 87-89, 95, 101, 105, 111). Whitelist-validate
      (`^[a-zA-Z0-9]+$` for the disk, `^[0-9A-Fa-f-]{36}$` for UUID) and pass values via
      `env` rather than string interpolation.
- [ ] **Validate `VM_USER`** in `create-chef360-plan.sh` (only `VM_HOSTNAME` is validated today);
      `stage-chef360-install-inputs.sh:59,62,78` interpolates it into remote commands.
      Allow `^[a-z_][a-z0-9_-]*$`.
- [ ] **`sudo -n apt-get` in `provision-chef360-data-disk.sh:83-84`** — uses interactive sudo,
      which can hang a batch run; switch to `-n` and document passwordless-sudo requirement.

## P1 — Find and fix the "adventurous" control-flow bugs

- [ ] **`&&`/`||` misuse in both validators** — `validate-chef360-vm.sh:22-25,32-48` and
      `validate-chef360-deployment.sh:90-97,111-138,147,181-190,202-205,219-223` rely on
      `pass` returning 0; any check that fails in a `pass ... || fail_check` chain silently
      inverts logic. Convert to `if cond; then pass; else fail_check; fi`.
- [ ] **Silent `set -e` aborts before diagnostics** — command substitutions that die before
      their intended `fail`:
      `fetch-ubuntu-iso.sh:40`, `check-libvirt-dns.sh:14`, `deploy-chef360-vm.sh:50`,
      `install-chef360.sh:95`, `stage-chef360-install-inputs.sh:51`,
      `bootstrap-kvm-host.sh:59,84-85`, validator getent/ssh-keygen/hostnamectl subs (34-48).
      Add `|| fail "...diagnostic message"`.
- [ ] **`validate-chef360-deployment.sh:219` treats any 3-digit HTTP code as PASS**
      — accept only `^2[0-9][0-9]$` (warn, not pass, on 3xx).
- [ ] **`curl` without `--fail` + empty-response Mailpit polling**
      (`validate-chef360-deployment.sh:234,251,271`) — log the curl status in the WAIT line
      so an empty JSON does not silently time out.
- [ ] **`local` global leak** — `lib-chef360-kvm.sh:306` `read -r _ oct2 oct3 oct4` writes
      `oct2/oct3/oct4` into global scope; declare `local oct2 oct3 oct4 _` and delete the
      unused `local oct` (also SC2034 at :305).
- [ ] **Brittle XML scraping** — `create-chef360-plan.sh:195-204` (awk `RS="</disk>"` magic
      offsets) and `lib-chef360-kvm.sh:324` (`virsh dumpxml | sed ... | head -1`) feed
      destructive ops. Port both to the Python `xml.etree` helper already used in
      `finalize-chef360-vm-boot.sh:15-33`, keyed by target device.
- [ ] **HTTP code 301 gate** — `install-chef360-workstation-clis.sh:73` shebang check uses
      `head -n 1 | grep -Eq '^#!.*(ba)?sh'`; CRLF breaks it. Use `read -r first` + anchored
      pattern.

## P2 — Kill duplication in `scripts/kvm/`

- [ ] **Extract shared SSH execution into `lib-chef360-kvm.sh`** — the option tuple
      `-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i "$SSH_PRIVATE_KEY"`
      is respelled 6+ times (`install-chef360.sh:87-93`, `stage-chef360-install-inputs.sh:44-50`,
      `validate-chef360-deployment.sh:99-105`, `validate-chef360-vm.sh:29,31`,
      `provision-chef360-data-disk.sh:41`, checkpoint 59-60/72-73 with `ConnectTimeout=5` drift).
      Ship `ssh_remote()` / `ssh_run()`; delete the dead `ssh_options()` at `lib:291-297`.
- [ ] **Share the guest preflight checks** — `validate-chef360-deployment.sh:89-138`
      duplicates nearly all of `validate-chef360-vm.sh:21-51` (XML probes, getent, swap/XFS,
      systemd, authorized_keys). Extract one `guest_preflight_checks` used by both.
- [ ] **One TLS-cert verification bundle** — the `openssl verify -verify_hostname/-verify_ip`
      + DER-public-key-sha256 logic is copy-pasted 5x with subtle drift
      (`generate-chef360-config.sh:82-88`, `prepare-chef360-install-inputs.sh:29-35`,
      `issue-chef360-certs.sh:102-110,144-146`, `create-chef360-plan.sh:321-352`).
      Add `verify_tls_cert cert key chain hostname ip` to lib.
- [ ] **`assert_chef360_version` in lib** — the `| chef-360 ... 1.7.3 |` grep is repeated
      5x (`acquire-chef360-assets.sh:94`, `prepare-chef360-install-inputs.sh:26-27`,
      `stage-chef360-install-inputs.sh:74`, `install-chef360.sh:110`,
      `validate-chef360-deployment.sh:138`). Parameterize the version.
- [ ] **Rename the shadowing soft-fail helpers in `create-chef360-plan.sh:57-72`**
      (`require_file`/`require_command` locally redefine the lib versions with *different*
      failure semantics). Either lift multi-file counting into lib or name them
      `require_file_soft`/`require_command_soft`.
- [ ] **Centralize wait/poll loops** — 7 hand-rolled loops differ only in constants
      (checkpoint SSH 56-68, data-disk SSH 43-53, autoinstall poweroff 207-215, pod/Mailpit/
      email loops in `validate-chef360-deployment.sh:140-266`, CLI download retry at
      `install-chef360-workstation-clis.sh:66-83`). Add `wait_for_ssh`, `wait_for "label"`,
      and `download_with_retries` helpers.
- [ ] **Shared VM-state / network / MAC helpers** — `assert_vm_state`, `assert_libvirt_network_active`,
      `resolve_fqdn_ip`, `get_vm_mac` collapse 2-4 copies each (see audit Themes 4.4-4.8).
- [ ] **Hostname/marker/identity triple** — `hostname -f` + `sudo -n true` + readness-marker
      checks are re-sent in `install-chef360.sh:95-101`, `stage-chef360-install-inputs.sh:51-56`,
      `deploy-chef360-checkpoint.sh:72-75`, and both validators; make `assert_guest_identity()`
      + `assert_guest_readiness()` (skip the marker when `PROVISION_METHOD=existing`).
- [ ] **Merge the duplicated staging/verify heredoc** — `stage-chef360-install-inputs.sh:62-76`
      and `install-chef360.sh:103-116` both test the same `/opt/chef360` tree.

## P3 — Cross-provider and azure duplication

- [ ] **Extract `scripts/lib/azure-common.sh`** — the preamble + `log_step`/`fail`/
      `require_command`/`seed_host_key_if_missing`/`wait_for_ssh` blocks are duplicated
      across 8 azure `.sh` files (e.g. `deploy-azure-two-linux.sh:4-10,30-71`; audit Theme 2.1/2.2).
- [ ] **Extend `scripts/lib/Import-Chef360Parameters.ps1`** with the common helpers currently
      redefined in each `.ps1` (`Write-Step`, `Require-Command`, `Seed-HostKeyIfMissing`,
      `Invoke-Checked`, state-hashtable loader) — 4-5 files shrink substantially.
- [ ] **One CLI-installer contract** — workstation CLI download/install logic exists in
      `install-chef360-workstation-clis.sh`, `register-chef360-nodes.sh:161-165` (azure), and
      `kots-demo-stand-main/.../workstation.tpl`. Extract a single
      `install_chef360_clis.sh` in `scripts/lib/`.
- [ ] **Document the AWS terraform imports as intentional divergences** in README
      (install/certs logic is a 3rd/4th copy inside `kots-demo-stand-main/` and
      `chef-360-single-node-terraform-main/` userdata), so future diffs are expected.

## P4 — Docs: de-duplicate and repair contradictions

- [ ] **Retire or fold in `docs/Chef360_Quick_Start_Guide_20260902_1044.md`** — near-duplicate
      of `docs/quick-start/chef360-1.7.3-quick-start.md` with drift (`/boot` 5GB vs 1GB :244,
      XFS/ext4 recommendation inverted :483) and it is outside the CI `QUICK_START_FILES` check.
- [ ] **Reconcile ext4 vs XFS across guides** — quick-start docs recommend ext4 for
      `/var/lib` with XFS "acceptable" (`chef360-1.7.3-quick-start.md:262,483,776`,
      `checklist.md:54`), but the tested KVM lab and `install-chef360.sh:111-112` require XFS
      `ftype=1`. Make XFS `ftype=1` the primary recommendation.
- [ ] **Pick one node/IP schema** — Chef Automate 10.0.0.21 / node1 .23 / node2 .24
      (lib + config + project-plan) vs 21_automate/31_node1/32_node2 (mcp-service
      `src/lib/lab.ts:22-35`, `src/chef_knowledge_mcp/server.py:67-74`,
      `knowledge-set/.../lab/topology.md`). Align them or document the lineage.
- [ ] **Derive `chef360-2.*` cert basename from `VM_SHORT_HOSTNAME`** — the filename is
      hardcoded in `lib:198-202`, `install-chef360.sh:14-15`,
      `validate-chef360-deployment.sh:205`, `docs/kvm-chef360-lab.md:274-278`.
- [ ] **Fix SSH-key-name contradiction** — docs use `~/.ssh/mbomba_firefly(.pub)` but lib
      default + `validate-chef360-vm.sh:39` expect `fury_rsa.pub`. Add
      `SSH_PRIVATE_KEY=~/.ssh/mbomba_firefly` to `config/kvm-chef360.env` (gitignored) or
      update the docs.
- [ ] **VM_MAC default** — project-plan doc documents `52:54:00:20:00:20`; live build uses
      `52:54:00:1f:c2:eb`. Recompute the documented default from the IP or state it is generated.
- [ ] **`briefing-room/index.html`** hardcodes `chef360-2.demo.lab`/`10.0.0.40`/`devsecops`
      pre-filled values (lines 90, 94, 120-133, 144, 148, 179-191); update to
      `chef360.demo.lab`/`10.0.0.20` and stop pre-filling passwords.
- [ ] **README typo** — `README.md:78` documents endpoint `https://chef360.example.com:3100`
      (should be `31000`).
- [ ] **`knowledge-set/.../operations/azure-node-access.md:13-15`** uses personal identifiers
      (`rg-sa-linux-dev`/`mbomba-sa-linux`); substitute neutral example values.
- [ ] **Consolidate knowledge-set vs root docs** — `knowledge-set/chef360-1.7.3/operations/kvm-lab-deployment.md`
      duplicates `docs/kvm-chef360-lab.md` topics with different detail; pick one owner and
      link the other.

## P5 — CI and conventions

- [ ] **Shellcheck all scripts, not just `scripts/kvm`** — extend `scripts/ci` (bash -n +
      `shellcheck -S error`) to `scripts/azure/`, `scripts/chef360/`, `scripts/lib/`,
      `scripts/content/`, `scripts/mcp/`.
- [ ] **Run the mcp-service TypeScript tests in CI** — `mcp.yml` only runs Python; nothing
      runs `npm test` / `npm run build` (`mcp-service/package.json:14`,
      `mcp-service/tests/lab.test.ts`).
- [ ] **PS1 analysis** — add PSScriptAnalyzer for `scripts/azure/*.ps1`.
- [ ] **Markdown lint + cross-doc staleness guard** — add markdownlint and a port/hostname/IP
      consistency checker across `docs/**` + `knowledge-set/**` (a typo like `3100` vs `31000`
      is currently invisible).
- [ ] **Gate all root paths** — `.github/workflows` currently only trigger on
      `docs/quick-start/**`, `scripts/kvm`, mcp paths, and azure parity. Cover root `docs/*.md`,
      `infra/`, `config/*.example.env`.
- [ ] **Secret-scan CI job** (also listed in P0) + `pre-commit` config.
- [ ] **Repo conventions** — add `LICENSE`, `CODEOWNERS`, `CONTRIBUTING.md`, a docs-aware PR
      template (`github/pull_request_template.md` is azure-only today), and document required
      status checks.

## P6 — KVM basics and testability

- [ ] **Executable bits** — `chmod +x` `acquire-chef360-assets.sh`, `bootstrap-kvm-host.sh`,
      `fetch-ubuntu-iso.sh`, `issue-chef360-certs.sh` (all 0644 but run-by-path in the docs);
      `chmod -x` `lib-chef360-kvm.sh` (0755 but only ever `source`d).
- [ ] **Library strictness** — `lib-chef360-kvm.sh` has no `set -euo pipefail`; assert or
      document the dependency on the sourcing parent.
- [ ] **Word-splitting fixes** — `bootstrap-kvm-host.sh:42` (`for p in ${KVM_HOST_PACKAGES}` →
      array), `for x in $(seq ...)` → `{1..N}` across scripts (SC2046/SC2005).
- [ ] **Portability notes** — GNU-only flags used (`sed -i :334`, `date --iso-8601`,
      `df --output=avail`, `cp --reflink`, multi-dir `install -d`) — gate on GNU coreutils in
      `require_command` or switch to portable forms.
- [ ] **Password via stdin** — `generate-ubuntu-autoinstall.sh:19` passes the initial password
      to `openssl passwd -6` as an argv (visible in `ps`); feed via stdin (`-stdin`) with
      `read -rs`.
- [ ] **YAML-injection validation** — `generate-ubuntu-autoinstall.sh` expands plan values into
      cloud-config heredocs; validate `VM_HOSTNAME`/`VM_USER`/serials
      (`^[A-Za-z0-9._-]+$`) before generation (reuse the plan script's validators).
- [ ] **Tests for KVM scripts** — extract the pure validators (`validate_ip/mac/port/vm_name`,
      `persist_plan_value`, `resolve_clone_source`) into lib; add a
      `KVM_VIRSH_BIN`/`KVM_SSH_BIN` indirection and a `tests/kvm/` bats harness.