# Day 59 – Helm: Kubernetes Package Manager

## What Helm Is

Helm is the package manager for Kubernetes — the same role `apt` plays for Ubuntu. Instead of writing and applying a dozen separate YAML files (Deployment, Service, ConfigMap, Secret, PVC...) by hand for every app, Helm packages them into a single unit you can install, upgrade, and roll back with one command.

Three core concepts:

- **Chart** — a package of Kubernetes manifest templates, parameterized with variables instead of hardcoded values.
- **Release** — one specific installation of a chart into a cluster. You can install the same chart multiple times under different release names, each with its own config.
- **Repository** — a collection of charts, hosted somewhere (like Bitnami's), that you can search and pull from.

---

## Task 1: Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
helm env
```

**Verify:** Helm version installed.

![alt text](<Screenshot From 2026-07-20 18-57-22.png>)

---

## Task 2: Add a Repository and Search

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx
helm search repo bitnami
```

**Verify:** Number of charts available in the Bitnami repo.

![alt text](<Screenshot From 2026-07-20 19-03-20.png>)

---

## Task 3: Install a Chart

```bash
helm install my-nginx bitnami/nginx
kubectl get all
helm list
helm status my-nginx
helm get manifest my-nginx
```

One command replaced writing a Deployment, Service, and ConfigMap by hand.

**Verify:** Pods running, Service type created.

**Environment note:** Bitnami's nginx chart defaults `service.type` to `LoadBalancer`. On a local `kind` cluster there's no cloud provider to hand out an external IP, so it sits at `<pending>` — expected, not a failure.

![alt text](<Screenshot From 2026-07-20 19-05-49.png>)

---

## Task 4: Customize with Values

```bash
helm show values bitnami/nginx

helm install nginx-custom bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=NodePort

helm install nginx-values bitnami/nginx -f custom-values.yaml
helm get values nginx-values
kubectl get pods -l app.kubernetes.io/instance=nginx-values
```

`custom-values.yaml` (full file also submitted alongside this doc):

```yaml
replicaCount: 3
service:
  type: NodePort
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

- `replicaCount: 3` — overrides the chart's default pod count.
- `service.type: NodePort` — exposes the Service on a static port on each node instead of the default `LoadBalancer`.
- `resources.requests` / `resources.limits` — sets the CPU/memory floor and ceiling per pod, so the scheduler makes sane placement decisions and no single pod can starve the node.

**NodePort isn't directly reachable on kind** unless the cluster was created with explicit port mappings, so verified with port-forward instead:

```bash
kubectl port-forward svc/nginx-values 8080:80
curl http://localhost:8080
```

**Verify:** Replicas and service type match the values file.

![alt text](<Screenshot From 2026-07-20 19-11-19.png>)

---

## Task 5: Upgrade and Rollback

```bash
helm upgrade my-nginx bitnami/nginx --set replicaCount=5
helm history my-nginx
helm rollback my-nginx 1
helm history my-nginx
```

Same concept as Deployment rollouts from Day 52, but applied at the full chart level.

**Verify:** Revision count after rollback. Important detail — rollback doesn't overwrite history, it creates a _new_ revision that matches the old config. So one upgrade + one rollback = 3 revisions total, not 2.

![alt text](<Screenshot From 2026-07-20 19-13-27.png>)

---

## Task 6: Create Your Own Chart

```bash
helm create my-app
```

```
my-app/
├── Chart.yaml          # chart metadata (name, version)
├── values.yaml          # default configuration
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    └── ...
```

Templates use Go templating to pull in values at install/upgrade time:

- `{{ .Values.replicaCount }}` — pulls from `values.yaml` (or a `--set`/`-f` override)
- `{{ .Chart.Name }}` — chart metadata
- `{{ .Release.Name }}` — the release name given at install

Edited `values.yaml`:

```yaml
replicaCount: 3
image:
  repository: nginx
  tag: "1.25"
```

```bash
helm lint my-app
helm template my-release ./my-app
helm install my-release ./my-app
kubectl get pods -l app.kubernetes.io/instance=my-release

helm upgrade my-release ./my-app --set replicaCount=5
kubectl get pods -l app.kubernetes.io/instance=my-release
```

**Verify:** 3 replicas after install, 5 after upgrade.

![alt text](<Screenshot From 2026-07-20 19-22-09.png>)

---

## Task 7: Clean Up

```bash
helm list
helm uninstall my-nginx
helm uninstall nginx-custom
helm uninstall nginx-values
helm uninstall my-release
helm list
rm -rf my-app
```

**Verify:** `helm list` shows zero releases.

![alt text](<Screenshot From 2026-07-20 19-24-45.png>)

---

## Summary

Eight days of hand-written Deployments, Services, ConfigMaps, Secrets, and PVCs — Helm collapses all of that into installable, versioned, rollback-able packages. The chart is the template, the release is a running instance of it, and `values.yaml` is the dial that makes one chart reusable across every environment.
