#!/bin/bash
# ==============================================================================
# Seed HashiCorp Vault Secrets (Bi-directional Sync: Live K8s + secrets.json)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_FILE="${SCRIPT_DIR}/vault-keys.json"
SECRETS_FILE="${SCRIPT_DIR}/secrets.json"

if [ ! -f "$SECRETS_FILE" ]; then
    echo "[!] secrets.json not found! Copying from secrets.json.example..."
    cp "${SCRIPT_DIR}/secrets.json.example" "$SECRETS_FILE"
fi

ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE" 2>/dev/null || echo "")

if [ -z "$ROOT_TOKEN" ]; then
    echo "[!] Vault Root Token not found in $KEYS_FILE."
    exit 1
fi

echo "=== Logging into Vault... ==="
kubectl exec -n vault vault-0 -- vault login "$ROOT_TOKEN" >/dev/null

echo "=== Ensuring KV-v2 Engine at secret/ ==="
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2 2>/dev/null || true

echo "=== Seeding Vault Secrets (Hybrid Syncing) ==="

# Helper function to safely update secrets.json without removing non-existent fields
update_secrets_json() {
    local json_path="$1"
    local new_val="$2"
    if [ -n "$new_val" ] && [ -f "$SECRETS_FILE" ]; then
        local current_val
        current_val=$(jq -r "${json_path} // empty" "$SECRETS_FILE" 2>/dev/null || echo "")
        if [ "$current_val" != "$new_val" ]; then
            echo "[*] Updating ${json_path} in secrets.json to match live runtime secret..."
            local tmp_json
            tmp_json=$(mktemp)
            jq --arg val "$new_val" "${json_path} = \$val" "$SECRETS_FILE" > "$tmp_json" && mv "$tmp_json" "$SECRETS_FILE"
        fi
    fi
}

