# MySQL automated backup script

Creates timestamped `mysqldump` output under `/var/backups/db`, gzips it, and deletes local dumps older than `RETENTION_DAYS`. Intended for root cron on app servers; pairs with [restic-vault](../restic-vault/README.md) for off-server copies of the same directory.

## Configure

Edit at the top of `database-backup.sh`:

- `DB_NAME` — database to dump (filename prefix `${DB_NAME}_db_backup_…`)
- `DB_USER` — typically `root` with `auth_socket` on Ubuntu
- `BACKUP_DIR` — default `/var/backups/db`
- `RETENTION_DAYS` — local retention only (restic has its own policy)

## Install on a server

```bash
sudo install -m 755 database-backup.sh /usr/local/sbin/database-backup.sh
# edit DB_NAME (and others) on the server, or maintain a server-local copy under /usr/local/sbin
sudo crontab -e
```

Example cron (every 3 hours):

```cron
0 */3 * * * /usr/local/sbin/database-backup.sh
```

Run restic after dumps exist (see restic-vault README).

## Restore a dump on the server

```bash
sudo zcat /var/backups/db/your_database_name_db_backup_2026-11-01_03-00-01.sql.gz | mysql your_database_name
```

Copy off the host:

```bash
scp root@HOST:/var/backups/db/your_database_name_db_backup_2026-11-01_03-00-01.sql.gz .
```

## Notes

- Assumes `mysqldump` can run as `DB_USER` without a password (e.g. root + `auth_socket`).
- Multiple databases: run separate cron lines with different `DB_NAME` values, or extend the script to loop over a list.
- Failure email alerts are not included here; add monitoring or wrap with your mail setup if needed.
