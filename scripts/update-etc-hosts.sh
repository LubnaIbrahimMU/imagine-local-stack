#!/bin/bash
# ==============================================================================
# Update /etc/hosts with Local Minikube IP for aliien.uk Subdomains
# ==============================================================================
set -e

MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "")

if [ -z "$MINIKUBE_IP" ]; then
    echo "[!] Minikube is not running."
    exit 1
fi

DOMAINS="vvault.aliien.uk vharbor.aliien.uk vminio.aliien.uk vapp.aliien.uk vapi.aliien.uk vgrafana.aliien.uk vargocd.aliien.uk"

echo "=== Minikube IP detected: ${MINIKUBE_IP} ==="
echo "=== Updating /etc/hosts for local routing... ==="

# Remove old aliien.uk entries
sudo sed -i '/\.aliien\.uk/d' /etc/hosts

# Append new clean mapping
echo "${MINIKUBE_IP} ${DOMAINS}" | sudo tee -a /etc/hosts >/dev/null

echo "=== /etc/hosts Updated Successfully! ==="
echo "Current /etc/hosts entries:"
grep aliien /etc/hosts
