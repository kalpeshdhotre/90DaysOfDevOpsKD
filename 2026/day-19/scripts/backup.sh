#!/bin/bash

set -euo pipefail

SOURCE="${1:-}"
DEST="${2:-}"

# Argument checking
if [[ -z "$SOURCE" ]] || [[ -z "$DEST" ]]; then
    echo "check source and destination"
    exit 1
fi

# Check source exists
if [ ! -d "$SOURCE" ]; then
  echo "ERROR: Source '$SOURCE' does not exist."
  exit 1
fi

# Create destination if missing
mkdir -p "$DEST"

# Create timestamped archive
DATE=$(date +%Y-%m-%d)
ARCHIVE="$DEST/backup-$DATE.tar.gz"

echo "=== Backup Started: $(date) ==="
tar -czf "$ARCHIVE" "$SOURCE"

# Verify archive created
if [ -f "$ARCHIVE" ]; then
  SIZE=$(du -sh "$ARCHIVE" | cut -f1)
  echo "Archive:  $ARCHIVE"
  echo "Size:     $SIZE"
else
  echo "ERROR: Backup failed — archive not created."
  exit 1
fi

# Delete backups older than 14 days
OLD_COUNT=$(find "$DEST" -name "backup-*.tar.gz" -mtime +14 | wc -l)
find "$DEST" -name "backup-*.tar.gz" -mtime +14 -delete
echo "Cleaned:  $OLD_COUNT old backup(s) removed"
echo "=== Backup Done: $(date) ==="