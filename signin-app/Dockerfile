# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies first (cached layer)
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY tsconfig*.json ./
COPY build.mjs ./
COPY src/ ./src/
COPY public/ ./public/

# Compile server TypeScript → dist/server/
# Bundle client TypeScript  → dist/public/bundle.js
RUN npm run build

# Copy static HTML/assets to dist/public (alongside bundle.js)
RUN cp -r public/* dist/public/

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM node:20-alpine AS runtime

ENV NODE_ENV=production
WORKDIR /app

# Only production dependencies
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy compiled artefacts from builder
COPY --from=builder /app/dist ./dist

# Cloud Run injects PORT; default 8080 matches the healthz path
ENV PORT=8080
EXPOSE 8080

# Non-root user for least-privilege execution
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

CMD ["node", "dist/server/server.js"]

