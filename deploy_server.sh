#!/bin/bash

# Configuration
KEY_PATH="./yeope-ssh-key.key"
SERVER_IP="152.67.208.177"
USER="opc"
REMOTE_DIR="/opt/yeope"

# Check for quick mode (static files only)
QUICK_MODE=false
if [ "$1" == "--quick" ] || [ "$1" == "-q" ]; then
    QUICK_MODE=true
    echo "🚀 Quick Deploy Mode (static files only)..."
else
    echo "🚀 Starting Full Deployment to OCI ($SERVER_IP)..."
fi

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

# 2. Quick mode: Just restart nginx (for static files)
if [ "$QUICK_MODE" == true ]; then
    echo "🔄 Reloading nginx for static files..."
    ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no $USER@$SERVER_IP << EOF
        cd $REMOTE_DIR/server
        docker compose exec nginx nginx -s reload 2>/dev/null || docker compose restart nginx
        echo "✅ Nginx reloaded."
EOF
    echo "✨ Quick Deployment Finished!"
    exit 0
fi

# 3. Full mode: Rebuild Docker containers
echo "🔄 Restarting Docker containers..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no $USER@$SERVER_IP << EOF
    cd $REMOTE_DIR/server
    
    # Fix permissions (ensure user owns the synced files)
    sudo chown -R $USER:$USER .

    echo "🐳 Rebuilding and restarting containers..."
    # Full restart to ensure network consistency
    docker compose down
    # Prune builder cache to prevent snapshot errors
    docker builder prune -f
    docker compose up -d --build
    
    # Verify
    docker compose ps
EOF

echo "✨ Deployment Finished!"
