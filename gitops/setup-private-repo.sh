#!/usr/bin/env bash
# ==============================================================================
# Configure Argo CD Private GitHub Repository Access via Vault / Environment
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GITHUB_TOKEN="${1:-$GITHUB_TOKEN}"

# Attempt to fetch GITHUB_TOKEN from Vault if not passed
if [ -z "$GITHUB_TOKEN" ]; then
  echo "--> Attempting to fetch GitHub Token from HashiCorp Vault (secret/dev/github)..."
  GITHUB_TOKEN=$(kubectl exec -n vault vault-0 -- vault kv get -field=token secret/dev/github 2>/dev/null || echo "")
fi

if [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" == "ghp_YOUR_PERSONAL_ACCESS_TOKEN_HERE" ]; then
  echo "[!] GITHUB_TOKEN not found in command arguments, environment, or Vault."
  echo "Usage: $0 <GITHUB_PERSONAL_ACCESS_TOKEN>"
  echo "Or store it in infrastructure/vault/secrets.json and run make vault-sync"
  exit 1
fi

echo "=== Registering Private GitHub Repository with Argo CD ==="

export GITHUB_TOKEN
if command -v envsubst &>/dev/null; then
  envsubst < "${SCRIPT_DIR}/argocd-repo-secret.yml" | kubectl apply -f -
else
  sed "s|\${GITHUB_TOKEN}|${GITHUB_TOKEN}|g" "${SCRIPT_DIR}/argocd-repo-secret.yml" | kubectl apply -f -
fi

echo "======================================================================"
echo "[SUCCESS] Private repository registered in Argo CD secret 'repo-imagine-local-stack'!"
echo "======================================================================"
