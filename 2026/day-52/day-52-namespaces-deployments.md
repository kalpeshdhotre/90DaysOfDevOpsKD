# Day 52 – Kubernetes Namespaces and Deployments

## What Namespaces Are and Why You'd Use Them

A namespace is a way to divide a single Kubernetes cluster into multiple virtual clusters. Resources inside one namespace are isolated from another — you can have a `dev` and a `production` namespace on the same physical cluster, each with its own Pods, Deployments, and Services, without them colliding.

Kubernetes ships with four built-in namespaces:

- `default` — where resources land if you don't specify a namespace
- `kube-system` — the cluster's own control plane components (API server, scheduler, DNS, etc.)
- `kube-public` — publicly readable resources, rarely used
- `kube-node-lease` — used for node heartbeat/lease tracking

Namespaces matter for:

- **Isolation** — dev/staging/production workloads don't accidentally interfere with each other
- **Organization** — teams or projects can own their own namespace
- **Access control** — RBAC policies can be scoped per namespace
- **Resource quotas** — you can cap CPU/memory usage per namespace

The default `kubectl get pods` only shows the `default` namespace — you have to pass `-n <namespace>` to target a specific one, or `-A` to see everything across all namespaces at once.
![alt text](<Screenshot From 2026-07-13 16-14-16.png>)

---

## The Deployment Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: dev
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.24
          ports:
            - containerPort: 80
```

**Section by section:**

- `apiVersion: apps/v1` — Deployments live in the `apps/v1` API group, unlike standalone Pods which use `v1`
- `kind: Deployment` — tells Kubernetes this is a self-managing controller, not a raw Pod
- `metadata.namespace: dev` — pins this Deployment (and everything it creates) to the `dev` namespace
- `spec.replicas: 3` — the desired state: always keep 3 identical Pods alive
- `spec.selector.matchLabels` — how the Deployment identifies "which Pods belong to me." This has to match `template.metadata.labels` exactly, or Kubernetes rejects the manifest
- `spec.template` — the Pod blueprint. Every replica the Deployment creates is stamped out from this template

![alt text](<Screenshot From 2026-07-13 16-17-40.png>)

---

## Deployment-Managed Pod vs Standalone Pod

Deleting a standalone Pod is permanent — nothing is watching it, so once it's gone, it's gone. You'd have to manually recreate it.

Deleting a Pod that's managed by a Deployment behaves completely differently. The Deployment's underlying ReplicaSet continuously compares desired replica count against actual running Pods. The moment a managed Pod is deleted, the ReplicaSet notices the mismatch (e.g. "I want 3, I only have 2") and immediately schedules a replacement. The replacement Pod gets a **new name** — a different hash suffix — because it's a genuinely new Pod object, not the old one resurrected.

This is the core value of a Deployment: self-healing. Standalone Pods have no such safety net.

---

## Scaling — Imperative vs Declarative

**Imperative** (fast, one-off, not saved anywhere):

```bash
kubectl scale deployment nginx-deployment --replicas=5 -n dev
```

Kubernetes immediately creates or terminates Pods to match the new count. Scaling down doesn't let you pick which Pods die — Kubernetes chooses.

**Declarative** (version-controlled, repeatable):
Edit the `replicas` field in the YAML manifest, then re-apply:

```bash
kubectl apply -f nginx-deployment.yaml
```

This is the GitOps-friendly approach — the desired state lives in a file that can be committed, reviewed, and reproduced, rather than a one-time command that leaves no trace.

![alt text](<Screenshot From 2026-07-13 16-29-14.png>)
![alt text](<Screenshot From 2026-07-13 16-31-41-1.png>)
![alt text](<Screenshot From 2026-07-13 16-33-36.png>)

---

## Rolling Updates and Rollbacks

Triggering an update:

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.25 -n dev
```

Kubernetes performs the update gradually: it brings up a new Pod on the updated image, waits for it to pass health checks, _then_ terminates one old Pod. This repeats until every Pod is on the new version. Because there's always a working Pod during the transition, the rollout achieves zero downtime.

Under the hood, a rolling update doesn't edit Pods in place — it creates a brand-new ReplicaSet for the new image version and scales it up while scaling the old ReplicaSet down to zero. That's also why rollback is instant:

```bash
kubectl rollout undo deployment/nginx-deployment -n dev
```

Kubernetes just reverses the process — scales the previous ReplicaSet back up and the current one down. Rollout history is tracked automatically:

```bash
kubectl rollout history deployment/nginx-deployment -n dev
```

After rollback, `kubectl describe deployment nginx-deployment -n dev | grep Image` confirmed the image was back to `nginx:1.24`.

## ![alt text](<Screenshot From 2026-07-13 16-46-07.png>)

## Key Takeaway

A Deployment is Kubernetes' answer to "how do I keep an application running reliably." It wraps Pods with a ReplicaSet that enforces a desired replica count, self-heals on failure, and enables safe, zero-downtime updates with instant rollback — none of which a standalone Pod can do on its own.
