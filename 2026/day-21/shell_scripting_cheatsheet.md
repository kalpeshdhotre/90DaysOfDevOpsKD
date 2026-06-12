# Shell Scripting Cheat Sheet
> Personal reference guide — Days 16–21 of #90DaysOfDevOps

---

## Quick Reference Table

| Topic | Key Syntax | Example |
|-------|-----------|---------|
| Shebang | `#!/bin/bash` | First line of every script |
| Variable | `VAR="value"` | `NAME="DevOps"` |
| Argument | `$1`, `$2`, `$#`, `$@` | `./script.sh arg1 arg2` |
| If | `if [[ condition ]]; then` | `if [[ -f file ]]; then` |
| For loop | `for i in list; do` | `for i in {1..10}; do` |
| While loop | `while [[ condition ]]; do` | `while [[ $N -gt 0 ]]; do` |
| Function | `name() { ... }` | `greet() { echo "Hi $1"; }` |
| Grep | `grep pattern file` | `grep -iE "error\|failed" log.txt` |
| Awk | `awk '{print $1}' file` | `awk -F: '{print $1}' /etc/passwd` |
| Sed | `sed 's/old/new/g' file` | `sed -i 's/foo/bar/g' config.txt` |
| Strict mode | `set -euo pipefail` | After shebang in every prod script |
| Exit code | `$?` | `echo $?` after any command |

---

## 1. Basics

### Shebang
```bash
#!/bin/bash    # tells OS to use bash interpreter
#!/bin/sh      # POSIX shell — fewer features, more portable
```
Without shebang, behaviour depends on the system's default shell — unpredictable.

### Running a script
```bash
chmod +x script.sh    # make executable (one time only)
./script.sh           # run directly
bash script.sh        # run without chmod — ignores shebang
```

### Comments
```bash
# This is a full-line comment
echo "hello"   # This is an inline comment
```

### Variables
```bash
NAME="Kalpesh"          # no spaces around =
ROLE="DevOps Engineer"

echo "$NAME"            # double quotes — expands variable → Kalpesh
echo "${NAME}"          # same, but explicit — preferred in strings
echo '$NAME'            # single quotes — literal → $NAME
echo "I am ${NAME}!"    # use {} when concatenating with other text
```

### User input
```bash
read -p "Enter your name: " NAME     # prompt on same line
read -sp "Enter password: " PASS     # -s = silent (no echo)
echo "Hello, $NAME"
```

### Command-line arguments
```bash
$0    # script name
$1    # first argument
$2    # second argument
$#    # total number of arguments
$@    # all arguments as a list
$?    # exit code of last command (0 = success, non-zero = failure)
$$    # current script's PID
```

---

## 2. Operators and Conditionals

### String comparisons
```bash
[[ "$A" = "$B" ]]     # equal
[[ "$A" != "$B" ]]    # not equal
[[ -z "$A" ]]         # true if A is empty/unset
[[ -n "$A" ]]         # true if A is non-empty
```

### Integer comparisons
```bash
[[ $A -eq $B ]]    # equal
[[ $A -ne $B ]]    # not equal
[[ $A -lt $B ]]    # less than
[[ $A -gt $B ]]    # greater than
[[ $A -le $B ]]    # less than or equal
[[ $A -ge $B ]]    # greater than or equal
```

### File test operators
```bash
[[ -f "$FILE" ]]    # is a regular file
[[ -d "$DIR" ]]     # is a directory
[[ -e "$PATH" ]]    # exists (file or directory)
[[ -r "$FILE" ]]    # readable
[[ -w "$FILE" ]]    # writable
[[ -x "$FILE" ]]    # executable
[[ -s "$FILE" ]]    # exists and is non-empty
```

### If / elif / else
```bash
if [[ condition ]]; then
  # commands
elif [[ other_condition ]]; then
  # commands
else
  # commands
fi
```

### Logical operators
```bash
[[ cond1 ]] && [[ cond2 ]]    # AND — both must be true
[[ cond1 ]] || [[ cond2 ]]    # OR  — at least one true
! [[ condition ]]              # NOT

command1 && command2       # run command2 only if command1 succeeds
command1 || command2       # run command2 only if command1 fails
```

