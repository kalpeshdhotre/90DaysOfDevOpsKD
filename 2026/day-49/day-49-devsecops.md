# Day 49 – DevSecOps: Adding Security to My CI/CD Pipeline

## What is DevSecOps?

DevSecOps means security checks run automatically inside the pipeline itself, not as a separate review that happens after the fact. Instead of a security team finding a vulnerability weeks after deployment, the pipeline catches it in minutes — before a bad image ever reaches Docker Hub, and before a vulnerable dependency ever gets merged.

---

## Task 1: Trivy Docker Image Scan

Added a Trivy vulnerability scan inside `reusable-docker.yml`, restructured so build and push are no longer a single atomic step:

```
Build image locally (push: false, load: true)
  → Trivy scan (exit-code 1 on CRITICAL/HIGH)
  → Push image (only runs if scan passes)
```

This protects **both** `docker-latest` and `docker-sha` jobs in `main-pipeline.yml`, since they both call this reusable workflow.

### Real vulnerability caught

Trivy flagged a genuine CVE on the first run:

| Library | CVE            | Severity | Installed | Fixed  |
| ------- | -------------- | -------- | --------- | ------ |
| undici  | CVE-2026-12151 | HIGH     | 6.26.0    | 6.27.0 |

Denial of Service via unbounded memory growth over WebSocket. `undici` was a transitive dependency, not something I imported directly.

**Fix applied:**

1. `npm install undici@6.27.0` + regenerated `package-lock.json`
2. Restructured Dockerfile into a multi-stage build (`deps` stage does `npm ci --omit=dev`, `runtime` stage copies `node_modules` from `deps`) so dependency layers invalidate correctly whenever the lockfile changes
3. Verified fix locally before trusting the pipeline: `docker run --rm test-image cat node_modules/undici/package.json`

**Debugging note:** the fix worked locally on the first try but the pipeline kept failing. Turned out to be a stale/queued Actions run — I was reading logs from a run that had started _before_ my fix was pushed. Lesson: always confirm the commit SHA on the Actions run matches `git log -1` before debugging further.

Base image: `node:26.5.0-alpine`

Screenshot: `./screenshots/trivy-scan-pass.png`

---

## Task 2: GitHub Secret Scanning + Push Protection

Enabled under Settings → Code security and analysis.

- **Secret scanning** detects secrets _after_ they've been pushed and committed to history — retroactive.
- **Push protection** blocks the `git push` itself before the secret ever enters the repo's history — preventive.
- If GitHub detects a leaked AWS key: it flags it, and for supported providers (AWS included) can notify the provider directly, who may auto-revoke or quarantine the credential.

![alt text](<Screenshot From 2026-07-10 20-08-10.png>)

---

## Task 3: Dependency Review on PRs

Added a `dependency-review` job to `pr-pipeline.yml`, running independently alongside `build-test`:

```yaml
dependency-review:
  runs-on: ubuntu-latest
  steps:
    - name: Checkout code
      uses: actions/checkout@v6

    - name: Check Dependencies for Vulnerabilities
      uses: actions/dependency-review-action@v5
      with:
        fail-on-severity: critical
```

**Tested by:**

1. Created a `test-dependency-review` branch
2. Added a new package (`lodash`) to `package.json`
3. Opened a PR into `main`
4. Confirmed `dependency-review` shows up as a check on the PR, alongside `build-test`

Scan result: 0 vulnerable packages, but flagged 2 packages with OpenSSF Scorecard issues (informational — didn't fail the check since only `critical` severity blocks the PR).

![alt text](<Screenshot From 2026-07-10 20-21-29.png>)

---

## Task 4: Least-Privilege Permissions

Added `permissions: contents: read` to workflow files, restricting default token scope from broad access down to read-only unless a job explicitly needs more.

**Why it matters:** by default, a workflow's `GITHUB_TOKEN` gets broad permissions. If a third-party action in the chain (`uses: someones/action@v1`) is ever compromised — a supply-chain attack via a hijacked tag or npm-style dependency confusion — that compromised action inherits whatever permissions the workflow granted it. With `contents: read`, the blast radius of a compromised action is capped at reading the repo, not writing to it, deleting branches, or modifying repo settings.

---

## Task 5: Secure Pipeline Diagram

```
PR opened
  → build & test
  → dependency vulnerability check     ← NEW (Day 49)
  → PR checks pass or fail

Merge to main
  → build & test
  → Docker build (local, not pushed)
  → Trivy image scan (fail on CRITICAL/HIGH)  ← NEW (Day 49)
  → Docker push (only if scan passes)   ← reordered so scan gates the push
  → deploy

Always active
  → GitHub secret scanning              ← NEW (Day 49)
  → push protection for secrets         ← NEW (Day 49)
  → permissions: contents: read on workflows ← NEW (Day 49)
```

---

## Key Takeaway

The most valuable part of today wasn't adding the Trivy step itself — it was the debugging loop afterward. A scanner is only as good as the pipeline's ability to actually gate on its result. Getting the build order right (scan _before_ push, not after) is what turns "we have a scanner" into "we have a gate."
