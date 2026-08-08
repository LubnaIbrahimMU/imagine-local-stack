#!/bin/bash
# ==============================================================================
# Database Failover & Pod Disruption Budget (PDB) Stress Testing
# ==============================================================================
set -e

NAMESPACE="${1:-dev}"

echo "======================================================================"
echo "[FAILOVER TEST] Namespace: ${NAMESPACE}"
echo "======================================================================"

echo "--> Checking current active DB node status via Backend API health probe..."
curl -s "http://app.${NAMESPACE}.mypro.local/health" | jq . || true

PRIMARY_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=primary -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$PRIMARY_POD" ]; then
    echo "--> Deleting Primary Database Pod (${PRIMARY_POD}) to simulate hardware failure..."
    kubectl delete pod -n "$NAMESPACE" "$PRIMARY_POD" --now

    echo "--> Verifying backend failover response during primary pod restart..."
    sleep 3
    curl -s "http://app.${NAMESPACE}.mypro.local/health" | jq . || true
else
    echo "[!] Primary pod not found in namespace ${NAMESPACE}"
fi

echo "======================================================================"
echo "[COMPLETE] DB Failover test completed."
echo "======================================================================"
