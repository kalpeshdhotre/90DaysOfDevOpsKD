# Day 53 – Kubernetes Services

## What Problem Do Services Solve?

Pods are unreliable as network endpoints for two reasons:

1. **Pod IPs are not stable** — when a Pod restarts or gets replaced, it gets a brand new IP.
2. **A Deployment runs multiple Pods** — there's no single IP to send traffic to.

A **Service** sits in front of a set of Pods (matched via a label `selector`) and gives them:

- A **stable virtual IP and DNS name** that never changes, no matter how many times the underlying Pods restart
- **Load balancing** across every healthy Pod that matches the selector

```
[Client] --> [Service (stable IP)] --> [Pod 1]
                                   --> [Pod 2]
                                   --> [Pod 3]
```

Deployments manage the Pods (how many replicas, how to update them); Services manage how traffic reaches those Pods. They're decoupled on purpose — you can scale, replace, or reschedule Pods freely and the Service endpoint never changes.

---

## Task 1: Deploy the Application

`app-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

3 Nginx Pods came up, each with its own Pod IP — confirmed those IPs are exactly the kind of thing that changes on restart, which is the whole reason Services exist.

![alt text](<Screenshot From 2026-07-14 19-40-05.png>)

---

## Task 2: ClusterIP Service (Internal Access)

`clusterip-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-clusterip
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
    - port: 80
      targetPort: 80
```

- `selector.app: web-app` routes traffic to every Pod carrying that label
- `port` is what the Service listens on; `targetPort` is what the container listens on

Tested from inside the cluster with a throwaway Pod:

```bash
kubectl run test-client --image=busybox:latest --rm -it --restart=Never -- sh
wget -qO- http://web-app-clusterip
```

Got the Nginx welcome page back. Ran it a few times — same Service IP every time, but the request landed on different Pods, which is the load-balancing in action.

## ![alt text](<Screenshot From 2026-07-14 19-43-36.png>)

## Task 3: Service Discovery via DNS

Every Service gets an automatic DNS entry:

```
<service-name>.<namespace>.svc.cluster.local
```

```bash
wget -qO- http://web-app-clusterip
wget -qO- http://web-app-clusterip.default.svc.cluster.local
nslookup web-app-clusterip
```

Both the short name and the full DNS name resolved to the same address, and `nslookup` matched the CLUSTER-IP shown by `kubectl get services`. Short name works fine within the same namespace; the full name is what you'd use to reach a Service in a different namespace.

![alt text](<Screenshot From 2026-07-14 19-45-12.png>)

---

## Task 4: NodePort Service

`nodeport-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-nodeport
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

**Technical callout:** on a `kind` cluster, `curl http://localhost:30080` does **not** work out of the box the way it does on Minikube or Docker Desktop — `kind` runs nodes as Docker containers and doesn't map NodePort ranges to the host unless the cluster config explicitly sets `extraPortMappings`. Worked around it with:

```bash
kubectl port-forward service/web-app-nodeport 8080:80
curl http://localhost:8080
```

Confirmed the Nginx page loaded through the forwarded port.

![alt text](<Screenshot From 2026-07-14 19-48-55.png>)

---

## Task 5: LoadBalancer Service

`loadbalancer-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: web-app
  ports:
    - port: 80
      targetPort: 80
```

EXTERNAL-IP stayed `<pending>` — expected, since there's no cloud provider on a local `kind` cluster to actually provision a load balancer. In a real EKS/GKE/AKS cluster this field would populate with a public IP or hostname.

## ![alt text](<Screenshot From 2026-07-14 19-50-33.png>)

## Task 6: Comparing All Three + Endpoints

```bash
kubectl get services -o wide
kubectl describe service web-app-loadbalancer
kubectl get endpoints
```

`kubectl describe service web-app-loadbalancer` confirmed the LoadBalancer Service also carries its own ClusterIP and NodePort — each Service type layers on top of the previous one (LoadBalancer → NodePort → ClusterIP).

`kubectl get endpoints` showed the actual Pod IPs each Service is currently routing to — this is the real-time mapping between a Service's selector and the Pods it matches.

| Type         | Accessible From                                                 | Use Case                                      |
| ------------ | --------------------------------------------------------------- | --------------------------------------------- |
| ClusterIP    | Inside the cluster only                                         | Internal service-to-service traffic           |
| NodePort     | `<NodeIP>:<NodePort>` (port-forward/docker exec needed on kind) | Dev/testing, direct node access               |
| LoadBalancer | Cloud load balancer (pending on local clusters)                 | Production traffic in real cloud environments |

## ![alt text](<Screenshot From 2026-07-14 19-52-09.png>)

## Task 7: Clean Up

```bash
kubectl delete -f app-deployment.yaml
kubectl delete -f clusterip-service.yaml
kubectl delete -f nodeport-service.yaml
kubectl delete -f loadbalancer-service.yaml
```

Confirmed only the built-in `kubernetes` Service remained in the default namespace after cleanup.

---

## Key Takeaways

- Services give Pods a stable identity that survives restarts — Deployments manage _what_ runs, Services manage _how it's reached_
- ClusterIP is the default and is only reachable from inside the cluster
- NodePort opens a port on every node — but on `kind`, that doesn't auto-map to `localhost` like it does on Minikube/Docker Desktop, so port-forwarding is the practical workaround
- LoadBalancer builds on top of NodePort and ClusterIP — it's the same chain each time, just with more infrastructure added at the top
- `kubectl get endpoints` is the fastest way to debug a Service that isn't routing traffic — if it's empty, the selector doesn't match any Pod labels
