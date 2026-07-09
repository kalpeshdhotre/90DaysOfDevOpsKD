# Day 48 — GitHub Actions Capstone: End-to-End CI/CD Pipeline

> **Note on Action versions:** all versions below (`actions/checkout@v6`,
> `actions/setup-node@v5` with Node 24, `docker/build-push-action@v6`,
> `actions/upload-artifact@v4`, `aquasecurity/trivy-action@0.29.0`) were current
> as of this writing. Before reusing this guide, check each action's release
> page on GitHub — don't trust version numbers from old tutorials.

## 1. Pipeline Architecture

![alt text](<ChatGPT Image Jul 9, 2026, 08_09_46 PM.png>)

## 2. Task 1 — Project Repo

App: minimal Express server with a `/health` endpoint.

**server.js**

```javascript
const express = require("express");
const app = express();
const PORT = process.env.PORT || 3000;

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    service: "github-actions-capstone",
    timestamp: new Date().toISOString(),
  });
});

app.get("/", (req, res) => {
  res.send("GitHub Actions Capstone App — Day 48 of #90DaysOfDevOps");
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = app;
```

**test.sh** (curl-based test — counts per the task hint)

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Starting app for testing..."
node server.js &
APP_PID=$!
sleep 2

echo "Testing /health endpoint..."
RESPONSE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/health)

kill "$APP_PID"

if [[ "$RESPONSE" == "200" ]]; then
  echo "Test passed: health endpoint returned 200"
  exit 0
else
  echo "Test failed: health endpoint returned $RESPONSE"
  exit 1
fi
```

**Dockerfile** (multi-stage, consistent with the Day 29–37 pattern)

```dockerfile
# ---- Stage 1: install dependencies ----
FROM node:24-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# ---- Stage 2: runtime image ----
FROM node:24-alpine AS runtime
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

EXPOSE 3000
ENV NODE_ENV=production

CMD ["node", "server.js"]
```

## 3. Task 2 — Reusable Workflow: Build & Test

`.github/workflows/reusable-build-test.yml`

```yaml
name: Reusable - Build & Test

on:
  workflow_call:
    inputs:
      node_version:
        description: "Node.js version to use"
        required: false
        type: string
        default: "24"
      run_tests:
        description: "Whether to run tests"
        required: false
        type: boolean
        default: true
    outputs:
      test_result:
        description: "Result of the test run: passed or failed"
        value: ${{ jobs.build-test.outputs.test_result }}

jobs:
  build-test:
    runs-on: ubuntu-latest
    outputs:
      test_result: ${{ steps.set-result.outputs.test_result }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Node.js
        uses: actions/setup-node@v5
        with:
          node-version: ${{ inputs.node_version }}
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        id: run-tests
        if: ${{ inputs.run_tests == true }}
        run: npm test

      - name: Set test result output
        id: set-result
        if: always()
        run: |
          if [[ "${{ inputs.run_tests }}" == "true" && "${{ steps.run-tests.outcome }}" == "failure" ]]; then
            echo "test_result=failed" >> "$GITHUB_OUTPUT"
          else
            echo "test_result=passed" >> "$GITHUB_OUTPUT"
          fi
```

**Why an explicit `set-result` step instead of just trusting job success:**
`workflow_call` outputs can only come from step outputs, not job conclusions
directly, so the `test_result` string is built by hand from the test step's
`outcome`, guarded with `if: always()` so it still runs even if the test step fails.

## 4. Task 3 — Reusable Workflow: Docker Build & Push

`.github/workflows/reusable-docker.yml`

```yaml
name: Reusable - Docker Build & Push

on:
  workflow_call:
    inputs:
      image_name:
        description: "Docker image name (without registry/username prefix)"
        required: true
        type: string
      tag:
        description: "Tag to apply to the image"
        required: true
        type: string
    secrets:
      docker_username:
        required: true
      docker_token:
        required: true
    outputs:
      image_url:
        description: "Full path to the pushed image"
        value: ${{ jobs.docker-build.outputs.image_url }}

jobs:
  docker-build:
    runs-on: ubuntu-latest
    outputs:
      image_url: ${{ steps.set-url.outputs.image_url }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.docker_username }}
          password: ${{ secrets.docker_token }}

      - name: Build and push image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ secrets.docker_username }}/${{ inputs.image_name }}:${{ inputs.tag }}

      - name: Set image URL output
        id: set-url
        run: echo "image_url=${{ secrets.docker_username }}/${{ inputs.image_name }}:${{ inputs.tag }}" >> "$GITHUB_OUTPUT"
```

## 5. Task 4 — PR Pipeline (test only, no Docker)

`.github/workflows/pr-pipeline.yml`

```yaml
name: PR Pipeline

on:
  pull_request:
    branches: [main]
    types: [opened, synchronize]

jobs:
  build-test:
    uses: ./.github/workflows/reusable-build-test.yml
    with:
      node_version: "24"
      run_tests: true

  pr-comment:
    needs: build-test
    runs-on: ubuntu-latest
    steps:
      - name: Print PR summary
        run: 'echo "PR checks passed for branch: ${{ github.head_ref }}"'
```

Note the whole `run:` value is wrapped in single quotes because it contains a
colon (`branch:`) — otherwise the YAML parser misreads it. Verified: opening a
PR runs `build-test` → `pr-comment` only, never touches Docker Hub.

## 6. Task 5 — Main Branch Pipeline (test → build → scan → deploy)

`.github/workflows/main-pipeline.yml`

```yaml
name: Main Branch Pipeline

on:
  push:
    branches: [main]

