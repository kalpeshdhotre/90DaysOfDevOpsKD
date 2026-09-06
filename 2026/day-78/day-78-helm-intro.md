# Day 78 — Introduction to Helm and Chart Basics

**Challenge:** #90DaysOfDevOps | #DevOpsKaJosh | #TrainWithShubham
**Repo context:** [AI-BankApp-DevOps](https://github.com/TrainWithShubham/AI-BankApp-DevOps) (branch `feat/gitops`)

---

## Task 1: Understand Helm Concepts

**What is Helm?**
Helm is the package manager for Kubernetes — the equivalent of `apt` for Ubuntu or `yum` for RHEL, but for K8s resources. It packages Kubernetes manifests into reusable, versioned units called **charts** and supports templating, so one chart can serve many environments instead of hand-editing YAML per environment.

**Core concepts:**

- **Chart** — a collection of files describing a set of Kubernetes resources (e.g. a Deployment + Service + ConfigMap + Secret bundled as one chart)
- **Release** — a running instance of a chart in a cluster. The same chart can be installed multiple times under different release names
- **Repository** — a place charts are stored and shared, similar to DockerHub for container images
- **Values** — the configuration layer (replicas, image tag, resource limits, etc.) that customizes a chart for a specific deployment

**Why Helm over raw manifests?**
The AI-BankApp's `k8s/` directory has 12 separate YAML files. Changing an image tag means editing `bankapp-deployment.yml` directly; switching environments means manually touching ConfigMaps and Secrets across files. Helm addresses this with:

- **Templating** — one chart, multiple environments (dev/staging/prod) via different values files
- **Versioning** — charts carry version numbers, and releases can be rolled back
- **Dependencies** — a chart can depend on other charts (the AI-BankApp's chart will depend on a MySQL chart)
- **Community ecosystem** — thousands of pre-built charts exist for common software (MySQL, Redis, Prometheus, ArgoCD)

---

## Task 2: Install Helm and Explore the AI-BankApp

Set up a Kind cluster using the AI-BankApp's own config (1 control-plane + 2 worker nodes):

```bash
git clone -b feat/gitops https://github.com/TrainWithShubham/AI-BankApp-DevOps.git
cd AI-BankApp-DevOps
kind create cluster --config setup-k8s/kind-config.yml
```

Installed Helm and confirmed cluster connectivity:

```bash
helm version
kubectl cluster-info
helm list
```

Explored the raw manifests that will eventually become a chart:

```bash
ls k8s/
```

```
bankapp-deployment.yml   configmap.yml   gateway.yml   mysql-deployment.yml
namespace.yml   ollama-deployment.yml   pv.yml   pvc.yml   secrets.yml
service.yml   hpa.yml   cert-manager.yml
```

12 files total — Deployments, Services, ConfigMaps, Secrets, PVCs, HPA, and more, all with hardcoded values. These get converted into a proper Helm chart on Day 79.

![alt text](<md-screenshots/Screenshot From 2026-09-06 17-49-04.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-06 17-53-06.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-06 17-53-17.png>)

---

## Task 3: Deploy MySQL Using a Helm Chart

Added the Bitnami chart repository:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo bitnami/mysql
```

**Gotcha hit here:** the chart's default image reference — `bitnami/mysql:9.4.0-debian-12-r1` — no longer exists. As of August 28, 2025, Bitnami moved almost all versioned images out of the public `docker.io/bitnami/*` catalog into an unmaintained `bitnamilegacy/*` repository, as part of Broadcom's push toward paid "Bitnami Secure Images." Any chart still defaulting to the old path fails with `Init:ImagePullBackOff` → `not found`.

**Fix** — point the chart at the legacy image repo and allow the (unmaintained) non-default registry:

```bash
helm install bankapp-mysql bitnami/mysql \
  --set image.repository=bitnamilegacy/mysql \
  --set global.security.allowInsecureImages=true \
  --set auth.rootPassword=Test@123 \
  --set auth.database=bankappdb \
  --set primary.resources.requests.memory=256Mi \
  --set primary.resources.requests.cpu=250m \
  --set primary.resources.limits.memory=512Mi \
  --set primary.resources.limits.cpu=500m \
  --set primary.persistence.size=5Gi
```

Compared to the raw manifest approach — which needs `mysql-deployment.yml` + `secrets.yml` + `pvc.yml` + `pv.yml` + `service.yml` stitched together manually — this is a single command.

Verified what Helm created:

```bash
helm list
kubectl get all -l app.kubernetes.io/instance=bankapp-mysql
kubectl get pvc -l app.kubernetes.io/instance=bankapp-mysql
kubectl get secret -l app.kubernetes.io/instance=bankapp-mysql
```

Confirmed MySQL was running and the database existed:

```bash
kubectl exec -it bankapp-mysql-0 -- mysql -uroot -pTest@123 -e "SHOW DATABASES;"
```

`bankappdb` appeared in the output.

![alt text](<md-screenshots/Screenshot From 2026-09-06 17-57-50.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-06 17-57-53.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-06 18-02-51.png>)

---

## Task 4: Customize a Deployment with a Values File

`--set` is fine for quick overrides; real projects use values files. Created `mysql-values.yaml`:

```yaml
image:
  repository: bitnamilegacy/mysql
global:
  security:
    allowInsecureImages: true
auth:
  rootPassword: Test@123
  database: bankappdb
primary:
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  persistence:
    size: 5Gi
    storageClass: ""
metrics:
  enabled: true
  serviceMonitor:
    enabled: false
```

**Field notes:**

- `image.repository` / `global.security.allowInsecureImages` — required override due to the Bitnami legacy-registry migration (see Task 3)
- `auth.rootPassword` / `auth.database` — bootstrap credentials and the initial database name
- `primary.resources.*` — CPU/memory requests and limits for the primary MySQL pod
- `primary.persistence.size` — PVC size for MySQL's data volume
- `metrics.enabled` — turns on the Prometheus exporter sidecar
- `metrics.serviceMonitor.enabled` — left off since no Prometheus Operator is running in this cluster

Deployed a second release from the file, confirmed it, then cleaned it up:

```bash
helm install bankapp-mysql-v2 bitnami/mysql -f mysql-values.yaml
helm show values bitnami/mysql | head -80
helm uninstall bankapp-mysql-v2
```

## ![alt text](<md-screenshots/Screenshot From 2026-09-06 18-05-33.png>)

## Task 5: Manage Releases — Upgrade, Rollback, Uninstall

**Gotcha hit here:** the first `helm upgrade` attempt only passed the new flag (`metrics.enabled=true`) plus auth values, omitting the image/persistence overrides from the original install. Helm doesn't merge `--set` values across `upgrade` calls — it recalculates from chart defaults for anything not explicitly passed. That reverted `primary.persistence.size`, which changes `volumeClaimTemplates` on the StatefulSet — an **immutable field** in Kubernetes. The upgrade was rejected outright:

```
Forbidden: updates to statefulset spec for fields other than 'replicas', 'ordinals', 'template',
'updateStrategy', 'revisionHistoryLimit', 'persistentVolumeClaimRetentionPolicy' and
'minReadySeconds' are forbidden
```

**Fix** — use `--reuse-values` to carry forward the previous release's full values and layer only the new setting on top:

```bash
helm upgrade bankapp-mysql bitnami/mysql \
  --reuse-values \
  --set metrics.enabled=true
```

Checked revision history:

```bash
helm history bankapp-mysql
```

Note: Helm revisions start at **1**, not 0. The failed upgrade attempt still consumes a revision number in the history (shown with `status: failed`), so the successful metrics-enabled upgrade landed as a later revision than the guide originally assumed — a good example of Helm tracking failed changes transparently rather than silently discarding them.

Rolled back to the original revision:

```bash
helm rollback bankapp-mysql 1
helm history bankapp-mysql
```

Rollback itself is recorded as a **new, forward-moving revision** — Helm never rewrites history, it reapplies the old config as the next entry in the sequence.

**Comparison to raw manifests:** with `kubectl apply`, there's no built-in rollback — you'd have to `git revert` and manually re-apply. Helm gives this out of the box via `helm rollback`.

[SCREENSHOT: helm history showing install → failed upgrade → successful upgrade → rollback revisions]
![alt text](<md-screenshots/Screenshot From 2026-09-06 18-09-29.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-06 18-10-53.png>)

---

## Task 6: Explore a Chart's Structure

Pulled the MySQL chart locally to inspect it:

```bash
helm pull bitnami/mysql --untar
ls mysql/
```

```
mysql/
  Chart.yaml
  values.yaml
  charts/
  templates/
    primary/
      statefulset.yaml
      svc.yaml
    _helpers.tpl
    NOTES.txt
    secrets.yaml
```

`templates/primary/statefulset.yaml` uses Go template syntax pulling from `values.yaml`:

```yaml
replicas: { { .Values.primary.replicaCount } }
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

`Chart.yaml`:

```yaml
apiVersion: v2
name: mysql
description: A Helm chart for MySQL
version: 12.2.1
appVersion: "8.0.40"
```

**`version` vs `appVersion`:** `version` is the chart's own packaging version — it changes when the chart's templates or structure change, independent of the software inside. `appVersion` tracks the version of the underlying application (MySQL itself) that the chart currently deploys. A chart can bump `version` (e.g. adding a new configurable value) without touching `appVersion` at all, and vice versa.

**Raw manifest vs Helm chart — comparison:**

| Aspect       | AI-BankApp `k8s/mysql-deployment.yml` | Bitnami MySQL Helm Chart                                      |
| ------------ | ------------------------------------- | ------------------------------------------------------------- |
| Secrets      | Hardcoded base64 in `secrets.yml`     | Generated and managed by Helm                                 |
| Storage      | Manual StorageClass + PVC files       | Configured via `persistence.size` value                       |
| Replicas     | Hardcoded in YAML                     | `primary.replicaCount` value                                  |
| Metrics      | Not included                          | `metrics.enabled: true`                                       |
| Rollback     | Manual (`git revert` + reapply)       | `helm rollback`                                               |
| Image source | Fixed                                 | Overridable — including today's registry migration workaround |

**Why the AI-BankApp's 12 raw files would benefit from becoming a chart:** the same pain points hit today with the community MySQL chart apply directly — templating for dev/staging/prod, safe rollback of a bad deploy, and a single point of configuration instead of touching Deployments, ConfigMaps, and Secrets separately. Converting `k8s/` into a chart tomorrow turns this into one versioned, values-driven package.

Cleaned up:

```bash
helm uninstall bankapp-mysql
rm -rf mysql/
```

## ![alt text](<md-screenshots/Screenshot From 2026-09-06 18-12-11.png>)

## Key Takeaways

- Helm turns a 12-file raw manifest sprawl into a single versioned, templated package
- Community charts carry real-world dependency risk — today's Bitnami legacy-registry migration broke the default MySQL chart install and needed an explicit `image.repository` + `allowInsecureImages` override
- `helm upgrade` does **not** merge `--set` values across calls — always pass the full override set or use `--reuse-values`, especially with StatefulSets where some fields are immutable post-creation
- Helm revisions start at 1, and rollbacks are recorded as new forward revisions, not history rewrites — failed upgrades still show up in the history

---

## Submission

Added to `2026/day-78/` in fork and pushed.
