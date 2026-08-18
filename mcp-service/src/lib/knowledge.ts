import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

export interface SearchResult {
  path: string;
  excerpt: string;
}

async function markdownFiles(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map(async (entry) => {
      const fullPath = path.join(directory, entry.name);
      if (entry.isDirectory()) return markdownFiles(fullPath);
      return entry.isFile() && entry.name.endsWith(".md") ? [fullPath] : [];
    }),
  );

  return files.flat();
}

export async function searchKnowledge(
  root: string,
  query: string,
  limit = 5,
): Promise<SearchResult[]> {
  const normalizedQuery = query.toLowerCase();
  const results: SearchResult[] = [];

  for (const file of await markdownFiles(root)) {
    const content = await readFile(file, "utf8");
    const index = content.toLowerCase().indexOf(normalizedQuery);
    if (index === -1) continue;

    const start = Math.max(0, index - 200);
    const end = Math.min(content.length, index + query.length + 400);
    results.push({
      path: path.relative(root, file),
      excerpt: content.slice(start, end).trim(),
    });

    if (results.length >= limit) break;
  }

  return results;
}
