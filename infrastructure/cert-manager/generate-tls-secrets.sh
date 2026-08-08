# #!/bin/bash
# # ==============================================================================
# # Declarative TLS Secret Manifest Generator
# # Converts Let's Encrypt certificates into static Kubernetes Secret YAML manifests
# # ==============================================================================
# set -e

# CERT_PATH="/etc/letsencrypt/live/aliien.uk/fullchain.pem"
# KEY_PATH="/etc/letsencrypt/live/aliien.uk/privkey.pem"
# OUTPUT_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tls-secrets.yaml"

# if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
#     echo "[!] Certbot certificates not found at /etc/letsencrypt/live/aliien.uk/"
#     echo "    Run certbot first to issue certificates."
#     exit 1
# fi

# B64_CERT=$(sudo base64 -w0 "$CERT_PATH")
# B64_KEY=$(sudo base64 -w0 "$KEY_PATH")

# NAMESPACES=("default" "harbor" "minio" "vault" "monitoring" "argocd")

# echo "# ==============================================================================" > "$OUTPUT_FILE"
# echo "# Declarative TLS Secret Manifests for aliien.uk (Auto-Generated)" >> "$OUTPUT_FILE"
# echo "# ==============================================================================" >> "$OUTPUT_FILE"

# for ns in "${NAMESPACES[@]}"; do
# cat <<EOF >> "$OUTPUT_FILE"
# ---
# apiVersion: v1
# kind: Secret
# metadata:
#   name: aliien-uk-tls
#   namespace: ${ns}
# type: kubernetes.io/tls
# data:
#   tls.crt: ${B64_CERT}
#   tls.key: ${B64_KEY}
# EOF
# done

# echo "[+] Created declarative TLS secret manifest at: ${OUTPUT_FILE}"


##for now i used by command >> after handeling the certbot and SSL certificate from Let's Encrypt

# sudo kubectl create secret tls aliien-uk-tls \
#   --cert=/etc/letsencrypt/live/aliien.uk/fullchain.pem \
#   --key=/etc/letsencrypt/live/aliien.uk/privkey.pem \
#   -n default --dry-run=client -o yaml | kubectl apply -f -