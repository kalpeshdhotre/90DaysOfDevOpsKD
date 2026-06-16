# Day 25 – Git Reset vs Revert & Branching Strategies

**Challenge:** 90 Days of DevOps  
**Day:** 25 of 90  
**Topic:** Undoing mistakes safely + branching strategies used by real engineering teams

---

## Task 1 – Git Reset (hands-on)

### Setup

```bash
mkdir reset-practice && cd reset-practice
git init

echo "line A" >> file.txt && git add . && git commit -m "commit A"
echo "line B" >> file.txt && git add . && git commit -m "commit B"
echo "line C" >> file.txt && git add . && git commit -m "commit C"

git log --oneline
# c3 commit C
# b2 commit B
# a1 commit A
```

---

### `--soft` reset

```bash
git reset --soft HEAD~1
git log --oneline   # commit C is gone
git status          # Changes to be committed (staged, green)
cat file.txt        # line C is still there
```

**Observation:** The commit disappears from history but the changes from commit C remain staged and ready to re-commit. It's as if you just haven't hit commit yet.

---

### `--mixed` reset (default)

```bash
git commit -m "commit C again"
git reset --mixed HEAD~1
git log --oneline   # commit C is gone
git status          # Changes not staged for commit (unstaged, red)
cat file.txt        # line C is still there
```

**Observation:** The commit disappears and the changes are unstaged — they're in the working directory but not in the staging area. You need to `git add` again before committing.

---

### `--hard` reset

```bash
git add . && git commit -m "commit C again"
git reset --hard HEAD~1
git log --oneline   # commit C is gone
git status          # nothing to commit, working tree clean
cat file.txt        # line C is GONE from the file
```

**Observation:** Everything is erased — the commit, the staged state, and the actual file changes. This is the only mode that touches your working directory.

---

### Safety net: `git reflog`

```bash
git reflog
# HEAD@{0}: reset: moving to HEAD~1
# HEAD@{1}: commit: commit C again
# HEAD@{2}: ...

git reset --hard HEAD@{1}   # recover the lost commit
```

`git reflog` tracks every movement of HEAD, even after a hard reset. It's the escape hatch when you think you've lost work.

---

### Answers to reflection questions

**What is the difference between `--soft`, `--mixed`, and `--hard`?**

| Flag | Commit history | Staging area | Working directory |
|---|---|---|---|
| `--soft` | Rewound | Kept staged | Unchanged |
| `--mixed` | Rewound | Cleared | Unchanged |
| `--hard` | Rewound | Cleared | **Cleared** |

**Which one is destructive and why?**  
`--hard` is destructive because it erases changes from the working directory with no automatic recovery. The other two modes preserve your actual file changes.

**When would you use each one?**
- `--soft` — you want to reword a commit message or combine multiple commits into one; changes are already staged for you
- `--mixed` — you want to unstage changes and re-think what goes into the next commit
- `--hard` — you want to completely abandon a line of work and start clean

**Should you ever use `git reset` on commits that are already pushed?**  
No. Reset rewrites history. If teammates have already pulled those commits, their local history diverges from yours and they'll hit conflicts on the next pull. Use `git revert` instead — it adds a new commit rather than rewriting history.

---

## Task 2 – Git Revert (hands-on)

### Setup

```bash
mkdir revert-practice && cd revert-practice
git init

echo "commit X content" >> story.txt && git add . && git commit -m "commit X"
echo "commit Y — the bad one" >> story.txt && git add . && git commit -m "commit Y"
echo "commit Z content" >> story.txt && git add . && git commit -m "commit Z"

git log --oneline
# z3 commit Z
# y2 commit Y
# x1 commit X
```

---

### Reverting a middle commit

```bash
git revert <hash-of-Y>
```

---

### Real-world observation: revert conflicts

> This is what actually happened during the exercise — the guide's expected "clean revert" didn't play out, and understanding why is the more valuable lesson.

