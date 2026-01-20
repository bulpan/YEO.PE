# Project & Server Migration Guide

This document provides a complete checklist for migrating both the **Development Environment** (Mac) and the **Production Server** (GCP).

## 1. Critical Security Assets (Do Not Commit to Git)

These files are ignored by git (`.gitignore`) and **MUST** be manually transferred or recreated on the new server.

| Type | Local Path | Server Path (Docker Host) | Description |
|------|------------|---------------------------|-------------|
| **SSL Cert** | `server/nginx/ssl/yeop3.com.crt` | `/home/yeope-gcp/yeope/server/nginx/ssl/` | Public SSL Certificate for HTTPS |
| **SSL Key** | `server/nginx/ssl/yeop3.com.key` | `/home/yeope-gcp/yeope/server/nginx/ssl/` | **Private** SSL Key (Matches CRT) |
| **Deployment Key** | `./gcp-yeope-key` | N/A (Local only) | SSH Private Key to access the server |
| **Firebase Key** | `server/config/firebase-service-account.json` | `/home/yeope-gcp/yeope/server/config/` | Service Account for FCM Push Notifications |
15: | **Docker Hub** | ID: `bulpankim` | Token: `dckr_pat_****************************` | For Image Registry |

> ⚠️ **Important:** The `gcp-yeope-key` must have `600` permissions (`chmod 600 gcp-yeope-key`).

### ✅ Quick Backup
You can verify and bundle all these files into a single archive using the provided script:
```bash
./scripts/archive_secrets.sh
```
This will create `yeope_secrets_backup.zip`. **Do not commit this file.**


## 2. Environment Configuration

| File | Local Path | Server Path | Description |
|------|------------|-------------|-------------|
| **Env Vars** | `server/.env` | `/home/yeope-gcp/yeope/server/.env` | Database creds, JWT secrets, API keys |

### Essential `.env` Variables Checklist
Ensure these are defined in the new `.env`:
*   `NODE_ENV=production`
*   `DB_PASSWORD` (Must match Postgres container config)
*   `JWT_SECRET`
*   `ADMIN_PASSWORD`

## 3. Infrastructure & Deployment Files

These files are in the repository, but ensure they are up-to-date.

| File | Purpose |
|------|---------|
| `deploy_zero_downtime.sh` | Main deployment script. (Requires proper `SERVER_IP` and `KEY_PATH` config inside) |
| `server/docker-compose.yml` | Defines services (App Blue/Green, Nginx, Postgres, Redis) |
| `server/nginx/docker.conf` | Nginx main configuration |
| `server/nginx/upstream.conf` | Generated dynamically by deployment script (for Zero Downtime) |

## 4. Migration Steps Summary

1.  **Prepare Destination Server**:
    *   Install Docker & Docker Compose.
    *   Create project directory (e.g., `~/yeope`).
2.  **Transfer Security Files**:
    *   Use `scp` to copy `ssl/`, `.env`, and `firebase-service-account.json` to the server.
    ```bash
    # Example
    scp -i gcp-yeope-key server/.env yeope-gcp@<IP>:~/yeope/server/
    scp -i gcp-yeope-key -r server/nginx/ssl yeope-gcp@<IP>:~/yeope/server/nginx/
    ```
3.  **Run Deployment**:
    *   Execute `./deploy_zero_downtime.sh` locally.

## 5. Troubleshooting
*   **SSL Error**: If Nginx logs show `key values mismatch`, ensure `.crt` and `.key` are a valid pair.
*   **Permission Denied**: Check SSH key permissions (`chmod 600`).

---

## 6. Setting Up a Fresh Development Environment (Mac)
If you are resetting your Mac or moving to a new one, follow these steps:

### Prerequisites
*   **Node.js**: Install latest LTS (v18+ recommended).
*   **Docker Desktop**: Install and start.
*   **Xcode**: Install from App Store + `xcode-select --install`.
*   **CocoaPods**: `sudo gem install cocoapods`

### Setup Steps
1.  **Clone Repository**:
    ```bash
    git clone <REPO_URL>
    cd YEO.PE
    ```
2.  **Restore Secrets**:
    *   Place `yeope_secrets_backup.zip` in the project root.
    *   Unzip it: `unzip yeope_secrets_backup.zip`
    *   Verify `gcp-yeope-key` permission: `chmod 600 gcp-yeope-key`
3.  **Server Setup**:
    ```bash
    cd server
    npm install
    docker compose up -d  # Starts DB/Redis for local dev
    ```
4.  **iOS Setup**:
    ```bash
    cd ios/YEO.PE
    pod install
    # Open YEO.PE.xcworkspace in Xcode
    ```
5.  **Verify**:
    *   Check if `server/.env` exists.
    *   Check if `ios/YEO.PE/YEO.PE/GoogleService-Info.plist` exists.
