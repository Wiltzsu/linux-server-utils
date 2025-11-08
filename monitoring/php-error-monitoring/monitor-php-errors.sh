#!/bin/bash

##############################################
# PHP-FPM Error Monitor for Better Uptime
# Sends logs to Better Uptime Telemetry
##############################################

# Configuration
LOG_FILE="<your_log_file>"
BETTERUPTIME_SOURCE_TOKEN="<your_source_token>"
BETTERUPTIME_INGEST_URL="<your_ingest_url"

# State file to track last read position
STATE_FILE="/var/run/php-error-monitor.state"

# Error patterns to send (Fatal, Parse, Warning, Exceptions)
ERROR_PATTERNS="PHP Fatal|PHP Parse|PHP Warning|PHP Exception|Uncaught"

# Exclude patterns (to filter out noise)
EXCLUDE_PATTERNS="hero-cover|Theme URI"

MAX_ERRORS_PER_RUN=20

##############################################
# Function: Send to Better Uptime Telemetry
##############################################
send_to_telemetry() {
    local log_line="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Determine severity based on error type
    local severity="error"
    if echo "$log_line" | grep -qi "fatal\|parse"; then
        severity="critical"
    elif echo "$log_line" | grep -qi "warning"; then
        severity="warning"
    fi
    
    # Escape for JSON
    local escaped_line=$(echo "$log_line" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\t/\\t/g')
    
    # Create JSON payload
    local json_payload=$(cat <<EOF
{
    "dt": "$timestamp",
    "level": "$severity",
    "message": "$escaped_line",
    "hostname": "$(hostname)",
    "application": "php-fpm",
    "service": "site.com",
    "source": "php-error-log"
}
EOF
)
    
    # Send to Better Uptime
    http_code=$(curl -X POST "$BETTERUPTIME_INGEST_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $BETTERUPTIME_SOURCE_TOKEN" \
        -d "$json_payload" \
        --silent \
        --write-out "%{http_code}" \
        --output /dev/null \
        --max-time 10)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ] || [ "$http_code" = "202" ] || [ "$http_code" = "204" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Sent: ${log_line:0:80}..."
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Failed (HTTP $http_code)" >&2
        return 1
    fi
}

##############################################
# Function: Process new log lines
##############################################
process_log_lines() {
    # Read new lines since last check
    if [ -f "$STATE_FILE" ]; then
        last_line=$(cat "$STATE_FILE")
    else
        last_line=0
    fi
    
    # Get current line count
    current_lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    
    if [ "$current_lines" -le "$last_line" ]; then
        # Log rotated or no new lines
        if [ "$current_lines" -lt "$last_line" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotated, resetting position"
            last_line=0
        else
            return 0
        fi
    fi
    
    
    # Calculate lines to read
    lines_to_read=$((current_lines - last_line))
    
    if [ "$lines_to_read" -gt 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing $lines_to_read new line(s)"
        
        # Initialize error counter
        error_count=0
        
        # Read and process new lines
        tail -n "$lines_to_read" "$LOG_FILE" | while IFS= read -r line; do
            if [ "$error_count" -ge "$MAX_ERRORS_PER_RUN" ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rate limit: max $MAX_ERRORS_PER_RUN errors per run" >&2
                break
            fi
            # Check if line matches error patterns
            if echo "$line" | grep -qiE "$ERROR_PATTERNS"; then
                # Check if line should be excluded
                if ! echo "$line" | grep -qiE "$EXCLUDE_PATTERNS"; then
                    send_to_telemetry "$line"
                    error_count=$((error_count + 1))
                fi
            fi
        done
    fi
    
    # Update state file
    echo "$current_lines" > "$STATE_FILE"
}

##############################################
# Main execution
##############################################

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file $LOG_FILE not found!" >&2
    exit 1
fi

# Check if source token is set
if [ "$BETTERUPTIME_SOURCE_TOKEN" = "YOUR_SOURCE_TOKEN_HERE" ]; then
    echo "Error: Please set your Better Uptime source token!" >&2
    echo "Get it from: Better Uptime → Telemetry → Sources" >&2
    exit 1
fi

# Check for required commands
for cmd in curl tail wc; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' not found!" >&2
        exit 1
    fi
done

echo "=========================================="
echo "PHP-FPM Error Monitor for Better Uptime"
echo "=========================================="
echo "Log file: $LOG_FILE"
echo "Monitoring patterns: $ERROR_PATTERNS"
echo "Excluding: $EXCLUDE_PATTERNS"
if [ "$1" = "--daemon" ]; then
    echo "Mode: Continuous monitoring (Press Ctrl+C to stop)"
else
    echo "Mode: One-shot (for cron)"
fi
echo "=========================================="

# Run mode: continuous or one-shot
if [ "$1" = "--daemon" ]; then
    # Daemon mode: continuous monitoring
    while true; do
        process_log_lines
        sleep 30  # Check every 30 seconds
    done
else
    # One-shot mode: process current logs and exit (for cron)
    process_log_lines
fi