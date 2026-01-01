FROM node:18-alpine

WORKDIR /usr/src/app

# Copy package files and install dependencies first for better caching
COPY package*.json ./

# Add build dependencies for native modules (bcrypt, sharp, etc.)
RUN apk add --no-cache python3 make g++

# Ensure any host node_modules are not used
RUN rm -rf node_modules

RUN npm install --only=production

# Copy the rest of the source code
COPY . .

# Build Admin Client
WORKDIR /usr/src/app/admin-client
# Force clean install to avoid platform mismatch (macOS vs Alpine)
RUN rm -rf node_modules package-lock.json
RUN npm install
RUN npm run build

# Artifacts are already in public/admin due to vite.config.js outDir
WORKDIR /usr/src/app

EXPOSE 3000

CMD ["npm", "start"]
