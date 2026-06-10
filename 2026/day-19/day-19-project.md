# Day 19 – Shell Scripting Project: Log Rotation, Backup & Crontab

## Overview

Real-world automation scripts combining everything from Days 16–18 — file operations, error handling, `find`, `tar`, and cron scheduling.

---

## Task 1 — Log Rotation Script (`log_rotate.sh`)

### What it does
- Takes a log directory as `$1`
- Compresses `.log` files older than 7 days using `gzip`
- Deletes `.gz` archives older than 30 days
- Reports count of each action
- Exits with error if directory doesn't exist

### Script

```bash
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

# Count and delete .gz files older than 30 days
DELETE_COUNT=$(find "$LOG_DIR" -name "*.gz" -mtime +30 | wc -l)
find "$LOG_DIR" -name "*.gz" -mtime +30 -delete
echo "Deleted:    $DELETE_COUNT archive(s)"
```

### Sample Output

```
====Log Rotation: /var/log/myapp ====
Started: Mon Jun  9 11:00:00 IST 2026
Compressed: 3 file(s)
Deleted:    1 archive(s)
```

---

## Task 2 — Server Backup Script (`backup.sh`)

### What it does
- Takes source dir as `$1` and backup destination as `$2`
- Creates a timestamped `.tar.gz` archive
- Verifies archive was created successfully
- Prints archive name and size
- Cleans up backups older than 14 days

### Script

```bash
#!/bin/bash
set -euo pipefail

SOURCE="${1:-}"
DEST="${2:-}"

if [[ -z "$SOURCE" ]] || [[ -z "$DEST" ]]; then
    echo "check source and destination"
    exit 1
fi

if [ ! -d "$SOURCE" ]; then
  echo "ERROR: Source '$SOURCE' does not exist."
  exit 1
fi

mkdir -p "$DEST"

DATE=$(date +%Y-%m-%d)
ARCHIVE="$DEST/backup-$DATE.tar.gz"

echo "=== Backup Started: $(date) ==="
tar -czf "$ARCHIVE" "$SOURCE"

if [ -f "$ARCHIVE" ]; then
  SIZE=$(du -sh "$ARCHIVE" | cut -f1)
  echo "Archive:  $ARCHIVE"
  echo "Size:     $SIZE"
else
  echo "ERROR: Backup failed — archive not created."
  exit 1
fi

OLD_COUNT=$(find "$DEST" -name "backup-*.tar.gz" -mtime +14 | wc -l)
find "$DEST" -name "backup-*.tar.gz" -mtime +14 -delete
echo "Cleaned:  $OLD_COUNT old backup(s) removed"
echo "=== Backup Done: $(date) ==="
```

### Sample Output

```
=== Backup Started: Mon Jun 9 11:05:00 IST 2026 ===
Archive:  /backup/backup-2026-06-09.tar.gz
Size:     24M
Cleaned:  2 old backup(s) removed
=== Backup Done: Mon Jun 9 11:05:03 IST 2026 ===
```

---

## Task 3 — Crontab

### Cron Syntax Reference

```
* * * * *  command
│ │ │ │ │
│ │ │ │ └── Day of week (0–7, 0 and 7 = Sunday)
│ │ │ └──── Month (1–12)
│ │ └────── Day of month (1–31)
│ └──────── Hour (0–23)
└────────── Minute (0–59)
```

### Cron Entries

```cron
# Run log_rotate.sh every day at 2 AM
0 2 * * * /path/to/log_rotate.sh /var/log/myapp >> /var/log/cron-output.log 2>&1

# Run backup.sh every Sunday at 3 AM
0 3 * * 0 /path/to/backup.sh /var/www /backup >> /var/log/cron-output.log 2>&1

# Run health check script every 5 minutes
*/5 * * * * /path/to/health_check.sh >> /var/log/cron-output.log 2>&1
```

> **Note:** Always use absolute paths in cron — it runs with a minimal `$PATH` and won't find scripts otherwise. Always redirect output with `>> logfile 2>&1` so errors are captured.

---

## Task 4 — Combined Maintenance Script (`maintenance.sh`)

### What it does
- Calls `log_rotate.sh` and `backup.sh` in sequence
- Wraps all output in timestamped log entries
- Appends everything to `/var/log/maintenance.log`

### Script

```bash
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
```

### Cron Entry

```cron
# Run daily at 1 AM
0 1 * * * /path/to/maintenance.sh >> /var/log/maintenance.log 2>&1
```

### Sample Log Output (`/var/log/maintenance.log`)

```
2026-06-09 01:00:01 : ===== MAINTENANCE START =====
2026-06-09 01:00:01 : Starting log rotation...
====Log Rotation: /var/log/myapp ====
Compressed: 2 file(s)
Deleted:    0 archive(s)
2026-06-09 01:00:02 : Log rotation complete.
2026-06-09 01:00:02 : Starting backup...
=== Backup Started: Mon Jun 9 01:00:02 IST 2026 ===
Archive:  /backup/backup-2026-06-09.tar.gz
Size:     18M
Cleaned:  0 old backup(s) removed
=== Backup Done: Mon Jun 9 01:00:05 IST 2026 ===
2026-06-09 01:00:05 : Backup complete.
2026-06-09 01:00:05 : ===== MAINTENANCE END =====
```

---

## Key Learnings

1. **Count before you act** — running `find ... | wc -l` before the destructive/mutating command lets you report meaningful numbers without a second pass through the filesystem.

2. **Always verify after tar** — `tar` exits 0 even in edge cases; explicitly checking `[ -f "$ARCHIVE" ]` after creation catches silent failures before they go unnoticed.

3. **Cron needs absolute paths and explicit logging** — cron runs in a stripped environment with no `$PATH`, so scripts that work in your shell silently fail in cron. Redirecting with `>> logfile 2>&1` makes debugging possible; without it, failures vanish into thin air.

---

*Day 19 of #90DaysOfDevOps · #DevOpsKaJosh · #TrainWithShubham*
