# Build Outline from source at a specific commit.
# Based on upstream Dockerfile.base + Dockerfile from outline/outline.
ARG OUTLINE_COMMIT=631a4b0efa0b05e2381b89d7aed3fa13afc439f2
ARG APP_PATH=/opt/outline

# --- Stage 1: Clone and build ---
FROM node:22.21.0 AS builder

ARG OUTLINE_COMMIT
ARG APP_PATH
WORKDIR $APP_PATH

RUN apt-get update && apt-get install -y cmake git

RUN git clone https://github.com/outline/outline.git . && \
    git checkout ${OUTLINE_COMMIT}

RUN corepack enable && \
    yarn install --immutable --network-timeout 1000000 && \
    yarn cache clean

RUN yarn build

RUN yarn workspaces focus --production && \
    yarn cache clean

# --- Stage 2: Runtime ---
FROM node:22.21.0-slim

LABEL org.opencontainers.image.source="https://github.com/outline/outline"

ARG APP_PATH
WORKDIR $APP_PATH
ENV NODE_ENV=production

RUN addgroup --gid 1001 nodejs && \
    adduser --uid 1001 --ingroup nodejs nodejs && \
    mkdir -p /var/lib/outline && \
    chown -R nodejs:nodejs /var/lib/outline && \
    chown -R nodejs:nodejs $APP_PATH

COPY --from=builder --chown=nodejs:nodejs $APP_PATH/build ./build
COPY --from=builder --chown=nodejs:nodejs $APP_PATH/server ./server
COPY --from=builder --chown=nodejs:nodejs $APP_PATH/public ./public
COPY --from=builder --chown=nodejs:nodejs $APP_PATH/.sequelizerc ./.sequelizerc
COPY --from=builder --chown=nodejs:nodejs $APP_PATH/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs $APP_PATH/package.json ./package.json

RUN apt-get update && \
    apt-get install -y wget && \
    rm -rf /var/lib/apt/lists/*

ENV FILE_STORAGE_LOCAL_ROOT_DIR=/var/lib/outline/data
RUN mkdir -p "$FILE_STORAGE_LOCAL_ROOT_DIR" && \
    chown -R nodejs:nodejs "$FILE_STORAGE_LOCAL_ROOT_DIR" && \
    chmod 1777 "$FILE_STORAGE_LOCAL_ROOT_DIR"

VOLUME /var/lib/outline/data

USER nodejs

HEALTHCHECK --interval=1m CMD wget -qO- "http://localhost:${PORT:-3000}/_health" | grep -q "OK" || exit 1

EXPOSE 3000
CMD ["node", "build/server/index.js"]
