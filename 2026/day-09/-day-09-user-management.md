# Day 09 – Linux User & Group Management Challenge

## Users & Groups Created

- Users: `tokyo`, `berlin`, `professor`, `nairobi`
- Groups: `developers`, `admins`, `project-team`

## Group Assignments

| User      | Groups                   |
| --------- | ------------------------ |
| tokyo     | developers, project-team |
| berlin    | developers, admins       |
| professor | admins                   |
| nairobi   | project-team             |

## Directories Created

| Directory             | Group Owner  | Permissions     |
| --------------------- | ------------ | --------------- |
| `/opt/dev-project`    | developers   | 775 (rwxrwxr-x) |
| `/opt/team-workspace` | project-team | 775 (rwxrwxr-x) |

---

## Task 1: Create Users

Created three users with home directories using `useradd -m`. The `-m` flag auto-creates the home directory at `/home/username`. Without it, the user is created but no home directory is made.

```bash
sudo useradd -m tokyo
sudo useradd -m berlin
sudo useradd -m professor
```

Set passwords for each user:

```bash
sudo passwd tokyo
sudo passwd berlin
sudo passwd professor
```

**Verified users were created:**

```bash
grep tokyo /etc/passwd
ls /home/
```

`/etc/passwd` stores one line per user with username, UID, GID, home path, and default shell. The `x` in the password field means the actual password is stored securely in `/etc/shadow`.

---

## Task 2: Create Groups

```bash
sudo groupadd developers
sudo groupadd admins
```

**Verified groups exist:**

```bash
grep -E "developers|admins" /etc/group
```

Output:

```
developers:x:1004:
admins:x:1005:
```

`/etc/group` shows group name, password placeholder, GID, and member list. Members appear empty here — they get populated after assigning users in Task 3.

---

## Task 3: Assign Users to Groups

```bash
sudo usermod -aG developers tokyo
sudo usermod -aG developers,admins berlin
sudo usermod -aG admins professor
```

The `-aG` flags are important:

- `-a` = append (don't remove existing group memberships)
- `-G` = specify the group(s) to add

For `berlin` who belongs to two groups, both can be comma-separated in one command.

> **Important:** Never use `-G` without `-a`. Without the append flag, it replaces all existing group memberships instead of adding to them — easy mistake, hard to debug.

**Verified group membership — two methods:**

Method 1: Check from the user's perspective

```bash
groups tokyo && groups berlin && groups professor
```

Output:

```
tokyo : tokyo developers
berlin : berlin developers admins
professor : professor admins
```

Method 2: Check from the group file directly

```bash
grep -E "developers|admins" /etc/group
```

**Observation:** Both methods verify group membership but from different angles. `groups username` shows all groups a user belongs to. `grep` on `/etc/group` shows which users are listed under each group — useful when you want to audit a group rather than a user.

---

## Task 4: Shared Directory — /opt/dev-project

```bash
sudo mkdir /opt/dev-project
sudo chgrp developers /opt/dev-project
sudo chmod 775 /opt/dev-project
```

**Verified permissions:**

```bash
ls -ld /opt/dev-project
```

Output:

```
drwxrwxr-x 2 root developers 4096 ... /opt/dev-project
```

Permission `775` breakdown:

- Owner (root): rwx — read, write, execute
- Group (developers): rwx — read, write, execute
- Others: r-x — read and execute only

**Tested file creation as tokyo and berlin:**

```bash
sudo -u tokyo touch /opt/dev-project/tokyo-file.txt
sudo -u berlin touch /opt/dev-project/berlin-file.txt
ls -l /opt/dev-project/
```

Both files created successfully — confirming group permissions work correctly. `sudo -u username command` runs a command as another user without switching accounts, useful for testing access.

---

## Task 5: Team Workspace — Full Setup

This task combined everything from Tasks 1–4 in one flow.

**Create user and group:**

```bash
sudo useradd -m nairobi
sudo passwd nairobi
sudo groupadd project-team
```

**Assign users to group:**

```bash
sudo usermod -aG project-team nairobi
sudo usermod -aG project-team tokyo
```

**Create and configure directory:**

```bash
sudo mkdir /opt/team-workspace
sudo chgrp project-team /opt/team-workspace
sudo chmod 775 /opt/team-workspace
```

**Test file creation as nairobi:**

```bash
sudo -u nairobi touch /opt/team-workspace/nairobi-test.txt
ls -l /opt/team-workspace/
```

Output:

```
-rw-r--r-- 1 nairobi nairobi 0 ... nairobi-test.txt
```

File created successfully — group permissions working as expected.

---

## Commands Reference

| Command                       | Purpose                           |
| ----------------------------- | --------------------------------- |
| `useradd -m username`         | Create user with home directory   |
| `passwd username`             | Set password for a user           |
| `groupadd groupname`          | Create a new group                |
| `usermod -aG group user`      | Add user to group (append, safe)  |
| `groups username`             | Show all groups a user belongs to |
| `grep username /etc/passwd`   | Verify user exists                |
| `grep -E "g1\|g2" /etc/group` | Verify groups and their members   |
| `chgrp groupname /path`       | Change group owner of a directory |
| `chmod 775 /path`             | Set rwxrwxr-x permissions         |
| `ls -ld /path`                | Check directory permissions       |
| `sudo -u username command`    | Run command as another user       |

---

## Key Learnings

- `useradd` is preferred over `adduser` in DevOps because it works on every Linux distro and is safe for scripting — `adduser` is interactive and may not exist on non-Debian systems like RHEL or Alpine.
- Always use `usermod -aG` (not `-G` alone) when adding a user to a group. Missing the `-a` flag silently removes all existing group memberships — a dangerous mistake in production.
- Group membership can be verified two ways: `groups username` checks from the user's side, while `grep` on `/etc/group` checks from the group's side. Both are useful depending on whether you're auditing a user or a group.
- Shared directories with group ownership and `775` permissions are how teams collaborate on a Linux server — the same pattern is used for application deployments, CI/CD shared workspaces, and log directories.
- `sudo -u username command` is the clean way to test access as another user without logging out or switching accounts.

---

_Day 09 of #90DaysOfDevOps — TrainWithShubham_
