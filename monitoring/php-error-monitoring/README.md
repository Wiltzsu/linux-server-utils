# PHP Error Monitoring with Better Stack - Complete Setup Guide

## Prerequisites

- Better Uptime account with Telemetry access
- Root/sudo access to server
- PHP-FPM with error logging configured

---

## Part 1: Better Stack Configuration

### Step 1: Create a Telemetry Source

1. Log into Better Uptime: https://betteruptime.com
2. Navigate to **Telemetry → Sources** (in the left sidebar)
3. Click "Connect source" or "New source"
4. Choose a name for the source
5. Open Logs & Metrics tab and choose "HTTP" as the source type
6. Click "Create source"

### Step 2: Get source credentials

After creating the source, you'll see:

- **Source Token**: A string like `z5FJU5TtJsDdbAJMCf1w6aif`
- **Ingestion URL**: Something like `https://s1582094.eu-nbg-2.betterstackdata.com`

Copy both values - you'll need them in the next step.

---

## Part 2: Script configuration

### Step 3: Create the monitoring script

Create the script file and copy the script from [`monitor-fatal-errors.sh`](monitor-fatal-errors.sh):

```bash
sudo nano /usr/local/bin/monitor-fatal-errors.sh
```

### Step 4: Configure the script

Edit the following lines in the script:

**Line 9** - Your PHP-FPM error log path:
```bash
LOG_FILE="/var/log/php-fpm/site-error.log"
```

**Line 10** - Your Better Stack source token:
```bash
BETTERUPTIME_SOURCE_TOKEN="z5FJU5LtJgDdbFJMCf1w6aif"
```

**Line 11** - Your Better Stack ingestion URL:
```bash
BETTERUPTIME_INGEST_URL="https://s1582094.eu-nbg-2.betterstackdata.com"
```

**Line 20** - Adjust exclude patterns for your site if needed:
```bash
EXCLUDE_PATTERNS="hero-cover|Theme URI"  # Add any noise to filter out
```

**Line 50** - Update service name:
```json
"service": "site.com",
```

### Step 5: Make script executable

```bash
sudo chmod +x /usr/local/bin/monitor-fatal-errors.sh
```

---

## Part 3: Testing

### Step 6: Test script configuration

Test that the script can find the log file:

```bash
sudo /usr/local/bin/monitor-fatal-errors.sh
```

You should see:

```
==========================================
PHP-FPM Error Monitor for Better Uptime
==========================================
Log file: /var/log/php-fpm/site-error.log
...
```

### Step 7: Create Test Error

Add a test error to your PHP log:

```bash
echo "[$(date -u '+%d-%b-%Y %H:%M:%S') UTC] PHP Fatal error: TEST - Uncaught Error: Call to undefined function test_function() in /var/www/test.php on line 42" | sudo tee -a /var/log/php-fpm/site-error.log
```

### Step 8: Run Script to Send Test Error

```bash
sudo /usr/local/bin/monitor-fatal-errors.sh
```

Expected output:

```
[2025-11-07 20:00:00] Processing 1 new line(s)
[2025-11-07 20:00:00] ✓ Sent: PHP Fatal error: TEST - Uncaught Error: Call to undefined function test_...
```

### Step 9: Verify in Better Stack

1. Go to **Better Uptime → Telemetry → Logs & Traces**
2. Select your source
3. You should see the test error with:
   - `level: critical`
   - Full error message
   - Timestamp

**If you see the error, the integration is working!**

---

## Part 4: Automate with Cron

### Step 10: Set up Cron job

```bash
sudo crontab -e
```

Add this line:

```bash
# Monitor PHP errors every minute
* * * * * /usr/local/bin/monitor-fatal-errors.sh >> /var/log/php-error-monitor.log 2>&1
```

Save and exit.

### Step 11: Verify Cron is running

Wait 1-2 minutes, then check:

```bash
# Check if cron ran
sudo grep "monitor-fatal-errors" /var/log/syslog | tail -5

# Check script output log
sudo tail -f /var/log/php-error-monitor.log
```

---

## Part 5: Set Up Alerts

### Step 12: Create Alert for Critical Errors

1. Go to **Better Uptime → Telemetry** → Click on your source
2. Click the **Alerts** tab
3. Click "Create alert" and choose "Create alert on logs or traces"

**Alert configuration:**

**Query builder (left side):**
- **Source dropdown**: Choose your created source
- **Where**: Add condition → `level equals critical`
- **Y-axis**: count
- **X-axis**: time
- **Group by**: level (optional)

**Alert settings (right side):**
- **Detection method**: Change from "Percentage change" to "Threshold"
- **Alert when**:
  - any series
  - is higher than
  - 0
- **Alert for**: Selected services only → Select your PHP error monitoring source
- **Notification channels**: Choose your on-call schedule/notification method

4. Click "Save alert"

### Step 13: Test the Alert

Add another test error:

```bash
echo "[$(date -u '+%d-%b-%Y %H:%M:%S') UTC] PHP Fatal error: ALERT TEST - Maximum execution time exceeded in /var/www/test.php on line 10" | sudo tee -a /var/log/php-fpm/site-error.log
```

Wait 1-2 minutes for:
1. Cron to run the script
2. Error to be sent to Better Stack
3. Alert to trigger
4. Notification to arrive

---

## Part 6: Verification checklist

- [x] Source created in Better Stack Telemetry
- [x] Script configured with correct credentials
- [x] Script executable and can read log file
- [x] Test error sent and visible in Better Stack
- [x] Cron job added and running every minute
- [x] Alert created for critical errors
- [x] Alert tested and notification received

---

## Maintenance

### View logs

```bash
# View script activity
sudo tail -f /var/log/php-error-monitor.log

# View PHP errors
sudo tail -f /var/log/php-fpm/site-error.log

# Check Better Stack
# Go to: Telemetry → Logs & Traces → Filter by your source
```

---

## Troubleshooting

### Script not sending errors:

```bash
# Check if log file exists
ls -la /var/log/php-fpm/site-error.log

# Run script manually with verbose output
sudo /usr/local/bin/monitor-fatal-errors.sh

# Check state file
cat /var/run/php-error-monitor.state
```

### Cron not running:

```bash
# Check cron status
sudo systemctl status cron

# View cron logs
sudo grep CRON /var/log/syslog | tail -20

# Verify crontab entry
sudo crontab -l
```

---

## Configuration options

### Adjust error patterns

To monitor different error types, edit line 17:

```bash
# Only fatal errors
ERROR_PATTERNS="PHP Fatal|PHP Parse"

# All errors including notices
ERROR_PATTERNS="PHP Fatal|PHP Parse|PHP Warning|PHP Notice|PHP Exception|Uncaught"
```

### Adjust rate limiting

Change line 22 to allow more/fewer errors per minute:

```bash
MAX_ERRORS_PER_RUN=50  # Allow up to 50 errors per cron run
```

### Multiple sites

For additional sites, copy the script and create separate sources:

```bash
sudo cp /usr/local/bin/monitor-fatal-errors.sh /usr/local/bin/monitor-fatal-errors-site2.sh
# Edit with different LOG_FILE, SOURCE_TOKEN, and service name
# Add separate cron entry
```
