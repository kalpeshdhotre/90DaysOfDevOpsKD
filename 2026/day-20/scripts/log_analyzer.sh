#!/bin/bash

set -euo pipefail

# TASK 1
# input validation
if [[ -z "${1:-}" ]]; then
    echo "Usage: ./log_analyzer.sh <path>"
    exit 1
fi

LOG_FILE="$1"

if [[ ! -f "$LOG_FILE" ]]; then
    echo "ERROR: File '$LOG_FILE' not found"
    exit 1
fi

echo "Analyzing: $LOG_FILE"

# TASK 2
# Error Count
ERROR_COUNT=$(grep -cE "ERROR|FAILED" "$LOG_FILE" || true)
echo "Total errors found: $ERROR_COUNT"

# TASK 3
# Critical Events
echo ""
echo "---Critical Lines----"
grep -n "CRITICAL" "$LOG_FILE" | awk -F: '{print "Line " $1 ": " substr($0, index($0, $2))}' || true

# TASK 4
# Top Error Messages
echo ""
echo "--- Top 5 Error Messages ---"
head -5 < <(grep "ERROR" "$LOG_FILE" | awk -F'] ' '{print $2}' | awk -F' - ' '{print $1}' \
    | sort | uniq -c | sort -rn) || true

# TASK 5
# Generate Summary report

DATE=$(date +%Y-%m-%d)
REPORT="log_report_${DATE}.txt"
TOTAL_LINES=$(wc -l < "$LOG_FILE")

{
  echo "=============================="
  echo " LOG ANALYSIS REPORT"
  echo "=============================="
  echo "Date:        $(date)"
  echo "Log file:    $LOG_FILE"
  echo "Total lines: $TOTAL_LINES"
  echo "Total errors: $ERROR_COUNT"
  echo ""
  echo "--- Top 5 Error Messages ---"
  head -5 < <(grep "ERROR" "$LOG_FILE" \
    | awk -F'] ' '{print $2}' \
    | awk -F' - ' '{print $1}' \
    | sort | uniq -c | sort -rn) || true
  echo ""
  echo "--- Critical Events ---"
  grep -n "CRITICAL" "$LOG_FILE" | \
    awk -F: '{print "Line " $1 ": " substr($0, index($0,$2))}' || true
  echo "=============================="
} | tee "$REPORT"

echo ""
echo "Report saved: $REPORT"

# TASK 6
# ARchive processed log
#
mkdir -p archive/
mv "$LOG_FILE" archive/
echo "Archived : $LOG_FILE -> archive/"
