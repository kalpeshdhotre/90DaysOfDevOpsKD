# Day 12 – Breather & Revision (Days 01–11)

## Days 01–11 Quick Recap

| Day | Topic                            | Key Takeaway                                        |
| --- | -------------------------------- | --------------------------------------------------- |
| 01  | DevOps learning plan             | Career blueprint — goals, timeline, consistency     |
| 02  | Linux architecture & systemd     | Kernel, user space, process states, init system     |
| 03  | Linux commands cheat sheet       | Command toolkit for process, filesystem, networking |
| 04  | Processes & services practice    | `ps`, `systemctl status`, `journalctl` hands-on     |
| 05  | Troubleshooting runbook          | CPU, memory, disk, network, logs — repeatable flow  |
| 06  | File read/write                  | `touch`, `>`, `>>`, `tee`, `cat`, `head`, `tail`    |
| 07  | Filesystem hierarchy + scenarios | `/etc`, `/var/log`, log rotation, `journalctl -f`   |
| 08  | Cloud server — Nginx on AWS EC2  | SSH, security groups, scp, log rotation discovery   |
| 09  | User & group management          | `useradd`, `groupadd`, `usermod -aG`, shared dirs   |
| 10  | File permissions                 | `chmod` symbolic and octal, default 644, `mkdir -m` |
| 11  | File ownership                   | `chown user:group`, `chgrp`, `chown -R`             |

---

## Block 1: Notes Skim

Skimmed notes from all 11 days. Core theme across the journey so far:
**Linux fundamentals → file system → permissions → ownership → cloud deployment.**
Each day builds on the previous one — commands from Day 06 were used in Day 08, Day 07 scenarios used Day 04 skills, and Day 09 users were reused all the way through Day 11.

---

## Block 2: Command Reruns

### Processes & Services

```bash
ps aux --sort=-%cpu | head -5
systemctl status nginx
journalctl -u nginx -n 20
```

### File Skills

```bash
echo "revision day 12" >> /tmp/revision.txt && cat /tmp/revision.txt
ls -lh /var/log/nginx/
tail -n 5 /var/log/nginx/access.log.1
```

### Permissions & Ownership

```bash
touch /tmp/test-revision.sh && ls -l /tmp/test-revision.sh
chmod 750 /tmp/test-revision.sh && ls -l /tmp/test-revision.sh
sudo chown tokyo:developers /tmp/test-revision.sh && ls -l /tmp/test-revision.sh
groups tokyo
```

---

## Block 3: Self-Check Answers

**Q1. Which 3 commands save you the most time right now, and why?**

- `grep` — filters output instantly. Instead of reading entire files or long lists, grep narrows it down to exactly what you need. Used constantly for searching logs, config files, and command output.
- `cat` — quickest way to check file content without opening an editor. One command, instant output.
- `systemctl` — single command to check status, start, stop, or restart any service. The first thing to run when anything service-related is suspected.

---

**Q2. How do you check if a service is healthy? List the exact commands you'd run first.**

```bash
systemctl status servicename
```

Shows whether the service is active, failed, or stopped — along with recent log snippets inline. If more detail is needed:

```bash
journalctl -u servicename -n 50
```

Reads the last 50 log lines from journald to find the exact error.

---

**Q3. How do you safely change ownership and permissions without breaking access?**

Always set both owner and group together using `chown user:group`, then set permissions with `chmod`. Use `-R` only when you intentionally want to change the entire directory tree — not by default. Always verify with `ls -l` after every change.

```bash
sudo chown root:developers /opt/dev-project
sudo chmod 775 /opt/dev-project
ls -ld /opt/dev-project
```

Key rules:

- Never use `usermod -G` without `-a` — it replaces all group memberships silently
- Never use `chown -R` without checking what's inside the directory first
- Always use `ls -ld` (with `d`) to check directory ownership — without `d` it lists contents instead

---

**Q4. What will you focus on improving in the next 3 days?**

Practicing and improving muscle memory — being able to run the right command instinctively without looking it up. The goal is to reach a point where troubleshooting flows naturally: status → logs → fix → verify, without hesitation on syntax.

---

## 5 Commands I'd Reach for First in an Incident

From the Day 03 cheat sheet — these are the ones that matter most right now:

1. `systemctl status <service>` — first thing, always
2. `journalctl -u <service> -n 50` — when status isn't enough
3. `grep` — filter any log or output instantly
4. `tail -f` / `journalctl -f` — follow live logs during an active incident
5. `ls -l` / `ls -ld` — verify permissions and ownership before and after any change

---

## Key Insight from 11 Days

The same 4-step flow works for almost every Linux problem:

```
status → logs → fix → verify
```

And ownership + permissions always follow the same pattern:

```
chown user:group path → chmod NNN path → ls -l to verify
```

## ![alt text](<Pasted image.png>)

_Day 12 of #90DaysOfDevOps — TrainWithShubham_
