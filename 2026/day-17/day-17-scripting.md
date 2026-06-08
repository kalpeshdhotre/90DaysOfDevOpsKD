# Day 17 – Loops, Arguments & Error Handling

---

## Task 1: For Loops

### Task 1.1 — for_loop.sh

```bash
#!/bin/bash

ITEMS="Banana Peru Kiwi Mango Pineapple"

for ITEM in $ITEMS; do
    echo "$ITEM"
done
```

### Output

```
Banana
Peru
Kiwi
Mango
Pineapple
```

`for` iterates over a space-separated list, assigning each value to `ITEM` one at a time. Always close the loop with `done` — same pattern as `fi` for if-else.

---

### Task 1.2 — count.sh

```bash
#!/bin/bash

for i in {1..10};
do
    echo "Count: $i"
done
```

### Output

```
Count: 1
Count: 2
Count: 3
...
Count: 10
```

`{1..10}` is brace expansion — bash automatically generates the sequence `1 2 3 ... 10`. Equivalent to using `seq 1 10`.

---

## Task 2: While Loop — countdown.sh

```bash
#!/bin/bash

read -p "Enter Number from where count down to start: " START

while [[ $START -gt 0 ]];
do
    echo $START
    START=$((START - 1))
done
```

### Output

```
Enter Number from where count down to start: 5
5
4
3
2
1
```

`$(( ))` is arithmetic expansion — the standard way to do math in bash. `START=$((START - 1))` decrements the counter each iteration. Without this line the loop runs forever (Ctrl+C to escape an infinite loop).

---

## Task 3: Command-Line Arguments

### Task 3.1 — greet.sh

```bash
#!/bin/bash

if [[ $1 ]] then
    echo "Hello $1"
else
    echo "Type your name while running script"
fi
```

### Output

```
$ ./greet.sh Kalpesh
Hello Kalpesh

$ ./greet.sh
Type your name while running script
```

`$1` holds the first argument passed to the script at runtime. When no argument is given, `$1` is empty and the else branch runs.

---

### Task 3.2 — args_demo.sh

```bash
#!/bin/bash

if [[ $1 ]] then
    echo "File name is $0, Total No of args are $#"
    echo "Arguments are $@"
else
    echo "No argument passed"
fi
```

### Output

```
$ ./args_demo.sh linux aws docker
File name is ./args_demo.sh, Total No of args are 3
Arguments are linux aws docker

$ ./args_demo.sh
No argument passed
```

**Special argument variables — available in every script automatically:**

| Variable | Meaning |
|----------|---------|
| `$0` | Script name |
| `$1`, `$2` ... | Positional arguments |
| `$#` | Total count of arguments |
| `$@` | All arguments as a list |

`$@` is especially useful inside loops: `for ARG in "$@"; do` iterates over every argument passed.

---

## Task 4: Install Packages Script — install_packages.sh

```bash
#!/bin/bash

PACKAGES="nginx curl wget tree"

for PACKAGE in $PACKAGES; do
    if rpm -q "$PACKAGE" >/dev/null; then
        echo "Package is already installed"
    else
        echo "Installing package..."
        sudo dnf install -y $PACKAGE
        echo "$PACKAGE installed successfully!"
    fi
done
```

### Output

```
curl is already installed
wget is already installed
Installing package...
nginx installed successfully!
Installing package...
tree installed successfully!
```

`rpm -q` checks if a package is installed on RHEL. `>/dev/null` suppresses output — only the exit code matters (0 = installed, non-zero = not installed). On Ubuntu/Debian use `dpkg -s` instead.

---

## Task 5: Error Handling — safe_script.sh

```bash
#!/bin/bash
set -e

mkdir /tmp/devops-test || echo "Directory already exists.."
cd /tmp/devops-test || { echo "Cannot navigate into the directory. Exiting"; exit 1; }
touch deployement.log || { echo "Cannot create file. Exiting."; exit 1; }

echo "All steps completed. Files in /tmp/devops-test:"
ls -lh /tmp/devops-test
```

### Output

```
# First run:
All steps completed. Files in /tmp/devops-test:
-rw-r--r-- 1 kalpesh kalpesh 0 ... deployement.log

# Second run:
Directory already exists..
All steps completed. Files in /tmp/devops-test:
-rw-r--r-- 1 kalpesh kalpesh 0 ... deployement.log
```

**Error handling concepts used:**

| Pattern | Meaning |
|---------|---------|
| `set -e` | Exit immediately if any command fails — prevents silent failures |
| `\|\|` | OR operator — if left side fails, run right side |
| `{ cmd; exit 1; }` | Group multiple fallback commands |

`set -e` is the first line of defence in production scripts — it ensures a broken step doesn't silently let later steps run on bad state.

---

## Commands Used

| Command / Syntax | Purpose |
|------------------|---------|
| `for ITEM in list; do ... done` | Iterate over a list |
| `{1..10}` | Brace expansion — generate a number sequence |
| `while [ condition ]; do ... done` | Loop while condition is true |
| `$((NUM - 1))` | Arithmetic expansion |
| `$1`, `$#`, `$@`, `$0` | Special argument variables |
| `rpm -q package` | Check if package is installed (RHEL) |
| `dnf install -y` | Install package without prompt (RHEL) |
| `set -e` | Exit on any command failure |
| `command \|\| fallback` | Run fallback if command fails |

---

## Key Learnings

- **Loops remove repetition from scripts.** `for` works over a list or a sequence (`{1..10}`); `while` runs as long as a condition holds. Together they handle most automation patterns — iterating over servers, packages, files, or arguments.
- **`$1`, `$#`, `$@` make scripts reusable.** Instead of hardcoding values, arguments let the same script work for any input at runtime. Checking `$1` before using it prevents confusing errors when the user forgets to pass an argument.
- **`set -e` and `||` are the two pillars of safe scripting.** `set -e` stops the script the moment anything fails; `||` lets you define what happens on failure instead of crashing silently. Together they make scripts predictable and production-ready.

---

*Day 17 of #90DaysOfDevOps — TrainWithShubham*
