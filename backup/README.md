# MySQL Automated Backup Script

This script automates the process of backing up a MySQL database, compressing the backup, and cleaning up old backup files. It is designed to be run as a scheduled cron job and will send an email alert if any step fails. Email alerts are set up using Postfix, which you can install on your server with the help of [these](../docs/install-postfix-mailutils.md) instructions.

---

## Features

- **Automated MySQL database backup** using `mysqldump`
- **Compression** of the backup file with `gzip`
- **Automatic cleanup** of backup files older than 7 days
- **Email alerts** sent on any failure (backup, compression, or cleanup)
- **Silent on success** (no email or output unless there is a problem)

## How It Works

1. **Creates a timestamped backup** of the specified MySQL database.
2. **Compresses** the backup file to save disk space.
3. **Deletes old backups** (older than 7 days) to manage storage.
4. **Sends an email alert** to the configured address if any step fails.

## Usage

1. **Configure the script:**
   - Set the `DB_USER`, `DB_NAME`, `BACKUP_DIR`, and `ALERT_EMAIL` variables at the top of the script.

2. **Make the script executable:**
   ```bash
   chmod +x /path/to/mysql_backup_script.sh
   ```

3. **Schedule with cron (example: every 3 hours):**
   ```cron
   0 */3 * * * /path/to/mysql_backup_script.sh
   ```

---

## Example Email Alerts

- **mysqldump failed:**  
  _"mysqldump failed for database mydatabase on myserver at 2025-07-15_03-00-01"_

- **Compression failed:**  
  _"gzip compression failed for /home/db_backups/mydatabase_db_backup_2025-07-15_03-00-01.sql on myserver at 2025-07-15_03-00-01"_

- **Cleanup failed:**  
  _"Failed to delete old backups for mydatabase on myserver at 2025-07-15_03-00-01"_

---

## Notes

- The script assumes the MySQL user can authenticate without a password (e.g., via `auth_socket`).
- No output is produced on success, so cron will not send emails unless there is a failure.
- Adjust the backup retention period by changing the `-mtime +7` value in the cleanup step.

### If needed, copy the dump from the server to your local environment
```
scp root@IP:/home/db_backups/mydatabase_db_backup_2025-05-10_12-20-46.sql.gz /your/local/folder/

# Unzip the file
gunzip mydatabase_db_backup_2025-05-10_12-20-46.sql.gz
```

---

## License

MIT — feel free to use, modify, and share. 