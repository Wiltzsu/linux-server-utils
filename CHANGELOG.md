# Changelog

All notable changes to this project will be documented in this file.

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

