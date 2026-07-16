# Day 55 – Persistent Volumes (PV) and Persistent Volume Claims (PVC)

## Why Containers Need Persistent Storage

Containers are ephemeral by design. When a Pod dies — crash, eviction, node drain, manual delete — everything written inside its filesystem disappears with it. For a stateless web server that's fine. For a database, a message queue, or anything that needs to remember data across restarts, it's a dealbreaker.

Kubernetes solves this by decoupling storage from the Pod's lifecycle: the data lives in a **Volume** that exists independently of any one Pod, and Pods just mount it.

---

## What PVs and PVCs Are, and How They Relate

- **PersistentVolume (PV):** a piece of storage in the cluster, provisioned either by an admin (static) or automatically by a StorageClass (dynamic). PVs are cluster-scoped resources — not tied to any namespace.
- **PersistentVolumeClaim (PVC):** a request for storage made by a user/Pod. A PVC specifies how much storage it needs and what access mode it wants. PVCs are namespaced.

The relationship: a PVC is bound to a PV that satisfies its request (capacity ≥ requested, matching access mode, matching storage class). Once bound, a Pod references the PVC by name and mounts it like any other volume — the Pod never talks to the PV directly.

```
Pod → PVC (claim) → PV (actual storage) → hostPath / cloud disk / NFS / etc.
```

---

## Task 1: See the Problem — Data Lost on Pod Deletion

`pod-emptydir.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-pod
spec:
  containers:
    - name: writer
      image: busybox
      command: ["sh", "-c", "date > /data/message.txt && sleep 3600"]
      volumeMounts:
        - name: data-vol
          mountPath: /data
  volumes:
    - name: data-vol
      emptyDir: {}
```

```bash
kubectl apply -f pod-emptydir.yaml
kubectl exec emptydir-pod -- cat /data/message.txt
kubectl delete pod emptydir-pod
kubectl apply -f pod-emptydir.yaml
kubectl exec emptydir-pod -- cat /data/message.txt
```

**Result:** the timestamp after recreation was different from the first run. `emptyDir` storage is tied directly to the Pod's lifecycle — delete the Pod, lose the data.

![alt text](<Screenshot From 2026-07-16 20-36-28.png>)
![alt text](<Screenshot From 2026-07-16 20-35-21.png>)

---

## Task 2: Create a PersistentVolume (Static Provisioning)

`pv.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-demo
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/k8s-pv-data
```

```bash
docker exec devops-days-control-plane mkdir -p /tmp/k8s-pv-data
kubectl apply -f pv.yaml
kubectl get pv
```

**Result:** STATUS = `Available`. No PVC has claimed it yet.

![alt text](<Screenshot From 2026-07-16 20-39-45.png>)

---

## Task 3: Create a PersistentVolumeClaim

`pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-demo
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

```bash
kubectl apply -f pvc.yaml
kubectl get pvc
kubectl get pv
```

**Result:** both showed `Bound`. VOLUME column in `kubectl get pvc` showed `pv-demo`.

> **Gotcha hit during this task:** my first attempt at `pvc.yaml` left out `storageClassName` entirely. On `kind`, PVCs with no storage class get auto-assigned the cluster's default (`standard`), while a PV created with no storage class field defaults to `""`. Mismatched storage classes mean no binding — the PVC sat `Pending` even though `pv-demo` was sitting right there `Available`. Fix: set `storageClassName: ""` explicitly on the PVC to opt out of dynamic provisioning and force it to look for a static PV.

![alt text](<Screenshot From 2026-07-16 20-45-09.png>)

---

## Task 4: Use the PVC in a Pod — Data That Survives

`pod-pvc.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
    - name: writer
      image: busybox
      command: ["sh", "-c", "echo Pod1-$(date) >> /data/message.txt && sleep 3600"]
      volumeMounts:
        - name: data-vol
          mountPath: /data
  volumes:
    - name: data-vol
      persistentVolumeClaim:
        claimName: pvc-demo
