# ============================================
# Stage 1: Build Admin Client
# ============================================
FROM node:18-alpine AS admin-builder

WORKDIR /usr/src/app

# Copy admin-client package files
COPY admin-client/package*.json ./admin-client/

# Install dependencies for building
WORKDIR /usr/src/app/admin-client
RUN npm install

# Copy admin-client source
COPY admin-client/ ./

# Build the admin client (outputs to ../public/admin)
RUN npm run build

# ============================================
# Stage 2: Production Runtime
# ============================================
FROM node:18-alpine

WORKDIR /usr/src/app

# Install build dependencies for native modules (bcrypt, sharp)
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm install --only=production && \
    npm cache clean --force && \
    rm -rf /root/.npm /tmp/*

# Remove build dependencies (we only needed them for npm install)
RUN apk del python3 make g++

# Copy application source (excluding node_modules and admin-client via .dockerignore)
COPY . .

# Copy built admin client from builder stage
# Note: vite builds to /usr/src/app/public/admin (one level up from admin-client)
COPY --from=admin-builder /usr/src/app/public/admin ./public/admin

EXPOSE 3000

CMD ["npm", "start"]
