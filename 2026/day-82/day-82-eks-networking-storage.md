# Day 82 — EKS Networking with Gateway API and Persistent Storage

## Overview

Set up production-grade networking for the AI-BankApp on EKS using the Kubernetes Gateway API (via Envoy Gateway) instead of traditional Ingress, explored cert-manager for automated TLS, and verified EBS persistent storage survives pod restarts.

---

## 1. Gateway API Architecture

```
[Internet]
    |
[AWS NLB] (auto-provisioned by Envoy Gateway on Gateway creation)
    |
[Gateway: bankapp-gateway]
  |-- Listener: HTTP  (port 80)
  |-- Listener: HTTPS (port 443, TLS terminated via bankapp-tls secret)
    |
[HTTPRoute: bankapp-route]  -- matches PathPrefix "/"
    |
[Service: bankapp-service:8080]
    |
[Pods: bankapp x2-4]  (sticky via BANKAPP_AFFINITY cookie)
```

## 2. Gateway API vs Ingress

| Feature           | Ingress              | Gateway API                                            |
| ----------------- | -------------------- | ------------------------------------------------------ |
| API maturity      | Stable but limited   | GA since Kubernetes 1.26                               |
| Traffic splitting | Not supported        | Built-in (weighted backends)                           |
| Header matching   | Annotation-dependent | Native HTTPRoute rules                                 |
| Role separation   | Single resource      | GatewayClass (infra) → Gateway (ops) → HTTPRoute (dev) |
| TLS management    | Annotation-based     | Native TLS config in Gateway listeners                 |
| Session affinity  | Not standardized     | BackendTrafficPolicy (Envoy-specific)                  |

The clearest win is the role separation: infra owns the `GatewayClass`, platform/ops owns the `Gateway` (listeners, TLS), and app teams own the `HTTPRoute` (routing rules) — without needing vendor-specific annotations bolted onto a single Ingress object.

## 3. Gateway API Resources Explained

**GatewayClass** — declares which controller implementation handles Gateways referencing it:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
```

Note: on this Envoy Gateway version (Helm chart v1.4.0), the GatewayClass is **not** auto-created by the Helm install — it had to be applied manually before anything else would work.

**Gateway** (`bankapp-gateway`) — defines the actual load balancer and its listeners (HTTP on 80, HTTPS on 443 terminating TLS). Applying this is what triggers Envoy Gateway to provision an AWS NLB automatically.

**HTTPRoute** (`bankapp-route`) — attaches to both the `http` and `https` listeners via `parentRefs` + `sectionName`, and routes `PathPrefix /` traffic to `bankapp-service:8080`.

**BackendTrafficPolicy** (`bankapp-session`) — configures `ConsistentHash` load balancing keyed on a cookie:

```yaml
loadBalancer:
  type: ConsistentHash
  consistentHash:
    type: Cookie
    cookie:
      name: BANKAPP_AFFINITY
      ttl: 3600s
