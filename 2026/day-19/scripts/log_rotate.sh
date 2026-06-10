#!/bin/bash
set -euo pipefail

LOG_DIR="${1:-}"

if [[ -z "$LOG_DIR" ]]; then
    echo "Please pass directory name while executing script. e.g. ./log_rotate /var/log"
    exit 1
fi

if [[ ! -d "$LOG_DIR" ]]; then
    echo "ERROR: Directory $LOG_DIR does not exist."
    exit 1
fi

echo "====Log Rotation: $LOG_DIR ===="
echo "Started: $(date)"

# Count and compress .log files older than 7 days
COMPRESS_COUNT=$(find "$LOG_DIR" -name "*.log" -mtime +7 | wc -l)
find "$LOG_DIR" -name "*.log" -mtime +7 -exec gzip {} \;
echo "Compressed: $COMPRESS_COUNT file(s)"

#Count and delete .gz files older than 30 days
DELETE_COUNT=$(find "$LOG_DIR" -name "*.gz" -mtime +30 | wc -l)
find "$LOG_DIR" -name "*.gz" -mtime +30 -delete
echo "Deleted:    $DELETE_COUNT archive(s)"
