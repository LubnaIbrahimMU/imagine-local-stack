#!/bin/bash
# ==============================================================================
# Install External Secrets Operator (ESO) & CRDs via Helm
# ==============================================================================
set -e

echo "=== Adding External Secrets Operator Helm Repository ==="
helm repo add external-secrets https://charts.external-secrets.io || true
helm repo update

echo "=== Installing External Secrets Operator & CRDs into namespace 'external-secrets' ==="
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set installCRDs=true

echo "=== External Secrets Operator Installed Successfully! ==="
