#!/bin/bash
# ==============================================================================
# Propagate Issued TLS Secret (aliien-uk-tls) Across All Namespaces
# ==============================================================================
set -e

NAMESPACES=("harbor" "minio" "vault" "monitoring" "argocd")

echo "=== Propagating aliien-uk-tls secret across namespaces ==="

for ns in "${NAMESPACES[@]}"; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
    kubectl get secret aliien-uk-tls -n default -o yaml | \
      sed "s/namespace: default/namespace: ${ns}/" | \
      kubectl apply -f -
    echo "[+] TLS Secret copied to namespace: ${ns}"
done

echo "=== TLS Secret Propagation Complete! ==="
