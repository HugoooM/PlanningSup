FROM node:16.14.0-alpine3.15 as builder
LABEL maintainer="kernoeb <kernoeb@protonmail.com>"

RUN apk add --no-cache curl bash

# https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN curl -f https://get.pnpm.io/v6.16.js | node - add --global pnpm

# https://github.com/duniul/clean-modules
RUN pnpm i -g clean-modules@2.0.4

WORKDIR /app

# Only copy the files we need for the moment
COPY package.json pnpm-lock.yaml .npmrc /app/
RUN pnpm install --frozen-lockfile --prefer-offline --unsafe-perm

# Copy all files, and build the app
COPY . /app/
RUN pnpm build -- --standalone
RUN rm -rf node_modules

# Only production dependencies
RUN pnpm install --frozen-lockfile --production --prefer-offline --unsafe-perm
RUN clean-modules --yes --exclude "**/*.mustache"

FROM node:16.14.0-alpine3.15 as app

RUN apk --no-cache add dumb-init curl bash

ENV NODE_ENV production
ENV HOST 0.0.0.0

# Remove some useless stuff
RUN rm -rf /usr/local/lib/node_modules/npm/ /usr/local/bin/npm /opt/yarn-*

# No evil root access
USER node
WORKDIR /app

COPY --chown=node:node . /app
COPY --chown=node:node --from=builder /app/node_modules /app/node_modules
COPY --chown=node:node --from=builder /app/.nuxt /app/.nuxt
COPY --chown=node:node --from=builder /app/static/ /app/static/

# The planning never falls, but you never know
HEALTHCHECK --interval=15s --timeout=5s --retries=5 \
  CMD ["curl", "-H", "ignore-statistics: true", "http://localhost:3000"]

EXPOSE 3000
CMD ["dumb-init", "node", "--max-old-space-size=2048", "node_modules/nuxt-start/bin/nuxt-start.js", "--port", "3000"]
