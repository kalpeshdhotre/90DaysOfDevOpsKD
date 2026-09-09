# Day 80 — Helm Project: Multi-Environment Deployment and CI/CD

Reference: [AI-BankApp-DevOps](https://github.com/TrainWithShubham/AI-BankApp-DevOps) (branch: `feat/gitops`)
Chart location in this fork: `helm-chart/bankapp/`

---

## Task 1: Environment-Specific Values

Created `values-dev.yaml`, `values-staging.yaml`, and `values-prod.yaml` inside `helm-chart/bankapp/`, each tuned for its environment.

| Setting          | Dev                                      | Staging    | Prod       |
| ---------------- | ---------------------------------------- | ---------- | ---------- |
| BankApp replicas | 1 (fixed)                                | 2–3 (HPA)  | 2–4 (HPA)  |
| Image tag        | `latest`                                 | `v1.2.0`   | `v1.2.0`   |
| MySQL storage    | 2Gi                                      | 5Gi        | 20Gi       |
| MySQL resources  | 128Mi/100m → **256Mi/500m (dev, tuned)** | 256Mi/250m | 512Mi/500m |
| Ollama memory    | 1Gi                                      | 2Gi        | 2.5Gi      |
| Gateway          | disabled                                 | disabled   | enabled    |

**Verification — dev deployed live, staging/prod rendered via `helm template`:**

```bash
helm install bankapp-dev helm-chart/bankapp/ -f helm-chart/bankapp/values-dev.yaml -n dev --create-namespace
helm template bankapp-staging helm-chart/bankapp/ -f helm-chart/bankapp/values-staging.yaml | grep -i "replica"
helm template bankapp-prod helm-chart/bankapp/ -f helm-chart/bankapp/values-prod.yaml | grep -i "replica"
```

Results:

- Dev → `replicas: 1` (static, no HPA)
- Staging → `minReplicas: 2`, `maxReplicas: 3`
- Prod → `minReplicas: 2`, `maxReplicas: 4`

![alt text](<md-screenshots/Screenshot From 2026-09-09 15-51-48.png>)

![alt text](<md-screenshots/Screenshot From 2026-09-09 17-31-35.png>)

### Issue hit and fixed

MySQL initially crashed with `OOMKilled` (exit 137) on the stock dev limits (128Mi/256Mi). Doubled the memory request/limit to `256Mi`/`512Mi` in `values-dev.yaml`, which resolved it — MySQL's startup footprint needs headroom beyond its steady-state usage.

A second issue followed: after the OOM fix, MySQL came back up but bankapp failed with:

```
Host '10.244.0.5' is not allowed to connect to this MySQL server
```

Root cause: the earlier OOMKilled attempts had already partially initialized the MySQL PVC's datadir with different credentials than the current secret. Since MySQL only runs its init script on a genuinely empty datadir, the stale volume was the real problem — not a config error. Fix: deleted the Deployment and PVC, then let `helm upgrade --install` recreate everything from a clean volume, which triggered a proper fresh init against the current secret and resolved the connection.

---

## Task 2: Helm Hooks

Added `helm-chart/bankapp/templates/pre-install-job.yaml` — a `busybox` Job polling `nc -z <fullname>-mysql 3306` until MySQL accepts connections, and `helm-chart/bankapp/templates/tests/test-connection.yaml` — a `helm.sh/hook: test` Pod hitting the Spring Boot `/actuator/health` endpoint.

**Annotations explained:**

- `helm.sh/hook: pre-install,pre-upgrade` (later changed — see below) — runs the check before install/upgrade proceeds.
- `helm.sh/hook-weight: "0"` — ordering relative to other hooks in the same phase (lower runs first).
- `helm.sh/hook-delete-policy: before-hook-creation` — deletes the previous run's Job right before creating a new one, so repeated `helm upgrade` calls don't collide with a stale completed Job of the same name.

### Issue hit and fixed — hook ordering on fresh installs

On a genuinely **fresh** install into a new namespace, `pre-install` hooks run _before Helm creates any other resource in the release_ — including the MySQL Service itself. The DB-readiness Job looped forever with `nc: bad address 'my-bankapp-mysql'` because that Service didn't exist yet. On `dev`, this had gone unnoticed because MySQL already existed there from a prior release, so the hook (running under `pre-upgrade`) found it immediately.

Fix: changed the hook annotation from `pre-install,pre-upgrade` to `post-install,pre-upgrade`. This lets Helm create all release resources first on a fresh install, then runs the readiness check after — while still correctly gating upgrades before changes roll out.

**Verification:**

```bash
helm upgrade --install bankapp-dev helm-chart/bankapp/ -f helm-chart/bankapp/values-dev.yaml -n dev
kubectl get jobs -n dev
helm test bankapp-dev -n dev
```

Result: `bankapp-dev-db-ready` → `Complete 1/1`; `helm test` → `Phase: Succeeded`.

![alt text](<md-screenshots/Screenshot From 2026-09-09 17-39-32.png>)

---

## Task 3: Package and Version the Chart

```bash
helm lint helm-chart/bankapp/
helm package helm-chart/bankapp/
# -> bankapp-0.1.0.tgz
```

Bumped `Chart.yaml`:

```yaml
version: 0.2.0 # chart structure changed (added hooks)
appVersion: "1.1.0"
```

```bash
helm package helm-chart/bankapp/
# -> bankapp-0.2.0.tgz
helm install my-bankapp bankapp-0.2.0.tgz -f helm-chart/bankapp/values-dev.yaml -n bankapp --create-namespace
kubectl get pods -n bankapp
```

Result: all pods `1/1 Running`, `my-bankapp-db-ready` `Completed` (post-install hook ordering fix from Task 2 confirmed working on a truly fresh namespace this time).

![alt text](<md-screenshots/Screenshot From 2026-09-09 17-44-57.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-09 17-49-44.png>)

---

## Task 4: Helm in the AI-BankApp GitOps Pipeline

**Current pipeline** (`.github/workflows/gitops-ci.yml`):

```
push -> build image -> tag with git SHA -> sed-patch k8s/bankapp-deployment.yml -> commit -> ArgoCD syncs raw manifests
```

**With Helm:**

```
push -> build image -> tag with git SHA -> yq-patch helm-chart/bankapp/values-prod.yaml -> commit -> ArgoCD runs helm upgrade
```

ArgoCD's `Application` source changes from `path: k8s` to `path: helm-chart/bankapp` with a `helm.valueFiles` block pointing at `values-prod.yaml`.

**Advantages of ArgoCD syncing a Helm chart vs raw manifests:**

- One parameterized chart covers dev/staging/prod instead of three sets of duplicated raw YAML — changes to shared logic (e.g. probes, labels) only need to happen once.
- `yq -i` edits the YAML structurally, unlike `sed`'s blind text replacement, which is fragile against formatting changes.
- ArgoCD renders the chart natively and diffs against the _rendered_ output, so drift detection still works correctly — it isn't just comparing raw files.
- Rollback maps to Helm's own release/revision history (`helm rollback`), not only a git revert.
- The hooks built in Task 2 (DB-readiness check, health test) become part of the release lifecycle itself, running automatically on every ArgoCD-triggered sync — raw manifests have no equivalent mechanism.

---

## Task 5: Helm Best Practices for Production

**1. `helm upgrade --install` with safety flags** (adapted for local kind testing — see note below):

```bash
helm upgrade --install bankapp helm-chart/bankapp/ \
  -f helm-chart/bankapp/values-prod.yaml \
  --set mysql.persistence.storageClass=standard \
  --set ollama.persistence.storageClass=standard \
  -n bankapp \
  --wait --timeout 300s \
  --rollback-on-failure
```

_(Note: `--atomic` is deprecated in the current Helm version in use, in favor of `--rollback-on-failure` — same behavior, auto-rollback on a failed upgrade.)_

### Issue hit and fixed — storageClass mismatch

`values-prod.yaml`'s `storageClass: gp3` is an AWS EBS class that doesn't exist on a local kind cluster (`kubectl get storageclass` only shows `standard`). The first attempt failed with PVCs stuck `Pending` and rolled back cleanly via `--rollback-on-failure` — confirming the safety flag works as intended. Overrode `storageClass` to `standard` via `--set` for local testing only; this is a legitimate environment adaptation, not a change to the actual prod values file (which correctly stays `gp3` for the real EKS target).

A second timing-related failure occurred (`--wait --timeout 300s` expired with `Available: 0/2`) while two full BankApp stacks were competing for image pulls/scheduling on the same kind node; a retry without the wait constraint succeeded, and pods came up healthy shortly after — pointing to timeout tuning rather than an app defect.

**2. `helm diff` before upgrading:**

```bash
helm plugin install https://github.com/databus23/helm-diff --verify=false
helm diff upgrade bankapp helm-chart/bankapp/ \
  -f helm-chart/bankapp/values-prod.yaml \
  --set mysql.persistence.storageClass=standard \
  --set ollama.persistence.storageClass=standard \
  --set bankapp.replicaCount=6 \
  -n bankapp
```

Confirmed: an unchanged diff against the live release produces no output (correct — nothing to show); introducing a real change (`replicaCount=6`) surfaces the diff.

**3. Per-namespace ResourceQuota** — added `helm-chart/bankapp/templates/resourcequota.yaml`.

### Issue hit and fixed — namespace defaulting in `helm template`

`kubectl describe resourcequota -n dev` initially returned nothing. Diagnosed with:

```bash
helm template bankapp-dev helm-chart/bankapp/ -f helm-chart/bankapp/values-dev.yaml | grep -A10 "kind: ResourceQuota"
```

which showed `namespace: default` — `helm template` without an explicit `-n dev` flag doesn't know the target namespace, so `{{ .Release.Namespace }}` fell back to `default`. Re-ran with `-n dev` and re-applied via `helm upgrade --install ... -n dev`, after which the quota appeared correctly under `dev`.

**4. Secrets discipline** — for a real production rollout, `values.yaml`'s plaintext secrets defaults (fine for local dev only) would be replaced with one of: External Secrets Operator + AWS Secrets Manager, Sealed Secrets, or HashiCorp Vault — with real values injected via CI/CD pipeline secrets and `--set`, never committed to the repo.

![alt text](<md-screenshots/Screenshot From 2026-09-09 18-17-26.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-09 18-32-35.png>)

---

## Task 6: Clean Up and Review

```bash
helm list -A
```

![alt text](<md-screenshots/Screenshot From 2026-09-09 18-33-35.png>)

**3-day recap:**

| Day | Concept                                        | AI-BankApp Connection                                |
| --- | ---------------------------------------------- | ---------------------------------------------------- |
| 78  | Helm install, repos, values, upgrade, rollback | Deployed MySQL for the BankApp via Bitnami chart     |
| 79  | Custom chart from scratch, Go templates        | Converted 12 raw `k8s/` manifests into a Helm chart  |
| 80  | Multi-env values, hooks, packaging, CI/CD      | Production-ready chart with dev/staging/prod configs |

**Helm vs raw manifests vs Kustomize:**

| Approach      | Best For                                      | AI-BankApp Example                             |
| ------------- | --------------------------------------------- | ---------------------------------------------- |
| Raw manifests | Simple, single-env deployments                | The current `k8s/` directory                   |
| Helm          | Multi-env, complex apps with dependencies     | The chart built today (3 services, HPA, hooks) |
| Kustomize     | Overlays on existing manifests, no templating | Good for patching `k8s/` without rewriting     |

**Cleanup:**

```bash
helm uninstall bankapp-dev -n dev
kubectl delete namespace dev
kind delete cluster --name tws-cluster
```

![alt text](<md-screenshots/Screenshot From 2026-09-09 18-34-29.png>)

---

## Key Takeaways

- Hook lifecycle phase matters as much as the hook logic itself — a correct readiness check can still deadlock the whole release if it's bound to the wrong phase (`pre-install` vs `post-install`).
- `--rollback-on-failure` (successor to `--atomic`) genuinely protects against half-deployed state — verified firsthand when the `gp3` StorageClass mismatch caused a clean automatic rollback rather than a stuck partial release.
- Environment-specific values (`gp3` vs `standard`, resource sizing) need to be understood as _target-environment assumptions_, not just numbers — porting `values-prod.yaml` to a local cluster requires deliberate, documented overrides rather than blind reuse.
- `helm template`/`helm diff` without an explicit `-n <namespace>` silently falls back to `default` — worth always passing the namespace flag explicitly, even for render-only/dry-run commands.
