#!/bin/bash
# ==============================================================================
# Machine Reboot Persistence & Domain Resolution Manager
# Automatically resolves cluster Ingress IP and updates /etc/hosts upon reboot
# ==============================================================================
set -e

DOMAINS=(
    "vharbor.aliien.uk"
    "vminio.aliien.uk"
    "vvault.aliien.uk"
    "vgrafana.aliien.uk"
    "vargocd.aliien.uk"
    "vapp.aliien.uk"
    "vapi.aliien.uk"
    "argocd.mypro.local"
    "vault.mypro.local"
    "minio.mypro.local"
    "harbor.mypro.local"
    "grafana.mypro.local"
    "app.dev.mypro.local"
)

echo "======================================================================"
echo "[REBOOT PERSISTENCE] Checking Kubernetes Cluster & Ingress Status..."
echo "======================================================================"

# 1. Detect & start local K8s cluster if stopped
if command -v minikube &>/dev/null; then
    STATUS=$(minikube status --format '{{.Host}}' 2>/dev/null || echo "Stopped")
    if [ "$STATUS" != "Running" ]; then
        echo "[!] Minikube cluster is stopped. Restarting Minikube..."
        minikube start --cpus=2 --memory=4096 --driver=docker --addons=ingress,metrics-server
    else
        echo "[+] Minikube cluster is already Running."
    fi
    INGRESS_IP=$(minikube ip 2>/dev/null || echo "")
elif command -v kubectl &>/dev/null; then
    echo "[+] Using current kubectl context..."
    INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
fi

# Fallback to local machine IP if LoadBalancer IP is not set
if [ -z "$INGRESS_IP" ] || [ "$INGRESS_IP" = "null" ]; then
    INGRESS_IP="127.0.0.1"
fi

echo "[+] Resolved Target Ingress IP: ${INGRESS_IP}"

# 2. Update /etc/hosts automatically
TMP_HOSTS=$(mktemp)
# Remove old aliien.uk entries
grep -v "aliien.uk" /etc/hosts > "$TMP_HOSTS" || true

echo "# === MYPRO KUBERNETES ALIIEN.UK DOMAINS (AUTO-GENERATED) ===" >> "$TMP_HOSTS"
for domain in "${DOMAINS[@]}"; do
    echo "${INGRESS_IP}   ${domain}" >> "$TMP_HOSTS"
done
echo "# =====================================================" >> "$TMP_HOSTS"

echo "[+] Updating /etc/hosts (requires sudo permissions if run manually)..."
if [ "$EUID" -ne 0 ]; then
    echo "Running with sudo to apply /etc/hosts changes:"
    sudo cp "$TMP_HOSTS" /etc/hosts
else
    cp "$TMP_HOSTS" /etc/hosts
fi
rm -f "$TMP_HOSTS"

echo "======================================================================"
echo "[SUCCESS] Domain resolution updated! Accessible Endpoints:"
for domain in "${DOMAINS[@]}"; do
    echo "  -> https://${domain}"
done
echo "======================================================================"
