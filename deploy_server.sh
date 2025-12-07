#!/bin/bash

# Configuration
KEY_PATH="./yeope-ssh-key.key"
SERVER_IP="152.67.208.177"
USER="opc"
REMOTE_DIR="/opt/yeope"

echo "🚀 Starting Deployment to OCI ($SERVER_IP)..."

# 1. Archive Server Code
echo "📦 Zipping server code..."
# Remove old zip if exists
rm -f yeope-server.zip
# Zip server directory excluding node_modules and other ignorables
zip -r -q yeope-server.zip server -x "server/node_modules/*" "server/.git/*" "server/coverage/*" "server/.DS_Store" "server/tests/simulation/*"

if [ ! -f yeope-server.zip ]; then
    echo "❌ Failed to create zip file."
    exit 1
fi
echo "✅ Zip created: yeope-server.zip"

# 2. Upload to Server
echo "📤 Uploading to server..."
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no yeope-server.zip $USER@$SERVER_IP:/home/$USER/yeope-server.zip

if [ $? -ne 0 ]; then
    echo "❌ Upload failed."
    exit 1
fi
echo "✅ Upload complete."

# 3. Remote Execution (Unzip & Restart Docker)
echo "🔄 Updating server and restarting Docker..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no $USER@$SERVER_IP << EOF
    # Go to root
    cd /home/$USER
    
    # Move zip to destination and unzip
    sudo mv yeope-server.zip $REMOTE_DIR/
    cd $REMOTE_DIR
    
    # Remove old code (optional, but safer to unzip specific files or purge)
    # Be careful not to delete .env or data if they are not persisted elsewhere
    # Here we overwrite with unzip
    echo "📂 Unzipping..."
    sudo unzip -o -q yeope-server.zip
    
    # Fix permissions
    sudo chown -R $USER:$USER server/
    
    # Restart Docker
    cd server
    echo "🐳 Rebuilding and restarting containers..."
    docker compose up -d --build app
    
    # Verify
    docker compose ps
EOF

echo "✨ Deployment Finished!"
