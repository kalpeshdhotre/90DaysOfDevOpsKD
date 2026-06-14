# Day 23 – Git Branching & Working with GitHub

## Task 1: Understanding Branches

**1. What is a branch in Git?**

A branch is a lightweight, movable pointer to a specific commit. When you create a branch, Git doesn't copy any files — it just creates a new pointer. This makes branching extremely fast and cheap. Each branch represents an independent line of development.

**2. Why do we use branches instead of committing everything to `main`?**

Branches provide isolation. If you're building a new feature and it breaks something, the `main` branch remains untouched and stable. Multiple team members can work in parallel on different branches without stepping on each other's changes. When a feature is ready and tested, it gets merged back into `main`.

**3. What is `HEAD` in Git?**

`HEAD` is a special pointer that tells Git which branch (or commit) you are currently working on. It moves automatically every time you make a commit or switch branches. Think of it as "you are here" on the Git timeline.

**4. What happens to your files when you switch branches?**

Git swaps the files in your working directory to match the snapshot of the branch you're switching to. Files that exist on the new branch appear; files that only exist on the previous branch disappear. If you have uncommitted changes, Git may warn you or block the switch to prevent losing work.

---

## Task 2: Branching Commands

### Commands practised

```bash
# List all branches
git branch

# Create a new branch
git branch feature-1

# Switch to a branch (legacy)
git checkout feature-1

# Switch to a branch (modern)
git switch feature-1

# Create and switch in one command (legacy)
git checkout -b feature-2

# Create and switch in one command (modern)
git switch -c feature-2

# Make a commit on feature-1
git switch feature-1
echo "feature work" >> feature-notes.txt
git add feature-notes.txt
git commit -m "add feature-1 work"

# Switch back to main and verify the commit is absent
git switch main
git log --oneline

# Delete a branch (safe — only if merged)
git branch -d feature-2

# Force delete an unmerged branch
git branch -D feature-2
```

### `git switch` vs `git checkout`

| | `git checkout` | `git switch` |
|---|---|---|
| Age | Older | Newer (Git 2.23+) |
| Purpose | Branches + files | Branches only |
| Clarity | Does too many things | Single clear purpose |
| Recommendation | Legacy scripts | Prefer for new work |

### Key observation

After committing on `feature-1` and switching back to `main`, running `ls` shows that `feature-notes.txt` is gone. Running `git log --oneline` confirms the feature-1 commit is not in main's history. Switching to `feature-1` again brings the file back. This is branching in action.

---

## Task 3: Push to GitHub

### Commands practised

```bash
# Connect local repo to GitHub remote
git remote add origin https://github.com/YOUR_USERNAME/devops-git-practice.git

# Verify the remote was added
git remote -v

# Push main branch (-u sets upstream tracking)
git push -u origin main

# Push feature-1 branch
git push -u origin feature-1
```

### What is the difference between `origin` and `upstream`?

**`origin`** is the default name Git gives to the remote you cloned from or manually added. Typically this is your own fork or your own repo on GitHub. This is where you push your changes.

**`upstream`** is a convention for the original repository that your fork was created from. You pull from upstream to stay in sync with the source of truth, and push to origin with your own changes.

```
Original repo (upstream) ──fork──► Your GitHub fork (origin) ──clone──► Local machine
        ▲                                                                      │
        └──────────────────── pull from upstream ◄────────────────────────────┘
```

---

## Task 4: Pull from GitHub

### Commands practised

```bash
# Safe two-step approach
git fetch origin                    # download changes, don't touch local files
git log origin/main --oneline       # inspect what came down
git merge origin/main               # apply downloaded changes to local branch

# Or in one step
git pull origin main
```

### What does `git merge origin/main` do?

`git fetch origin` downloads the latest commits from GitHub but stores them in a temporary holding area called `origin/main`. Your local `main` branch is completely untouched at this point.

`git merge origin/main` takes those downloaded commits from the holding area and merges them into your current local branch. Together, fetch + merge = what `git pull` does automatically.

### What is the difference between `git fetch` and `git pull`?

| | `git fetch` | `git pull` |
|---|---|---|
| Downloads remote changes | ✅ Yes | ✅ Yes |
| Updates local branch | ❌ No | ✅ Yes (merge) |
| Safe to run anytime | ✅ Yes | ⚠ Can create merge commits |
| Good for | Reviewing before merging | Quick sync when you trust the remote |

**Best practice:** Use `git fetch` + inspect + `git merge` when collaborating. Use `git pull` when you're confident there are no conflicts.

---

## Task 5: Clone vs Fork

### Commands practised

```bash
# Clone the original repo
git clone https://github.com/ORIGINAL_OWNER/devboard.git

# After forking on GitHub, clone YOUR fork into a separate folder
git clone https://github.com/YOUR_USERNAME/devboard.git devboard-fork

# Inside devboard-fork, add upstream to stay in sync
git remote add upstream https://github.com/ORIGINAL_OWNER/devboard.git

# Verify both remotes
git remote -v
# origin    https://github.com/YOUR_USERNAME/devboard.git (fetch)
# origin    https://github.com/YOUR_USERNAME/devboard.git (push)
# upstream  https://github.com/ORIGINAL_OWNER/devboard.git (fetch)
# upstream  https://github.com/ORIGINAL_OWNER/devboard.git (push)

# Keep fork in sync with original
git fetch upstream
git merge upstream/main
git push origin main
```

### What is the difference between clone and fork?

**Clone** is a Git command. It copies a repository (from any remote URL) to your local machine. You can clone any repo — your own, someone else's, or a fork.

**Fork** is a GitHub concept (not a Git command). It creates your own copy of someone else's repository on GitHub. You now own that copy and can push to it freely without needing permission from the original author.

### When would you clone vs fork?

**Clone when:**
- You own the repo (or are a collaborator with push access)
- You just want to use or read the code without contributing back
- Example: cloning a tool or library to run it locally

**Fork when:**
- You want to contribute to someone else's open-source project
- You want your own modifiable copy of a project on GitHub
- Example: contributing to a #90DaysOfDevOps challenge repo

### After forking, how do you keep your fork in sync with the original repo?

Add the original repo as a second remote called `upstream`. Then periodically fetch from upstream and merge into your local branch, and push the result to your own fork (origin).

```bash
git remote add upstream <original-repo-url>
git fetch upstream
git merge upstream/main
git push origin main
```

---

## New Commands Added to `git-commands.md`

| Command | Description |
|---|---|
| `git branch` | List all local branches |
| `git branch <name>` | Create a new branch |
| `git switch <name>` | Switch to a branch |
| `git switch -c <name>` | Create and switch to a branch in one step |
| `git checkout -b <name>` | Create and switch (legacy equivalent) |
| `git branch -d <name>` | Delete a merged branch |
| `git branch -D <name>` | Force delete a branch (unmerged) |
| `git remote add origin <url>` | Connect local repo to a GitHub remote |
| `git remote -v` | List all remotes with their URLs |
| `git push -u origin <branch>` | Push a branch and set upstream tracking |
| `git fetch origin` | Download remote changes without merging |
| `git merge origin/main` | Merge fetched changes into current branch |
| `git pull origin main` | Fetch + merge in one step |
| `git remote add upstream <url>` | Add the original repo as upstream remote |

---

*Day 23 of 90 · #90DaysOfDevOps · #DevOpsKaJosh · #TrainWithShubham*
