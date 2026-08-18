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