jobs:
  prep:
    runs-on: ubuntu-latest
    outputs:
      short_sha: ${{ steps.sha.outputs.short_sha }}
    steps:
      - name: Compute short SHA
        id: sha
        run: echo "short_sha=$(echo ${{ github.sha }} | cut -c1-7)" >> "$GITHUB_OUTPUT"

  build-test:
    needs: prep
    uses: ./.github/workflows/reusable-build-test.yml
    with:
      node_version: "24"
      run_tests: true

  docker-latest:
    needs: build-test
    uses: ./.github/workflows/reusable-docker.yml
    with:
      image_name: github-actions-capstone
      tag: latest
    secrets:
      docker_username: ${{ secrets.DOCKER_USERNAME }}
      docker_token: ${{ secrets.DOCKER_TOKEN }}

  docker-sha:
    needs: [build-test, prep]
    uses: ./.github/workflows/reusable-docker.yml
    with:
      image_name: github-actions-capstone
      tag: sha-${{ needs.prep.outputs.short_sha }}
    secrets:
      docker_username: ${{ secrets.DOCKER_USERNAME }}
      docker_token: ${{ secrets.DOCKER_TOKEN }}

  # --- Brownie points: DevSecOps scan against the freshly pushed :latest tag ---
  security-scan:
    needs: docker-latest
    runs-on: ubuntu-latest
    steps:
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@0.29.0
        with:
          image-ref: ${{ needs.docker-latest.outputs.image_url }}
          format: "table"
          output: "trivy-report.txt"
          severity: "CRITICAL"
          exit-code: "1"

      - name: Upload Trivy report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: trivy-security-report
          path: trivy-report.txt

  deploy:
    needs: [docker-latest, docker-sha, security-scan]
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy notification
        run: 'echo "Deploying image: ${{ needs.docker-latest.outputs.image_url }} to production"'
```

**Why a separate `prep` job for the short SHA:** `with:` blocks in a
`workflow_call` step can't run shell commands inline, so the short SHA has to
be computed in an ordinary job first (`cut -c1-7` on `github.sha`) and passed
in through `needs.prep.outputs.short_sha`.

**Why `security-scan` sits between the Docker jobs and `deploy`:** it scans
the image that was just pushed to `:latest` and blocks `deploy` if a CRITICAL
CVE is found — `exit-code: '1'` fails the job, which fails `deploy`'s
`needs:` dependency.

Verified: merging a PR to `main` runs test → build/push (both tags) → Trivy
scan → deploy, in that order, with `deploy` waiting on the `production`
environment's manual approval.

## 7. Task 6 — Scheduled Health Check

`.github/workflows/health-check.yml`

```yaml
name: Scheduled Health Check

on:
  schedule:
    - cron: "0 */12 * * *"
  workflow_dispatch:

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - name: Pull latest image
        run: docker pull ${{ secrets.DOCKER_USERNAME }}/github-actions-capstone:latest

      - name: Run container
        run: docker run -d --name capstone-health -p 3000:3000 ${{ secrets.DOCKER_USERNAME }}/github-actions-capstone:latest

      - name: Wait for container to be ready
        run: sleep 5

      - name: Check health endpoint
        id: health
        run: |
          RESPONSE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/health)
          if [[ "$RESPONSE" == "200" ]]; then
            echo "status=PASSED" >> "$GITHUB_OUTPUT"
          else
            echo "status=FAILED" >> "$GITHUB_OUTPUT"
          fi

      - name: Stop and remove container
        if: always()
        run: docker stop capstone-health && docker rm capstone-health

      - name: Write step summary
        if: always()
        run: |
          echo "## Health Check Report" >> $GITHUB_STEP_SUMMARY
          echo "- Image: github-actions-capstone:latest" >> $GITHUB_STEP_SUMMARY
          echo "- Status: ${{ steps.health.outputs.status }}" >> $GITHUB_STEP_SUMMARY
          echo "- Time: $(date)" >> $GITHUB_STEP_SUMMARY
```

![alt text](<Screenshot From 2026-07-09 19-18-24-1.png>)
![alt text](<Screenshot From 2026-07-09 19-18-45-1.png>)
![alt text](<Screenshot From 2026-07-09 19-19-10-1.png>)
![alt text](<Screenshot From 2026-07-09 19-20-00-1.png>)
![alt text](<Screenshot From 2026-07-09 19-22-10-1.png>)
![alt text](<Screenshot From 2026-07-09 19-26-57-1.png>)
![alt text](<Screenshot From 2026-07-09 19-36-41-1.png>)
![alt text](<Screenshot From 2026-07-09 20-01-28-1.png>)

## 8. Task 7 — Badges & Notes

Badges added to `README.md` for all three top-level workflows (PR pipeline,
main pipeline, health check).

**Screenshots** _(paste your own from the Actions tab)_:

- [ ] PR pipeline run — test-only, green check, no Docker job present
- [ ] Main pipeline run — full chain: prep → build-test → docker-latest/docker-sha → security-scan → deploy (with approval gate)

**Docker Hub image:** `docker.io/kalpeshdhotre/github-actions-capstone`

## 9. What I'd add next

- Slack/Discord notification step on `deploy` success or failure
- A staging environment between PR merge and production deploy, with its own
  protection rules
- Rollback job that re-deploys the previous `sha-*` tag if the health check
  fails post-deploy
- Concurrency groups on `main-pipeline.yml` so overlapping pushes to `main`
  don't race each other
- Moving the Trivy severity threshold check into the `reusable-docker.yml`
  workflow itself, so any caller gets scanning for free (this is exactly
  where Day 49 is headed)
