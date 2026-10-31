# Ubuntu vuln-watch

Daily scan on a single Ubuntu host: local apt/kernel snapshot, recent USNs for your release, and a **short HTML + plain email** that only highlights what applies on **this** machine.

Install on the server (pick an install directory, e.g. `~/scripts/ubuntu-vuln-watch`):

```bash
INSTALL=~/scripts/ubuntu-vuln-watch
mkdir -p "$INSTALL"
# copy scan.sh, build_email.py, analyze_with_cursor.py, config.env.example into $INSTALL
chmod +x "$INSTALL"/scan.sh "$INSTALL"/build_email.py "$INSTALL"/analyze_with_cursor.py
cp "$INSTALL"/config.env.example "$INSTALL"/config.env && chmod 600 "$INSTALL"/config.env
```

Cron (root, so apt/reboot checks work):

```cron
30 7 * * * /path/to/ubuntu-vuln-watch/scan.sh >>/path/to/ubuntu-vuln-watch/scan.log 2>&1
```

Preview without sending:

```bash
DRY_RUN_EMAIL=1 ./scan.sh
# then open run/email-*.html
```

Requires: `python3`, Postfix (`sendmail`), `mailutils` optional. Email is sent as multipart HTML via `/usr/sbin/sendmail`.
