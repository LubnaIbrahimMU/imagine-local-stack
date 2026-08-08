#!/bin/bash
# ==============================================================================
# Cert-Manager Helm Installation Script (with CRDs)
# ==============================================================================
set -e

echo "=== Installing Cert-Manager into cert-manager namespace ==="

helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait --timeout=120s

echo "=== Cert-Manager Installation Complete! ==="
