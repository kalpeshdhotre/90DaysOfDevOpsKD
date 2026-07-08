# Day 47 – Advanced Triggers: PR Events, Cron Schedules & Event-Driven Pipelines

## Submission Summary

Completed all 6 tasks covering advanced GitHub Actions triggers — PR lifecycle events, PR validation gates, cron scheduling, path/branch filters, `workflow_run` chaining, and `repository_dispatch` external triggers.

---

## Task 1: Pull Request Event Types

`.github/workflows/pr-lifecycle.yml`

```yaml
name: PR Lifecycle Tracker

on:
  pull_request:
    types: [opened, synchronize, reopened, closed]

jobs:
  track-pr-event:
    runs-on: ubuntu-latest
    steps:
      - name: Print event details
        run: |
          echo "Event action: ${{ github.event.action }}"
          echo "PR title: ${{ github.event.pull_request.title }}"
          echo "PR author: ${{ github.event.pull_request.user.login }}"
          echo "Source branch: ${{ github.head_ref }}"
          echo "Target branch: ${{ github.base_ref }}"

      - name: Merge-only step
        if: github.event.pull_request.merged == true
        run: echo "🎉 PR was merged into ${{ github.base_ref }}"
```

Verified across the full PR lifecycle: `opened` → `synchronize` (on push) → `closed` (on merge, with `merged == true`).

![alt text](<Screenshot From 2026-07-08 18-35-47.png>)

![alt text](<Screenshot From 2026-07-08 18-37-49.png>)

![alt text](<Screenshot From 2026-07-08 18-39-41.png>)

## Task 2: PR Validation Workflow

`.github/workflows/pr-checks.yml`

```yaml
name: PR Checks

on:
  pull_request:
    branches: [main]

jobs:
  file-size-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Fail on files > 1MB
        run: |
          big_files=$(find . -type f -size +1M -not -path "./.git/*")
          if [ -n "$big_files" ]; then
            echo "❌ Files exceeding 1MB found:"
            echo "$big_files"
            exit 1
          fi
          echo "✅ All files under 1MB"

  branch-name-check:
    runs-on: ubuntu-latest
    steps:
      - name: Validate branch naming pattern
        run: |
          branch="${{ github.head_ref }}"
          echo "Branch: $branch"
          if [[ "$branch" =~ ^(feature|fix|docs)/ ]]; then
            echo "✅ Branch name follows convention"
          else
            echo "❌ Branch must start with feature/, fix/, or docs/"
            exit 1
          fi

  pr-body-check:
    runs-on: ubuntu-latest
    steps:
      - name: Warn on empty PR description
        run: |
          body='${{ github.event.pull_request.body }}'
          if [ -z "$body" ]; then
            echo "::warning::PR description is empty — consider adding context"
          else
            echo "✅ PR description present"
          fi
```

Verified: PR from a badly named branch (not `feature/*`, `fix/*`, `docs/*`) correctly fails `branch-name-check`.

![alt text](<Screenshot From 2026-07-08 19-57-58.png>)

---

## Task 3: Scheduled Workflows

`.github/workflows/scheduled-tasks.yml`

```yaml
name: Scheduled Tasks

on:
  schedule:
    - cron: '30 2 * * 1'    # Every Monday at 2:30 AM UTC
    - cron: '0 */6 * * *'   # Every 6 hours
  workflow_dispatch:

jobs:
  scheduled-job:
    runs-on: ubuntu-latest
    steps:
      - name: Identify which schedule fired
        run: echo "Triggered by cron: ${{ github.event.schedule }}"

      - name: Health check
        run: |
          status=$(curl -s -o /dev/null -w "%{http_code}" https://api.github.com)
          echo "Health check response code: $status"
          if [ "$status" -ne 200 ]; then
            echo "::warning::Health check did not return 200"
          fi
```

**Cron expressions:**
| Requirement | Expression |
|---|---|
| Every weekday at 9 AM IST (= 3:30 AM UTC) | `30 3 * * 1-5` |
| First day of every month at midnight | `0 0 1 * *` |

