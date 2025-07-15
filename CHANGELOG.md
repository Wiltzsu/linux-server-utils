# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

- Ongoing improvements and new utilities.

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

### Changed
- N/A

### Fixed
- N/A

---

