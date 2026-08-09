#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_FILE="${SCRIPT_DIR}/vault-keys.json"

echo "=== Vault Automated Initialization & Configuration ==="

kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -

echo "Ensuring host directory permissions for Vault storage..."
if command -v minikube &>/dev/null; then
    minikube ssh "sudo mkdir -p /mnt/data/vault && sudo chmod -R 777 /mnt/data" &>/dev/null || true
fi
sudo mkdir -p /mnt/data/vault 2>/dev/null || true
sudo chmod -R 777 /mnt/data 2>/dev/null || true

if ! kubectl get app vault -n argocd &>/dev/null; then
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm repo update
  helm upgrade --install vault hashicorp/vault \
    --namespace vault \
    -f "${SCRIPT_DIR}/vault-values.yml" || true
else
  echo "Argo CD GitOps is active. Vault deployment managed by Argo CD."
fi

VAULT_POD="vault-0"

echo "Waiting for Vault pod $VAULT_POD to be Running..."
kubectl wait --namespace vault --for=jsonpath='{.status.phase}'=Running pod/$VAULT_POD --timeout=120s || true

# Check if Vault is initialized inside the container
IS_INIT=$(kubectl exec -n vault $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.initialized // false' 2>/dev/null || echo "false")

if [ "$IS_INIT" = "false" ]; then
    echo "Vault is NOT initialized. Initializing Vault operator..."
    rm -f "$KEYS_FILE" "${KEYS_FILE}.tmp"
    kubectl exec -n vault $VAULT_POD -- vault operator init -key-shares=5 -key-threshold=3 -format=json > "${KEYS_FILE}.tmp" 2>/dev/null || true
    if [ -s "${KEYS_FILE}.tmp" ]; then
        mv "${KEYS_FILE}.tmp" "$KEYS_FILE"
        echo "Vault initialization keys saved securely to $KEYS_FILE"
    fi
else
    echo "Vault is already initialized."
fi

UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' "$KEYS_FILE" 2>/dev/null || echo "")
UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' "$KEYS_FILE" 2>/dev/null || echo "")
UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' "$KEYS_FILE" 2>/dev/null || echo "")
ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE" 2>/dev/null || echo "")

if [ -n "$UNSEAL_KEY_1" ]; then
    echo "Unsealing Vault..."
    kubectl exec -n vault $VAULT_POD -- vault operator unseal "$UNSEAL_KEY_1" || true
    kubectl exec -n vault $VAULT_POD -- vault operator unseal "$UNSEAL_KEY_2" || true
    kubectl exec -n vault $VAULT_POD -- vault operator unseal "$UNSEAL_KEY_3" || true
fi

if [ -n "$ROOT_TOKEN" ]; then
    echo "Logging into Vault with Root Token..."
    kubectl exec -n vault $VAULT_POD -- vault login "$ROOT_TOKEN" || true

    echo "Enabling KV-v2 Secrets Engine at secret/..."
    kubectl exec -n vault $VAULT_POD -- vault secrets enable -path=secret kv-v2 2>/dev/null || true

    echo "Writing Database & Service Secrets..."
    bash "${SCRIPT_DIR}/seed-vault-secrets.sh" || true

    echo "Applying Vault Access Policies..."
    kubectl exec -n vault -i $VAULT_POD -- vault policy write app-policy - < "${SCRIPT_DIR}/policies/app-policy.hcl" || true

    echo "Enabling Kubernetes Authentication Engine..."
    kubectl exec -n vault $VAULT_POD -- vault auth enable kubernetes 2>/dev/null || true

    echo "Configuring Kubernetes Authentication Engine..."
    kubectl exec -n vault $VAULT_POD -- vault write auth/kubernetes/config \
        kubernetes_host="https://kubernetes.default.svc:443" || true

    echo "Binding Vault Role 'app-role' to Application ServiceAccounts..."
    kubectl exec -n vault $VAULT_POD -- vault write auth/kubernetes/role/app-role \
        bound_service_account_names="*-backend-sa,default,backend-service-sa" \
        bound_service_account_namespaces="default,dev,uat,prd" \
        policies="app-policy" \
        ttl=24h || true
fi

echo "=== Vault Initialization & Secret Injection Setup Complete ==="
