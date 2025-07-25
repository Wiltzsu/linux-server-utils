# Server Resource Monitoring Script

This script monitors your server’s key resources (CPU load, disk usage, and RAM usage) and sends an email alert if any threshold is exceeded.

---

## Features

- **Monitors:**  
  - CPU load average  
  - Root disk usage  
  - RAM usage

- **Alerts:**  
  - Sends an email if any resource exceeds its configured threshold.

---

## Prerequisites

- **Mail tool:**  
  Email alerts are sent using the `mail` command. You must have a mail transfer agent (like Postfix) and `mailutils` installed and configured.  
  See [these instructions](../../docs/install-postfix-mailutils.md) for setup.

---

## Configuration

You can adjust the alert thresholds by editing these variables at the top of `server-resources.sh`:

```bash
MAX_LOAD=2      # Maximum allowed 1-minute load average
MAX_DISK=80     # Maximum allowed root disk usage percentage
MAX_RAM=80      # Maximum allowed RAM usage percentage
```

The alert email recipient is set in the script.

---

## Usage

Make the script executable:

```bash
chmod +x server-resources.sh
```

Run it manually:

```bash
./server-resources.sh
```

If any threshold is exceeded, you will receive an email alert.

---

## Scheduling with Cron

To run the script automatically (e.g., every 10 minutes), add a cron job:

```bash
crontab -e
```

Add the following line:

```cron
*/10 * * * * /path/to/monitoring/server-monitoring/server-resources.sh
```

Replace `/path/to/monitoring/server-monitoring/` with the actual path on your server.

---

## Troubleshooting

- **No email received?**
  - Ensure Postfix and mailutils are installed and configured.
  - Check `/var/log/mail.log` for errors.
  - Make sure the script is executable and the cron job is set up correctly.

- **Customizing checks:**  
  You can add more resource checks by extending the script.

---

## License

MIT License