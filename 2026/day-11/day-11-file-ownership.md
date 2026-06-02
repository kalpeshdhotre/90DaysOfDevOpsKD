# Day 11 – File Ownership Challenge (chown & chgrp)

## Files & Directories Created

| File / Directory                    | Purpose                        |
| ----------------------------------- | ------------------------------ |
| `devops-file.txt`                   | chown practice — owner change  |
| `team-notes.txt`                    | chgrp practice — group change  |
| `project-config.yaml`               | combined chown user:group      |
| `app-logs/`                         | directory ownership change     |
| `heist-project/vault/gold.txt`      | recursive ownership test       |
| `heist-project/plans/strategy.conf` | recursive ownership test       |
| `bank-heist/access-codes.txt`       | challenge — tokyo:vault-team   |
| `bank-heist/blueprints.pdf`         | challenge — berlin:tech-team   |
| `bank-heist/escape-plan.txt`        | challenge — nairobi:vault-team |

## Ownership Changes Summary

| File                           | Before        | After                        |
| ------------------------------ | ------------- | ---------------------------- |
| `devops-file.txt`              | ubuntu:ubuntu | tokyo:ubuntu → berlin:ubuntu |
| `team-notes.txt`               | ubuntu:ubuntu | ubuntu:heist-team            |
| `project-config.yaml`          | ubuntu:ubuntu | professor:heist-team         |
| `app-logs/`                    | ubuntu:ubuntu | berlin:heist-team            |
| `heist-project/` (entire tree) | ubuntu:ubuntu | professor:planners           |
| `bank-heist/access-codes.txt`  | ubuntu:ubuntu | tokyo:vault-team             |
| `bank-heist/blueprints.pdf`    | ubuntu:ubuntu | berlin:tech-team             |
| `bank-heist/escape-plan.txt`   | ubuntu:ubuntu | nairobi:vault-team           |

---

## Task 1: Understanding Ownership

```bash
ls -l ~
```

Output format:

```
-rw-r--r-- 1 ubuntu ubuntu 35 ... notes.txt
              ↑      ↑
           owner   group
```

**Owner vs Group:**

- Owner — the individual user who owns the file. Permissions in the first `rwx` block apply to them.
- Group — a set of users who share access to the file. Permissions in the second `rwx` block apply to all members of that group.

A file has exactly one owner and one group. Multiple users can belong to the same group, giving them shared access without making any of them the individual owner.

## ![alt text](<Screenshot From 2026-06-02 17-21-28.png>)

## Task 2: Basic chown Operations

```bash
touch devops-file.txt
ls -l devops-file.txt
```

```
-rw-r--r-- 1 ubuntu ubuntu ... devops-file.txt
```

**Change owner to tokyo:**

```bash
sudo chown tokyo devops-file.txt
ls -l devops-file.txt
```

```
-rw-r--r-- 1 tokyo ubuntu ... devops-file.txt
```

**Change owner to berlin:**

```bash
sudo chown berlin devops-file.txt
ls -l devops-file.txt
```

```
-rw-r--r-- 1 berlin ubuntu ... devops-file.txt
```

**Observation:** When using `chown username` to change only the owner, the group column stays unchanged — it remained `ubuntu` throughout. `chown` with just a username only touches the owner column, nothing else.

## ![alt text](<Screenshot From 2026-06-02 17-26-08.png>)

## Task 3: Basic chgrp Operations

```bash
touch team-notes.txt
ls -l team-notes.txt
```

```
-rw-r--r-- 1 ubuntu ubuntu ... team-notes.txt
```

**Create group and change file group:**

```bash
sudo groupadd heist-team
sudo chgrp heist-team team-notes.txt
ls -l team-notes.txt
```

```
-rw-r--r-- 1 ubuntu heist-team ... team-notes.txt
```

**Observation:** Only the group column changed — the owner stayed as `ubuntu`. `chgrp` only changes the group, not the owner. Group must exist before assigning — always run `groupadd` first.

## ![alt text](<Screenshot From 2026-06-02 17-30-33.png>)

## Task 4: Combined Owner & Group Change

```bash
touch project-config.yaml
mkdir app-logs
```

**Change owner and group together in one command:**

```bash
sudo chown professor:heist-team project-config.yaml
sudo chown berlin:heist-team app-logs
```

