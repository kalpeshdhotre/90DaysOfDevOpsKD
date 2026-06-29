# Day 38 – YAML Basics

## Overview

Before writing CI/CD pipelines, you need to get comfortable with **YAML** — the language every pipeline, Kubernetes manifest, and Docker Compose file is written in. Today covered YAML syntax from the ground up: key-value pairs, lists, nested objects, multi-line strings, and validation.

---

## YAML Files Created

### `person.yaml`

```yaml
name: Kalpesh Dhotre
role: Junior Cloud Engineer
experience_years: 22
learning: true

tools:
    - docker
    - kubernetes
    - git
    - linux
    - google-cloud

hobbies: [keyboards, electronics, cricket]
```

### `server.yaml`

```yaml
server:
    name: prod-web-01
    ip: 192.168.1.100
    port: 8080

database:
    host: localhost
    name: appdb
    credentials:
        user: dbadmin
        password: changeme123

startup_script: |
    #!/bin/bash
    echo "Starting server..."
    systemctl start nginx
    systemctl start app

startup_message: >
    This server runs the main application.
    It connects to the database on localhost.
    All logs go to /var/log/app/.
```

---

## Task Outputs

### Task 1 – Key-Value Pairs

Created `person.yaml` with `name`, `role`, `experience_years`, and `learning` (boolean).

**Verified with:** `cat person.yaml` — clean output, no tabs.  
**Tab check:** `cat -A person.yaml` — no `^I` characters found.

---

### Task 2 – Lists

Added `tools` (block style) and `hobbies` (inline style) to `person.yaml`.

**Two ways to write a list in YAML:**

1. **Block style** — one item per line, each prefixed with `- `:

    ```yaml
    tools:
        - docker
        - kubernetes
    ```

2. **Inline/flow style** — comma-separated values inside square brackets:
    ```yaml
    hobbies: [keyboards, electronics, cricket]
    ```

---

### Task 3 – Nested Objects

Created `server.yaml` with three levels of nesting: `server` → `database` → `credentials`.

**Tab test:** Replaced spaces with a tab under `server:` and ran `yamllint server.yaml`.

**Error received:**

```
server.yaml
  2:1  error  found character '\t' that cannot start any token  (syntax)
```

Fixed by restoring 2-space indentation.

---

### Task 4 – Multi-line Strings

Added `startup_script` using `|` and `startup_message` using `>`.

| Style         | Symbol | Behaviour                      | When to use                                           |
| ------------- | ------ | ------------------------------ | ----------------------------------------------------- |
| Literal block | `\|`   | Preserves every newline        | Shell scripts, SQL, code where line breaks are syntax |
| Folded block  | `>`    | Collapses newlines into spaces | Long descriptions, messages, prose                    |

---

### Task 5 – Validate Your YAML

**Installed yamllint:**

```bash
pip install yamllint --break-system-packages
```

**Validated both files:**

```bash
yamllint person.yaml   # No errors
yamllint server.yaml   # No errors
```

**Intentional break — added a tab character:**

```bash
yamllint server.yaml
# server.yaml
#   2:1  error  found character '\t' that cannot start any token  (syntax)
```

**Fixed and re-validated — both files passed.**

---

### Task 6 – Spot the Difference

```yaml
# Block 1 – correct
name: devops
tools:
    - docker
    - kubernetes
```

```yaml
# Block 2 – broken
name: devops
tools:
    - docker
      - kubernetes
```

**What's wrong with Block 2:**  
`kubernetes` is indented under `docker` instead of being a sibling list item. The `- docker` entry is at column 1 (no indent), while `- kubernetes` is at column 3 (indented by 2 spaces). YAML interprets this as `kubernetes` being a nested element inside `docker`, which is invalid. Both list items must be at the same indent level.

**Fixed:**

```yaml
name: devops
tools:
    - docker
    - kubernetes
```

---

## Key Learnings

1. **Spaces only — never tabs.**  
   YAML rejects tab characters at the parser level. `yamllint` catches this immediately with `found character '\t' that cannot start any token`. This is a hard rule, not a style preference.

2. **Two list formats, same result.**  
   Block style (`- item` per line) is used when readability matters or the list is long. Inline/flow style (`[item1, item2]`) works for short lists. Both produce identical parsed output.

3. **`|` preserves newlines, `>` folds them.**  
   `|` (literal block) is the right choice for shell scripts and any content where line breaks carry meaning. `>` (folded block) collapses everything into a single line — useful for long descriptions in CI/CD pipeline configs where formatting doesn't matter.

---

## Tools Used

- `yamllint` — YAML linter and validator
- `cat -A` — to inspect tab vs space characters in files

---

_Part of the #90DaysOfDevOps challenge by TrainWithShubham_  
_#DevOpsKaJosh #TrainWithShubham_
