#!/bin/bash

# Configuration
BACKUP_NAME="yeope_secrets_backup.zip"
FILES_TO_BACKUP=(
    "server/nginx/ssl/yeop3.com.crt"
    "server/nginx/ssl/yeop3.com.key"
    "server/.env"
    "server/config/firebase-service-account.json"
    "gcp-yeope-key"
    "ios/YEO.PE/YEO.PE/GoogleService-Info.plist"
)

echo "📦 Starting backup of essential secret files..."

# Check existence
MISSING_FILES=0
for FILE in "${FILES_TO_BACKUP[@]}"; do
    if [ ! -f "$FILE" ]; then
        echo "⚠️  Warning: File not found: $FILE"
        MISSING_FILES=1
    fi
done

# Create Zip
if [ -f "$BACKUP_NAME" ]; then
    echo "🗑  Removing old backup..."
    rm "$BACKUP_NAME"
fi

zip -r "$BACKUP_NAME" "${FILES_TO_BACKUP[@]}"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Backup created successfully: $BACKUP_NAME"
    echo "⚠️  KEEP THIS FILE SAFE. DO NOT COMMIT TO GIT."
else
    echo "❌ Backup failed."
    exit 1
fi
