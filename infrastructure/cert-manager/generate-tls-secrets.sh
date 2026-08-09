#!/bin/bash
# ==============================================================================
# Declarative TLS Secret Manifest Generator
# Converts Let's Encrypt certificates into static Kubernetes Secret YAML manifests
# ==============================================================================
set -e

CERT_PATH="/etc/letsencrypt/live/aliien.uk/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/aliien.uk/privkey.pem"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${SCRIPT_DIR}/tls-secrets.yml"

# Check file existence with sudo since /etc/letsencrypt/live is restricted to root
if ! sudo test -f "$CERT_PATH" || ! sudo test -f "$KEY_PATH"; then
    echo "[!] Certbot certificates not found at /etc/letsencrypt/live/aliien.uk/"
    echo "    Run certbot first to issue certificates."
    exit 1
fi

B64_CERT=$(sudo base64 -w0 "$CERT_PATH")
B64_KEY=$(sudo base64 -w0 "$KEY_PATH")

NAMESPACES=("default" "harbor" "minio" "vault" "monitoring" "argocd" "dev" "uat" "prd")

echo "# ==============================================================================" > "$OUTPUT_FILE"
echo "# Declarative TLS Secret Manifests for aliien.uk (Auto-Generated)" >> "$OUTPUT_FILE"
echo "# ==============================================================================" >> "$OUTPUT_FILE"

for ns in "${NAMESPACES[@]}"; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true

cat <<EOF >> "$OUTPUT_FILE"
---
apiVersion: v1
kind: Secret
metadata:
  name: aliien-uk-tls
  namespace: ${ns}
type: kubernetes.io/tls
data:
  tls.crt: ${B64_CERT}
  tls.key: ${B64_KEY}
EOF
done

# Also ensure harbor-ingress secret exists in harbor namespace for Helm compatibility
cat <<EOF >> "$OUTPUT_FILE"
---
apiVersion: v1
kind: Secret
metadata:
  name: harbor-ingress
  namespace: harbor
type: kubernetes.io/tls
data:
  tls.crt: ${B64_CERT}
  tls.key: ${B64_KEY}
EOF

echo "[+] Created declarative TLS secret manifest at: ${OUTPUT_FILE}"

echo "=== Applying TLS Secrets across namespaces ==="
kubectl apply -f "$OUTPUT_FILE"

echo "======================================================================"
echo "[SUCCESS] HTTPS TLS Secret 'aliien-uk-tls' applied across all namespaces!"
echo "======================================================================"

# ==============================================================================
# Single-line alternative command (Kept hashed for reference as requested)
# ==============================================================================
# sudo kubectl create secret tls aliien-uk-tls \
#   --cert=/etc/letsencrypt/live/aliien.uk/fullchain.pem \
#   --key=/etc/letsencrypt/live/aliien.uk/privkey.pem \
#   -n default --dry-run=client -o yaml | kubectl apply -f -
