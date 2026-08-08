#!/bin/bash
# ==============================================================================
# One-Touch Local Environment Bootstrapper
# Initializes Minikube, NGINX Ingress, Vault, Harbor, Argo CD, Monitoring
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== [1/6] Initializing Minikube Cluster ==="
if command -v minikube &>/dev/null; then
    minikube status &>/dev/null || minikube start --cpus=2 --memory=4096 --driver=docker --addons=ingress,metrics-server
fi

echo "=== [2/6] Deploying NGINX Ingress Controller ==="
# Option A: Minikube Native Ingress Addon (Recommended for local dev)
"${BASE_DIR}/infrastructure/nginx-ingress/install-nginx.sh"
# Option B: Standard Helm Chart Installation (Uncomment to use Helm)
# "${BASE_DIR}/infrastructure/nginx-ingress/install-nginx.sh" --helm



echo "=== [3/6] Initializing & Unsealing HashiCorp Vault ==="
"${BASE_DIR}/infrastructure/vault/vault-init.sh"

echo "=== [4/6] Deploying Self-Hosted Harbor Registry ==="
"${BASE_DIR}/infrastructure/harbor/harbor-setup.sh" || true

echo "=== [5/6] Deploying Argo CD GitOps Operator ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== [6/6] Syncing Reboot Persistence & Local Host Resolution ==="
"${SCRIPT_DIR}/reboot-persistence-sync.sh"

echo "======================================================================"
echo "[COMPLETE] Local Enterprise Kubernetes Platform is Ready!"
echo "Argo CD Admin Password Retrieval Command:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "======================================================================"
