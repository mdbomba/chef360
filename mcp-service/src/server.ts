import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

import { registerLabTools } from "./tools/lab.js";
import { registerSearchKnowledge } from "./tools/search-knowledge.js";

export function createServer(): McpServer {
  const server = new McpServer({
    name: "chef360-mcp-service",
    version: "0.1.0",
  });

  registerLabTools(server);
  registerSearchKnowledge(server);
  return server;
}