### Case statement
```bash
case "$VAR" in
  "start")
    echo "Starting..."
    ;;
  "stop")
    echo "Stopping..."
    ;;
  *)
    echo "Unknown option"
    ;;
esac
```

---

## 3. Loops

### For loop — list based
```bash
for FRUIT in apple banana mango; do
  echo "$FRUIT"
done
```

### For loop — range
```bash
for i in {1..10}; do
  echo $i
done
```

### For loop — C style
```bash
for (( i=0; i<5; i++ )); do
  echo $i
done
```

### While loop
```bash
COUNT=5
while [[ $COUNT -gt 0 ]]; do
  echo $COUNT
  COUNT=$(( COUNT - 1 ))
done
```

### Until loop
```bash
# Runs UNTIL condition becomes true (opposite of while)
until [[ $COUNT -eq 0 ]]; do
  echo $COUNT
  COUNT=$(( COUNT - 1 ))
done
```

### Break and continue
```bash
for i in {1..10}; do
  [[ $i -eq 5 ]] && break      # stop loop at 5
  [[ $i -eq 3 ]] && continue   # skip 3, keep going
  echo $i
done
```

### Loop over files
```bash
for FILE in *.log; do
  echo "Processing: $FILE"
done
```

### Loop over command output
```bash
while read LINE; do
  echo "Line: $LINE"
done < /etc/passwd
```

---

## 4. Functions

### Define and call
```bash
greet() {
  echo "Hello, $1!"
}

greet "Kalpesh"    # call with argument
```

### Return values
```bash
# Bash functions don't return values — they echo output
get_date() {
  echo "$(date +%Y-%m-%d)"
}

TODAY=$(get_date)    # capture output with command substitution
echo "Today: $TODAY"

# return only sends an exit code (0-255), not a value
check_file() {
  [[ -f "$1" ]] && return 0 || return 1
}
```

### Local variables
```bash
my_func() {
  local CITY="Mumbai"    # scoped to function only
  echo "$CITY"
}

my_func
echo "$CITY"    # empty — local variable did not leak
```

---

## 5. Text Processing Commands

### grep — search
```bash
grep "ERROR" file.log           # basic search
grep -i "error" file.log        # case insensitive
grep -r "ERROR" /var/log/       # recursive search in directory
grep -c "ERROR" file.log        # count matching lines
grep -n "ERROR" file.log        # show line numbers
grep -v "INFO" file.log         # invert — lines NOT matching
grep -E "ERROR|CRITICAL" file   # extended regex — multiple patterns
grep -l "ERROR" *.log           # list filenames that match
```

### awk — field processing
```bash
awk '{print $1}' file           # print first field (space separated)
awk -F: '{print $1}' /etc/passwd   # -F sets delimiter (: here)
awk '{print $1, $3}' file       # print fields 1 and 3
awk '/ERROR/ {print $0}' file   # print lines matching pattern
awk 'NR==5' file                # print line number 5
awk '{sum += $1} END {print sum}' file   # sum a column
awk 'BEGIN {print "Start"} {print} END {print "End"}' file
```

### sed — stream editor
```bash
sed 's/old/new/' file           # replace first occurrence per line
sed 's/old/new/g' file          # replace all occurrences
sed -i 's/old/new/g' file       # in-place edit (modifies file)
sed -n '5,10p' file             # print lines 5 to 10
sed '/ERROR/d' file             # delete lines matching pattern
sed '1d' file                   # delete first line
```

### cut — extract columns
```bash
cut -d: -f1 /etc/passwd         # delimiter :, extract field 1
cut -d, -f2,3 data.csv          # CSV, extract fields 2 and 3
cut -c1-10 file                 # extract characters 1 to 10
```

### sort
```bash
sort file                       # alphabetical ascending
sort -r file                    # reverse
sort -n file                    # numerical sort
sort -rn file                   # numerical descending
sort -u file                    # sort and remove duplicates
sort -t: -k3 -n /etc/passwd     # sort by field 3, delimiter :
```