When reverting commit Y, a **conflict occurred**. Git flagged `story.txt` because commit Z had already built on top of Y's line. Git couldn't cleanly remove line 2 without potentially disrupting line 3 that followed it.

**What the file looked like mid-conflict:**

```
commit X content
<<<<<<< HEAD
commit Y — the bad one
commit Z content
=======
>>>>>>> parent of <hash> (commit Y)
```

**Resolution steps taken:**

```bash
# 1. Opened story.txt, removed the conflict markers and the bad line
# 2. Saved the file
git add story.txt
git revert --continue
# Editor opened for revert commit message → saved and closed
```

**Resulting log:**

```
Revert "commit Y"
commit Z
commit Y        ← still here, not deleted
commit X
```

---

### Why the conflict happened

Because all three commits appended to the **same file sequentially**, each commit depended on the previous line being present. Reverting a middle commit in that setup almost always conflicts. In real repos this is normal and expected.

| Scenario | What happens |
|---|---|
| Reverting the most recent commit | Usually clean — nothing has built on top yet |
| Reverting an older middle commit | Often conflicts — later commits may depend on that change |
| Reverting a commit on a separate file | Usually clean — no dependency chain |

---

### Revert conflict flow (reference)

```bash
git revert <hash>          # conflict occurs — Git pauses
# open file, resolve markers, keep what should remain
git add <resolved-file>
git revert --continue      # finishes creating the revert commit
# OR to abort entirely:
git revert --abort
```

---

### Answers to reflection questions

**How is `git revert` different from `git reset`?**  
Reset moves HEAD backward and optionally discards changes — it rewrites history. Revert creates a new commit that applies the inverse of a past commit — history stays intact.

**Why is revert considered safer than reset for shared branches?**  
Everyone on the team has already pulled the commits you want to undo. Adding a new "undo" commit on top means everyone can `git pull` cleanly. Force-pushing a reset would cause their local history to diverge.

**When would you use revert vs reset?**
- Use **reset** when the commit is only local and you haven't pushed yet
- Use **revert** when the commit is already on a shared/remote branch

---

## Task 3 – Reset vs Revert comparison

| | `git reset` | `git revert` |
|---|---|---|
| What it does | Moves HEAD backward, optionally discarding changes | Creates a new commit that undoes a previous one |
| Removes commit from history? | Yes — rewrites history | No — history stays intact |
| Safe for shared/pushed branches? | No — causes divergence for others | Yes — everyone can pull cleanly |
| When to use | Local cleanup before pushing | Undoing a commit already pushed or shared |

---

## Task 4 – Branching Strategies

### 1. GitFlow

**How it works:**  
Uses multiple long-lived branches with defined roles: `main` (production), `develop` (integration), `feature/*` (new work), `release/*` (prep for release), `hotfix/*` (emergency production fixes).

**Text diagram:**

```
main   ──────────────────────────────────────►
               ↑                    ↑
           hotfix/1           release/1.1
               ↑                    ↑
develop ──────────────────────────────────────►
                    ↑         ↑
               feature/A  feature/B
```

**When/where it's used:**  
Teams with scheduled, versioned releases — mobile apps, packaged software, anything where v1.0 / v1.1 / v2.0 matters and QA needs a stable branch to test against while development continues.

**Pros:**
- Clear separation between development and stable production code
- Hotfixes can ship independently of in-progress features
- Structured process that scales across large teams

**Cons:**
- High ceremony — lots of branches to maintain and merge
- Long-lived branches increase merge conflicts over time
- Slower to ship; not suited for continuous delivery

---

### 2. GitHub Flow

**How it works:**  
Just two types of branches: `main` (always deployable) and short-lived `feature/*` branches. You branch off main, open a PR, get it reviewed, merge it back, deploy immediately.

**Text diagram:**

```
main ──────────────────────────────────────►
          ↑               ↑
     feature/x       feature/y
     (PR → merge)    (PR → merge)
```

