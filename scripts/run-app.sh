#!/bin/bash
# ==============================================================================
# MYPRO PLATFORM - STANDALONE APPLICATION RUNNER & DEPLOYMENT SCRIPT
# ==============================================================================
# This script provides all the necessary commands to run, deploy, and verify
# the MyPro Enterprise application on Kubernetes using Helm & GitOps (Argo CD).
# Location: ./scripts/run-app.sh
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${NAMESPACE:-dev}"
RELEASE_NAME="${RELEASE_NAME:-app-mypro-dev}"
CHART_PATH="${SCRIPT_DIR}/helm/charts/umbrella-app"
VALUES_PATH="${SCRIPT_DIR}/helm/values/values-dev.yml"

echo "========================================================================="
echo "             MYPRO KUBERNETES & HELM APPLICATION RUNNER                  "
echo "========================================================================="

usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Available Commands:"
    echo "  deploy          Deploy the complete application stack using Helm"
    echo "  deploy-gitops   Deploy the application via Argo CD GitOps"
    echo "  package-charts  Rebuild & package all sub-charts into the umbrella chart"
    echo "  sync-vault      Seed & sync HashiCorp Vault secrets with Kubernetes"
    echo "  fix-harbor      Fix Harbor Postgres PVC directory permissions in minikube"
    echo "  status          Display current pod and deployment health status"
    echo "  verify          Run health checks on API and Frontend endpoints"
    echo "  clean           Tear down the dev environment namespace"
    echo ""
}

MODE="${1:-deploy}"

case "$MODE" in
    package-charts)
        echo "=== Packaging Helm Sub-Charts ==="
        helm package "${SCRIPT_DIR}/helm/charts/backend-service" -d "${SCRIPT_DIR}/helm/charts/umbrella-app/charts/"
        helm package "${SCRIPT_DIR}/helm/charts/backup-service" -d "${SCRIPT_DIR}/helm/charts/umbrella-app/charts/"
        helm package "${SCRIPT_DIR}/helm/charts/db-service" -d "${SCRIPT_DIR}/helm/charts/umbrella-app/charts/"
        helm package "${SCRIPT_DIR}/helm/charts/frontend-service" -d "${SCRIPT_DIR}/helm/charts/umbrella-app/charts/"
        helm package "${SCRIPT_DIR}/helm/charts/redis-service" -d "${SCRIPT_DIR}/helm/charts/umbrella-app/charts/"
        echo "[+] Helm charts packaged successfully!"
        ;;

    sync-vault)
        echo "=== Syncing Vault Secrets ==="
        "${SCRIPT_DIR}/infrastructure/vault/seed-vault-secrets.sh"
        ;;

    fix-harbor)
        echo "=== Fixing Harbor Postgres PVC Permissions ==="
        if command -v minikube &>/dev/null; then
            minikube ssh "sudo chown -R 999:999 /mnt/data/postgres && sudo chmod -R 700 /mnt/data/postgres && sudo find /mnt/data/postgres -type d -exec chmod 700 {} \;"
            kubectl delete pod harbor-database-0 -n harbor --ignore-not-found=true
            echo "[+] Harbor database permissions fixed!"
        fi
        ;;

    deploy)
        echo "=== Deploying MyPro Application via Helm ==="
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
        
        # Package chart dependencies
        "$0" package-charts

        # Deploy Umbrella Chart
        echo "[*] Running Helm Upgrade/Install..."
        helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
            --namespace "$NAMESPACE" \
            --create-namespace \
            -f "$VALUES_PATH"

        echo "[+] Waiting for workloads to become ready..."
        kubectl rollout status deployment/"${RELEASE_NAME}-frontend" -n "$NAMESPACE" --timeout=3m || true
        kubectl rollout status statefulset/"${RELEASE_NAME}-db-primary" -n "$NAMESPACE" --timeout=3m || true

        echo "=== Application Deployed Successfully ==="
        "$0" status
        ;;

    deploy-gitops)
        echo "=== Deploying MyPro Application via Argo CD GitOps ==="
        kubectl apply -f "${SCRIPT_DIR}/gitops/apps/applications/mypro-app-dev.yml"
        echo "[+] Argo CD Application created/updated."
        kubectl get app app-mypro-dev -n argocd
        ;;

    status)
        echo "=== Current Pod Status in '${NAMESPACE}' Namespace ==="
        kubectl get pods -n "$NAMESPACE" -o wide
        echo ""
        echo "=== Ingress Endpoints ==="
        kubectl get ingress -n "$NAMESPACE"
        ;;

    verify)
        echo "=== Verifying Application Health Endpoints ==="
        MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "127.0.0.1")
        echo "[*] Minikube Node IP: $MINIKUBE_IP"
        
        echo -n "[1/2] Checking Backend API Health (https://vapi.aliien.uk/health)... "
        CURL_BACKEND=$(curl -s -k --resolve vapi.aliien.uk:443:"${MINIKUBE_IP}" https://vapi.aliien.uk/health || echo "FAILED")
        echo "$CURL_BACKEND"

        echo -n "[2/2] Checking Frontend UI (https://vapp.aliien.uk/)... "
        CURL_FRONTEND=$(curl -s -k -o /dev/null -w "%{http_code}" --resolve vapp.aliien.uk:443:"${MINIKUBE_IP}" https://vapp.aliien.uk/ || echo "FAILED")
        echo "HTTP Status Code: $CURL_FRONTEND"
        ;;

    clean)
        echo "=== Cleaning Development Environment ==="
        helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null || true
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        echo "[+] Namespace '${NAMESPACE}' cleaned."
        ;;

    *)
        usage
        exit 1
        ;;
esac
