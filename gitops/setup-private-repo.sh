#!/usr/bin/env bash
set -e

# ==============================================================================
# Configure Argo CD Private GitHub Repository Access
# ==============================================================================

GITHUB_TOKEN="${1:-$GITHUB_TOKEN}"

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Usage: $0 <GITHUB_PERSONAL_ACCESS_TOKEN>"
  echo "Or set GITHUB_TOKEN environment variable."
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
[SUCCESS] Private repository registered in Argo CD secret 'repo-imagine-local-stack'!
======================================================================

