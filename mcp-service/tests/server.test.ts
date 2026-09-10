import assert from "node:assert/strict";
import test from "node:test";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";

import { createServer } from "../src/server.js";

test("introduces the service without overwhelming the client", async () => {
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const server = createServer();
  const client = new Client({ name: "onboarding-test", version: "1.0.0" });

  try {
    await server.connect(serverTransport);
    await client.connect(clientTransport);

    const instructions = client.getInstructions() ?? "";
    assert.ok(instructions.length > 0 && instructions.length <= 350);
    assert.match(instructions, /Read-only/);
    assert.match(instructions, /Chef 360 1\.7\.3/);

    const tools = await client.listTools();
    const names = tools.tools.map((tool) => tool.name);
    assert.ok(names.includes("search_knowledge"));
    assert.ok(names.includes("get_chef360_document"));
    assert.ok(names.includes("get_chef_service_overview"));

    const overview = await client.callTool({
      name: "get_chef_service_overview",
      arguments: {},
    });
    assert.equal(overview.isError, undefined);
    const structured = overview.structuredContent as {
      service: { readOnly: boolean };
      knowledge: { version: string };
      sources?: unknown;
    };
    assert.equal(structured.service.readOnly, true);
    assert.equal(structured.knowledge.version, "1.7.3");
    assert.equal(structured.sources, undefined);

    const resources = await client.listResources();
    assert.ok(resources.resources.some((resource) => resource.uri === "chef360://service/overview"));
  } finally {
    await client.close();
    await server.close();
  }
});
