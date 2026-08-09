#!/bin/bash
# ==============================================================================
# One-Touch Local Environment Bootstrapper
# Initializes Minikube, NGINX Ingress, Vault, Harbor, MinIO, Argo CD, Monitoring
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== [1/6] Initializing Minikube Cluster & Storage Directories ==="
if command -v minikube &>/dev/null; then
    minikube status &>/dev/null || minikube start --cpus=4 --memory=6144 --driver=docker --addons=ingress,metrics-server
    
    # Create persistent paths with the UIDs used by the containers. Do not wipe
    # persistent service data during an idempotent setup run.
    minikube ssh "sudo mkdir -p /mnt/data/vault /mnt/data/minio /mnt/data/harbor/registry /mnt/data/postgres /mnt/data/redis /mnt/data/backups && sudo chown -R 999:999 /mnt/data/redis /mnt/data/postgres && sudo chown -R 1000:1000 /mnt/data/minio && sudo chmod -R 777 /mnt/data && sudo chmod 700 /mnt/data/postgres" &>/dev/null
fi

echo "--> Applying Platform Namespaces..."
kubectl apply -f "${BASE_DIR}/infrastructure/namespaces.yml"

echo "--> Applying Local Persistent Volumes & PVCs (PV/PVC)..."
kubectl apply -f "${BASE_DIR}/infrastructure/pv-local.yml"

echo "=== [2/6] Deploying NGINX Ingress Controller ==="
"${BASE_DIR}/infrastructure/nginx-ingress/install-nginx.sh"

echo "=== [3/6] Initializing & Unsealing HashiCorp Vault ==="
"${BASE_DIR}/infrastructure/vault/vault-init.sh"

echo "=== [4/6] Deploying Self-Hosted Harbor Registry & MinIO Storage ==="
"${BASE_DIR}/infrastructure/harbor/harbor-setup.sh"

if [ -f "${BASE_DIR}/infrastructure/minio/minio-setup.sh" ]; then
    chmod +x "${BASE_DIR}/infrastructure/minio/minio-setup.sh"
    "${BASE_DIR}/infrastructure/minio/minio-setup.sh" || true
fi

echo "=== [5/6] Deploying Metrics Server & Argo CD GitOps Operator ==="
"${BASE_DIR}/infrastructure/metrics-server/install-metrics-server.sh"
"${BASE_DIR}/infrastructure/argocd/install-argocd.sh"

if [ -f "${BASE_DIR}/gitops/setup-private-repo.sh" ]; then
    chmod +x "${BASE_DIR}/gitops/setup-private-repo.sh"
    "${BASE_DIR}/gitops/setup-private-repo.sh" || true
fi

if [ -f "${BASE_DIR}/gitops/argo-app-of-apps/argo.yml" ]; then
    kubectl apply -f "${BASE_DIR}/gitops/argo-app-of-apps/argo.yml" || true
fi

echo "=== [6/6] Applying TLS Secrets across All Platform Namespaces ==="
if [ -f "${BASE_DIR}/infrastructure/cert-manager/generate-tls-secrets.sh" ]; then
    chmod +x "${BASE_DIR}/infrastructure/cert-manager/generate-tls-secrets.sh"
    "${BASE_DIR}/infrastructure/cert-manager/generate-tls-secrets.sh" || true
fi

# Automatically configure Minikube Docker daemon to trust Harbor registry TLS certificate
if kubectl get secret aliien-uk-tls -n harbor &>/dev/null; then
    kubectl get secret aliien-uk-tls -n harbor -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/harbor-ca.crt 2>/dev/null || true
    minikube ssh "sudo mkdir -p /etc/docker/certs.d/vharbor.aliien.uk" &>/dev/null || true
    minikube cp /tmp/harbor-ca.crt /tmp/harbor-ca.crt &>/dev/null || true
    minikube ssh "sudo mv /tmp/harbor-ca.crt /etc/docker/certs.d/vharbor.aliien.uk/ca.crt && sudo systemctl restart docker" &>/dev/null || true
fi

echo "=== Syncing Reboot Persistence & Local Host Resolution ==="
"${SCRIPT_DIR}/reboot-persistence-sync.sh"

echo "======================================================================"
echo "[COMPLETE] Local Enterprise Kubernetes Platform is Ready!"
echo "Argo CD Admin Password Retrieval Command:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "======================================================================"
