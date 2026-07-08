# Linux server utilities

This repository is a collection of Linux server-related tools, scripts, and configuration guides used on personal servers and projects.

The goal is to provide a structured, reusable, and documented set of utilities for everyday sysadmin tasks.

---

## Repository structure

```
linux-server-utils/
├── backup/
│   └── database-backup/
│       ├── database-backup.sh
│       └── README.md
├── docs/
│   ├── enable-remote-mysql-access.md
│   ├── install-postfix-mailutils.md
│   └── ufw-basic-setup.md
├── monitoring/
│   ├── php-error-monitoring/
│   │   ├── monitor-php-errors.sh
│   │   └── README.md
│   └── server-monitoring/
│       ├── server-resources.sh
│       └── README.md
├── user/
│   └── create-user.sh
├── CHANGELOG.md
└── README.md
```

---

## Contents

### User management

| Script | Description |
|--------|-------------|
| [`user/create-user.sh`](user/create-user.sh) | Create a new sudo user with login password and ed25519 SSH key setup |

Run as root:

```bash
sudo ./user/create-user.sh [username]
```

The script creates a user with a home directory and `/bin/bash`, adds them to the `sudo` and `www-data` groups (for deploying/editing web files), generates SSH keys, and prints connection instructions. Log out and back in after creation so group membership takes effect.

### Backup

| Script | Description |
|--------|-------------|
| [`backup/database-backup/database-backup.sh`](backup/database-backup/database-backup.sh) | MySQL backup with gzip compression, retention cleanup, and email alerts on failure |

See [`backup/database-backup/README.md`](backup/database-backup/README.md) for configuration and cron setup.

### Monitoring

| Script | Description |
|--------|-------------|
| [`monitoring/server-monitoring/server-resources.sh`](monitoring/server-monitoring/server-resources.sh) | CPU load, disk, and RAM monitoring with email alerts |
| [`monitoring/php-error-monitoring/monitor-php-errors.sh`](monitoring/php-error-monitoring/monitor-php-errors.sh) | PHP-FPM error log monitoring with Better Stack Telemetry |

- Server monitoring: [`monitoring/server-monitoring/README.md`](monitoring/server-monitoring/README.md)
- PHP error monitoring: [`monitoring/php-error-monitoring/README.md`](monitoring/php-error-monitoring/README.md)

### Guides (`docs/`)

| Guide | Description |
|-------|-------------|
| [`docs/install-postfix-mailutils.md`](docs/install-postfix-mailutils.md) | Postfix and mailutils setup for email alerts |
| [`docs/ufw-basic-setup.md`](docs/ufw-basic-setup.md) | Basic UFW firewall setup |
| [`docs/enable-remote-mysql-access.md`](docs/enable-remote-mysql-access.md) | Secure remote MySQL access (firewall + user restrictions) |

---

## Requirements & compatibility

- Scripts are written in **Bash**
- Target environment: **Ubuntu/Debian-based systems**
- Tested on Ubuntu 24.04 LTS

_Note: Some commands or paths (like PHP config locations) may vary slightly between different distributions._

---

## Getting started

Clone this repository and start using or adapting the scripts as needed:

```bash
git clone https://github.com/yourusername/linux-server-utils.git
cd linux-server-utils
```

Make scripts executable before running them:

```bash
chmod +x user/create-user.sh
chmod +x backup/database-backup/database-backup.sh
chmod +x monitoring/server-monitoring/server-resources.sh
chmod +x monitoring/php-error-monitoring/monitor-php-errors.sh
```

See each folder's README for detailed configuration, cron examples, and troubleshooting.

---

## License

MIT — feel free to use, modify, and share.
