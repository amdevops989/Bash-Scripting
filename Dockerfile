# Stage 1: The Builder Environment
FROM node:20-alpine AS builder
WORKDIR /app

# Copy dependency files first to leverage Docker layer caching
COPY package.json package-lock.json ./
RUN npm ci

# Copy the rest of the application source code
COPY . .

# (Optional) Run your build step if using TypeScript or bundlers
# RUN npm run build

# Stage 2: The Production Runner
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Copy ONLY the package configuration and production dependencies
COPY package.json package-lock.json ./
RUN npm ci --only=production

# Copy the application source code from the builder stage
COPY --from=builder /app .

EXPOSE 3000
CMD ["node", "index.js"]