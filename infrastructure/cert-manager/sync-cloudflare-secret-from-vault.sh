#!/bin/bash
# ==============================================================================
# Sync Cloudflare API Token from Vault into Kubernetes Secrets
# (For cert-manager and default namespaces)
# ==============================================================================
set -e

echo "=== Fetching Cloudflare API Token from Vault ==="
CF_TOKEN=$(kubectl exec -n vault vault-0 -- vault kv get -field=api-token secret/dev/cloudflare 2>/dev/null || kubectl exec -n vault vault-0 -- vault kv get -field=api-token secret/cloudflare 2>/dev/null || echo "")

if [ -z "$CF_TOKEN" ] || [ "$CF_TOKEN" == "cfut_placeholder_token" ]; then
    echo "[!] Cloudflare API token not found or is placeholder in Vault."
    echo "    Run: ./infrastructure/vault/seed-vault-secrets.sh"
    exit 1
fi

echo "=== Syncing Kubernetes Secret 'cloudflare-api-token-secret' ==="
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic cloudflare-api-token-secret -n cert-manager \
  --from-literal=api-token="$CF_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic cloudflare-api-token-secret -n default \
  --from-literal=api-token="$CF_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=== Secret Sync Complete! ==="
