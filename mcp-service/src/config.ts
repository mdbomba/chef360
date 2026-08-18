import path from "node:path";

export const config = {
  host: process.env.HOST ?? "0.0.0.0",
  knowledgePath: path.resolve(
    process.env.KNOWLEDGE_PATH ?? "../knowledge-set/chef360-1.7.3",
  ),
  port: Number.parseInt(process.env.PORT ?? "3000", 10),
};
