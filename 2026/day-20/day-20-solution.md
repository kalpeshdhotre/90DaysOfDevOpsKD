# Day 20 – Bash Scripting Challenge: Log Analyzer and Report Generator

## Overview

Built a log analysis utility that processes application log files, extracts critical events, identifies common error patterns, generates a detailed report, and archives processed logs.

This challenge combines input validation, text processing, reporting, and file management using common Linux tools such as `grep`, `awk`, `sort`, `uniq`, and `wc`.

---

## Task 1 — Input Validation

### What it does

- Accepts a log file path as a command-line argument
- Validates that an argument was provided
- Validates that the file exists
- Exits with a clear error message when validation fails

### Script

```bash
# Input validation
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
```

### Sample Output

```text
$ ./log_analyzer.sh

Usage: ./log_analyzer.sh <path>
```

```text
$ ./log_analyzer.sh missing.log

ERROR: File 'missing.log' not found
```

---

## Task 2 — Error Count

### What it does

- Searches for log entries containing:
    - `ERROR`
    - `FAILED`
- Counts matching entries
- Prints total errors found

### Script

```bash
ERROR_COUNT=$(grep -cE "ERROR|FAILED" "$LOG_FILE" || true)

echo "Total errors found: $ERROR_COUNT"
```

### Sample Output

```text
Total errors found: 94
```

---

## Task 3 — Critical Events

### What it does

- Searches for all `CRITICAL` log entries
- Displays matching lines
- Includes original line numbers from the log file

### Script

```bash
echo ""
echo "---Critical Lines----"

grep -n "CRITICAL" "$LOG_FILE" | \
awk -F: '{print "Line " $1 ": " substr($0, index($0, $2))}' || true
```

### Sample Output

```text
---Critical Lines----

Line 4: 2026-06-11 19:49:14 [CRITICAL] - 9542
Line 5: 2026-06-11 19:49:14 [CRITICAL] - 26969
Line 13: 2026-06-11 19:49:14 [CRITICAL] - 3666
Line 16: 2026-06-11 19:49:14 [CRITICAL] - 25783
```

---

## Task 4 — Top 5 Error Messages

### What it does

- Extracts all log entries containing `ERROR`
- Removes timestamps and random IDs
- Groups identical error messages
- Counts occurrences
- Displays the five most common errors

### Script

```bash
echo ""
echo "--- Top 5 Error Messages ---"

head -5 < <(
    grep "ERROR" "$LOG_FILE" |
    awk -F'] ' '{print $2}' |
    awk -F' - ' '{print $1}' |
    sort |
    uniq -c |
    sort -rn
) || true
```

### Sample Output

```text
--- Top 5 Error Messages ---

     21 Invalid input
     18 Out of memory
     17 Segmentation fault
     16 Failed to connect
     15 Disk full
```

---

## Task 5 — Summary Report Generation

### What it does

Creates a report file named:

```text
log_report_<date>.txt
```

The report contains:

- Analysis date
- Log file name
- Total lines processed
- Total error count
- Top 5 error messages
- Critical events with line numbers

### Script

```bash
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
  head -5 < <(
    grep "ERROR" "$LOG_FILE" |
    awk -F'] ' '{print $2}' |
    awk -F' - ' '{print $1}' |
    sort |
    uniq -c |
    sort -rn
  ) || true

  echo ""
  echo "--- Critical Events ---"

  grep -n "CRITICAL" "$LOG_FILE" | \
    awk -F: '{print "Line " $1 ": " substr($0,index($0,$2))}' || true

  echo "=============================="
} | tee "$REPORT"
```

### Sample Report

```text
==============================
 LOG ANALYSIS REPORT
==============================
Date: Thu Jun 11 20:00:00 IST 2026
Log file: test.log
Total lines: 500
Total errors: 94

--- Top 5 Error Messages ---
21 Invalid input
18 Out of memory
17 Segmentation fault
16 Failed to connect
15 Disk full

--- Critical Events ---
Line 4: 2026-06-11 19:49:14 [CRITICAL] - 9542
Line 5: 2026-06-11 19:49:14 [CRITICAL] - 26969

==============================
```

---

## Task 6 — Archive Processed Logs

### What it does

- Creates an `archive/` directory if it does not already exist
- Moves the processed log file into the archive directory
- Prints confirmation

### Script

```bash
mkdir -p archive/

mv "$LOG_FILE" archive/

echo "Archived : $LOG_FILE -> archive/"
```

### Sample Output

```text
Archived : test.log -> archive/
```

---

## Commands and Tools Used

| Command    | Purpose                         |
| ---------- | ------------------------------- |
| `grep`     | Search log entries              |
| `grep -c`  | Count matching lines            |
| `grep -n`  | Display line numbers            |
| `awk`      | Extract and format log data     |
| `sort`     | Sort error messages             |
| `uniq -c`  | Count duplicate messages        |
| `head`     | Display top 5 results           |
| `wc -l`    | Count total lines               |
| `tee`      | Write output to file and screen |
| `mkdir -p` | Create archive directory        |
| `mv`       | Archive processed log           |

---

## Key Learnings

### 1. grep Exit Codes Matter with `set -e`

`grep` returns exit code `1` when no matches are found. Using `|| true` prevents the script from terminating unexpectedly when no matching records exist.

### 2. awk Makes Log Parsing Easy

Custom field separators allow extraction of specific portions of log entries without complex string manipulation.

Example:

```bash
awk -F'] ' '{print $2}'
```

removes timestamps and log level information, making analysis simpler.

### 3. sort + uniq Provide Quick Analytics

A simple pipeline:

```bash
sort | uniq -c | sort -rn
```

can quickly identify the most frequent events in large log files and is commonly used for log analysis and troubleshooting.

---

## Conclusion

This project demonstrated how Bash can be used for practical log analysis tasks including validation, event filtering, frequency analysis, report generation, and log archiving. By combining standard Linux utilities, it is possible to build powerful automation tools with relatively small scripts.

---

**#90DaysOfDevOps**  
**#DevOpsKaJosh**  
**#TrainWithShubham**
