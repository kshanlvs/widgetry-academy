# Widgetry Jobs API: small production image for Cloud Run (or any container host)
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-slim
ENV NODE_ENV=production
# Chromium prints resume PDFs (same templates as the website); fonts are bundled in fonts/
RUN apt-get update \
 && apt-get install -y --no-install-recommends chromium fonts-liberation fonts-noto-core ca-certificates \
 && rm -rf /var/lib/apt/lists/*
ENV CHROMIUM_PATH=/usr/bin/chromium
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY migrations ./migrations
COPY knowledge ./knowledge
COPY fonts ./fonts
USER node
EXPOSE 8080
CMD ["node", "dist/server.js"]