**When/where it's used:**  
Teams shipping continuously — SaaS products, web apps, startups. Most popular open source repos on GitHub use this (React, for example).

**Pros:**
- Simple and low friction
- Main is always in a deployable state
- Easy for new contributors to understand

**Cons:**
- No built-in release staging
- Relies on good CI/CD and test coverage to keep main stable
- Less structure for teams managing multiple release versions

---

### 3. Trunk-Based Development

**How it works:**  
Everyone commits directly to `main` (the "trunk"), or uses very short-lived branches (hours to 1–2 days). Incomplete features are hidden behind feature flags rather than kept on a separate branch.

**Text diagram:**

```
main ──────────────────────────────────────►
       ↑  ↑   ↑   ↑   ↑   ↑
    short branches (hours to 1-2 days max)
```

**When/where it's used:**  
High-velocity engineering teams with strong CI/CD, automated testing, and feature flag infrastructure. Used at Google and Meta at scale.

**Pros:**
- Fastest possible integration — no long-lived branch drift
- Encourages small, frequent commits and fast feedback loops
- Reduces merge conflict pain significantly

**Cons:**
- Requires mature CI/CD and test coverage — risky without it
- Feature flags add operational complexity
- Harder to adopt for teams without existing tooling

---

### Reflection answers

**Which strategy for a startup shipping fast?**  
GitHub Flow or Trunk-Based Development. Low ceremony, fast iteration, no release branch overhead. The goal is getting code to users quickly.

**Which strategy for a large team with scheduled releases?**  
GitFlow. The `release` branch gives QA a stable surface to test while `develop` continues accepting new work. Hotfixes can be shipped independently without pulling in unfinished features.

**Which does React use?** (checked on GitHub)  
React uses a simplified GitHub Flow — `main` as the stable branch, feature branches opened as PRs. No long-lived `develop` branch.

---

## Task 5 – git-commands.md additions (Days 22–25)

```bash
# ── Setup & Config ──────────────────────────────────────────
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --list

# ── Basic Workflow ───────────────────────────────────────────
git init
git status
git add <file>
git add .
git commit -m "message"
git log --oneline
git diff
git diff --staged

# ── Branching ────────────────────────────────────────────────
git branch
git branch <name>
git switch <name>
git switch -c <name>          # create and switch
git checkout <name>           # older syntax
git branch -d <name>          # delete merged branch
git branch -D <name>          # force delete

# ── Remote ───────────────────────────────────────────────────
git remote add origin <url>
git push origin <branch>
git push -u origin <branch>   # set upstream
git pull
git fetch
git clone <url>

# ── Merging & Rebasing ───────────────────────────────────────
git merge <branch>
git rebase <branch>
git rebase -i HEAD~3          # interactive rebase (squash, reword)

# ── Stash & Cherry Pick ──────────────────────────────────────
git stash
git stash pop
git stash list
git cherry-pick <hash>

# ── Reset & Revert ───────────────────────────────────────────
git reset --soft HEAD~1       # undo commit, keep changes staged
git reset --mixed HEAD~1      # undo commit, unstage changes (default)
git reset --hard HEAD~1       # undo commit + discard all changes
git reflog                    # show all HEAD movements — your safety net
git revert <hash>             # create new commit that undoes <hash>
git revert HEAD               # revert the most recent commit
git revert --continue         # finish revert after resolving conflict
git revert --abort            # cancel revert mid-conflict
```

---

## Key takeaways

- **Reset rewrites history. Revert adds to it.** That single distinction explains every rule about when to use each one.
- `git reflog` is the safety net after any reset — Git remembers everything.
- Revert conflicts are normal and expected when reverting middle commits on a shared file — resolving them is part of the workflow, not a sign something went wrong.
- Branching strategy choice comes down to release cadence and team size: continuous shipping → GitHub Flow / Trunk-Based; versioned releases → GitFlow.
