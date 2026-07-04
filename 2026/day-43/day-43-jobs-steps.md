# Day 43 – Jobs, Steps, Env Vars & Conditionals

## What I built

- `multi-job.yml` — build → test → deploy chain using `needs:`
- `env-vars.yml` — env vars at workflow, job, and step level + GitHub context vars
- `job-outputs.yml` — passing a generated date from one job to another
- `conditionals.yml` — branch-based, failure-based, and event-based conditionals
- `smart-pipeline.yml` — parallel lint + test, followed by a summary job

---

## Task 1: Multi-Job Workflow

```yaml
name: Multi Job Workflow

on: workflow_dispatch

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Build step
        run: echo "Building the app"

  test:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Test step
        run: echo "Running tests"

  deploy:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - name: Deploy step
        run: echo "Deploying"
```

**Screenshot — dependency graph:**

## ![alt text](<Screenshot From 2026-07-04 19-18-56.png>)

## Task 2: Environment Variables

```yaml
name: Env Vars Demo

on: workflow_dispatch

env:
  APP_NAME: myapp

jobs:
  show-env:
    runs-on: ubuntu-latest
    env:
      ENVIRONMENT: staging
    steps:
      - name: Print env vars
        env:
          VERSION: 1.0.0
        run: |
          echo "App: $APP_NAME"
          echo "Environment: $ENVIRONMENT"
          echo "Version: $VERSION"

      - name: Print GitHub context vars
        run: |
          echo "Commit SHA: ${{ github.sha }}"
          echo "Triggered by: ${{ github.actor }}"
```

**Screenshot — run output showing all 3 levels + context vars:**

## ![alt text](<Screenshot From 2026-07-04 19-27-13.png>)

## Task 3: Job Outputs

```yaml
name: Job Outputs Demo

on: workflow_dispatch

jobs:
  generate-date:
    runs-on: ubuntu-latest
    outputs:
      today: ${{ steps.get-date.outputs.date }}
    steps:
      - name: Get date
        id: get-date
        run: echo "date=$(date)" >> "$GITHUB_OUTPUT"

  use-date:
    runs-on: ubuntu-latest
    needs: generate-date
    steps:
      - name: Print received date
        run: 'echo "Date from previous job: ${{ needs.generate-date.outputs.today }}"'
```

**Screenshot — second job printing the date from the first:**

![alt text](<Screenshot From 2026-07-04 19-38-39.png>)

### Why pass outputs between jobs?

Jobs run on separate, isolated runners with no shared filesystem or memory. A value set in one job's `run:` step simply doesn't exist in another job. `outputs:` is the official handoff — set it in a step via `$GITHUB_OUTPUT`, promote it to the job with `outputs:`, and read it downstream with `needs.<job>.outputs.<name>`.

---

## Task 4: Conditionals

```yaml
name: Conditionals Demo

on: workflow_dispatch

jobs:
  push-only-job:
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
      - name: Only runs on push
        run: echo "This job only runs on push events, not PRs"

  main-branch-job:
    runs-on: ubuntu-latest
    steps:
      - name: Runs only on main
        if: github.ref == 'refs/heads/main'
        run: echo "This step only runs on the main branch"

      - name: A step that might fail
        id: risky
        continue-on-error: true
        run: exit 1

      - name: Runs only if previous step failed
        if: steps.risky.outcome == 'failure'
        run: echo "Previous step failed — running cleanup/alert logic"
```

**Screenshot — conditional steps skipped/run as expected:**

![alt text](<Screenshot From 2026-07-04 19-48-36.png>)

### `continue-on-error: true`

Lets a step fail without failing the job or blocking later steps. The failure is still reported for visibility, but the pipeline keeps going — useful for optional or experimental steps.

---

## Task 5: Smart Pipeline

```yaml
name: Smart Pipeline

on:
  workflow_dispatch:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Lint step
        run: echo "Linting code"

  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test step
        run: echo "Running tests"

  summary:
    runs-on: ubuntu-latest
    needs: [lint, test]
    steps:
      - name: Branch summary
        if: github.ref == 'refs/heads/main'
        run: echo "This is a MAIN branch push"

      - name: Feature branch summary
        if: github.ref != 'refs/heads/main'
        run: 'echo "This is a FEATURE branch push (${{ github.ref_name }})"'

      - name: Print commit message
        run: 'echo "Commit message: ${{ github.event.head_commit.message }}"'
```

**Screenshot — lint + test running in parallel, summary running after:**

![alt text](<Screenshot From 2026-07-04 19-54-04.png>)

---

## `needs:`

Makes a job wait for one or more other jobs to finish successfully before it starts. Without it, all jobs run in parallel on separate runners with no guaranteed order.

## Gotchas I hit

- **YAML colon parsing error**: when a `run:` string itself contains a `:` (e.g. `"Commit message: ${{ ... }}"`), YAML misreads it as a new key-value pair and throws a syntax error. Fix: wrap the whole `run:` value in single quotes — `run: 'echo "Commit message: ${{ github.event.head_commit.message }}"'`.

- All workflows set to `workflow_dispatch` per my earlier convention change, to avoid unwanted triggers on push.