**Verify:**

```bash
ls -l project-config.yaml && ls -ld app-logs
```

```
-rw-r--r-- 1 professor heist-team ... project-config.yaml
drwxr-xr-x 2 berlin    heist-team ... app-logs
```

**Observation:** `chown user:group` sets both owner and group in a single command — cleaner than running `chown` and `chgrp` separately. Note the use of `ls -ld` (with the `d` flag) for directories — without `d`, `ls -l` lists the directory's contents instead of the directory itself.

## ![alt text](<Screenshot From 2026-06-02 17-36-02.png>)

## Task 5: Recursive Ownership

**Create directory structure:**

```bash
mkdir -p heist-project/vault heist-project/plans
touch heist-project/vault/gold.txt
touch heist-project/plans/strategy.conf
```

**Create group and apply recursive ownership:**

```bash
sudo groupadd planners
sudo chown -R professor:planners heist-project/
```

**Verify entire tree:**

```bash
ls -lR heist-project/
```

```
heist-project/:
drwxr-xr-x 2 professor planners ... vault
drwxr-xr-x 2 professor planners ... plans

heist-project/vault/:
-rw-r--r-- 1 professor planners ... gold.txt

heist-project/plans/:
-rw-r--r-- 1 professor planners ... strategy.conf
```

**Observation:** The `-R` flag applied the ownership change to the top-level directory, all subdirectories, and all files inside — all in one command. Without `-R`, only the top-level `heist-project/` directory would change. Every file and folder in the tree showed `professor:planners` after the command.

## ![alt text](<Screenshot From 2026-06-02 17-49-03.png>)

## Task 6: Practice Challenge — bank-heist

**Create groups:**

```bash
sudo groupadd vault-team
sudo groupadd tech-team
```

**Create directory and files:**

```bash
mkdir bank-heist
touch bank-heist/access-codes.txt
touch bank-heist/blueprints.pdf
touch bank-heist/escape-plan.txt
```

**Set different ownership per file:**

```bash
sudo chown tokyo:vault-team bank-heist/access-codes.txt
sudo chown berlin:tech-team bank-heist/blueprints.pdf
sudo chown nairobi:vault-team bank-heist/escape-plan.txt
```

**Verify:**

```bash
ls -l bank-heist/
```

```
-rw-r--r-- 1 tokyo   vault-team ... access-codes.txt
-rw-r--r-- 1 berlin  tech-team  ... blueprints.pdf
-rw-r--r-- 1 nairobi vault-team ... escape-plan.txt
```

## ![alt text](<Screenshot From 2026-06-02 17-55-44.png>)

## Commands Reference

| Command                         | Purpose                                    |
| ------------------------------- | ------------------------------------------ |
| `ls -l filename`                | View owner and group of a file             |
| `ls -ld directory/`             | View owner and group of a directory itself |
| `ls -lR directory/`             | View ownership of entire directory tree    |
| `sudo chown user file`          | Change owner only                          |
| `sudo chgrp group file`         | Change group only                          |
| `sudo chown user:group file`    | Change both owner and group in one command |
| `sudo chown :group file`        | Change group only via chown                |
| `sudo chown -R user:group dir/` | Recursive ownership change                 |
| `sudo groupadd groupname`       | Create a new group                         |

---

## Key Learnings

- `chown username file` changes only the owner — the group column is untouched. To change both in one step, always use `chown user:group file`.
- `chgrp` and `chown :group` both change the group only — `chown user:group` is preferred since it handles both in one command and reduces the chance of stale ownership.
- The `-R` flag on `chown` is essential for directory trees — without it only the top-level directory changes, leaving all files and subdirectories with their original ownership. Always verify with `ls -lR` after a recursive change.
- The group must exist before assigning it to a file. If you run `chown user:nonexistent file`, it fails immediately. Always run `groupadd` first.
- Use `ls -ld` (with the `d` flag) when checking a directory's own ownership — without `d`, `ls -l` lists the directory's contents instead.
- In real DevOps, recursive ownership changes are used constantly — when deploying applications, the entire app directory tree needs to be owned by the service user (e.g. `www-data` for nginx, `deploy` for CI/CD).

---

_Day 11 of #90DaysOfDevOps — TrainWithShubham_