```

```bash
kubectl apply -f pod-pvc.yaml
kubectl exec pvc-pod -- cat /data/message.txt
kubectl delete pod pvc-pod
kubectl apply -f pod-pvc.yaml
kubectl exec pvc-pod -- cat /data/message.txt
```

**Result:** `/data/message.txt` contained entries from both the first and second Pod. The data lives in the PV, backed by the node's filesystem — not inside any single container — so it survives Pod deletion and recreation.

![alt text](<Screenshot From 2026-07-16 20-48-06.png>)

---

## Task 5: StorageClasses and Dynamic Provisioning

```bash
kubectl get storageclass
kubectl describe storageclass standard
```

**Result:** the default StorageClass in the `kind` cluster is `standard`, provisioned by `rancher.io/local-path`, with `volumeBindingMode: WaitForFirstConsumer` — meaning the actual PV isn't created until a Pod that uses the PVC is scheduled.

With dynamic provisioning, developers only ever write a PVC; the StorageClass's provisioner creates the matching PV automatically in the background.

![alt text](<Screenshot From 2026-07-16 20-48-06-1.png>)

---

## Task 6: Dynamic Provisioning

`pvc-dynamic.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-dynamic
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 200Mi
```

`pod-dynamic.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dynamic-pod
spec:
  containers:
    - name: writer
      image: busybox
      command: ["sh", "-c", "date > /data/message.txt && sleep 3600"]
      volumeMounts:
        - name: data-vol
          mountPath: /data
  volumes:
    - name: data-vol
      persistentVolumeClaim:
        claimName: pvc-dynamic
```

```bash
kubectl apply -f pvc-dynamic.yaml
kubectl apply -f pod-dynamic.yaml
kubectl get pv
```

**Result:** two PVs existed after this step — `pv-demo` (manually written) and an auto-named PV like `pvc-xxxxxxxx` (created automatically by the `standard` provisioner the moment `dynamic-pod` needed storage).

![alt text](<Screenshot From 2026-07-16 20-48-06-2.png>)

---

## Task 7: Clean Up

```bash
kubectl delete pod dynamic-pod
kubectl delete pvc pvc-demo
kubectl delete pvc pvc-dynamic
kubectl get pv
kubectl delete pv pv-demo
```

**Result:** the dynamically-provisioned PV was deleted automatically (its reclaim policy defaults to `Delete`). `pv-demo` switched to `Released` instead of disappearing, because its reclaim policy is `Retain` — Kubernetes leaves the underlying data alone and waits for manual cleanup or reuse.
![alt text](<Screenshot From 2026-07-16 20-55-07.png>)

---

## Static vs Dynamic Provisioning

|                    | Static                         | Dynamic                                  |
| ------------------ | ------------------------------ | ---------------------------------------- |
| Who creates the PV | Admin, manually                | StorageClass provisioner, automatically  |
| When               | Ahead of time                  | On-demand, when a PVC needs it           |
| Developer writes   | PV + PVC                       | PVC only                                 |
| Typical use        | Learning, fixed/legacy storage | Cloud environments, day-to-day workloads |

## Access Modes and Reclaim Policies

**Access modes:**

- `ReadWriteOnce (RWO)` — read-write by a single node
- `ReadOnlyMany (ROX)` — read-only by many nodes
- `ReadWriteMany (RWX)` — read-write by many nodes

**Reclaim policies:**

- `Retain` — PV keeps its data and moves to `Released` after the PVC is deleted; requires manual cleanup or repurposing
- `Delete` — PV and its underlying storage are deleted automatically when the PVC is deleted (default for dynamically provisioned volumes)

---

## Answers to Verify Questions

| Task | Question                                      | Answer                                                                     |
| ---- | --------------------------------------------- | -------------------------------------------------------------------------- |
| 1    | Timestamp same or different after recreation? | Different — `emptyDir` data dies with the Pod                              |
| 2    | STATUS of PV after creation?                  | `Available`                                                                |
| 3    | VOLUME column in `kubectl get pvc`?           | `pv-demo`                                                                  |
| 4    | Data from both Pods present?                  | Yes                                                                        |
| 5    | Default StorageClass?                         | `standard` (provisioner: `rancher.io/local-path`)                          |
| 6    | PV count after dynamic provisioning?          | 2 — one manual (`pv-demo`), one dynamic                                    |
| 7    | Which PV auto-deleted, which retained?        | Dynamic PV deleted (`Delete` policy); `pv-demo` retained (`Retain` policy) |

---

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`