```

## 4. Why Session Affinity Matters Here

BankApp uses Spring Security with form-based login, which stores session state server-side (`JSESSIONID`). Without pod-sticky routing, a user's subsequent requests could land on a different pod than the one holding their session, silently logging them out. The `BANKAPP_AFFINITY` cookie — set by Envoy on the first response — ensures all requests from a given browser session are consistently hashed to the same backend pod.

Verified live with `curl -v`: the response included both `JSESSIONID` (app-level) and `BANKAPP_AFFINITY` (Envoy-level) cookies, with a `302` redirect to `/login` confirming the app is reachable and routing correctly through the full chain.

## 5. Gateway Status — NLB Provisioned

`kubectl get gateway -n bankapp` showing the NLB address assigned and `PROGRAMMED: True`:

![alt text](<md-screenshots/Screenshot From 2026-09-14 18-29-52.png>)

**Gotcha hit:** the HTTPRoute's `hostname` field (`<ip>.nip.io`) has to exactly match the _current_ NLB's resolved IP — since NLBs get reprovisioned with new IPs on every cluster recreation, a stale hostname in `gateway.yml` causes Envoy to return a silent `404` (no route matched) even though the NLB itself is reachable. Fixed by resolving the live NLB IP with `dig` and updating both the Gateway listener hostname and HTTPRoute hostname to match before reapplying.

## 6. cert-manager and Automated TLS

Installed via Helm with CRDs enabled:

```bash
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true --wait
```

**How the ClusterIssuer automates HTTPS:**

1. cert-manager requests a certificate from Let's Encrypt for the Gateway's hostname.
2. Let's Encrypt issues an HTTP-01 challenge.
3. cert-manager creates a temporary HTTPRoute (via the `gatewayHTTPRoute` solver, targeting `bankapp-gateway`) to respond to the challenge.
4. Let's Encrypt verifies the challenge response and issues the certificate.
5. The certificate is stored in the `bankapp-tls` Kubernetes Secret.
6. The Gateway's HTTPS listener consumes that Secret to terminate TLS.

Until the certificate exists, the Gateway's `https` listener correctly reports `NoReadyListeners` in the HTTPRoute status — confirming the Gateway won't advertise a broken HTTPS listener while waiting on the cert.

## 7. EBS Persistent Storage

**Storage flow:** StorageClass (`gp3`) → PVC (`mysql-pvc` 5Gi, `ollama-pvc` 10Gi) → dynamically provisioned PV → EBS volume → mounted into the pod.

`kubectl get pvc -n bankapp` showing both volumes bound:

![alt text](<md-screenshots/Screenshot From 2026-09-14 18-51-09.png>)

![alt text](<md-screenshots/Screenshot From 2026-09-14 20-50-31.png>)

Cross-verified against the actual EBS volumes in AWS — both present, correctly sized (5Gi / 10Gi), `gp3` type, and tagged with `kubernetes.io/cluster/bankapp-eks: owned` and `ebs.csi.aws.com/cluster-name` for CSI ownership.

**Key concepts:**

- `WaitForFirstConsumer` binds the volume in the same AZ as the pod it's claimed by, avoiding cross-AZ attach failures.
- `ReadWriteOnce` means an EBS volume attaches to one node at a time — the reason MySQL and Ollama use the `Recreate` deployment strategy (old pod must fully terminate, releasing the volume, before the new pod can attach it).
- `gp3` is the current-generation SSD type: 3000 IOPS baseline, cheaper than `gp2`.
- `allowVolumeExpansion: true` lets volumes grow without needing to be recreated.

**Persistence test:** deleted the MySQL pod and confirmed `SHOW DATABASES` returned identical results before and after — the EBS volume persisted independently of the pod lifecycle.

## 8. Resource Budget (3x t3.medium nodes)

| Component           | CPU Request         | Memory Request     | Instances |
| ------------------- | ------------------- | ------------------ | --------- |
| BankApp             | 250m                | 256Mi              | 2–4 pods  |
| MySQL               | 250m                | 256Mi              | 1 pod     |
| Ollama              | 900m                | 2Gi                | 1 pod     |
| Init containers     | 50m                 | 32Mi               | temporary |
| System pods         | ~500m               | ~500Mi             | per node  |
| **Total available** | **6000m (3 nodes)** | **12Gi (3 nodes)** |           |

Ollama is the single heaviest consumer on the cluster. Scaling BankApp to its max of 4 pods pushes total CPU requests to roughly 2.9 cores plus per-node system overhead — comfortably inside the 6-core budget, but worth watching if more workloads are added later.

## 9. Troubleshooting Notes (real issues hit today)

- **Stale kubeconfig after cluster recreation:** destroying and reapplying Terraform gives the cluster a new API endpoint; `aws eks update-kubeconfig --name bankapp-eks --region us-east-1` is required before any `kubectl`/`helm` command will work again.
- **GatewayClass not auto-created:** unlike what the reference material assumed, Envoy Gateway v1.4.0's Helm chart does not automatically register the `envoy-gateway` GatewayClass — it needs to be applied manually.
- **Hostname/IP drift on cluster recreation:** the NLB gets a new IP every time the Gateway is recreated; `gateway.yml`'s hardcoded `nip.io` hostname has to be updated to match, or routing silently 404s.
- **Wrong region in the EBS CLI filter:** confirmed the cluster is consistently `us-east-1` throughout (not `us-west-2`), and the EBS tag filter key differs from the reference doc — actual tag is `kubernetes.io/cluster/bankapp-eks: owned`, not `kubernetes.io/created-by`.

---

## Summary

Gateway API + Envoy Gateway gave the AI-BankApp production-style ingress with native TLS listener config and cookie-based session affinity — cleaner and more explicit than Ingress annotations. cert-manager automates certificate issuance end-to-end via the Gateway API's HTTPRoute-based ACME solver. EBS-backed storage confirmed durable across pod restarts, with `WaitForFirstConsumer` and `ReadWriteOnce` driving the `Recreate` strategy for stateful components.
