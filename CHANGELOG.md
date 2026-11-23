# Changelog

All notable changes to this project will be documented in this file.

## [1.6.0] - 2026-11-23

### Added
- **`LICENSE`**: MIT license file (the README already said MIT, but there was no file).

### Changed
- **`README.md`**: Rewritten with a table of every tool, a deployment note and smaller headings.
- **`backup/restic-vault/README.md`**: Removed a reference to private notes. It was also scrubbed from git history, so commit hashes from 2026-10-31 onwards have changed.

---

## [1.5.4] - 2026-11-22

### Changed
- **`monitoring/ubuntu-vuln-watch/build_email.py`**: For each affected package, compares apt's candidate version with the USN fix and `apt list --upgradable`, and labels it as upgrade ready, fix not in the apt indexes yet, or held back by phasing/holds/pins. The email no longer implies that `apt upgrade` fixes every USN that applies.

---

## [1.5.3] - 2026-11-13

### Changed
- **`monitoring/server-monitoring/server-resources.sh`**: Alerts go to `ALERT_EMAIL` (default `root`, forward it in `/etc/aliases`) instead of a placeholder address. Limits can be set from the environment, `MAX_LOAD` defaults to the CPU count, and a lasting problem sends at most one mail per `COOLDOWN` (default 1 hour).

---

## [1.5.2] - 2026-11-02

### Changed
- **`.github/workflows/sync-servers.yml`**: Syncs to a second server as well.
- **`monitoring/ubuntu-vuln-watch`**: Docs and email footers point at the install directory instead of old `~/scripts` paths.

---

## [1.5.1] - 2026-11-01

### Changed
- **`backup/restic-vault`**: Renamed to `restic-backup-vault.sh` and `vault.env` to match the paths used on servers (`/etc/restic/vault.env`).
- **`backup/database-backup/database-backup.sh`**: Dumps go to `/var/backups/db`; restic defaults and docs updated to match.

---

## [1.5.0] - 2026-10-31

### Added
- **`monitoring/ubuntu-vuln-watch`**: Daily scan that matches recent Ubuntu security notices against installed package versions and emails only what applies to the host. Optional AI summary step via `analyze_with_cursor.py`.
- **`backup/restic-vault`**: restic wrapper that copies the MySQL dumps to off-server storage.
- **`.github/workflows/sync-servers.yml`**: Pushes to `master` update the copy of this repo on the server. Can also be run by hand.

### Removed
- **`monitoring/php-error-monitoring`**: PHP error alerts are now handled by a log shipper instead.

---

## [1.4.6] - 2026-08-19

### Changed
- **`README.md`**: Removed sections that repeated the per-tool READMEs.
- **Docs**: Sentence-case headings, hyphens instead of em dashes, MIT noted only in the root README.

---

## [1.4.5] - 2026-07-18

### Added
- **`web/setup-fastcgi-cache/setup-fastcgi-cache.sh`**: Enable nginx FastCGI cache for WordPress/Bedrock sites (cache path, snippets, site config patch, reload).
- **`web/setup-fastcgi-cache/README.md`**: Usage, bypass rules, verification, and purge instructions.

### Changed
- **`README.md`**: Document FastCGI cache setup script.

---

## [1.4.4] - 2026-07-13

### Added
- **`user/setup-github-deploy-key.sh`**: Passphrase-free SSH key for GitHub Actions deploys (one key per server, shared across app repos).
- **`web/setup-app-directory.sh`**: Create `/var/www/myapp` with `user:www-data` ownership and group write.

### Changed
- **`README.md`**: Document deploy key vs laptop login key and link to platform getting started.
- **`docs/server-hardening.md`**: Cross-link to GitHub Actions deploy key setup.

---

## [1.4.3] - 2026-07-08

### Changed
- **`docs/server-hardening.md`**: Added brief finishing touches section (provider 2FA, remove server private key, PM2 boot persistence, reboot test).

---

## [1.4.2] - 2026-07-08

### Changed
- **`docs/server-hardening.md`**: Expanded optional SSH IP restriction section (defense-in-depth, dynamic IP tradeoffs, VPN approach).

---

## [1.4.1] - 2026-07-08