### uniq
```bash
sort file | uniq                # remove duplicates (must sort first)
sort file | uniq -c             # count occurrences
sort file | uniq -d             # show only duplicates
sort file | uniq -u             # show only unique lines
```

### tr — translate/delete characters
```bash
echo "hello" | tr 'a-z' 'A-Z'  # lowercase to uppercase
echo "hello world" | tr -d ' ' # delete spaces
echo "a:b:c" | tr ':' ','       # replace : with ,
```

### wc — count
```bash
wc -l file      # count lines
wc -w file      # count words
wc -c file      # count bytes/characters
wc -l < file    # count lines — suppress filename in output
```

### head / tail
```bash
head -n 10 file          # first 10 lines
tail -n 10 file          # last 10 lines
tail -f file             # follow — live stream new lines
tail -f file | grep ERROR   # live error monitoring
head -5 < <(sort file)   # avoid SIGPIPE with sort|head + pipefail
```

---

## 6. Useful One-Liners

```bash
# Find and delete files older than 7 days
find /var/log -name "*.log" -mtime +7 -delete

# Count lines in all .log files
wc -l /var/log/*.log | tail -1

# Replace a string across multiple files
sed -i 's/old_string/new_string/g' *.conf

# Check if a service is running
systemctl is-active nginx && echo "running" || echo "stopped"

# Monitor disk usage and alert if above 80%
USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
[[ "$USAGE" -gt 80 ]] && echo "ALERT: Disk at ${USAGE}%"

# Live tail log and filter errors
tail -f /var/log/nginx/access.log | grep --line-buffered "ERROR"

# Top 5 CPU processes
ps aux --sort=-%cpu | head -6

# Count occurrences of each error type in a log
grep "ERROR" app.log | awk '{print $NF}' | sort | uniq -c | sort -rn

# Extract all unique IPs from nginx access log
awk '{print $1}' /var/log/nginx/access.log | sort -u

# Archive and compress a directory with timestamp
tar -czf backup-$(date +%Y-%m-%d).tar.gz /path/to/dir
```

---

## 7. Error Handling and Debugging

### Exit codes
```bash
$?              # exit code of last command
exit 0          # success
exit 1          # generic error
exit 2          # misuse of command

command && echo "success" || echo "failed"
```

### Strict mode flags
```bash
set -e           # exit immediately on any error
set -u           # treat unset variables as errors
set -o pipefail  # fail if any command in a pipe fails
set -x           # debug mode — print each command before executing

# Always use together in production scripts:
set -euo pipefail
```

### set -x debug mode
```bash
#!/bin/bash
set -x           # enable debug trace
echo "hello"     # output: + echo 'hello'
set +x           # disable debug trace
```

### sort | head with pipefail — known issue
```bash
# BREAKS with set -o pipefail (SIGPIPE)
sort file | head -5

# FIX — use process substitution
head -5 < <(sort file)
```

### Trap — cleanup on exit
```bash
cleanup() {
  echo "Cleaning up..."
  rm -f /tmp/tempfile
}

trap cleanup EXIT         # runs cleanup() when script exits (any reason)
trap cleanup INT TERM     # also on Ctrl+C or kill signal
```

### || operator for inline error handling
```bash
mkdir /opt/myapp || { echo "Failed to create dir"; exit 1; }

# Or with subshell (avoids vim/nvim parser false positives)
mkdir /opt/myapp || ( echo "Failed to create dir" && exit 1 )
```

---

## 8. Patterns from Real Scripts

### Root check
```bash
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi
```

### Check argument exists
```bash
if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <argument>"
  exit 1
fi
```

### Timestamped logging function
```bash
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" | tee -a "$LOGFILE"
}
log "Script started"
```

### Count + act pattern (avoid acting on wrong count)
```bash
COUNT=$(find /var/log -name "*.log" -mtime +7 | wc -l)
find /var/log -name "*.log" -mtime +7 -delete
echo "Deleted: $COUNT file(s)"
```

### Package install check (RHEL)
```bash
rpm -q packagename &> /dev/null && echo "installed" || echo "missing"
```

---

*Built during Days 16–21 of #90DaysOfDevOps — TrainWithShubham*
