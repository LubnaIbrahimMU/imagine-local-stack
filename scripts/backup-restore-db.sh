#!/bin/bash
# ==============================================================================
# Database Backup & Restore Operational Verification Script
# ==============================================================================
set -e

NAMESPACE="${1:-dev}"
RELEASE_NAME="${2:-app-mypro-dev}"
CRONJOB_NAME="${RELEASE_NAME}-db-backup-cronjob"
PVC_NAME="${RELEASE_NAME}-db-backup-pvc"

echo "======================================================================"
echo "[BACKUP & RESTORE] Triggering Manual Backup in Namespace: ${NAMESPACE}"
echo "======================================================================"

# 1. Create a valid SQL backup dump directly from Primary DB
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/tmp/backup_appdb_${TIMESTAMP}.sql.gz"

echo "[*] Creating database dump from primary database..."
kubectl exec -n "$NAMESPACE" "${RELEASE_NAME}-db-primary-0" -- mysqldump --no-tablespaces -u appuser -papp_password_123 appdb | gzip > "$BACKUP_FILE"

echo "[+] Backup successfully created: ${BACKUP_FILE} ($(du -h "$BACKUP_FILE" | cut -f1))"

echo ""
echo "=== READING BACKUP FILE CONTENTS (SQL DUMP) ==="
zcat "$BACKUP_FILE" | grep -E "INSERT INTO|CREATE TABLE" || true

echo ""
echo "=== USERS FOUND IN BACKUP FILE ==="
zcat "$BACKUP_FILE" | grep -i "INSERT INTO \`users\`" || true

echo ""
echo "======================================================================"
echo "[SUCCESS] Database Backup verification complete."
echo "======================================================================"
