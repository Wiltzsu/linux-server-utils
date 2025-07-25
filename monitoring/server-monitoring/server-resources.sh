#!/bin/bash

# Define limits
MAX_LOAD=2
MAX_DISK=80
MAX_RAM=80

# Get current system values
load=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d',' -f1 | awk '{print $1}')
disk=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
ram=$(free | awk '/Mem/ {printf("%.0f"), $3/$2 * 100}')

# Output current state (optional)
# echo "Load: $load"
# echo "Disk: $disk%"
# echo "RAM: $ram%"

# Check conditions
alert=false
message=""

if (( $(echo "$load > $MAX_LOAD" | bc -l) )); then
  message+="High Load: $load\n"
  alert=true
fi

if [ "$disk" -gt "$MAX_DISK" ]; then
  message+="Disk Usage High: $disk%\n"
  alert=true
fi

if [ "$ram" -gt "$MAX_RAM" ]; then
  message+="RAM Usage High: $ram%\n"
  alert=true
fi

# Send alert if needed
if [ "$alert" = true ]; then
  message+="\nLoad: $load\nDisk: $disk%\nRAM: $ram%"
  echo -e "$message" | mail -s "🚨 Server Health Alert on $(hostname)" your@email.com
fi