# 1. GitHub Token
GH_TOKEN=$(jq -r '.github.token // empty' "$SECRETS_FILE")
if [ -n "$GH_TOKEN" ] && [ "$GH_TOKEN" != "ghp_YOUR_PERSONAL_ACCESS_TOKEN_HERE" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/github token="$GH_TOKEN"
    echo "[+] secret/dev/github updated"
fi

# 2. Cloudflare API Token
CF_TOKEN=$(jq -r '.cloudflare.api_token // empty' "$SECRETS_FILE")
if [ -n "$CF_TOKEN" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/cloudflare api-token="$CF_TOKEN"
    echo "[+] secret/cloudflare updated"
fi

# 3. Harbor (Live K8s Secret OR secrets.json)
LIVE_HARBOR_PASS=$(kubectl get secret -n harbor harbor-core -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
HARBOR_PASS="${LIVE_HARBOR_PASS:-$(jq -r '.harbor.admin_password // empty' "$SECRETS_FILE")}"
HARBOR_KEY=$(jq -r '.harbor.secret_key // "harbor_secret_key_123"' "$SECRETS_FILE")

if [ -n "$LIVE_HARBOR_PASS" ]; then
    update_secrets_json ".harbor.admin_password" "$LIVE_HARBOR_PASS"
fi

if [ -n "$HARBOR_PASS" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/harbor admin-password="$HARBOR_PASS" secret-key="$HARBOR_KEY"
    echo "[+] secret/harbor updated"
fi

# 4. MinIO (Live K8s Secret OR secrets.json)
LIVE_MINIO_USER=$(kubectl get secret -n minio minio-secret -o jsonpath='{.data.root-user}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
LIVE_MINIO_PASS=$(kubectl get secret -n minio minio-secret -o jsonpath='{.data.root-password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
MINIO_USER="${LIVE_MINIO_USER:-$(jq -r '.minio.root_user // "admin"' "$SECRETS_FILE")}"
MINIO_PASS="${LIVE_MINIO_PASS:-$(jq -r '.minio.root_password // empty' "$SECRETS_FILE")}"
MINIO_ENDPOINT=$(jq -r '.minio.endpoint // "https://vminio.aliien.uk"' "$SECRETS_FILE")
MINIO_BUCKET=$(jq -r '.minio.bucket // "app-backups"' "$SECRETS_FILE")

if [ -n "$LIVE_MINIO_USER" ]; then
    update_secrets_json ".minio.root_user" "$LIVE_MINIO_USER"
fi
if [ -n "$LIVE_MINIO_PASS" ]; then
    update_secrets_json ".minio.root_password" "$LIVE_MINIO_PASS"
fi

if [ -n "$MINIO_PASS" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/minio root-user="$MINIO_USER" root-password="$MINIO_PASS" endpoint="$MINIO_ENDPOINT" bucket="$MINIO_BUCKET"
    echo "[+] secret/minio updated"
fi

# 5. Database Secrets
DEV_USER=$(jq -r '.database.dev.user // .database.dev.username // "appuser"' "$SECRETS_FILE")
DEV_PASS=$(jq -r '.database.dev.password // "app_password_123"' "$SECRETS_FILE")
DEV_ROOT_PASS=$(jq -r '.database.dev.root_password // "root_password_123"' "$SECRETS_FILE")
DEV_DB=$(jq -r '.database.dev.name // .database.dev.database // "appdb"' "$SECRETS_FILE")

if [ -n "$DEV_PASS" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/database \
        user="$DEV_USER" \
        username="$DEV_USER" \
        password="$DEV_PASS" \
        root-password="$DEV_ROOT_PASS" \
        name="$DEV_DB" \
        database="$DEV_DB" \
        minio_endpoint="$MINIO_ENDPOINT" \
        minio_access_key="$MINIO_USER" \
        minio_secret_key="$MINIO_PASS" \
        minio_bucket="$MINIO_BUCKET"
    echo "[+] secret/dev/database updated"
fi

# 6. App Secrets
JWT_SECRET=$(jq -r '.app.jwt_secret // "SuperSecretJwtKey2026!"' "$SECRETS_FILE")
DB_URL=$(jq -r '.app.db_url // "mysql://appuser:app_password_123@db-primary:3306/appdb"' "$SECRETS_FILE")

if [ -n "$JWT_SECRET" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/app jwt-secret="$JWT_SECRET" db-url="$DB_URL"
    echo "[+] secret/app updated"
fi

# 7. Argo CD (Live K8s Secret OR secrets.json)
LIVE_ARGO_PASS=$(kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
ARGO_USER=$(jq -r '.argocd.admin_user // "admin"' "$SECRETS_FILE")
ARGO_PASS="${LIVE_ARGO_PASS:-$(jq -r '.argocd.admin_password // empty' "$SECRETS_FILE")}"
ARGO_URL=$(jq -r '.argocd.url // "https://vargocd.aliien.uk"' "$SECRETS_FILE")

if [ -n "$LIVE_ARGO_PASS" ]; then
    update_secrets_json ".argocd.admin_password" "$LIVE_ARGO_PASS"
fi

if [ -n "$ARGO_PASS" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/argocd admin-user="$ARGO_USER" admin-password="$ARGO_PASS" url="$ARGO_URL"
    echo "[+] secret/dev/argocd updated"
fi

# 8. Grafana Secrets
GRAFANA_USER=$(jq -r '.grafana.admin_user // "admin"' "$SECRETS_FILE")
GRAFANA_PASS=$(jq -r '.grafana.admin_password // "admin"' "$SECRETS_FILE")
GRAFANA_URL=$(jq -r '.grafana.url // "https://vgrafana.aliien.uk"' "$SECRETS_FILE")

if [ -n "$GRAFANA_PASS" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/grafana admin-user="$GRAFANA_USER" admin-password="$GRAFANA_PASS" url="$GRAFANA_URL"
    echo "[+] secret/dev/grafana updated"
fi

echo "=== Vault & secrets.json Hybrid Secret Sync Complete! ==="
