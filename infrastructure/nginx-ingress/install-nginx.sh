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
      -f "${SCRIPT_DIR}/values-nginx.yml"
elif command -v minikube &>/dev/null; then
    echo "Enabling Minikube Native Ingress Addon..."
    minikube addons enable ingress
else
    echo "Deploying via Native Kubernetes Manifest..."
    kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f "${SCRIPT_DIR}/nginx-ingress-manifest.yml"
fi

echo "Waiting for NGINX Ingress Controller to be ready..."
kubectl rollout status deployment/ingress-nginx-controller \
  --namespace ingress-nginx \
  --timeout=5m

# The admission jobs populate the webhook CA bundle. Deleting the webhook here
# causes Minikube's addon manager to recreate an unsigned definition, after the
# one-shot patch job has already completed, and all later Ingress applies fail.
if kubectl get validatingwebhookconfiguration ingress-nginx-admission &>/dev/null; then
  kubectl wait --for=condition=complete job/ingress-nginx-admission-create \
    --namespace ingress-nginx --timeout=2m
  kubectl wait --for=condition=complete job/ingress-nginx-admission-patch \
    --namespace ingress-nginx --timeout=2m
fi

echo "=== NGINX Ingress Controller Deployed Successfully ==="
