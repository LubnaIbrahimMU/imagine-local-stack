#!/bin/bash
# ==============================================================================
# Install External Secrets Operator (ESO) & CRDs via Helm
# ==============================================================================
set -e

echo "=== Adding External Secrets Operator Helm Repository ==="
helm repo add external-secrets https://charts.external-secrets.io || true
helm repo update

echo "=== Installing External Secrets CRDs (Server-Side Apply) ==="
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml

echo "=== Installing External Secrets Operator into namespace 'external-secrets' ==="
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace

echo "=== External Secrets Operator Installed Successfully! ==="
