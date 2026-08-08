#!/usr/bin/env bash
set -e

# ==============================================================================
# Configure Argo CD Private GitHub Repository Access via Vault / Environment
# ==============================================================================

GITHUB_TOKEN="${1:-$GITHUB_TOKEN}"

# Attempt to fetch GITHUB_TOKEN from Vault if not passed
if [ -z "$GITHUB_TOKEN" ]; then
  echo "--> Attempting to fetch GitHub Token from HashiCorp Vault (secret/dev/github)..."
  GITHUB_TOKEN=$(kubectl exec -n vault vault-0 -- vault kv get -field=token secret/dev/github 2>/dev/null || echo "")

fi

if [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" == "ghp_YOUR_PERSONAL_ACCESS_TOKEN_HERE" ]; then
  echo "[!] GITHUB_TOKEN not found in command arguments, environment, or Vault."
  echo "Usage: $0 <GITHUB_PERSONAL_ACCESS_TOKEN>"
  echo "Or store it in infrastructure/vault/secrets.json and run seed-vault-secrets.sh"
  exit 1
fi

echo "=== Registering Private GitHub Repository with Argo CD ==="

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: repo-imagine-local-stack
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/LubnaIbrahimMU/imagine-local-stack.git
  username: LubnaIbrahimMU
  password: "${GITHUB_TOKEN}"
EOF

echo "======================================================================"
echo "[SUCCESS] Private repository registered in Argo CD secret 'repo-imagine-local-stack'!"
echo "======================================================================"

