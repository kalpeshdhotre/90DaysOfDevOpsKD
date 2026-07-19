# Day 58 – Metrics Server and Horizontal Pod Autoscaler (HPA)

## What the Metrics Server Is, and Why HPA Needs It

The Metrics Server is a cluster add-on that polls each kubelet every 15 seconds for live CPU and memory usage of nodes and pods, and exposes that data through the Kubernetes Metrics API (`metrics.k8s.io`). It doesn't store history — it only ever holds the most recent snapshot.

This matters for HPA because the HPA controller has no way to "see" resource usage on its own. It has no built-in monitoring — it queries the Metrics API on the same 15-second loop the Metrics Server refreshes on, compares current usage against the target you set, and decides whether to scale. No Metrics Server running means no data means HPA has nothing to act on (TARGETS shows `<unknown>` forever).

On `kind` specifically, the stock metrics-server manifest doesn't work out of the box — kind's kubelet doesn't present certificates that metrics-server can validate externally, so it crash-loops with an `x509` error until you add `--kubelet-insecure-tls` to its args. Fine for a local dev cluster, never for production.

## How HPA Calculates Desired Replicas

```
desiredReplicas = ceil(currentReplicas * (currentMetricValue / desiredMetricValue))
```

Concretely: if you've got 1 replica running at 200% of its CPU request, and your target is 50%, HPA computes `ceil(1 * (200/50)) = 4` replicas. As load spreads across more pods, per-pod CPU usage drops, the ratio shrinks, and HPA stops scaling once it converges near the target.

This is also exactly why the Deployment needs `resources.requests.cpu` set — "200% utilization" is meaningless without a request value to measure against. Skip the request and HPA has no denominator to work with.

## autoscaling/v1 vs autoscaling/v2

|                  | v1                               | v2                                                                                           |
| ---------------- | -------------------------------- | -------------------------------------------------------------------------------------------- |
| Metrics          | CPU only                         | CPU, memory, custom, and external metrics                                                    |
| Multiple metrics | No                               | Yes — scales on whichever metric demands the most replicas                                   |
| Scaling behavior | Fixed defaults, not configurable | `behavior` block — separate scale-up/scale-down policies, stabilization windows, rate limits |
| Created by       | `kubectl autoscale` (imperative) | YAML manifest (declarative)                                                                  |

`kubectl autoscale` generates a `v1` object under the hood, which is why Task 6 required deleting the imperative HPA and reapplying as YAML — there's no imperative flag that produces a `v2` object with a `behavior` section.

---

## Task 1: Install the Metrics Server

Installed via the official manifest, then patched for kind's self-signed kubelet certs:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

![alt text](<Screenshot From 2026-07-19 18-12-01.png>)

**Verify:** Node CPU/memory usage — _[see screenshot]_

---

## Task 2: Explore kubectl top

```bash
kubectl top nodes
kubectl top pods -A
kubectl top pods -A --sort-by=cpu
```

![alt text](<Screenshot From 2026-07-19 18-13-50.png>)

**Verify:** Highest CPU pod — _[see screenshot]_

---

## Task 3: Deployment with CPU Requests

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  replicas: 1
  selector:
    matchLabels:
      run: php-apache
  template:
    metadata:
      labels:
        run: php-apache
    spec:
      containers:
        - name: php-apache
          image: registry.k8s.io/hpa-example
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 200m
            limits:
              cpu: 500m
```

```bash
kubectl apply -f php-apache.yaml
kubectl expose deployment php-apache --port=80
```

![alt text](<Screenshot From 2026-07-19 18-17-20.png>)

**Verify:** Pod CPU usage at baseline — _[see screenshot]_

---

## Task 4: HPA (Imperative)

```bash
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
```

![alt text](<Screenshot From 2026-07-19 18-20-06.png>)

**Verify:** TARGETS column — _[see screenshot]_

---

## Task 5: Generate Load and Watch Autoscaling

```bash
kubectl run load-generator --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://php-apache; done"
kubectl get hpa php-apache --watch
```

![alt text](<Screenshot From 2026-07-19 18-23-51.png>)
![alt text](<Screenshot From 2026-07-19 18-23-41.png>)

**Verify:** HPA scaled up to **9 replicas** under sustained load, from a baseline of 1 — a 9x scale-out driven entirely by the 50% CPU target.

---

## Task 6: HPA from YAML (Declarative)

```bash
kubectl delete hpa php-apache
```

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
```

![alt text](<Screenshot From 2026-07-19 18-26-50.png>)

**Verify:** The `behavior` section controls how aggressively HPA scales in each direction, independently:

- **Scale Up:** `stabilizationWindowSeconds: 0` — react immediately, no delay. `Percent` policy at `100`/`15s` — can double replica count every 15 seconds, capped by `Select Policy: Max` picking whichever configured policy allows the largest change.
- **Scale Down:** `stabilizationWindowSeconds: 300` — wait 5 minutes of sustained lower usage before shrinking, to avoid flapping on a brief dip. `Percent` policy at `50`/`60s` — removes at most half the replicas per minute once it does scale down.

Post-cleanup, the Deployment confirmed at `0 current / 0 desired`.

---

## Task 7: Clean Up

```bash
kubectl delete hpa php-apache
kubectl delete service php-apache
kubectl delete deployment php-apache
kubectl delete pod load-generator --ignore-not-found
```

Metrics Server left installed for future days.

---

## Key Takeaways

- HPA is blind without the Metrics Server — no metrics pipeline, no scaling decisions
- `resources.requests.cpu` isn't optional for HPA — it's the denominator in the utilization calculation
- `kubectl autoscale` is quick to reach for, but it can only ever produce a `v1` HPA — `behavior` tuning requires dropping to YAML
- On kind, expect the `--kubelet-insecure-tls` patch — it's not a bug in your setup, it's how kind's kubelet certs work
- Scale-up and scale-down are intentionally asymmetric: fast to react to spikes, slow and cautious to shrink back down
