#!/bin/bash

# Backup directory on the server
BACKUP_DIR="/home/db_backups"

# Database credentials
DB_USER="your_db_user"
DB_NAME="your_db_name"

# Email to send alert to
ALERT_EMAIL="your@email.com"

# Collect the current timestamp
TIMESTAMP=$(date +"%F_%H-%M-%S")

# Backup filename and path
BACKUP_FILE="your_db_backup_$TIMESTAMP.sql"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Perform MySQL backup (uses root without password due to auth_socket)
if ! mysqldump -u "$DB_USER" --skip-column-statistics "$DB_NAME" > "$BACKUP_PATH"; then
  echo "mysqldump failed for database $DB_NAME on $(hostname) at $TIMESTAMP" | \
    mail -s "❌ MySQL Backup FAILED for $DB_NAME on $(hostname)" "$ALERT_EMAIL"
  exit 1
fi

# Compress the backup
if ! gzip "$BACKUP_PATH"; then
  echo "gzip compression failed for $BACKUP_PATH on $(hostname) at $TIMESTAMP" | \
    mail -s "❌ MySQL Backup Compression FAILED for $DB_NAME on $(hostname)" "$ALERT_EMAIL"
  exit 1
fi

BACKUP_PATH="$BACKUP_PATH.gz"

# Delete backups older than 7 days
if ! find "$BACKUP_DIR" -type f -name "your_db_backup_*.sql.gz" -mtime +7 -exec rm {} \; ; then
  echo "Failed to delete old backups for $DB_NAME on $(hostname) at $TIMESTAMP" | \
    mail -s "❌ MySQL Backup Cleanup FAILED for $DB_NAME on $(hostname)" "$ALERT_EMAIL"
  exit 1
fi

# (Optional) Log to a file instead of stdout
# echo "Backup succeeded: $BACKUP_PATH" >> /var/log/db_backup.log