# Changelog

All notable changes to this project will be documented in this file.

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

