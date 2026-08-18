import assert from "node:assert/strict";
import { createServer } from "node:net";
import test from "node:test";

import { checkTcpPort, labMachines } from "../src/lib/lab.js";

test("defines the expected Chef lab machines", () => {
  assert.deepEqual(Object.keys(labMachines), [
    "chef360",
    "automate",
    "node1",
    "node2",
  ]);
  assert.equal(labMachines.chef360.domain, "20_chef360");
  assert.equal(labMachines.chef360.servicePort, 31000);
  assert.equal(labMachines.automate.ip, "10.0.0.21");
});

test("checks TCP reachability", async () => {
  const server = createServer();
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));

  try {
    const address = server.address();
    assert.ok(address && typeof address !== "string");
    assert.equal(await checkTcpPort("127.0.0.1", address.port), true);
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  }
});
