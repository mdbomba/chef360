import path from "node:path";

export interface ServiceConfig {
  host: string;
  port: number;
  knowledgePath: string;
}

export const config: ServiceConfig = {
  host: process.env.HOST ?? "0.0.0.0",
  port: Number.parseInt(process.env.PORT ?? "3000", 10),
  knowledgePath: path.resolve(process.env.KNOWLEDGE_PATH ?? "../knowledge-set/chef360-1.7.3"),
};