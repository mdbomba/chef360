import assert from "node:assert/strict";
import test from "node:test";
import path from "node:path";

import { searchKnowledge } from "../src/lib/knowledge.js";

test("searches the Chef 360 knowledge set", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const results = await searchKnowledge(knowledgePath, "node enrollment", 3);

  assert.ok(results.length > 0);
  assert.ok(results[0].path.endsWith(".md"));
});

test("ranks focused documents instead of filesystem order", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const results = await searchKnowledge(
    knowledgePath,
    "provider neutral Terraform Proxmox guest contract",
    3,
  );

  assert.equal(results[0]?.path, "operations/infrastructure-automation.md");
  assert.equal(results[0]?.version, "1.7.3");
  assert.equal(results[0]?.id, "operations-infrastructure-automation");
});

test("exposes the mandatory Azure node access prerequisite", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const results = await searchKnowledge(
    knowledgePath,
    "mandatory first step for every Azure-node request",
    3,
  );

  assert.equal(results[0]?.path, "operations/azure-node-access.md");
  assert.match(results[0]?.excerpt ?? "", /api\.ipify\.org/);
});

test("searches the related Chef product knowledge", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const queries = [
    ["Automate Gateway", "automate/overview.md"],
    ["compliance-as-code", "inspec/overview.md"],
    ["Policyfile workflow", "workstation/overview.md"],
  ] as const;

  for (const [query, expectedPath] of queries) {
    const results = await searchKnowledge(knowledgePath, query, 5);
    assert.ok(results.some((result) => result.path === expectedPath));
  }
});

test("exposes provider-neutral installation guidance", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const queries = [
    ["Common Provisioner Contract", "operations/infrastructure-automation.md"],
    ["ConfigValues and Command-Line Installation", "operations/config-values-installation.md"],
  ] as const;

  for (const [query, expectedPath] of queries) {
    const results = await searchKnowledge(knowledgePath, query, 5);
    assert.ok(results.some((result) => result.path === expectedPath));
  }
});

test("finds the Automate connector API key procedure", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const results = await searchKnowledge(
    knowledgePath,
    "Configure the Chef 360 Automate Connector",
    5,
  );

  assert.ok(results.some((result) => result.path === "automate/overview.md"));
});

test("finds the Automate connector upgrade lifecycle", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const results = await searchKnowledge(
    knowledgePath,
    "Connector Lifecycle and Upgrades",
    5,
  );

  assert.ok(results.some((result) => result.path === "automate/overview.md"));
});

test("finds KVM autoinstall and Netplan troubleshooting", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const results = await searchKnowledge(
    knowledgePath,
    "autoinstall Netplan ftype Mailpit",
    5,
  );

  assert.equal(results[0]?.path, "operations/kvm-lab-deployment.md");
});

test("finds private pod DNS guidance for the Automate connector", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const results = await searchKnowledge(
    knowledgePath,
    "CoreDNS private lab Automate",
    5,
  );

  assert.ok(results.some((result) => result.path === "automate/overview.md"));
});

test("finds libvirt dnsmasq provisioning guidance", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const results = await searchKnowledge(
    knowledgePath,
    "libvirt dnsmasq public upstream",
    5,
  );

  assert.ok(results.some((result) => result.path === "operations/kvm-lab-deployment.md"));
});

test("finds the validated Automate FQDN burn test", async () => {
  const knowledgePath = path.resolve("../knowledge-set/chef360-1.7.3");
  const results = await searchKnowledge(
    knowledgePath,
    "500 query CoreDNS burn test automate FQDN",
    5,
  );

  assert.ok(results.some((result) => result.path === "automate/overview.md"));
});
