#!/bin/bash

# Configuration
KEY_PATH="./gcp-yeope-key"
SERVER_IP="34.47.109.80"
USER="yeope-gcp"
REMOTE_DIR="/home/yeope-gcp/yeope"

echo "🚀 Starting Zero-Downtime Deployment to OCI ($SERVER_IP)..."

# 1. Sync Server Code (Rsync)
echo "🔄 Syncing server code via rsync..."
rsync -avz --delete \
    -e "ssh -i $KEY_PATH -o StrictHostKeyChecking=no" \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude '.DS_Store' \
    --exclude 'coverage' \
    --exclude 'tests/simulation' \
    --exclude 'uploads' \
    --exclude 'logs' \
    --exclude '.env' \
    server/ \
    $USER@$SERVER_IP:$REMOTE_DIR/server/

if [ $? -ne 0 ]; then
    echo "❌ Rsync failed."
    exit 1
fi
echo "✅ Rsync complete."

# 2. Execute Blue/Green Logic on Remote Server
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no $USER@$SERVER_IP << 'EOF'
    cd /home/yeope-gcp/yeope/server

    # Fix permissions
    sudo chown -R yeope-gcp:yeope-gcp .

    echo "🔍 Checking current active container..."
    
    # Check if we are running blue or green
    IS_BLUE=$(docker ps --format "{{.Names}}" | grep -w "yeope-app-blue")
    IS_GREEN=$(docker ps --format "{{.Names}}" | grep -w "yeope-app-green")
    IS_OLD=$(docker ps --format "{{.Names}}" | grep -w "yeope-app")

    if [ -n "$IS_BLUE" ]; then
        CURRENT="blue"
        TARGET="green"
        echo "🔵 Current is BLUE. Deploying to GREEN."
    elif [ -n "$IS_GREEN" ]; then
        CURRENT="green"
        TARGET="blue"
        echo "🟢 Current is GREEN. Deploying to BLUE."
    else
        # Fallback / Initial State (Migrating from 'yeope-app')
        echo "⚪ No Blue/Green found (or clean state). defaulting to BLUE."
        CURRENT="none"
        TARGET="blue"
    fi

    # 3. Build & Start Target
    echo "🏗 Building and starting $TARGET..."
    
    # Ensure upstream.conf exists to prevent Nginx crash on first run
    touch nginx/upstream.conf
    
    # Pull/Build target
    docker compose up -d --build app-$TARGET

    # 4. Health Check
    echo "💓 Waiting for $TARGET to be healthy..."
    MAX_RETRIES=24  # 24 * 5s = 120s
    COUNT=0
    HEALTHY=false

    while [ $COUNT -lt $MAX_RETRIES ]; do
        sleep 5
        # Use docker exec to check health internally (since port is not exposed to host)
        # Assuming wget or curl exists in the app image. If not, use node script or similar.
        # Here we try strict node health check or simple TCP check if no curl
        # Let's assume standard node fetch is available or use docker inspect healthcheck if defined
        
        # Checking container status first
        STATE=$(docker inspect -f '{{.State.Running}}' yeope-app-$TARGET 2>/dev/null)
        if [ "$STATE" != "true" ]; then
             echo "⚠️ Container is not running."
        else
             # Use Node.js for reliable health check (using 127.0.0.1 to avoid ipv6 issues)
             HTTP_STATUS=$(docker exec yeope-app-$TARGET node -e 'http.get("http://127.0.0.1:3000/health", (r) => { console.log(r.statusCode); r.resume(); }).on("error", (e) => { console.log("ERR"); });' 2>/dev/null)
             
             echo "   ... status: $HTTP_STATUS (attempt $COUNT/$MAX_RETRIES)"

             if [ "$HTTP_STATUS" == "200" ]; then
                 HEALTHY=true
                 break
             fi
             echo "   ... status: $HTTP_STATUS (attempt $COUNT/$MAX_RETRIES)"
        fi
        COUNT=$((COUNT+1))
    done

    if [ "$HEALTHY" == "false" ]; then
        echo "❌ Health check failed. Rolling back..."
        docker compose stop app-$TARGET
        exit 1
    fi
    echo "✅ $TARGET is healthy."

    # 5. Switch Traffic
    echo "🔀 Switching traffic to $TARGET..."
    echo "upstream backend { server app-$TARGET:3000; }" > nginx/upstream.conf
    
    # Reload Nginx
    # Ensure Nginx is running first
    # Reload Nginx
    # ALWAYS ensure Nginx is running with latest config (recreates if config changed)
    echo "🔄 Ensuring Nginx is up-to-date..."
    docker compose up -d nginx
    
    # Reload to apply upstream changes (if container wasn't recreated)
    docker compose exec nginx nginx -s reload
    echo "✅ Nginx reloaded."

    # 6. Cleanup
    if [ "$CURRENT" != "none" ]; then
        echo "🛑 Stopping old container ($CURRENT)..."
        docker compose stop app-$CURRENT
    fi

    # Handle migration case (if 'yeope-app' still exists)
    if [ -n "$IS_OLD" ]; then
        echo "🧹 Removing legacy container (yeope-app)..."
        docker compose stop app
        docker compose rm -f app
    fi
    
    # Prune old images
    docker image prune -f

    echo "✨ Zero-Downtime Deployment Complete! ($TARGET is live)"
EOF
