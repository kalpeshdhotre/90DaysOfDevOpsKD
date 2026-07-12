# Day 51 – Kubernetes Manifests and Your First Pods

## The Four Required Fields of a Kubernetes Manifest

| Field | Purpose |
|---|---|
| `apiVersion` | Which API group/version to use (`v1` for core resources like Pods) |
| `kind` | The resource type being defined (`Pod`, `Deployment`, `Service`, etc.) |
| `metadata` | Identity of the resource — `name` (required), `labels`, `namespace` |
| `spec` | Desired state — for a Pod, the containers, images, ports, etc. |

---

## My Pod Manifests

### 1. nginx-pod.yaml
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

### 2. busybox-pod.yaml
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox-pod
  labels:
    app: busybox
    environment: dev
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sh", "-c", "echo Hello from BusyBox && sleep 3600"]
```

### 3. httpd-pod.yaml
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: httpd-pod
  labels:
    app: httpd
    environment: dev
    team: devops
spec:
  containers:
  - name: httpd
    image: httpd:latest
    ports:
    - containerPort: 80
```

---

## Imperative vs Declarative

- **Imperative** (`kubectl run redis-pod --image=redis:latest`) — tell Kubernetes exactly what action to take, right now. Fast for quick tests, but not repeatable or version-controllable.
- **Declarative** (`kubectl apply -f nginx-pod.yaml`) — describe the desired end state in a file, and Kubernetes figures out how to get there. Repeatable, diffable, and safe to store in Git.

Extracting the generated YAML from the imperative pod (`kubectl get pod redis-pod -o yaml`) showed how much Kubernetes fills in automatically that I never had to write by hand: `metadata.uid`, `metadata.resourceVersion`, `metadata.creationTimestamp`, `spec.nodeName`, `spec.serviceAccountName`, `spec.tolerations`, container `terminationMessagePath`, plus the full `status` block. My hand-written manifests only had the fields I explicitly set — everything else is server-side default.

---

## Client-side vs Server-side Dry-Run

- `--dry-run=client` — validates YAML structure/types against the local OpenAPI schema only. No cluster contact. It did **not** catch a missing `image` field, because `image` isn't schema-required (some edge cases like ephemeral containers can omit it).
- `--dry-run=server` — sends the request to the real API server for full admission validation, without persisting the object. This is what actually caught the missing field:

```
error: error validating "broken-pod.yaml": error validating data: ValidationError(Pod.spec.containers[0]): missing required field "image" in io.k8s.api.core.v1.Container
```

**Takeaway:** client-side dry-run is a fast local sanity check; server-side dry-run is the real validation gate.

---

## Screenshots

`kubectl get pods` (all three pods Running):

*[screenshot here]*

`kubectl get pods --show-labels`:

*[screenshot here]*

Server-side dry-run error output:

*[screenshot here]*

---

## What Happens When You Delete a Standalone Pod?

It's gone for good. There's no controller watching a bare Pod, so nothing recreates it. This is exactly why production workloads use a **Deployment** instead — a Deployment's controller continuously reconciles the actual state against the desired state and respawns Pods that disappear. That's tomorrow's topic (Day 52).
