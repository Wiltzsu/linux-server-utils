#!/bin/bash
# Server health alert: mails when load, disk or RAM go over the limits.
# Run from root's crontab, e.g. every 5 minutes:
#   */5 * * * * /bin/bash /root/monitor.sh
#
# Alerts go to $ALERT_EMAIL, or to root by default (forward root in /etc/aliases).
# A lasting problem sends at most one mail per COOLDOWN seconds.

ALERT_EMAIL="${ALERT_EMAIL:-root}"

# Define limits
MAX_LOAD="${MAX_LOAD:-$(nproc)}"   # 1-minute load average; defaults to the CPU count
MAX_DISK="${MAX_DISK:-80}"
MAX_RAM="${MAX_RAM:-80}"
COOLDOWN="${COOLDOWN:-3600}"
STAMP=/var/tmp/monitor-last-alert

# Get current system values
load=$(cut -d' ' -f1 /proc/loadavg)
disk=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
ram=$(free | awk '/Mem/ {printf("%.0f"), $3/$2 * 100}')

# Check conditions
message=""
if (( $(echo "$load > $MAX_LOAD" | bc -l) )); then
  message+="High Load: $load\n"
fi
if [ "$disk" -gt "$MAX_DISK" ]; then
  message+="Disk Usage High: $disk%\n"
fi
if [ "$ram" -gt "$MAX_RAM" ]; then
  message+="RAM Usage High: $ram%\n"
fi

[ -z "$message" ] && exit 0

# Cooldown: skip if an alert was sent recently
now=$(date +%s)
last=$(cat "$STAMP" 2>/dev/null || echo 0)
(( now - last < COOLDOWN )) && exit 0
echo "$now" > "$STAMP"

# Send alert
message+="\nLoad: $load\nDisk: $disk%\nRAM: $ram%"
echo -e "$message" | mail -s "Server Health Alert on $(hostname)" "$ALERT_EMAIL"
