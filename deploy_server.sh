#!/bin/bash

# Configuration
KEY_PATH="./yeope-ssh-key.key"
SERVER_IP="152.67.208.177"
USER="opc"
REMOTE_DIR="/opt/yeope"

echo "🚀 Starting Deployment to OCI ($SERVER_IP)..."

# 1. Sync Server Code (Rsync)
echo "🔄 Syncing server code via rsync..."

rsync -avz --delete \
    -e "ssh -i $KEY_PATH -o StrictHostKeyChecking=no" \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude '.DS_Store' \
    --exclude 'coverage' \
    --exclude 'tests/simulation' \
    server/ \
    $USER@$SERVER_IP:$REMOTE_DIR/server/

if [ $? -ne 0 ]; then
    echo "❌ Rsync failed."
    exit 1
fi
echo "✅ Rsync complete."

# 2. Remote Execution (Restart Docker)
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
