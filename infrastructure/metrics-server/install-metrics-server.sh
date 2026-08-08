#!/bin/bash
# ==============================================================================
# Install Kubernetes Metrics Server for HPA & kubectl top metrics
# ==============================================================================
set -e

echo "=== Installing Kubernetes Metrics Server ==="

# Check if running minikube
if command -v minikube &>/dev/null && minikube status &>/dev/null; then
    echo "--> Enabling Minikube metrics-server addon..."
    minikube addons enable metrics-server
else
    echo "--> Applying official Kubernetes Metrics Server manifest..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # Patch metrics-server deployment to allow insecure TLS for local development kubelets
    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
      {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}
    ]' 2>/dev/null || true
fi

echo "=== Metrics Server Installed Successfully! ==="
