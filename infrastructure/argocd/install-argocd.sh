#!/bin/bash
# ==============================================================================
# Install Argo CD Controller & CRDs into Namespace 'argocd'
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "=== [1/2] Applying Platform Namespaces ==="
kubectl apply -f "${BASE_DIR}/infrastructure/namespaces.yml"

echo "=== [2/3] Installing Argo CD Core Controller & CRDs ==="
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== [3/3] Creating Argo CD Ingress Routing ==="
kubectl apply -f "${SCRIPT_DIR}/argocd-ingress.yml"

echo "=== Argo CD Engine Installed & Ingress Configured! ==="
