import { createServer as createHttpServer } from "node:http";

import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";

import { config } from "./config.js";
import { createServer as createMcpServer } from "./server.js";
import { SERVICE_NAME, SERVICE_VERSION } from "./tools/overview.js";

const httpServer = createHttpServer(async (request, response) => {
  const url = new URL(request.url ?? "/", `http://${request.headers.host ?? "localhost"}`);

  if (request.method === "GET" && url.pathname === "/health") {
    response.writeHead(200, { "content-type": "application/json" });
    response.end(JSON.stringify({ status: "ok", service: SERVICE_NAME, version: SERVICE_VERSION }));
    return;
  }

  if (request.method === "GET" && url.pathname === "/") {
    response.writeHead(200, { "content-type": "application/json" });
    response.end(JSON.stringify({
      service: SERVICE_NAME,
      version: SERVICE_VERSION,
      readOnly: true,
      knowledgeVersion: "1.7.3",
      mcpEndpoint: "/mcp",
      warning: "The HTTP transport has no built-in authentication.",
    }));
    return;
  }

  if (request.method !== "POST" || url.pathname !== "/mcp") {
    response.writeHead(404, { "content-type": "application/json" });
    response.end(JSON.stringify({ error: "Not found" }));
    return;
  }

  const server = createMcpServer();
  const transport = new StreamableHTTPServerTransport({
    enableJsonResponse: true,
    sessionIdGenerator: undefined,
  });

  try {
    await server.connect(transport);
    await transport.handleRequest(request, response);
  } catch (error) {
    console.error("MCP request failed", error);
    if (!response.headersSent) {
      response.writeHead(500, { "content-type": "application/json" });
      response.end(
        JSON.stringify({
          jsonrpc: "2.0",
          error: { code: -32603, message: "Internal server error" },
          id: null,
        }),
      );
    }
  } finally {
    await transport.close();
    await server.close();
  }
});

httpServer.listen(config.port, config.host, () => {
  console.log(`Chef 360 MCP HTTP server listening on ${config.host}:${config.port}`);
});
