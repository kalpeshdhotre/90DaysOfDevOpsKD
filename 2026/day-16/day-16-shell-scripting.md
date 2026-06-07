# Day 16 – Shell Scripting Basics

---

## Task 1: Your First Script — hello.sh

### Script

```bash
#!/bin/bash

echo "Hello, Devops"
```

### Output

```
Hello, Devops
```

### What happens without the shebang?

Without `#!/bin/bash`, the OS doesn't know which interpreter to use. The script may still run if the default shell is bash — but it's unreliable. On some systems it falls back to `/bin/sh`, which has fewer features and different syntax. Always include the shebang to guarantee consistent behaviour.

---

## Task 2: Variables — variable.sh

### Script

```bash
#!/bin/bash
# Task 2 - Variable

NAME="Kalpesh"
ROLE="DevOps Engineer"

echo 'Hello, I am $NAME and I am $ROLE'
```

### Output

```
Hello, I am $NAME and I am $ROLE
```

### Single quotes vs Double quotes

| Quote Type | Behaviour | Example Output |
|------------|-----------|----------------|
| Double `"` | Expands variables | `Hello, I am Kalpesh and I am a DevOps Engineer` |
| Single `'` | Treats everything literally | `Hello, I am $NAME and I am a $ROLE` |

**Rule:** Always use double quotes when your string contains variables. Use single quotes only when you want the exact literal string.

---

## Task 3: User Input with read — greet.sh

### Script

```bash
#!/bin/bash

read -p "Enter your name: " Name
read -p "Enter your favorite tool in DevOps: " Tool
echo "Hello $Name, your favorite tool is $Tool"
```

### Output

```
Enter your name: Kalpesh
Enter your favorite tool in DevOps: Linux
Hello Kalpesh, your favorite tool is Linux
```

**Note:** `read -p` prints the prompt on the same line as the input cursor. Whatever the user types is stored in the named variable.

---

## Task 4: If-Else Conditions

### Task 4.1 — check_number.sh

```bash
#1/bin/bash

read -p "Enter number to be checked: " Number

if [ $Number -gt 0 ]; then
    echo "Number is positive"
elif [ $Number -lt 0 ]; then
    echo "Number is negative"
else
    echo "The Number is zero"
fi
```

### Output

```
Enter number to be checked: -5
Number is negative

Enter number to be checked: 7
Number is positive

Enter number to be checked: 0
The Number is zero
```

**Operators used:**

| Operator | Meaning |
|----------|---------|
| `-gt` | Greater than |
| `-lt` | Less than |
| `-eq` | Equal to |

**Key rule:** Spaces inside `[ ]` are mandatory. `[$NUM -gt 0]` fails; `[ $NUM -gt 0 ]` works. Always close an `if` block with `fi`.

---

### Task 4.2 — file_check.sh

```bash
#!/bin/bash
read -p "Enter file name to be check: " FILE

if [ -f "$FILE" ]; then
    echo "File exists"
else
    echo "Entered file do not exists"
fi
```

### Output

```
Enter file name to be check: /etc/hostname
File exists

Enter file name to be check: /etc/fakefile
Entered file do not exists
```

**Common file test flags:**

| Flag | Checks |
|------|--------|
| `-f` | File exists |
| `-d` | Directory exists |
| `-r` | File is readable |
| `-w` | File is writable |
| `-x` | File is executable |

Always quote `"$FILE"` to handle filenames with spaces correctly.

---

## Task 5: Combine It All — server_check.sh

### Script

```bash
#!/bin/bash

read -p "Enter service name to be checked: " SERVICE

read -p "Procced with the status check of $SERVICE? (y/n): " ANSWER

if [ $ANSWER == "y" ]; then
    STATUS=$(systemctl is-active $SERVICE)
    if [ "$STATUS" == "active" ]; then
        echo "Service is running."
    else
        echo "Service is not running. Status: $STATUS"
    fi
else
    echo "Service checking skipped"
fi
```

### Output

```
Enter service name to be checked: nginx
Procced with the status check of nginx? (y/n): y
Service is running.

Enter service name to be checked: nginx
Procced with the status check of nginx? (y/n): n
Service checking skipped
```

**Key concept — Command substitution:** `$(command)` runs a command and stores its output in a variable. `systemctl is-active` returns a single word — `active` or `inactive` — which is cleaner to compare than parsing the full `systemctl status` output.

---

## Commands Used

| Command | Purpose |
|---------|---------|
| `chmod +x script.sh` | Make script executable |
| `./script.sh` | Run the script |
| `read -p "prompt" VAR` | Read user input with inline prompt |
| `if [ condition ]; then` | Start a conditional block |
| `elif` | Else-if branch |
| `fi` | Close the if block |
| `$(command)` | Command substitution — capture command output |
| `systemctl is-active` | Check if a service is active (returns one word) |

---

## Key Learnings

- **Shebang and execute permission are non-negotiable.** `#!/bin/bash` on line 1 tells the OS which interpreter to run the script with. `chmod +x` grants execute permission — without either, the script won't behave reliably. These two steps always go together before running any script.
- **Variable syntax in bash is strict.** No spaces around `=` when assigning (`NAME="Kalpesh"` not `NAME = "Kalpesh"`). Double quotes expand variables; single quotes print them literally. Spaces inside `[ ]` in conditionals are mandatory — missing them causes syntax errors that are hard to debug.
- **Command substitution `$()` bridges scripting and system commands.** Wrapping any command in `$()` captures its output into a variable. This is the key pattern that makes shell scripts powerful for DevOps — you can store the result of `systemctl`, `grep`, `curl`, or any other command and act on it with conditionals.

---

*Day 16 of #90DaysOfDevOps — TrainWithShubham*
