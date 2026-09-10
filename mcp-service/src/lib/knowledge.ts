import { readFile, realpath } from "node:fs/promises";
import path from "node:path";

interface ManifestDocument {
  id: string;
  path: string;
  title: string;
  topics: string[];
}

interface KnowledgeManifest {
  name: string;
  version: string;
  source?: string;
  documents: ManifestDocument[];
}

interface IndexedDocument extends ManifestDocument {
  content: string;
  lowered: string;
  metadata: string;
}

interface KnowledgeIndex {
  manifest: KnowledgeManifest;
  root: string;
  documents: IndexedDocument[];
  byId: Map<string, IndexedDocument>;
}

export interface SearchResult {
  id: string;
  title: string;
  path: string;
  topics: string[];
  version: string;
  source?: string;
  score: number;
  excerpt: string;
}

const indexes = new Map<string, Promise<KnowledgeIndex>>();

function terms(value: string): string[] {
  return (value.toLowerCase().match(/[a-z0-9][a-z0-9_.-]+/g) ?? []).slice(0, 12);
}

async function buildIndex(root: string): Promise<KnowledgeIndex> {
  const resolvedRoot = await realpath(root);
  const manifest = JSON.parse(
    await readFile(path.join(resolvedRoot, "manifest.json"), "utf8"),
  ) as KnowledgeManifest;

  const documents = await Promise.all(
    manifest.documents.map(async (document) => {
      if (
        path.isAbsolute(document.path) ||
        document.path.split(/[\\/]/).includes("..") ||
        path.extname(document.path).toLowerCase() !== ".md"
      ) {
        throw new Error(`Unsafe knowledge document path: ${document.path}`);
      }
      const file = await realpath(path.join(resolvedRoot, document.path));
      if (path.relative(resolvedRoot, file).startsWith("..")) {
        throw new Error(`Knowledge document escapes root: ${document.path}`);
      }
      const content = await readFile(file, "utf8");
      return {
        ...document,
        content,
        lowered: content.toLowerCase(),
        metadata: document.topics.join(" ").toLowerCase(),
      };
    }),
  );

  return {
    manifest,
    root: resolvedRoot,
    documents,
    byId: new Map(documents.map((document) => [document.id, document])),
  };
}

export function loadKnowledge(root: string): Promise<KnowledgeIndex> {
  const key = path.resolve(root);
  let index = indexes.get(key);
  if (!index) {
    index = buildIndex(key);
    indexes.set(key, index);
  }
  return index;
}

export async function knowledgeSummary(root: string) {
  const index = await loadKnowledge(root);
  return {
    name: index.manifest.name,
    version: index.manifest.version,
    source: index.manifest.source,
    documentCount: index.documents.length,
  };
}

export async function knowledgeManifest(root: string): Promise<KnowledgeManifest> {
  return (await loadKnowledge(root)).manifest;
}

export async function knowledgeReadme(root: string): Promise<string> {
  const index = await loadKnowledge(root);
  return readFile(path.join(index.root, "README.md"), "utf8");
}

export async function searchKnowledge(
  root: string,
  query: string,
  limit = 5,
): Promise<SearchResult[]> {
  const index = await loadKnowledge(root);
  const queryTerms = terms(query);
  const phrase = query.toLowerCase().replace(/\s+/g, " ").trim();
  const ranked: SearchResult[] = [];

  for (const document of index.documents) {
    const title = document.title.toLowerCase();
    if (!queryTerms.every((term) => document.lowered.includes(term) || title.includes(term) || document.metadata.includes(term))) {
      continue;
    }
    let score = 0;
    for (const term of queryTerms) {
      score += Math.min(document.lowered.split(term).length - 1, 8);
      if (title.includes(term)) score += 20;
      if (document.metadata.includes(term)) score += 10;
    }
    const normalizedContent = document.lowered.replace(/\s+/g, " ");
    if (normalizedContent.includes(phrase)) score += 50;
    const positions = queryTerms
      .map((term) => document.lowered.indexOf(term))
      .filter((position) => position >= 0);
    const matchAt = positions.length ? Math.min(...positions) : 0;
    const start = Math.max(0, matchAt - 180);
    ranked.push({
      id: document.id,
      title: document.title,
      path: document.path,
      topics: document.topics,
      version: index.manifest.version,
      source: index.manifest.source,
      score,
      excerpt: document.content.slice(start, start + 600).trim(),
    });
  }

  return ranked.sort((a, b) => b.score - a.score || a.id.localeCompare(b.id)).slice(0, limit);
}

export async function readKnowledgeDocument(
  root: string,
  id: string,
  offset = 0,
  maxCharacters = 1000,
) {
  const index = await loadKnowledge(root);
  const document = index.byId.get(id);
  if (!document) throw new Error(`Chef 360 document not found: ${id}`);
  const content = document.content.slice(offset, offset + maxCharacters);
  return {
    id: document.id,
    title: document.title,
    path: document.path,
    topics: document.topics,
    version: index.manifest.version,
    source: index.manifest.source,
    offset,
    nextOffset: offset + content.length < document.content.length ? offset + content.length : null,
    totalCharacters: document.content.length,
    content,
  };
}
