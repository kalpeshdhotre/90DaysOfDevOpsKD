#!/bin/bash

set -euo pipefail

LOGFILE="/var/log/maintenance.log"
LOG_DIR="/var/log/myapp"
BACKUP_SRC="/var/www"
BACKUP_DEST="/backup"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" | tee -a "$LOGFILE"
}

log "===== MAINTENANCE START ====="

log "Starting log rotation..."
/path/to/log_rotate.sh "$LOG_DIR" >> "$LOGFILE" 2>&1
log "Log rotation complete."

log "Starting backup..."
/path/to/backup.sh "$BACKUP_SRC" "$BACKUP_DEST" >> "$LOGFILE" 2>&1
log "Backup complete."

log "===== MAINTENANCE END ====="