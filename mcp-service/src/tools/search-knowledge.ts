import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

import { config } from "../config.js";
import { searchKnowledge } from "../lib/knowledge.js";

export function registerSearchKnowledge(server: McpServer): void {
  server.tool(
    "search_knowledge",
    "Search the Chef 360 Platform knowledge set",
    {
      query: z.string().min(2).describe("Text to find in the knowledge set"),
      limit: z.number().int().min(1).max(20).default(5),
    },
    async ({ query, limit }) => {
      const results = await searchKnowledge(config.knowledgePath, query, limit);

      return {
        content: [
          {
            type: "text",
            text: results.length
              ? JSON.stringify(results, null, 2)
              : `No Chef 360 documentation matched "${query}".`,
          },
        ],
      };
    },
  );
}
