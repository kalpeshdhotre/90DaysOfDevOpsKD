# Day 84 — Introduction to GitOps and ArgoCD

> Deployed the AI-BankApp on EKS through ArgoCD, replacing manual `kubectl apply` with a Git-driven, self-healing reconciliation loop — then debugged a full chain of real-world GitOps issues along the way.

## Navigation

- [Task 1: GitOps Principles](#task-1-gitops-principles)
- [Task 2: Accessing ArgoCD](#task-2-accessing-argocd)
- [Task 3: The Application Manifest](#task-3-the-application-manifest)
- [Task 4: Deploying via ArgoCD](#task-4-deploying-via-argocd)
- [Task 5: Exploring the Live View](#task-5-exploring-the-live-view)
- [Task 6: Self-Healing Tests](#task-6-self-healing-tests)
- [Real-World Debugging Log](#real-world-debugging-log)
- [Key Learnings](#key-learnings)
- [Teardown](#teardown)

---

## Task 1: GitOps Principles

[Back to top](#day-84--introduction-to-gitops-and-argocd)

**What is GitOps:** Git becomes the single source of truth for both infra and app state. ArgoCD continuously watches the repo and reconciles the live cluster to match it. Any manual change made directly to the cluster gets reverted — this is _self-healing_. Every change flows through Git: pull requests, code review, a full audit trail.

**GitOps vs traditional CI/CD:**

| Aspect             | Traditional CI/CD                | GitOps                             |
| ------------------ | -------------------------------- | ---------------------------------- |
| Deployment trigger | CI pipeline runs `kubectl apply` | Git commit triggers sync           |
| Source of truth    | Pipeline scripts                 | Git repository                     |
| Drift detection    | None                             | Continuous reconciliation          |
| Rollback           | Re-run pipeline / manual         | `git revert`                       |
| Audit trail        | Pipeline logs                    | Git history                        |
| Access control     | Pipeline needs cluster creds     | Only ArgoCD has cluster access     |
| Security           | CI server has broad access       | Devs push to Git, never to cluster |

**AI-BankApp's GitOps flow:**

```
Developer pushes to feat/gitops
        │
  GitHub Actions CI
   - build, test
   - build & push Docker image
   - update image tag in k8s/
   - commit back to Git
        │
  ArgoCD watches repo
   - detects new commit
   - diffs manifests vs cluster
   - syncs (rolling update)
        │
  Zero human intervention after push
```

**Four OpenGitOps principles:** Declarative, Versioned & immutable, Pulled automatically, Continuously reconciled.

---

## Task 2: Accessing ArgoCD

[Back to top](#day-84--introduction-to-gitops-and-argocd)

ArgoCD ships via the `terraform/` folder's `helm_release.argocd` resource (chart `argo-cd` v10.9.2, LoadBalancer service). Accessed the UI via `kubectl port-forward svc/argocd-server -n argocd 8443:443` and logged into `https://localhost:8443` with the auto-generated admin secret.

![alt text](<md-screenshots/Screenshot From 2026-09-20 18-24-28.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-20 18-24-41.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-20 18-24-48.png>)

---

## Task 3: The Application Manifest

[Back to top](#day-84--introduction-to-gitops-and-argocd)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bankapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: <fork-url>
    targetRevision: feat/gitops
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: bankapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

| Field                                        | Purpose                                          |
| -------------------------------------------- | ------------------------------------------------ |
| `source.repoURL` / `targetRevision` / `path` | Which repo, branch, and directory ArgoCD watches |
| `destination.namespace`                      | Target namespace (`bankapp`), auto-created       |
| `prune: true`                                | Deletes cluster resources removed from Git       |
| `selfHeal: true`                             | Reverts manual, out-of-band cluster edits        |
| `ServerSideApply=true`                       | Cleaner conflict handling across controllers     |

---

## Task 4: Deploying via ArgoCD

[Back to top](#day-84--introduction-to-gitops-and-argocd)

Forked `AI-BankApp-DevOps`, applied the `Application` manifest pointing at the fork (`feat/gitops` branch), and let ArgoCD sync.

![alt text](<md-screenshots/Screenshot From 2026-09-20 21-08-25.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-20 21-08-33.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-20 20-59-08.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-20 20-59-16.png>)

---

## Task 5: Exploring the Live View

[Back to top](#day-84--introduction-to-gitops-and-argocd)

Explored the resource tree (Deployments → ReplicaSets → Pods, Services, PVCs, HPA, Gateway, HTTPRoute, Certificate), live pod logs, diffs, and sync history via `argocd app history bankapp`.

---

## Task 6: Self-Healing Tests

[Back to top](#day-84--introduction-to-gitops-and-argocd)

| Test             | Action                                          | Result                                        | Revert Time |
| ---------------- | ----------------------------------------------- | --------------------------------------------- | ----------- |
| Scale down       | `kubectl scale deployment bankapp --replicas=1` | ArgoCD detected drift, restored replica count | ~3–5 min    |
| Delete ConfigMap | `kubectl delete configmap bankapp-config`       | Recreated from Git automatically              | < 3 min     |
| Edit env var     | Changed `MYSQL_DATABASE` in ConfigMap directly  | Overwritten back to the Git-defined value     | < 3 min     |

Confirmed the core GitOps promise: manual cluster changes do not survive. Everything must go through Git.

![alt text](<md-screenshots/Screenshot From 2026-09-20 21-09-37.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-20 21-12-32.png>)

---

## Real-World Debugging Log

[Back to top](#day-84--introduction-to-gitops-and-argocd)

This deployment surfaced a realistic chain of GitOps/infra issues worth documenting — none of these were in the original task brief, all encountered live:

**1. Fork missed non-default branches.** GitHub forks only copy the default branch unless "copy all branches" is checked. `feat/gitops` was missing → `ComparisonError: unable to resolve 'feat/gitops' to a commit SHA`. Fixed by re-forking with all branches included.

**2. Missing CRDs for cert-manager and Gateway API.** ArgoCD's manifests referenced `cert-manager.io/v1`, `gateway.networking.k8s.io/v1`, and `gateway.envoyproxy.io/v1alpha1` resources, but none of the controllers were installed on the freshly re-provisioned cluster (Day 83's infra had been destroyed and recreated — `terraform apply` from Day 81's config only provisions VPC/EKS/node group/ArgoCD, **not** cert-manager or Envoy Gateway, which are separate Helm installs and raw manifests applied outside Terraform). Installed in order: Gateway API CRDs → Envoy Gateway Helm chart → cert-manager Helm chart (with CRDs) → `k8s/cert-manager.yml` (ClusterIssuer) → `k8s/gateway.yml`.

**3. Helm/kubectl field-manager conflict.** Manually `kubectl apply`-ing the Gateway API CRDs before Envoy Gateway's Helm install caused a server-side-apply ownership conflict on the same CRDs. Fixed by deleting the manually-applied CRDs and letting Helm own them from install.

**4. Stale Load Balancer IP (`nip.io` pattern).** The Gateway/Certificate/HTTPRoute referenced a hardcoded `<ip>.nip.io` hostname. Every time the `bankapp` Application (and its underlying NLB) was deleted and recreated, the LB got a **new IP**, breaking TLS cert issuance (`NoMatchingListenerHostname`) and routing (`403` from an unrelated AWS-internal endpoint once the old IP was reassigned to another AWS service). Root cause: NLB IPs are not static. Fixed each time by resolving the Gateway's live `status.addresses` hostname to its current IP and updating the manifest. **Key takeaway:** an IP-pinned `nip.io` hostname is fragile across LB recreation — a Route53 alias or using the ELB hostname directly would be far more resilient.

**5. HPA vs ArgoCD `selfHeal` fighting over `spec.replicas`.** With `selfHeal: true` and no `ignoreDifferences`, ArgoCD treated HPA's scaling decisions as drift from Git and reverted them, while HPA kept trying to scale — a continuous pod-cycling loop, compounded by `FailedGetResourceMetric` errors (HPA couldn't read CPU from not-yet-ready pods, causing further erratic rescaling). Fixed with:

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      name: bankapp
      jsonPointers:
        - /spec/replicas
```

This tells ArgoCD to leave `spec.replicas` entirely to the HPA controller — a standard, necessary pattern whenever GitOps and horizontal autoscaling coexist on the same resource.

**6. Cosmetic Envoy Gateway v1.1.0 status lag.** Observed a case where the Gateway's own per-listener status (`Programmed: True`, `attachedRoutes: 1`) was fully healthy and traffic worked correctly, while the HTTPRoute's own status still reported a stale `NoMatchingListenerHostname` — resolved itself after a subsequent full resync. Documented as a known status-reporting quirk in this version rather than a real routing failure, verified via direct `curl` testing against the live endpoint.

---

## Key Learnings

[Back to top](#day-84--introduction-to-gitops-and-argocd)

- GitOps eliminates "who ran kubectl and when" — but debugging shifts from imperative commands to reading declarative status conditions (`kubectl describe`, ArgoCD's health/sync badges) — a different skill.
- Not everything in a real cluster is Terraform-managed; identifying what's IaC vs Helm vs raw manifests vs ArgoCD-managed is essential before any teardown or infra recreation.
- `selfHeal: true` is powerful but needs `ignoreDifferences` wherever another controller (HPA, cert-manager, etc.) legitimately owns a field ArgoCD would otherwise "correct."
- Cloud LB IPs are not stable identifiers — hardcoding them into TLS/routing config (`nip.io` pattern) is fine for quick demos but breaks on any infra churn.
- ArgoCD's resource health status can occasionally lag the underlying controller's own status — worth verifying real traffic before trusting a red badge as ground truth.

---

## Teardown

[Back to top](#day-84--introduction-to-gitops-and-argocd)

Since cert-manager, Envoy Gateway, and Gateway API CRDs were installed outside Terraform (Helm + raw manifests), `terraform destroy` alone leaves them orphaned. Correct order:

```bash
# 1. Delete ArgoCD-managed Application (cascades to bankapp namespace resources)
kubectl delete application bankapp -n argocd
kubectl get namespace bankapp   # wait until gone

# 2. Remove Gateway API custom resources
kubectl delete -f k8s/gateway.yml --ignore-not-found

# 3. Uninstall Envoy Gateway
helm uninstall eg -n envoy-gateway-system
kubectl delete namespace envoy-gateway-system --ignore-not-found

# 4. Uninstall cert-manager + ClusterIssuer
kubectl delete -f k8s/cert-manager.yml --ignore-not-found
helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager --ignore-not-found

# 5. Remove Gateway API CRDs
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml --ignore-not-found

# 6. Verify clean before touching Terraform
kubectl get ns
kubectl get crd | grep -E "cert-manager|gateway"

# 7. Destroy Terraform-managed infra (VPC, EKS, node group, ArgoCD, EBS CSI IRSA)
cd day-81/AI-BankApp-DevOps/terraform
terraform destroy

# 8. Clean up local kubeconfig
kubectl config delete-context arn:aws:eks:us-east-1:115655017925:cluster/bankapp-eks
kubectl config delete-cluster arn:aws:eks:us-east-1:115655017925:cluster/bankapp-eks
```
