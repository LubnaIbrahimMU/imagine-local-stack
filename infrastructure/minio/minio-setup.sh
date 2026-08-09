#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREREQUISITES_ONLY="${1:-false}"

echo "=== Deploying Self-Hosted MinIO Object Storage ==="

kubectl create namespace minio --dry-run=client -o yaml | kubectl apply -f -

echo "Ensuring host directory permissions for MinIO..."
if command -v minikube &>/dev/null; then
    minikube ssh "sudo mkdir -p /mnt/data/minio && sudo chmod -R 777 /mnt/data" &>/dev/null || true
fi
sudo mkdir -p /mnt/data/minio 2>/dev/null || true
sudo chmod -R 777 /mnt/data 2>/dev/null || true

# Fetch secrets from Vault (checking /dev/minio or /minio) or fallback to local secrets.json
MINIO_USER=$(kubectl exec -n vault vault-0 -- vault kv get -field=root-user secret/dev/minio 2>/dev/null || kubectl exec -n vault vault-0 -- vault kv get -field=root-user secret/minio 2>/dev/null || jq -r '.minio.root_user // "admin"' "${SCRIPT_DIR}/../vault/secrets.json" 2>/dev/null || echo "admin")
MINIO_PASS=$(kubectl exec -n vault vault-0 -- vault kv get -field=root-password secret/dev/minio 2>/dev/null || kubectl exec -n vault vault-0 -- vault kv get -field=root-password secret/minio 2>/dev/null || jq -r '.minio.root_password // "MinioAdminPassword123"' "${SCRIPT_DIR}/../vault/secrets.json" 2>/dev/null || echo "MinioAdminPassword123")

# Dynamically create Kubernetes secret for MinIO
kubectl create secret generic minio-secret -n minio \
  --from-literal=root-user="$MINIO_USER" \
  --from-literal=root-password="$MINIO_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

if [ "$PREREQUISITES_ONLY" = "--prerequisites-only" ]; then
  echo "MinIO storage and credentials are ready; Argo CD will deploy MinIO."
  exit 0
fi

if ! kubectl get app minio -n argocd &>/dev/null; then
  kubectl delete deployment minio -n minio 2>/dev/null || true
  kubectl apply -f "${SCRIPT_DIR}/../pv-local.yml"
  kubectl apply -f "${SCRIPT_DIR}/minio-deployment.yml"
else
  echo "Argo CD GitOps is active. MinIO deployment managed by Argo CD."
fi


echo "=== MinIO Object Storage Deployed Successfully ==="
echo "Access URL:     https://vminio.aliien.uk"
