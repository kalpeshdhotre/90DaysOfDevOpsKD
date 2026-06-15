# Day 24 – Advanced Git: Merge, Rebase, Stash & Cherry-pick

> **90 Days of DevOps** | Week 4 | Git Deep Dive

---

## Concepts Covered

| Topic | What it does |
|---|---|
| `git merge` | Integrates one branch into another — fast-forward or merge commit |
| `git rebase` | Replays commits on top of another branch tip, rewriting history |
| `git merge --squash` | Collapses all branch commits into one staged change on target |
| `git stash` | Shelves uncommitted changes so you can switch context |
| `git cherry-pick` | Copies a specific commit from any branch onto the current branch |

---

## Task 1 — Git Merge

### Concept

A **fast-forward merge** happens when the target branch (e.g. `main`) has not diverged from the feature branch — Git simply moves the branch pointer forward. No new commit is created.

A **merge commit** is created when both branches have diverged (both have commits the other doesn't). Git creates a new commit with two parents to join the histories.

A **merge conflict** occurs when the same line(s) in the same file have been changed on both branches. Git inserts conflict markers and pauses, requiring manual resolution before the merge can complete.

### Key commands

```bash
# Fast-forward scenario
git checkout -b feature-login
# ... make commits ...
git checkout main
git merge feature-login          # Output: "Fast-forward"

# Merge commit scenario (both branches have new commits)
git checkout -b feature-signup
# ... make commits on feature-signup AND on main ...
git checkout main
git merge feature-signup         # Opens editor for merge commit message

# Intentionally trigger a conflict
# Edit the same line in both branches, then:
git merge feature-signup         # CONFLICT (content): Merge conflict in <file>

# Resolve conflict, then:
git add <file>
git merge --continue

# Visualise history
git log --oneline --graph --all
```

### Sample output — fast-forward vs merge commit

```
# Fast-forward
* abc1234 (HEAD -> main, feature-login) Add login route
* def5678 Initial commit

# Merge commit
*   9f3c112 (HEAD -> main) Merge branch 'feature-signup'
|\
| * 7b2a3c4 (feature-signup) Add signup validation
| * 6a1b2c3 Add signup form
* | 4d5e6f7 Add nav link
|/
* def5678 Initial commit
```

### Answers

**What is a fast-forward merge?**
When the feature branch is a direct linear extension of `main` with no diverging commits, Git just moves the `main` pointer to the tip of the feature branch. History stays perfectly linear.

**When does Git create a merge commit instead?**
When both `main` and the feature branch have independent commits — the histories have diverged. Git needs a new commit with two parents to bring them together.

**What is a merge conflict?**
When the same line(s) in the same file were changed differently on both branches. Git cannot auto-resolve this and inserts `<<<<<<<`, `=======`, `>>>>>>>` markers. You manually edit the file to the desired state, stage it, and complete the merge.

---

## Task 2 — Git Rebase

### Concept

`git rebase` takes your branch's commits, detaches them, and replays them one by one on top of the target branch's latest commit. Each replayed commit gets a **new hash** — rebase rewrites history. The result is a clean linear history with no merge bubbles.

### Key commands

```bash
git checkout -b feature-dashboard
# ... make 2-3 commits ...

git checkout main
# ... add 1 new commit to main ...

git checkout feature-dashboard
git rebase main               # Replays feature-dashboard commits on top of main's new tip

git log --oneline --graph --all
```

### Sample output — rebase vs merge (same scenario)

```
# After MERGE — shows diverge-and-join shape
*   c1d2e3f Merge branch 'feature-dashboard'
|\
| * b2c3d4e Add chart component
| * a1b2c3d Add dashboard layout
* | 9f8e7d6 Add footer to main
|/
* 1a2b3c4 Initial commit

# After REBASE — linear, no merge bubble
* f7e8d9c (HEAD -> feature-dashboard) Add chart component
* e6d7c8b Add dashboard layout
* 9f8e7d6 (main) Add footer to main
* 1a2b3c4 Initial commit
```

### Answers

**What does rebase actually do to your commits?**
It detaches them from their original base and replays them on top of the new base, assigning new commit hashes in the process. The content of the changes stays the same; only the parent pointers (and thus the hashes) change.

**How is the history different from a merge?**
Rebase produces a perfectly linear history — as if the feature branch was always developed on top of the latest main. Merge preserves the true branching structure with a visible merge commit.

**Why should you never rebase commits already pushed and shared?**
Rebase rewrites commit hashes. If teammates have already pulled those commits, their local history will diverge from your rewritten history. Merging becomes messy and force-pushing can overwrite others' work.

**When to use rebase vs merge?**

| Use rebase | Use merge |
|---|---|
| Local feature branches not yet pushed | Merging a long-running feature into main |
| Keeping a clean, readable linear history | Preserving exact context of when a feature was integrated |
| Pulling in latest main changes before opening a PR | Team/public branches — never rewrite shared history |

---

## Task 3 — Squash Merge vs Regular Merge

### Concept

`git merge --squash` takes all commits from a feature branch and stages them as a single combined change on the target branch. You then write one clean commit yourself. The individual branch commits never appear in `main`'s log.

### Key commands

```bash
# Squash merge
git checkout -b feature-profile
# ... 4-5 small commits (typo fix, formatting, etc.) ...
git checkout main
git merge --squash feature-profile    # Stages all changes but does NOT commit
git commit -m "feat: add user profile page"

# Regular merge (for comparison)
git checkout -b feature-settings
# ... a few commits ...
git checkout main
git merge feature-settings            # Creates merge commit preserving all individual commits

git log --oneline
```

### Sample output — squash vs regular

```
# After squash merge — only 1 commit on main
* 3c4d5e6 (HEAD -> main) feat: add user profile page
* ...

# After regular merge — all branch commits visible
*   8f9a0b1 Merge branch 'feature-settings'
|\
| * 7e8f9a0 Fix settings save button
| * 6d7e8f9 Add dark mode toggle
| * 5c6d7e8 Add settings page skeleton
|/
* 3c4d5e6 feat: add user profile page
* ...
```

### Answers

**What does squash merging do?**
Condenses all commits from the feature branch into a single set of staged changes. You write one final commit capturing the whole feature, keeping `main`'s history clean and easy to scan.

**When to use squash vs regular merge?**
Use squash when branch commits are noisy (lots of WIP/fixup commits) and only the final result matters for `main`'s history. Use regular merge when the individual commit story is meaningful for audit or debugging.

**Trade-off of squashing?**
You lose the granular "why each small step was made" story. If a specific change inside the feature ever needs to be identified or reverted, you can't cherry-pick it — it's buried in one big squash commit.

---

## Task 4 — Git Stash

### Concept

`git stash` saves your uncommitted changes (both staged and unstaged) onto a LIFO stack and reverts your working directory to the last commit. You can retrieve the stash later with `pop` or `apply`.

### Key commands

```bash
# Basic stash
git stash push -m "wip: login form styles"

# List all stashes
git stash list
# stash@{0}: On main: wip: login form styles
# stash@{1}: On feature-dashboard: wip: chart colours

# Apply and remove the most recent stash
git stash pop

# Apply a specific stash WITHOUT removing it
git stash apply stash@{1}

# Remove a specific stash
git stash drop stash@{1}

# Clear all stashes
git stash clear
```

### Sample output — stash list

```
stash@{0}: On feature-login: wip: login form styles
stash@{1}: On main: wip: update readme
stash@{2}: On feature-dashboard: wip: chart colours
```

### Answers

**`git stash pop` vs `git stash apply`**

| | `pop` | `apply` |
|---|---|---|
| Applies stash? | Yes | Yes |
| Removes from stash list? | Yes | No |
| Use when | You're done with the stash | You want to apply to multiple branches |

**When to use stash in real-world workflow?**
- Urgent context switch — hotfix needed while mid-feature work
- Pulling latest changes when your working tree is dirty
- Experimenting with a clean slate before deciding to keep or discard changes
- Moving WIP changes to a different branch

---

## Task 5 — Cherry-pick

### Concept

`git cherry-pick <hash>` copies a specific commit from anywhere in Git history and applies its diff onto your current branch as a new commit. Only that one commit's changes are brought over — nothing else from the source branch.

### Key commands

```bash
# Find the commit hash you want
git log --oneline feature-hotfix
# abc1234 Fix null pointer in auth
# def5678 Add email validation        <-- want this one
# ghi9012 Refactor login controller

# Cherry-pick only the second commit onto main
git checkout main
git cherry-pick def5678

# Verify
git log --oneline
# jkl3456 Add email validation        <-- new hash, same change
# ...
```

### Sample output — before and after

```
# feature-hotfix log
abc1234 Fix null pointer in auth
def5678 Add email validation
ghi9012 Refactor login controller

# main log after cherry-picking def5678
jkl3456 (HEAD -> main) Add email validation
mno7890 Previous main commit
```

### Answers

**What does cherry-pick do?**
Applies the diff of a specific commit onto the current branch as a new commit with a new hash. It's a surgical copy of one change — not a branch merge.

**When to use cherry-pick?**
- Backporting a bug fix from `main` to a release/hotfix branch
- Pulling one specific fix from a feature branch before the whole feature is ready
- Recovering a useful commit from an abandoned branch

**What can go wrong?**
- The cherry-picked commit gets a new hash. If you later merge the source branch, Git may see what looks like a duplicate change and create a conflict or double-apply it.
- If the cherry-picked commit depends on other commits not on your current branch, the patch may fail to apply cleanly.
- Overuse of cherry-pick across long-lived branches creates divergence that's hard to untangle.

---

## Command Reference — Day 24

```bash
# Merge
git merge <branch>                      # Merge branch into current
git merge --no-ff <branch>             # Force a merge commit even if fast-forward is possible
git merge --squash <branch>            # Stage all branch changes as one, without committing

# Rebase
git rebase <branch>                    # Replay current branch commits on top of <branch>
git rebase --abort                     # Cancel a rebase in progress
git rebase --continue                  # Continue after resolving a rebase conflict

# Stash
git stash push -m "description"        # Save WIP with a label
git stash list                         # Show all stashes
git stash pop                          # Apply latest stash and remove from list
git stash apply stash@{n}             # Apply specific stash, keep in list
git stash drop stash@{n}              # Remove specific stash from list
git stash clear                        # Remove all stashes

# Cherry-pick
git cherry-pick <hash>                 # Copy a specific commit onto current branch
git cherry-pick <hash1> <hash2>       # Cherry-pick multiple commits
git cherry-pick --abort                # Cancel a cherry-pick in progress

# Visualise history (use this constantly)
git log --oneline --graph --all
```

---

*Day 24 of 90 | #90DaysOfDevOps #DevOpsKaJosh #TrainWithShubham*
