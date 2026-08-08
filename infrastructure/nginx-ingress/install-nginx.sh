#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USE_HELM="${1:-false}"

echo "=== Deploying NGINX Ingress Controller ==="

if [ "$USE_HELM" == "--helm" ]; then
    echo "Deploying via Helm Chart..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
      --namespace ingress-nginx \
      -f "${SCRIPT_DIR}/values-nginx.yaml"
elif command -v minikube &>/dev/null; then
    echo "Enabling Minikube Native Ingress Addon..."
    minikube addons enable ingress
else
    echo "Deploying via Native Kubernetes Manifest..."
    kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f "${SCRIPT_DIR}/nginx-ingress-manifest.yaml"
fi

echo "Waiting for NGINX Ingress Controller to be ready..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=90s || true

echo "=== NGINX Ingress Controller Deployed Successfully ==="