### Removed
- **`docs/hardening-ubuntu-server-blog-post.md`**: Removed blog draft; use `docs/server-hardening.md` as the canonical guide.

---

## [1.4.0] - 2026-07-08

### Added
- **`docs/server-hardening.md`**: Guide covering admin user setup, SSH hardening, UFW audit, MySQL localhost binding, unattended-upgrades, and fail2ban configuration.

---

## [1.3.2] - 2026-07-08

### Changed
- **`user/create-user.sh`**: Connection instructions now use the server's public IP (with fallbacks) instead of hostname for `scp`, SSH login, and `HostName` in the optional SSH config.

---

## [1.3.1] - 2026-07-08

### Changed
- **`user/create-user.sh`**: New users are now added to the `www-data` group in addition to `sudo`, so they can deploy and edit web files without extra setup.
- **`README.md`**: Updated repository structure, script paths, and documentation links for all folders (`user/`, `backup/`, `monitoring/`, `docs/`).

---

## [1.3.0] - 2026-06-27

### Added
- **Added `user/create-user.sh`**: Interactive script to create a new sudo user with login password and SSH key setup.
  - Prompts for username, login password, and SSH key passphrase with validation
  - Creates user with home directory and bash shell, adds to sudo group
  - Generates ed25519 SSH key pair and installs public key for key-only SSH login
  - Prints connection instructions including scp command and optional SSH config entry

---

## [1.2.0] - 2025-11-08

### Added
- **Added `monitoring/php-error-monitoring/monitor-php-errors.sh`**: Automated PHP error monitoring script that sends errors to Better Stack Telemetry via HTTP API.
  - Monitors PHP-FPM error logs for Fatal errors, Parse errors, Warnings, and Exceptions
  - Sends structured log data to Better Stack with severity levels (critical/error/warning)
  - Tracks last read position to avoid duplicate sends
  - Configurable exclude patterns to filter out noise
  - Rate limiting (max errors per run) to prevent alert flooding
  - Two operational modes:
    - One-shot mode (default): Process logs once and exit - designed for cron jobs
    - Daemon mode (`--daemon`): Continuous monitoring with 30-second intervals
  - State management using `/var/run/php-error-monitor.state`
  - HTTP API integration with Bearer token authentication
  - Timestamped logging and error reporting
- **Added `monitoring/php-error-monitoring/README.md`**: Comprehensive setup and configuration guide covering:
  - Better Stack Telemetry source creation and configuration
  - Script installation and configuration steps
  - Testing procedures with example commands
  - Cron automation setup for every-minute monitoring
  - Alert configuration for critical errors with threshold-based detection
  - Verification checklist for successful deployment
  - Maintenance commands for viewing logs and monitoring script activity
  - Troubleshooting guide for common issues
  - Configuration options for adjusting error patterns, rate limiting, and multi-site deployments

---

## [1.1.0] - 2025-07-25

- Added `monitoring/server-monitoring/server-resources.sh`: Script to monitor server load, disk, and RAM with email alerts.
- Added and extended `monitoring/server-monitoring/README.md` with detailed usage, configuration, and troubleshooting instructions for the monitoring script.
- Added `docs/enable-remote-mysql-access.md`: Step-by-step guide for enabling secure remote MySQL access (Hetzner/cloud), including layered firewall and MySQL user restrictions.
- **Added `docs/ufw-basic-setup.md`: Clear, step-by-step guide for basic UFW firewall setup and best practices.**
- Improved documentation:
  - Clarified project goals in `README.md` to reflect personal and public utility.
  - Enhanced `docs/install-postfix-mailutils.md` and other docs for clarity and completeness.

---

## [1.0.0] - 2025-07-15

### Added
- Initial release of **Linux Server Utilities**.
- Backup script for MySQL databases with:
  - Timestamped backups
  - Automatic compression with gzip
  - Cleanup of backups older than 7 days
  - Email alerts on failure (mysqldump, compression, or cleanup)
- Example monitoring script for server health (load, disk, RAM) with email alerts.
- Example crontab entries for scheduled backups and monitoring.
- Documentation:
  - `README.md` with project overview and usage instructions
  - `docs/install-postfix.md` for setting up Postfix and mailutils with Gmail relay
- Project structure and initial directory layout.
- Placeholder scripts and documentation.

---