**Why scheduled workflows may be delayed/skipped on inactive repos:** GitHub runs them on shared runners with best-effort timing under load, and deprioritizes — or auto-disables after 60 days of repo inactivity — scheduled workflows to avoid wasting compute on abandoned projects.

---

## Task 4: Path & Branch Filters

`.github/workflows/smart-triggers.yml`

```yaml
name: Smart Triggers

on:
  push:
    branches:
      - main
      - "release/*"
    paths:
      - "src/**"
      - "app/**"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Code change detected in src/ or app/ on an allowed branch"
```

Second workflow — skip docs-only changes:

```yaml
name: Skip Docs-Only Changes

on:
  push:
    branches:
      - main
      - "release/*"
    paths-ignore:
      - "*.md"
      - "docs/**"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Non-docs change detected — running full pipeline"
```

Verified: a push touching only `README.md` did not trigger the `paths-ignore` workflow.

**`paths` vs `paths-ignore`:** Use `paths` when the workflow should run only for a narrow, specific set of directories (e.g. `src/`, `app/`). Use `paths-ignore` when the workflow should run for almost everything except a known exclusion list (e.g. docs-only changes).

![alt text](<Screenshot From 2026-07-08 20-10-40.png>)

## ![alt text](<Screenshot From 2026-07-08 20-14-19.png>)

## Task 5: `workflow_run` — Chain Workflows Together

`.github/workflows/tests.yml`

```yaml
name: Run Tests

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Run tests
        run: echo "Running test suite..." && exit 0
```

`.github/workflows/deploy-after-tests.yml`

```yaml
name: Deploy After Tests

on:
  workflow_run:
    workflows: ["Run Tests"]
    types: [completed]

jobs:
  deploy:
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success'
    steps:
      - name: Deploy
        run: echo "✅ Tests passed — deploying now"

  handle-failure:
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'failure'
    steps:
      - name: Warn and exit
        run: |
          echo "::warning::Upstream tests failed — skipping deploy"
          exit 0
```

Verified: pushing a commit triggered `Run Tests` first, then `Deploy After Tests` fired automatically once the first workflow completed, gated correctly on `conclusion`.

![alt text](<Screenshot From 2026-07-08 20-17-31.png>)

---

## Task 6: `repository_dispatch` — External Event Triggers

`.github/workflows/external-trigger.yml`

```yaml
name: External Trigger

on:
  repository_dispatch:
    types: [deploy-request]

jobs:
  handle-dispatch:
    runs-on: ubuntu-latest
    steps:
      - name: Print payload
        run: echo "Deploy environment requested: ${{ github.event.client_payload.environment }}"
```

Triggered via:

```bash
gh api repos/kalpeshdhotre/github-action-practice-90days-challenge/dispatches \
  -f event_type=deploy-request \
  -f client_payload[environment]=production
```

![alt text](<Screenshot From 2026-07-08 20-17-31-1.png>)

(Note: `-f` sends string values by default in `gh api`; nested JSON needs bracket notation `client_payload[key]=value`, or raw JSON piped via `--input -`.)

**When would an external system trigger a pipeline?** A monitoring tool detecting an incident and kicking off a rollback, a Slack `/deploy` command dispatching to a specific environment, or a ticketing/CMS system triggering a release once a change is approved — any automation living outside GitHub that needs to kick off a pipeline on demand.

---

## `workflow_run` vs `workflow_call` — In My Own Words

- **`workflow_run`** = event-driven, loosely coupled. Workflow B listens for Workflow A to finish and reacts to its outcome via the event context. Good for "deploy only if tests passed."
- **`workflow_call`** = direct invocation, like calling a function. One workflow explicitly calls another as a reusable workflow, passes inputs, and can receive outputs back. Good for DRY-ing up shared logic across pipelines.

---

## Key Learnings

- `github.head_ref` is only populated for `pull_request` events, not `push`.
- `paths`/`paths-ignore` filtering happens before the run starts — a skipped run doesn't even appear in the Actions tab.
- Scheduled workflows only fire from the default branch, regardless of which branch holds the workflow file.
- `repository_dispatch` requires a PAT with `repo` scope — the default `GITHUB_TOKEN` can't trigger it.
- `gh api -f` stringifies values by default; nested JSON payloads need bracket notation or `--input`.

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`
