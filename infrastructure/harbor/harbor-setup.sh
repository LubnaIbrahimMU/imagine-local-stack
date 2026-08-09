#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARBOR_CHART_VERSION="1.15.2"

echo "=== Deploying Self-Hosted Harbor Registry ==="

kubectl create namespace harbor --dry-run=client -o yaml | kubectl apply -f -

echo "Ensuring host directory permissions for Harbor..."
if command -v minikube &>/dev/null; then
    minikube ssh "sudo mkdir -p /mnt/data/harbor/registry /mnt/data/postgres /mnt/data/redis && sudo chown -R 999:999 /mnt/data/redis /mnt/data/postgres && sudo chmod -R 777 /mnt/data" &>/dev/null
fi
sudo mkdir -p /mnt/data/harbor 2>/dev/null || true
sudo chmod -R 777 /mnt/data 2>/dev/null || true

# Fetch admin password dynamically from Vault (checking /dev/harbor or /harbor) or fallback to local secrets.json
HARBOR_PASS=$(kubectl exec -n vault vault-0 -- vault kv get -field=admin-password secret/dev/harbor 2>/dev/null || kubectl exec -n vault vault-0 -- vault kv get -field=admin-password secret/harbor 2>/dev/null || jq -r '.harbor.admin_password // "HarborAdminPassword123"' "${SCRIPT_DIR}/../vault/secrets.json" 2>/dev/null || echo "HarborAdminPassword123")

# Harbor chart 1.19+ writes Valkey RDB files. Chart 1.15.x uses Redis, which
# cannot read that format. This can happen when a previous unpinned Helm
# install is later reconciled by Argo CD. Quarantine cache only; Harbor's
# durable registry and database volumes are left untouched.
if minikube ssh "sudo sh -c 'test -f /mnt/data/redis/dump.rdb && head -c 6 /mnt/data/redis/dump.rdb | grep -q VALKEY'" &>/dev/null; then
  echo "Found a Valkey cache file incompatible with Harbor chart ${HARBOR_CHART_VERSION}; quarantining it..."
  kubectl scale statefulset harbor-redis -n harbor --replicas=0 &>/dev/null || true
  kubectl wait -n harbor --for=delete pod/harbor-redis-0 --timeout=120s &>/dev/null || true
  minikube ssh "sudo sh -c 'mv /mnt/data/redis/dump.rdb /mnt/data/redis/dump.rdb.valkey-incompatible && chown -R 999:999 /mnt/data/redis'"
  kubectl scale statefulset harbor-redis -n harbor --replicas=1
  kubectl rollout status statefulset/harbor-redis -n harbor --timeout=5m
  kubectl rollout restart deployment/harbor-core deployment/harbor-jobservice -n harbor
fi

if ! kubectl get app harbor -n argocd &>/dev/null; then
  helm repo add harbor https://helm.goharbor.io
  helm repo update

  helm upgrade --install harbor harbor/harbor \
    --version "${HARBOR_CHART_VERSION}" \
    --namespace harbor \
    --set harborAdminPassword="$HARBOR_PASS" \
    -f "${SCRIPT_DIR}/harbor-values.yml" \
    --wait --timeout 10m
else
  echo "Argo CD GitOps is active. Harbor deployment managed by Argo CD."
fi

echo "Waiting for Harbor Redis, database, core, registry, and jobservice..."
for workload in harbor-redis harbor-database; do
  kubectl rollout status "statefulset/${workload}" -n harbor --timeout=10m
done
for workload in harbor-core harbor-registry harbor-jobservice; do
  kubectl rollout status "deployment/${workload}" -n harbor --timeout=10m
done

echo "=== Harbor Registry Deployed Successfully ==="
echo "Access URL: https://vharbor.aliien.uk"
echo "Admin Username: admin"
