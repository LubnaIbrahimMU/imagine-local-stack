#!/bin/sh
set -e

BACKUP_DIR="/backups"
DB_HOST="${DB_HOST:-db-primary}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-app_password}"
DB_NAME="${DB_NAME:-appdb}"
SINGLE_SHOT="${SINGLE_SHOT:-false}"
INTERVAL_SECONDS="${BACKUP_INTERVAL_SECONDS:-60}"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Database Backup Runner started."
echo "Target DB: $DB_HOST | Target Database: $DB_NAME"

do_backup() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="${BACKUP_DIR}/backup_${DB_NAME}_${TIMESTAMP}.sql.gz"

    echo "[$(date)] Starting backup dump to $BACKUP_FILE..."

    if mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" --single-transaction --quick "$DB_NAME" 2>/tmp/backup.log | gzip > "$BACKUP_FILE"; then
        FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        echo "[$(date)] SUCCESS: Database backup created at $BACKUP_FILE ($FILE_SIZE)"
    else
        echo "[$(date)] ERROR: Backup failed!"
        cat /tmp/backup.log
        rm -f "$BACKUP_FILE"
        return 1
    fi

    # Retention policy: keep 7 days
    find "$BACKUP_DIR" -type f -name "backup_*.sql.gz" -mtime +7 -delete 2>/dev/null || true
}

if [ "$SINGLE_SHOT" = "true" ]; then
    do_backup
else
    while true; do
        do_backup || true
        sleep "$INTERVAL_SECONDS"
    done
fi
