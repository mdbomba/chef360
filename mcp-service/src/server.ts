import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { existsSync } from "node:fs";
import path from "node:path";

import { registerLabTools } from "./tools/lab.js";
import { registerOverview, SERVICE_NAME, SERVICE_VERSION, serviceInstructions } from "./tools/overview.js";
import { registerSearchKnowledge } from "./tools/search-knowledge.js";

function commandAvailable(command: string): boolean {
  return (process.env.PATH ?? "")
    .split(":")
    .some((directory) => directory && existsSync(`${directory}/${command}`));
}

export function createServer(): McpServer {
  const labToolsAvailable = commandAvailable("virsh") && commandAvailable("chef");
  const server = new McpServer(
    { name: SERVICE_NAME, version: SERVICE_VERSION },
    { instructions: serviceInstructions(labToolsAvailable) },
  );

  if (labToolsAvailable) registerLabTools(server);
  registerOverview(server, labToolsAvailable);
  registerSearchKnowledge(server);
  return server;
}
