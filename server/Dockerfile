# Production Dockerfile for Neonatal STW MongoDB REST API Backend
FROM node:22-alpine

WORKDIR /app

# Copy dependency specifications first for layer caching
COPY package*.json ./

RUN npm ci --only=production

# Copy source code and scripts
COPY src ./src
COPY scripts ./scripts

# Environment defaults
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# Non-root user for security
USER node

CMD ["node", "src/server.js"]
