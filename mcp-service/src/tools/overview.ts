import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

import { config } from "../config.js";
import { knowledgeManifest, knowledgeReadme, knowledgeSummary } from "../lib/knowledge.js";

export const SERVICE_NAME = "chef360-mcp-service";
export const SERVICE_VERSION = "0.1.0";

export function serviceInstructions(labToolsAvailable: boolean): string {
  return `Read-only Chef knowledge service covering Chef 360 1.7.3. Search with search_knowledge, then fetch only the needed page with get_chef360_document. Local lab inspection is ${labToolsAvailable ? "available" : "unavailable"}; call get_chef_service_overview when you need more context.`;
}

export async function serviceOverview(
  detail: "brief" | "sources" | "capabilities" = "brief",
  labToolsAvailable = false,
) {
  const knowledge = await knowledgeSummary(config.knowledgePath);
  const overview: Record<string, unknown> = {
    service: { name: SERVICE_NAME, version: SERVICE_VERSION, readOnly: true },
    knowledge: { product: "Chef 360", version: knowledge.version },
    summary: "Search and retrieve focused Chef guidance; no Chef or cloud resources are changed.",
    suggestedNextAction: "Ask a Chef 360 question or call search_knowledge.",
  };
  if (detail === "sources") {
    overview.sources = { publicKnowledge: { ...knowledge, available: true } };
  } else if (detail === "capabilities") {
    overview.capabilities = [
      "search_knowledge",
      "get_chef360_document",
      "get_chef_service_overview",
      ...(labToolsAvailable
        ? ["list_lab_machines", "inspect_lab_machine", "chef_workstation_versions"]
        : []),
    ];
    overview.labInspection = { available: labToolsAvailable };
  }
  return overview;
}

export function registerOverview(server: McpServer, labToolsAvailable: boolean): void {
  server.tool(
    "get_chef_service_overview",
    "Introduce this read-only service with brief, source, or capability details",
    { detail: z.enum(["brief", "sources", "capabilities"]).default("brief") },
    async ({ detail }) => {
      const result = await serviceOverview(detail, labToolsAvailable);
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        structuredContent: result,
      };
    },
  );

  server.registerResource(
    "chef-service-overview",
    "chef360://service/overview",
    { title: "Chef Knowledge Service Overview", mimeType: "application/json" },
    async (uri) => ({
      contents: [{ uri: uri.href, mimeType: "application/json", text: JSON.stringify(await serviceOverview("brief", labToolsAvailable), null, 2) }],
    }),
  );
  server.registerResource(
    "chef360-manifest",
    "chef360://knowledge/1.7.3/manifest",
    { title: "Chef 360 1.7.3 Knowledge Manifest", mimeType: "application/json" },
    async (uri) => ({
      contents: [{ uri: uri.href, mimeType: "application/json", text: JSON.stringify(await knowledgeManifest(config.knowledgePath), null, 2) }],
    }),
  );
  server.registerResource(
    "chef360-readme",
    "chef360://knowledge/1.7.3/readme",
    { title: "Chef 360 1.7.3 Knowledge README", mimeType: "text/markdown" },
    async (uri) => ({
      contents: [{ uri: uri.href, mimeType: "text/markdown", text: await knowledgeReadme(config.knowledgePath) }],
    }),
  );
}
