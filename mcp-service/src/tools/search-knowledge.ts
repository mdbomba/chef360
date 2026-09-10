import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

import { config } from "../config.js";
import { readKnowledgeDocument, searchKnowledge } from "../lib/knowledge.js";

export function registerSearchKnowledge(server: McpServer): void {
  server.tool(
    "search_knowledge",
    "Search ranked, versioned Chef 360 guidance; review excerpts before retrieving a document page",
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

  server.tool(
    "get_chef360_document",
    "Read one bounded page from a manifest-declared Chef 360 document",
    {
      id: z.string().min(1).max(100),
      offset: z.number().int().min(0).max(1_000_000).default(0),
      maxCharacters: z.number().int().min(1).max(4000).default(1000),
    },
    async ({ id, offset, maxCharacters }) => {
      const result = await readKnowledgeDocument(
        config.knowledgePath,
        id,
        offset,
        maxCharacters,
      );
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        structuredContent: result,
      };
    },
  );
}
