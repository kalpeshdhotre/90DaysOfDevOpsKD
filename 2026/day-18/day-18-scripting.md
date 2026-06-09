# Day 18 – Shell Scripting: Functions & Intermediate Concepts

## Scripts Written

| Script | Purpose |
|--------|---------|
| `functions.sh` | Basic functions — greet and add |
| `disk_check.sh` | Functions with system checks |
| `strict_demo.sh` | set -euo pipefail demonstration |
| `local_demo.sh` | Local vs global variable scope |
| `system_info.sh` | Full system info reporter |

---

## Task 1: Basic Functions — functions.sh

```bash
#!/bin/bash

greet(){
    echo "Hello, $1!"
}

add(){
    local RESULT=$(( $1 + $2 ))
    echo "Sum of $1 and $2 = $RESULT"
}

greet "Kalpesh"
add 10 25
```

📸 *Screenshot: functions-output.png*

**Observations:**
- Inside a function, `$1` and `$2` refer to the function's own arguments — completely separate from the script's arguments.
- `local RESULT` keeps the variable scoped inside the function — good practice from the start.
- The same function can be called multiple times with different arguments — that's the core value of functions.

---

## Task 2: Functions with System Checks — disk_check.sh

```bash
#!/bin/bash

check_disk(){
    echo "============================="
    echo "Your system disk usage status"
    echo "============================="
    df -h /
    echo ""
}

check_memory(){
    echo "============================="
    echo "Your system memory status"
    echo "============================="
    free -h
}

check_disk
check_memory
```

📸 *Screenshot: disk-check-output.png*

**Observations:**
- Bash functions don't return values like other languages — they communicate through `echo` output.
- Each function is self-contained — adding a new check is as simple as defining a new function and calling it.

---

## Task 3: Strict Mode — strict_demo.sh

```bash
#!/bin/bash
set -euo pipefail

echo "Testing strict mode"

# This will cause script to exit immediately
# because UNDEFINED_VAR was never set (set -u)
# echo "Value: $UNDEFINED_VAR"

# This will exit because /kdkd does not exist
# ls /kdkd

# This will exit because file does not exist
# cat nonexisted.txt | grep "nothing"

echo "This line will not be executed"
```

📸 *Screenshot: strict-demo-output.png*

### What each flag does

| Flag | Behaviour |
|------|-----------|
| `set -e` | Exit immediately if any command returns a non-zero exit code. Prevents silent failures. |
| `set -u` | Treat undefined/unset variables as errors. Without this, undefined variables silently expand to empty string — very hard to debug. |
| `set -o pipefail` | Without this, a pipeline like `failing_cmd \| grep x` returns 0 (success) because grep succeeded — even though the first command failed. With pipefail, the pipe fails if ANY part fails. |

**Observation:** Each commented-out line was tested individually. `set -u` catches the undefined variable error immediately and exits — the script never reaches the next line. This is the most valuable flag for catching typos in variable names.

---

## Task 4: Local Variables — local_demo.sh

```bash
#!/bin/bash

localFunc(){
    local NAME="I am local variable"
    echo "from inside function - $NAME"
}

globalFunc(){
    GLOBAL="I am global variable"
    echo "from inside function - $GLOBAL"
}

localFunc
globalFunc
echo "Whats inside function, localFunc? '$NAME'"
echo "Whats inside function, globalFunc? '$GLOBAL'"
```

📸 *Screenshot: local-demo-output.png*

**Observations:**
- `localFunc` — `NAME` declared with `local`. After the function returns, `$NAME` is empty outside — it did not leak.
- `globalFunc` — `GLOBAL` declared without `local`. After the function returns, `$GLOBAL` is still accessible outside — it leaked into the global scope.
- Always use `local` inside functions unless you explicitly need to set a global variable. Without it, functions can accidentally overwrite each other's variables — a hard-to-find bug in longer scripts.

---

## Task 5: System Info Reporter — system_info.sh

```bash
#!/bin/bash
set -euo pipefail

osinfo(){
    echo "Your Hostname and OS: $(uname -on)"
}

showUptime(){
    echo "Your system is $(uptime -p)"
}

diskUsage(){
    echo "Your system disk usage:"
    # IMPORTANT: du -h | sort -rh | head -5 breaks with set -euo pipefail
    # because sort receives a SIGPIPE when head closes the pipe early
    # Fix: use process substitution to avoid the broken pipe
    head -5 < <(du -h ~ | sort -rh)
}

memoryUsage(){
    echo "Your system memory status:"
    free -h
}

cpuUsage(){
    echo "Your CPU usage report:"
    ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu | head -6
}

main(){
    echo "====== SYSTEM INFO REPORT ======"
    osinfo
    echo "====="
    showUptime
    echo "====="
    diskUsage
    echo "====="
    memoryUsage
    echo "====="
    cpuUsage
    echo "====="
    echo "====== REPORT END ======"
}

main
```

📸 *Screenshot: system-info-output.png*

### Critical Observation — sort | head breaks with set -euo pipefail

This was the most important discovery of Day 18.

**The problem:**
```bash
du -h ~ | sort -rh | head -5   # BREAKS with set -euo pipefail
```

When `head -5` gets its 5 lines it closes its end of the pipe. `sort` is still writing output and gets a **SIGPIPE** signal — it exits with a non-zero code. With `set -o pipefail` active, this non-zero exit code causes the entire script to exit immediately, even though the output was correct.

**The fix — process substitution:**
```bash
head -5 < <(du -h ~ | sort -rh)   # WORKS correctly
```

`< <(command)` runs `du | sort` in a subshell and feeds its output to `head` as a file input rather than a pipe. `head` reads 5 lines and stops — but now `sort` finishes cleanly without SIGPIPE, so the exit code is 0 and `pipefail` is not triggered.

**Why this matters in DevOps:**
This pattern (`sort | head`) appears everywhere — log analysis, monitoring scripts, disk checks. Any script using `set -euo pipefail` (which all production scripts should) will silently break on this pattern without the process substitution fix.

---

## Commands Reference

| Command / Syntax | Purpose |
|-----------------|---------|
| `function_name() { }` | Define a function |
| `local VAR="value"` | Declare a variable scoped to the function |
| `set -euo pipefail` | Strict mode — exit on error, undefined vars, pipe failures |
| `$(( $1 + $2 ))` | Arithmetic expansion |
| `$1, $2` inside function | Function's own arguments |
| `< <(command)` | Process substitution — avoids SIGPIPE issue with pipefail |
| `uname -on` | Show hostname and OS name |
| `uptime -p` | Human-readable uptime |
| `ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu` | Process list sorted by CPU |

---

## Key Learnings

- Functions make scripts reusable and readable — define once, call many times with different arguments. Inside a function `$1/$2` are the function's own arguments, not the script's.
- Always use `local` for variables inside functions. Without it, variables leak into global scope and can silently overwrite values in other functions — a very hard bug to find in longer scripts.
- `sort | head` breaks with `set -o pipefail` because `head` closing the pipe early sends SIGPIPE to `sort`, causing a non-zero exit. Fix with process substitution `head -5 < <(du | sort -rh)` — this pattern appears constantly in DevOps scripts and is essential to know.

---

*Day 18 of #90DaysOfDevOps — TrainWithShubham*
