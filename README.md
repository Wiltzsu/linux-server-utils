### linux-server-utils

Scripts and notes I use to set up and look after my own Ubuntu servers. The scripts are Bash. The vuln-watch email is built with Python 3. Tested on Ubuntu 24.04, should mostly work on other Debian-based systems (paths like PHP config locations can differ).

### What's here

| Path | What it does |
| --- | --- |
| [monitoring/ubuntu-vuln-watch](monitoring/ubuntu-vuln-watch/README.md) | Daily check of recent Ubuntu security notices against installed package versions. Emails only what actually affects the host, and whether the fix can be installed yet. |
| [monitoring/server-monitoring](monitoring/server-monitoring/README.md) | Cron script that mails when load, disk or RAM go over a limit, at most once an hour while the problem lasts. |
| [backup/database-backup](backup/database-backup/README.md) | Timestamped, gzipped `mysqldump`s with local retention. |
| [backup/restic-vault](backup/restic-vault/README.md) | restic copies of the dumps to off-server storage. |
| [user/create-user.sh](user/create-user.sh) | New sudo user with generated password and passphrase-protected SSH key. |
| [user/setup-github-deploy-key.sh](user/setup-github-deploy-key.sh) | Separate passphrase-free key for GitHub Actions deploys. |
| [web/setup-app-directory.sh](web/setup-app-directory.sh) | App directory under `/var/www` owned by the deploy user and `www-data`. |
| [web/setup-fastcgi-cache](web/setup-fastcgi-cache/README.md) | nginx FastCGI cache for WordPress/Bedrock sites. |
| [docs](docs) | Notes on server hardening, UFW, Postfix relay and remote MySQL access. |

### Deployment

Pushing to `master` pulls the latest version onto my servers through a GitHub Actions workflow (`.github/workflows/sync-servers.yml`), so the copy on each host stays in sync with this repo.

### License

MIT
