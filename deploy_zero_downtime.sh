#!/bin/bash

# Configuration
KEY_PATH="./gcp-yeope-key"
SERVER_IP="34.47.109.80"
USER="yeope-gcp"
REMOTE_DIR="/home/yeope-gcp/yeope"
DOCKER_ID="bulpankim"
IMAGE_NAME="yeope"
TAG="latest"

echo "🚀 Starting Zero-Downtime Deployment via Docker Hub..."

# 1. Local Build & Push
echo "🏗  [Local] Building Docker Image for AMD64..."
# Essential: --platform linux/amd64 for GCP compatibility if building on Mac Apple Silicon
docker build --platform linux/amd64 -t $DOCKER_ID/$IMAGE_NAME:$TAG ./server

if [ $? -ne 0 ]; then
    echo "❌ Local Build failed."
    exit 1
fi

echo "TX  [Local] Pushing Image to Docker Hub ($DOCKER_ID/$IMAGE_NAME:$TAG)..."
docker push $DOCKER_ID/$IMAGE_NAME:$TAG

if [ $? -ne 0 ]; then
    echo "❌ Docker Push failed. Please check 'docker login'."
    exit 1
fi
echo "✅ Push complete."

# 2. Sync Configuration Code (Only small files, no huge build context)
echo "🔄 [Local] Syncing configuration & secrets..."
# We still need docker-compose.yml and nginx config on the server
rsync -avz --delete \
    -e "ssh -i $KEY_PATH -o StrictHostKeyChecking=no" \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude 'uploads' \
    --exclude 'logs' \
    server/docker-compose.yml \
    server/package.json \
    server/nginx \
    $USER@$SERVER_IP:$REMOTE_DIR/server/

# Note: We do NOT sync 'server/src' anymore because code is inside the image!
# But wait, looking at docker-compose.yml volumes:
#       - ./src:/usr/src/app/src
# This volume mount OVERRIDES the image content with local content.
# FATAL FLAW: If we deploy image, but mount ./src, the server uses OLD code on disk unless we sync src.
# FIX: We must REMOVE the volume mount for 'src' in production, OR we must sync src.
# Syncing src is safer for now to ensure consistency if we don't change docker-compose.yml dynamically.
# BUT, syncing src defeats the purpose of "Image Only" deployment if we want to avoid rsync issues?
# NO, rsyncing text files (src) is tiny. The previous issue was node_modules or build artifacts?
# Actually, the previous issue was Disk Full. 
# Let's Sync 'src' too, it's small.
rsync -avz \
    -e "ssh -i $KEY_PATH -o StrictHostKeyChecking=no" \
    --exclude 'node_modules' \
    server/src \
    $USER@$SERVER_IP:$REMOTE_DIR/server/

echo "✅ Configuration sync complete."

# 3. Remote Deployment Logic
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no $USER@$SERVER_IP << EOF
    cd /home/yeope-gcp/yeope/server

    echo "🔍 [Remote] Checking current state..."
    IS_BLUE=\$(docker ps --format "{{.Names}}" | grep -w "yeope-app-blue")
    IS_GREEN=\$(docker ps --format "{{.Names}}" | grep -w "yeope-app-green")

    if [ -n "\$IS_BLUE" ]; then
        TARGET="green"
        echo "🔵 Current is BLUE. Deploying to GREEN."
    elif [ -n "\$IS_GREEN" ]; then
        TARGET="blue"
        echo "🟢 Current is GREEN. Deploying to BLUE."
    else
        TARGET="blue"
        echo "⚪ Initial deployment. Defaulting to BLUE."
    fi

    # [Smart Cleanup]
    echo "🧹 [Remote] Cleaning old images (safe)..."
    docker image prune -f

    echo "⬇️  [Remote] Pulling new image ($DOCKER_ID/$IMAGE_NAME:$TAG)..."
    docker pull --platform linux/amd64 $DOCKER_ID/$IMAGE_NAME:$TAG

    echo "🚀 [Remote] Starting \$TARGET..."
    touch nginx/upstream.conf
    
    # Start container (No --build flag needed)
    docker compose up -d app-\$TARGET

    # Health Check
    echo "💓 [Remote] Waiting for health check..."
    MAX_RETRIES=12
    COUNT=0
    HEALTHY=false

    while [ \$COUNT -lt \$MAX_RETRIES ]; do
        sleep 5
        HTTP_STATUS=\$(docker exec yeope-app-\$TARGET node -e 'http.get("http://127.0.0.1:3000/health", r => { console.log(r.statusCode); r.resume() }).on("error", e=>console.log("ERR"))' 2>/dev/null)
        
        if [ "\$HTTP_STATUS" == "200" ]; then
            echo "   ✅ Health Check Passed!"
            HEALTHY=true
            break
        fi
        echo "   ... waiting (\$COUNT/\$MAX_RETRIES)"
        COUNT=\$((COUNT+1))
    done

    if [ "\$HEALTHY" == "false" ]; then
        echo "❌ Deployment Failed. Container unhealth."
        docker compose stop app-\$TARGET
        exit 1
    fi

    # Switch Traffic
    echo "🔀 [Remote] Switching Nginx traffic..."
    echo "upstream backend { server app-\$TARGET:3000; }" > nginx/upstream.conf
    docker compose exec nginx nginx -s reload

    # Stop Old
    if [ -n "\$IS_BLUE" ] && [ "\$TARGET" == "green" ]; then
        echo "🗑️  Stopping old Blue container..."
        docker compose stop app-blue
        docker compose rm -f app-blue
    elif [ -n "\$IS_GREEN" ] && [ "\$TARGET" == "blue" ]; then
        echo "🗑️  Stopping old Green container..."
        docker compose stop app-green
        docker compose rm -f app-green
    fi
    
    # Aggressive Cleanup
    echo "🧹 Final cleanup of unused images..."
    docker image prune -f
    docker container prune -f
    
    echo "📊 Disk usage after cleanup:"
    df -h / | grep -v Filesystem

    echo "✨ Deployment Success!"
EOF
