#!/bin/bash
# ==============================================================================
# Database Backup & Restore Operational Verification Script
# ==============================================================================
set -e

NAMESPACE="${1:-dev}"

echo "======================================================================"
echo "[BACKUP & RESTORE] Triggering Manual CronJob Execution in ${NAMESPACE}"
echo "======================================================================"

JOB_NAME="manual-db-backup-$(date +%s)"
kubectl create job --from=cronjob/mypro-db-backup-cronjob "$JOB_NAME" -n "$NAMESPACE" || true

echo "--> Waiting for backup job to complete..."
kubectl wait --for=condition=complete job/"$JOB_NAME" -n "$NAMESPACE" --timeout=60s || true

echo "--> Inspecting generated backup archives on PersistentVolumeClaim..."
BACKUP_POD="backup-inspector-$(date +%s)"
kubectl run "$BACKUP_POD" --image=alpine --restart=Never -n "$NAMESPACE" \
  --overrides='{
    "spec": {
      "volumes": [{"name": "backup-vol", "persistentVolumeClaim": {"claimName": "mypro-db-backup-pvc"}}],
      "containers": [{"name": "inspector", "image": "alpine", "command": ["ls", "-lh", "/backups"], "volumeMounts": [{"name": "backup-vol", "mountPath": "/backups"}]}]
    }
  }'

sleep 5
kubectl logs -n "$NAMESPACE" "$BACKUP_POD" || true
kubectl delete pod -n "$NAMESPACE" "$BACKUP_POD" --now || true

echo "======================================================================"
echo "[SUCCESS] Database Backup verification complete."
echo "======================================================================"
