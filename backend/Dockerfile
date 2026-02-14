# Aura Backend - Production Dockerfile
FROM oven/bun:1-alpine AS base
WORKDIR /app

# Install dependencies
FROM base AS deps
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile || bun install

# Build
FROM base AS runner
COPY --from=deps /app/node_modules node_modules
COPY . .

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

USER bun
CMD ["bun", "run", "src/index.ts"]
