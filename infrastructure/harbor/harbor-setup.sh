#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploying Self-Hosted Harbor Registry ==="

kubectl create namespace harbor --dry-run=client -o yaml | kubectl apply -f -

echo "Ensuring host directory permissions for Harbor..."
if command -v minikube &>/dev/null; then
    minikube ssh "sudo mkdir -p /mnt/data/harbor && sudo chmod -R 777 /mnt/data" &>/dev/null || true
fi
sudo mkdir -p /mnt/data/harbor 2>/dev/null || true
sudo chmod -R 777 /mnt/data 2>/dev/null || true

# Fetch admin password dynamically from Vault (checking /dev/harbor or /harbor) or fallback to local secrets.json
HARBOR_PASS=$(kubectl exec -n vault vault-0 -- vault kv get -field=admin-password secret/dev/harbor 2>/dev/null || kubectl exec -n vault vault-0 -- vault kv get -field=admin-password secret/harbor 2>/dev/null || jq -r '.harbor.admin_password // "HarborAdminPassword123"' "${SCRIPT_DIR}/../vault/secrets.json" 2>/dev/null || echo "HarborAdminPassword123")

if ! kubectl get app harbor -n argocd &>/dev/null; then
  helm repo add harbor https://helm.goharbor.io
  helm repo update
  helm upgrade --install harbor harbor/harbor \
    --namespace harbor \
    --set harborAdminPassword="$HARBOR_PASS" \
    -f "${SCRIPT_DIR}/harbor-values.yml"
else
  echo "Argo CD GitOps is active. Harbor deployment managed by Argo CD."
fi


echo "=== Harbor Registry Deployed Successfully ==="
echo "Access URL: https://vharbor.aliien.uk"
echo "Admin Username: admin"
