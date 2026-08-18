FROM node:22-alpine AS build

WORKDIR /app/mcp-service
COPY mcp-service/package*.json ./
RUN npm ci
COPY mcp-service/ ./
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine AS runtime

ENV HOST=0.0.0.0
ENV KNOWLEDGE_PATH=/app/knowledge-set/chef360-1.7.3
ENV NODE_ENV=production
ENV PORT=3000

WORKDIR /app/mcp-service
COPY --from=build /app/mcp-service/dist ./dist
COPY --from=build /app/mcp-service/node_modules ./node_modules
COPY --from=build /app/mcp-service/package.json ./package.json
COPY knowledge-set/chef360-1.7.3 /app/knowledge-set/chef360-1.7.3

EXPOSE 3000
USER node
CMD ["npm", "run", "start:http"]
