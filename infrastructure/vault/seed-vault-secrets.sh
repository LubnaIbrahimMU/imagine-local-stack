#!/bin/bash
# ==============================================================================
# Seed HashiCorp Vault Secrets from Local JSON Configuration (secrets.json)
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

echo "=== Seeding Vault Secrets from ${SECRETS_FILE} ==="

# Read values using jq
CF_TOKEN=$(jq -r '.cloudflare.api_token // empty' "$SECRETS_FILE")
HARBOR_PASS=$(jq -r '.harbor.admin_password // empty' "$SECRETS_FILE")
HARBOR_KEY=$(jq -r '.harbor.secret_key // empty' "$SECRETS_FILE")
MINIO_USER=$(jq -r '.minio.root_user // empty' "$SECRETS_FILE")
MINIO_PASS=$(jq -r '.minio.root_password // empty' "$SECRETS_FILE")

DEV_USER=$(jq -r '.database.dev.username // empty' "$SECRETS_FILE")
DEV_PASS=$(jq -r '.database.dev.password // empty' "$SECRETS_FILE")
DEV_DB=$(jq -r '.database.dev.database // empty' "$SECRETS_FILE")

JWT_SECRET=$(jq -r '.app.jwt_secret // empty' "$SECRETS_FILE")
DB_URL=$(jq -r '.app.db_url // empty' "$SECRETS_FILE")

# Write to Vault
if [ -n "$CF_TOKEN" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/cloudflare api-token="$CF_TOKEN"
    echo "[+] secret/cloudflare updated"
fi

if [ -n "$HARBOR_PASS" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/harbor admin-password="$HARBOR_PASS" secret-key="$HARBOR_KEY"
    echo "[+] secret/harbor updated"
fi

MINIO_ENDPOINT=$(jq -r '.minio.endpoint // empty' "$SECRETS_FILE")
MINIO_BUCKET=$(jq -r '.minio.bucket // empty' "$SECRETS_FILE")

if [ -n "$MINIO_PASS" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/minio root-user="$MINIO_USER" root-password="$MINIO_PASS" endpoint="$MINIO_ENDPOINT" bucket="$MINIO_BUCKET"
    echo "[+] secret/minio updated"
fi

if [ -n "$DEV_PASS" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/database username="$DEV_USER" password="$DEV_PASS" database="$DEV_DB" minio_endpoint="$MINIO_ENDPOINT" minio_access_key="$MINIO_USER" minio_secret_key="$MINIO_PASS" minio_bucket="$MINIO_BUCKET"
    echo "[+] secret/dev/database updated"
fi


if [ -n "$JWT_SECRET" ]; then
    kubectl exec -n vault vault-0 -- vault kv put secret/dev/app jwt-secret="$JWT_SECRET" db-url="$DB_URL"
    echo "[+] secret/app updated"
fi

echo "=== Vault Secret Sync Complete! ==="
