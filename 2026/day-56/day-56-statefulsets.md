# Day 56 – Kubernetes StatefulSets

## What is a StatefulSet?

A **StatefulSet** is a Kubernetes workload controller for applications that need **stable identity and persistent storage per replica** — think databases (MySQL, PostgreSQL), message queues (Kafka), and other stateful systems where "which pod am I talking to" and "did my data survive a restart" actually matter.

A **Deployment** is built for stateless apps: any replica can be replaced by any other replica at any time, pods get random names, and storage (if any) is typically shared. A StatefulSet trades that flexibility for **predictability**: pods get fixed, ordered names, come up one at a time, and each one owns its own slice of storage that follows it across restarts.

### When to use which

| Feature          | Deployment                  | StatefulSet                                 |
| ---------------- | --------------------------- | ------------------------------------------- |
| Pod names        | Random (`app-xyz-abc`)      | Stable, ordered (`app-0`, `app-1`, `app-2`) |
| Startup order    | All at once                 | Ordered: pod-0, then pod-1, then pod-2      |
| Storage          | Shared PVC (or none)        | Each pod gets its own PVC                   |
| Network identity | No stable hostname          | Stable DNS per pod                          |
| Use case         | Stateless web servers, APIs | Databases, queues, clustered/stateful apps  |

---

## Task 1: The Problem with Deployments

Created a 3-replica nginx Deployment and confirmed pod names are random. Deleted a pod — the replacement came back with a **new** random name, not the same one.

```bash
kubectl create deployment web --image=nginx --replicas=3
kubectl get pods -l app=web -o wide
kubectl delete pod <one-pod-name>
kubectl get pods -l app=web
kubectl delete deployment web
```

**Screenshot:**
![alt text](<Screenshot From 2026-07-17 18-30-27.png>)

**Why this breaks for databases:** In a database cluster, each node usually has a specific role (e.g., primary vs. replicas) and other nodes/clients need to consistently find _the same node_ again — especially after a restart, to reattach to its data. Random names mean there's no reliable way to say "this is node 0, the primary" — every restart reshuffles identity, which breaks replication topology, leader election, and client connection strings that expect fixed addresses.

---

## Task 2: Headless Service

A Headless Service (`clusterIP: None`) skips load-balancing and instead gives **each pod its own DNS entry**. This is the networking foundation StatefulSets rely on.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
  labels:
    app: web
spec:
  clusterIP: None
  selector:
    app: web
  ports:
    - port: 80
      name: http
```

```bash
kubectl apply -f web-headless-svc.yaml
kubectl get svc nginx-headless
```

**Screenshot:**
![alt text](<Screenshot From 2026-07-17 18-33-02.png>)

**Verify:** CLUSTER-IP column shows `None` — confirming no single virtual IP is created; DNS resolves directly to individual pod IPs instead.

---

## Task 3: Creating the StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: nginx-headless
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - name: web-data
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: web-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 100Mi
```

```bash
kubectl apply -f web-statefulset.yaml
kubectl get pods -l app=web -w
kubectl get sts web
kubectl get pvc
```

Watched pods come up in strict order — `web-0` reached Ready before `web-1` even started, then `web-2` after that.

**Screenshot:**
![alt text](<Screenshot From 2026-07-17 18-36-36.png>)

**Verify — exact names:**

- Pods: `web-0`, `web-1`, `web-2`
- PVCs: `web-data-web-0`, `web-data-web-1`, `web-data-web-2`

PVC naming pattern: `<volumeClaimTemplate-name>-<statefulset-name>-<ordinal>`.

---

## Task 4: Stable Network Identity (Per-Pod DNS)

Each StatefulSet pod is addressable at:

```
<pod-name>.<headless-service-name>.<namespace>.svc.cluster.local
```

```bash
kubectl get pods -l app=web -o wide

kubectl run dns-test --image=busybox:1.36 -it --rm --restart=Never -- sh
nslookup web-0.nginx-headless.default.svc.cluster.local
nslookup web-1.nginx-headless.default.svc.cluster.local
nslookup web-2.nginx-headless.default.svc.cluster.local
exit
```

**Screenshot:**

![alt text](<Screenshot From 2026-07-17 18-40-41.png>)
![alt text](<Screenshot From 2026-07-17 18-39-27.png>)

**Verify:** Yes — the IP returned by each `nslookup` matched the corresponding pod's IP from `kubectl get pods -o wide`. Unlike the ClusterIP of a normal Service, this DNS name resolves straight to the individual pod, which is what lets other pods in a cluster talk to a _specific_ member (e.g., "always connect to `web-0` as primary").

---

## Task 5: Stable Storage — Data Survives Pod Deletion

```bash
kubectl exec web-0 -- sh -c "echo 'Data from web-0' > /usr/share/nginx/html/index.html"
kubectl exec web-1 -- sh -c "echo 'Data from web-1' > /usr/share/nginx/html/index.html"
kubectl exec web-2 -- sh -c "echo 'Data from web-2' > /usr/share/nginx/html/index.html"

kubectl delete pod web-0
kubectl get pods -l app=web -w
kubectl exec web-0 -- cat /usr/share/nginx/html/index.html
```

**Screenshot:**
![alt text](<Screenshot From 2026-07-17 18-42-57.png>)

**Verify:** Yes — data was identical after recreation. Kubernetes recreated `web-0` with the _same name_ and reattached it to the _same PVC_ (`web-data-web-0`), so the pod picked up right where it left off. This is the core guarantee a Deployment can't give you: identity and storage are tied together and preserved across restarts.

---

## Task 6: Ordered Scaling

```bash
kubectl scale statefulset web --replicas=5
kubectl get pods -l app=web -w
```

`web-3` became Ready before `web-4` was created.

```bash
kubectl scale statefulset web --replicas=3
kubectl get pods -l app=web -w
```

`web-4` terminated first, then `web-3` — reverse order.

```bash
kubectl get pvc
```

**Screenshot:**
![alt text](<Screenshot From 2026-07-17 18-46-18.png>)

**Verify:** After scaling down to 3 replicas, all **5** PVCs were still present (`web-data-web-0` through `web-data-web-4`). Kubernetes never auto-deletes PVCs on scale-down — the data for `web-3` and `web-4` is preserved in case you scale back up and expect them to still have their state.

---

## Task 7: Clean Up

```bash
kubectl delete sts web
kubectl delete svc nginx-headless
kubectl get pvc
```

**Screenshot:**
`[SCREENSHOT: kubectl get pvc showing PVCs still present after StatefulSet deletion]`

**Verify:** PVCs were **not** auto-deleted with the StatefulSet — this is a deliberate safety feature so you don't accidentally nuke a database's data by deleting the controller.

```bash
kubectl delete pvc -l app=web
kubectl get pvc
```

---

## Key Takeaways

- **StatefulSets = identity + order + per-pod storage.** Deployments give you neither stable names nor guaranteed pod-to-storage mapping.
- **Headless Service is mandatory** — it's what gives each pod its own resolvable DNS name instead of load-balancing across replicas.
- **Ordered creation/termination** (0→1→2 up, 2→1→0 down) matters for apps with startup dependencies, like a primary that must exist before replicas join.
- **PVCs outlive both pods and the StatefulSet itself** — scaling down or deleting the StatefulSet never deletes storage. Cleanup is a deliberate, separate step.
- **DNS + PVC naming both follow the ordinal**, which is what lets a database node be found and rehydrated with its own data every single time, regardless of which node in the cluster it's rescheduled to.

---

## Files

- `2026/day-56/day-56-statefulsets.md` (this file)
- `web-headless-svc.yaml`
- `web-statefulset.yaml`
