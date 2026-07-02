# Day 41 – Triggers & Matrix Builds

## Task 1: Trigger on Pull Request

**Workflow file:** `.github/workflows/pr-check.yml`

```yaml
name: PR Check

on:
  pull_request:
    branches: [main]
    types: [opened, synchronize]

jobs:
  pr-check:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Print branch info
        run: 'echo "PR check running for branch: ${{ github.head_ref }}"'
```

**Note:** Hit a YAML syntax error on the `run:` line initially — wrapping the
full string in quotes fixed it. Good reminder of how strict YAML is with
`${{ }}` expressions inside unquoted strings.

**Steps performed:**

- Created branch `feature/pr-trigger-test`
- Pushed a commit, opened PR #1 (`feature/pr-trigger-test` → `main`)
- Workflow ran automatically on the PR via `synchronize` trigger

![alt text](<Screenshot From 2026-07-02 20-44-54.png>)

---

## Task 2: Scheduled Trigger

**Workflow file:** `.github/workflows/scheduled.yml`

```yaml
name: Nightly Job

on:
  schedule:
    - cron: "0 0 * * *" # every day at midnight UTC

jobs:
  nightly:
    runs-on: ubuntu-latest
    steps:
      - name: Say hello
        run: echo "Running scheduled nightly job at $(date -u)"
```

**Note:** Scheduled workflows only run from the default branch (`main`). Had
this initially on a feature branch — merged to `main` for the schedule to
actually activate.

**Cron expression — every Monday at 9 AM UTC:**

```
0 9 * * 1
```

---

## Task 3: Manual Trigger

**Workflow file:** `.github/workflows/manual.yml`

```yaml
name: Manual Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

jobs:
  manual-run:
    runs-on: ubuntu-latest
    steps:
      - name: Print input
        run: echo "Deploying to environment: ${{ inputs.environment }}"
```

**Steps performed:**

- Ran manually via Actions tab → Run workflow → selected environment
- Input value printed correctly in logs

**Screenshot:**

![alt text](<Screenshot From 2026-07-02 20-44-20.png>)

---

## Task 4: Matrix Builds

**Workflow file:** `.github/workflows/matrix.yml`

```yaml
name: Matrix Build

on: push

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
        python-version: ["3.10", "3.11", "3.12"]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}

      - name: Print Python version
        run: python --version
```

**Result:** 2 OS × 3 Python versions = **6 parallel jobs**, all visible
running side by side in the Actions tab.

**Screenshot:**

![alt text](<Screenshot From 2026-07-02 20-43-30.png>)

---

## Task 5: Exclude & Fail-Fast

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]
        python-version: ["3.10", "3.11", "3.12"]
        exclude:
          - os: windows-latest
            python-version: "3.10"
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}

      - name: Print Python version
        run: python --version
```

**Result:** total jobs dropped from 6 to **5** after excluding
`windows-latest + python 3.10`.

**`fail-fast: true` (default) vs `false`:**

- `true` — the moment one job fails, all other in-progress/queued jobs in the
  matrix are cancelled immediately. Fast feedback, incomplete picture.
- `false` — every job runs to completion independently, regardless of
  sibling failures. Gives the full compatibility picture across all
  OS/version combinations — useful when debugging exactly which
  combinations are broken.

**Screenshot:**

![alt text](<Screenshot From 2026-07-02 20-43-15.png>)

## ![alt text](<Screenshot From 2026-07-02 20-43-03.png>)

## Key Learnings

- Today was intense — hit a real YAML syntax error and had to debug/resolve
  it before the workflow would run. Solid hands-on lesson in how strict YAML
  indentation and quoting rules are, especially around `${{ }}` expressions.
- `pull_request` workflows must exist on the **base branch** to trigger —
  adding them only on the feature branch does nothing.
- `schedule` triggers only run from the **default branch**.
- Matrix builds are a cartesian product across every dimension defined —
  easy to underestimate how fast job count grows.

---

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`
