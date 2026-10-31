# Restic backups to Hetzner Storage Box (forge)

Off-server copies for **apps-host**. Complements local MySQL dumps in `/home/db_backups` (root cron today). Credentials stay on the server only, not in git.

**Vault:** Hetzner Storage Box (BX11). See private `~/career/automation.md` (**A7**).

## What v1 backs up

- **`/home/db_backups`** — `.sql.gz` files from `/home/mysql_backup_script.sh` (every 3 hours)

Expand `RESTIC_BACKUP_PATHS` later (uploads, selected `/var/www` trees) once DB off-site backup is proven.

## One-time setup on forge

Install restic (already present on forge as of 2026-10):

```bash
sudo apt install restic
```

Create secrets directory and repo password:

```bash
sudo install -d -m 700 /etc/restic
sudo sh -c 'openssl rand -base64 32 > /etc/restic/password'
sudo chmod 600 /etc/restic/password
```

Install env file and script from this repo:

```bash
sudo cp forge.env.example /etc/restic/forge.env
sudo chmod 600 /etc/restic/forge.env
# Edit RESTIC_REPOSITORY with your Storage Box SFTP user/host from Hetzner Console

sudo install -m 755 restic-backup-forge.sh /usr/local/sbin/restic-backup-forge.sh
sudo touch /var/log/restic-forge.log
sudo chmod 640 /var/log/restic-forge.log
```

Initialize the remote repository (once):

```bash
sudo bash -c 'set -a; source /etc/restic/forge.env; set +a; restic init'
```

If `init` says the repo already exists, skip it.

## Manual proof run

```bash
sudo /usr/local/sbin/restic-backup-forge.sh
sudo bash -c 'set -a; source /etc/restic/forge.env; set +a; restic snapshots'
tail -20 /var/log/restic-forge.log
```

## Test restore once (A7 done criteria)

```bash
sudo mkdir -p /tmp/restic-restore-test
sudo bash -c 'set -a; source /etc/restic/forge.env; set +a; restic restore latest --target /tmp/restic-restore-test --path /home/db_backups'
ls -la /tmp/restic-restore-test/home/db_backups | head
sudo rm -rf /tmp/restic-restore-test
```

## Cron

Run **after** local dumps exist (e.g. daily 04:15 UTC, local MySQL job runs every 3 hours):

```cron
15 4 * * * /usr/local/sbin/restic-backup-forge.sh
```

Optional monthly integrity check (1st of month, 05:00):

```cron
0 5 1 * * RESTIC_RUN_CHECK=1 /usr/local/sbin/restic-backup-forge.sh
```

(`RESTIC_RUN_CHECK` must be exported in cron or add it to `/etc/restic/forge.env`.)

## Wrapper script

`restic-backup-forge.sh` loads `/etc/restic/forge.env`, backs up `RESTIC_BACKUP_PATHS`, runs `forget --prune`, logs to `/var/log/restic-forge.log`, and uses a flock lock at `/run/restic-forge.lock`.

## References

- [Hetzner Storage Box SFTP](https://docs.hetzner.com/storage/storage-box/access/access-ssh-sftp/)
- [restic](https://restic.readthedocs.io/)
