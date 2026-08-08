#!/usr/bin/env bash
# ==============================================================================
# Configure Host Docker Daemon to Trust Harbor Self-Signed Certificate / Insecure Registry
# ==============================================================================
set -euo pipefail

REGISTRY_HOST="${1:-vharbor.aliien.uk}"

# Resolve Kubeconfig when running via sudo
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
export KUBECONFIG="${KUBECONFIG:-${TARGET_HOME}/.kube/config}"

echo "=== Configuring Docker Trust for Harbor Registry (${REGISTRY_HOST}) ==="
echo "--> Using Kubeconfig: ${KUBECONFIG}"

# 1. Install TLS Certificate to Docker certs directory
echo "--> Creating Docker certs directory for ${REGISTRY_HOST}..."
mkdir -p "/etc/docker/certs.d/${REGISTRY_HOST}"
mkdir -p "/etc/docker/certs.d/harbor.aliien.uk"

echo "--> Extracting TLS certificate from Kubernetes secret aliien-uk-tls..."
kubectl get secret -n harbor aliien-uk-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > "/etc/docker/certs.d/${REGISTRY_HOST}/ca.crt"
kubectl get secret -n harbor aliien-uk-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > "/etc/docker/certs.d/harbor.aliien.uk/ca.crt"

echo "[+] Certificate saved to /etc/docker/certs.d/${REGISTRY_HOST}/ca.crt"

# 2. Configure /etc/docker/daemon.json for insecure registries fallback
DAEMON_JSON="/etc/docker/daemon.json"
if [ ! -f "${DAEMON_JSON}" ]; then
  cat <<EOF > "${DAEMON_JSON}"
{
  "insecure-registries": [
    "vharbor.aliien.uk",
    "harbor.aliien.uk"
  ]
}
EOF
  echo "[+] Created ${DAEMON_JSON} with insecure-registries."
fi

# 3. Restart Docker daemon if systemctl is available
if command -v systemctl >/dev/null 2>&1; then
  echo "--> Restarting Docker service..."
  systemctl restart docker || systemctl reload docker || true
fi

echo "======================================================================"
echo "[SUCCESS] Docker is now configured to trust Harbor (${REGISTRY_HOST})!"
echo "======================================================================"
