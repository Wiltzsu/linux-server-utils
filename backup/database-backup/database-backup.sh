#!/bin/bash
set -euo pipefail

BACKUP_DIR="/var/backups/db"
DB_USER="root"
DB_NAME="your_database_name"
RETENTION_DAYS=7

TIMESTAMP=$(date +"%F_%H-%M-%S")
BACKUP_FILE="${DB_NAME}_db_backup_${TIMESTAMP}.sql"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

mkdir -p "$BACKUP_DIR"

mysqldump -u "$DB_USER" --skip-column-statistics "$DB_NAME" >"$BACKUP_PATH"
gzip "$BACKUP_PATH"
BACKUP_PATH="${BACKUP_PATH}.gz"

echo "Backup created: $BACKUP_PATH"

find "$BACKUP_DIR" -type f -name "${DB_NAME}_db_backup_*.sql.gz" -mtime +"${RETENTION_DAYS}" -exec rm {} \;

echo "Backup stored on server."
