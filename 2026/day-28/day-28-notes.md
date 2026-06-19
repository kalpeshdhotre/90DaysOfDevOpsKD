# Day 28 – Revision Day: Everything from Day 1 to Day 27

## Weak Spots Identified

After going through the self-assessment checklist, I identified three areas that need revisiting:

1. **LVM (Logical Volume Management)** – Concepts are still fuzzy; need hands-on practice with `pvcreate`, `vgcreate`, `lvcreate`, and online resize.
2. **Shell Scripting** – Crontab scheduling syntax needs more practice. The concept is clear but I haven't written enough crontab entries from scratch.
3. **Git** – Core concepts are solid; need to practice `git stash` more precisely (it saves *uncommitted* changes, not commits).

---

## Task 2: What I Re-learned

### LVM
LVM adds an abstraction layer between physical disks and the filesystem. Three layers:
- **PV (Physical Volume)** – real disk marked for LVM: `pvcreate /dev/sdb`
- **VG (Volume Group)** – pool of one or more PVs: `vgcreate myvg /dev/sdb`
- **LV (Logical Volume)** – virtual partition carved from VG: `lvcreate -L 10G -n mylv myvg`

Key advantage over regular partitions: you can resize online without unmounting, span across disks, and take snapshots.

### Shell Scripting – Crontab
Crontab format: `minute hour day month weekday command`

To schedule a script every day at 3 AM:
```bash
0 3 * * * /path/to/script.sh >> /var/log/script.log 2>&1
```
- `crontab -e` to edit, `crontab -l` to list, `crontab -r` to remove.

### Git – Stash vs Reset
- `git stash` – saves *uncommitted* working tree changes (staged + unstaged) to a temporary stack. Does NOT operate on commits.
- `git reset --hard` – moves HEAD and discards all changes; rewrites history.
- `git revert` – creates a new commit that undoes a previous one; safe for shared branches.

---

## Task 3: Quick-Fire Answers

| # | Question | My Answer | Result |
|---|----------|-----------|--------|
| 1 | `chmod 755 script.sh` | Owner: rwx, Group: r-x, Others: r-x | ✅ Correct |
| 2 | Process vs service | Process has PID; service is managed by systemd, can start on boot | ✅ Correct |
| 3 | Find process on port 8080 | `ss -tlnp \| grep 8080` | ✅ Correct |
| 4 | `set -euo pipefail` | Exit on error (-e), unset vars (-u), pipeline failures (-o pipefail) | ✅ Correct |
| 5 | `git reset --hard` vs `git revert` | reset rewrites history; revert creates a new undo commit | ✅ Correct |
| 6 | Branching strategy for 5 devs | Feature branches per developer, PR + review, merge to main, deploy | ✅ Correct (GitHub Flow) |
| 7 | `git stash` | Saves uncommitted changes aside; can restore later | ⚠️ Mostly correct – stash saves *uncommitted* changes, not commits |
| 8 | Crontab for 3 AM daily | `0 3 * * * /path/script.sh` – concept clear, syntax needs practice | 🔄 Need to revisit |
| 9 | `git fetch` vs `git pull` | fetch downloads but doesn't merge; pull = fetch + merge | ✅ Correct |
| 10 | LVM vs regular partitions | LVM allows resize, snapshot, span across disks; partitions are fixed | 🔄 Need hands-on practice |

**Score: 8/10 – 2 topics flagged for hands-on revisit (crontab, LVM)**

---

## Task 5: Teach It Back – Git

> *Explaining Git to someone who has never coded*

Git is a version control system — think of it as a save history for your code. Whenever you're writing code, you keep making changes, and sometimes you realize an older version was better. Git lets you save snapshots (called *commits*) at any point, so you can always go back to one that worked.

When you run `git init` in a folder, Git creates a hidden `.git` folder that stores all your history. If you delete that folder, your entire version history is gone — so don't touch it.

GitHub is an online platform that hosts your Git repositories, so your code is backed up in the cloud and others can collaborate. GitLab is a similar alternative. GitHub also has a CLI tool called `gh` that lets you create repos, manage pull requests, and close issues — all from the terminal, which is great for automating workflows.

---

## Task 4: Housekeeping Checklist

- [ ] All day-1 through day-27 submissions committed and pushed
- [ ] `git-commands.md` up to date with Day 22–26 commands
- [ ] Shell scripting cheat sheet complete (Day 21)
- [ ] GitHub profile and repos clean (Day 27)

---

## Key Takeaways from Day 28

- Git fundamentals and branching strategies are solid ✅
- Shell scripting concepts are clear; crontab syntax needs more hands-on writing 🔄
- LVM is the biggest gap — needs dedicated hands-on practice on the RHEL VM 🔄
- Teaching back Git helped clarify the distinction between `git stash` (uncommitted changes) and `git reset` (commit history)

---

*Day 28 of #90DaysOfDevOps | #DevOpsKaJosh | TrainWithShubham*
