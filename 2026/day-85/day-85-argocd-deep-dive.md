# Day 85 — ArgoCD Deep Dive: Sync Strategies, Rollbacks, and Multi-App Management

> Reference repo: https://github.com/kalpeshdhotre/AI-BankApp-DevOps (fork, branch `feat/gitops`)
> Cluster: `bankapp-eks`, region `us-west-2` (kept as-is from the forked repo's Terraform defaults)

## Navigation

- [Infra Refresh Notes](#infra-refresh-notes)
- [Task 1: Manual vs Automated Sync](#task-1-manual-vs-automated-sync)
- [Task 2: Sync Waves and Resource Ordering](#task-2-sync-waves-and-resource-ordering)
- [Task 3: ArgoCD Rollback vs `git revert`](#task-3-argocd-rollback-vs-git-revert)
- [Task 4: App of Apps Pattern](#task-4-app-of-apps-pattern)
- [Task 5: ArgoCD Notifications](#task-5-argocd-notifications)
- [Task 6: Projects and RBAC](#task-6-projects-and-rbac)
- [Infra Teardown](#infra-teardown)

---

## Infra Refresh Notes

Before starting today's tasks, the cluster was reprovisioned from scratch via `terraform apply` in the forked repo's `terraform/` directory, which required a full stale-info refresh:

- `terraform init` failed on a locked provider version mismatch (`hashicorp/aws 6.40.0` vs constraint requiring `>= 6.59.0`) — resolved by deleting the fork's stale `.terraform.lock.hcl` and re-running `terraform init` clean.
- `aws eks update-kubeconfig --region us-west-2 --name bankapp-eks` to point kubectl at the new cluster.
- Reinstalled the non-Terraform-managed add-ons: Gateway API CRDs (skipped in the end — Envoy Gateway's own Helm chart bundles and owns them, applying separately caused SSA/CSA field-manager conflicts), cert-manager (with `config.enableGatewayAPI=true` explicitly set, since Gateway API support isn't on by default), Envoy Gateway.
- Applied `k8s/gateway.yml` (twice) — first pass to trigger the LoadBalancer creation, second pass after fetching the real NLB IP via `nslookup` on the LB hostname and updating the `nip.io` hostname in the manifest.
- Opened inbound ports 80/443 on the EKS node security group (NLB forwards straight to NodePort, not 80/443 directly — also had to open the actual NodePort + health-check NodePort) — the ACME HTTP-01 self-check was timing out until this was fixed.
- Discovered mid-troubleshooting that the LB IP had rotated between an earlier check and the actual apply — re-resolved via `nslookup` against `.status.loadBalancer.ingress[0].hostname` and corrected the hostname in Git (had to push the fix since ArgoCD's `selfHeal` was reverting local-only edits).
- Re-applied the ArgoCD `bankapp` Application (with `repoURL` pointed at the fork, `feat/gitops` branch, and `ignoreDifferences` on `spec.replicas` for the HPA-managed Deployment) since ArgoCD itself comes back empty even though it's Terraform-provisioned.
- Result: `bankapp-tls` Certificate issued successfully, `bankapp-gateway` and `bankapp-route` both healthy, ArgoCD showing 18/18 resources Synced and Healthy.

`[SCREENSHOT: ArgoCD bankapp app view — Healthy/Synced, all resources green]`

[⬆ Back to top](#day-85--argocd-deep-dive-sync-strategies-rollbacks-and-multi-app-management)

---

## Task 1: Manual vs Automated Sync

- Switched `bankapp` to manual sync:
  ```bash
  argocd app set bankapp --sync-policy none
  ```
- Added a new, non-breaking key to `k8s/configmap.yml` (`APP_ENV: demo-sync-test`) rather than editing an existing key, to safely demonstrate drift without risking app breakage. Committed and pushed.
- Confirmed ArgoCD detected drift but did **not** auto-correct — `argocd app get bankapp` showed `OutOfSync`.
- Reviewed the diff:
  ```bash
  argocd app diff bankapp
  ```
- Dry-ran and then applied the sync:
  ```bash
  argocd app sync bankapp --dry-run
  argocd app sync bankapp
  ```
- Re-enabled automated sync:
  ```bash
  argocd app set bankapp --sync-policy automated --self-heal --auto-prune
  ```

**Automated vs manual — when to use each:**
| | Automated | Manual |
|---|---|---|
| Use case | Dev/staging | Production |
| Approval | None — syncs within ~3 min of a Git push | Human must run `sync` or click Sync in UI |
| Risk | Fast iteration, no review gate | Slower, but every change is reviewed before hitting the cluster |
| selfHeal | Reverts manual cluster drift automatically | Drift is only detected, not corrected |

![alt text](<md-screenshots/Screenshot From 2026-09-21 13-09-05.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-21 13-09-34.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-21 13-10-01.png>)

[⬆ Back to top](#day-85--argocd-deep-dive-sync-strategies-rollbacks-and-multi-app-management)

---

## Task 2: Sync Waves and Resource Ordering

Added `argocd.argoproj.io/sync-wave` annotations across the AI-BankApp manifests:

| Wave | Resources                   | File(s)                                                                    |
| ---- | --------------------------- | -------------------------------------------------------------------------- |
| `-2` | Namespace, StorageClass     | `k8s/namespace.yml`, `k8s/pv.yml`                                          |
| `-1` | PVCs, ConfigMap, Secret     | `k8s/pvc.yml` (both), `k8s/configmap.yml`, `k8s/secrets.yml`               |
| `0`  | MySQL, Ollama, all Services | `k8s/mysql-deployment.yml`, `k8s/ollama-deployment.yml`, `k8s/service.yml` |
| `1`  | BankApp Deployment          | `k8s/bankapp-deployment.yml`                                               |
| `2`  | HPA                         | `k8s/hpa.yml`                                                              |

Committed as "Sync Wave testing" and pushed. ArgoCD auto-synced and applied resources in wave order, waiting for each wave to be healthy before proceeding to the next.

![alt text](<md-screenshots/Screenshot From 2026-09-21 13-33-25.png>)

[⬆ Back to top](#day-85--argocd-deep-dive-sync-strategies-rollbacks-and-multi-app-management)

---

## Task 3: ArgoCD Rollback vs `git revert`

- Viewed sync history:
  ```bash
  argocd app history bankapp
  ```
- Attempted `argocd app rollback bankapp 4` — **failed initially**: `rollback cannot be initiated when auto-sync is enabled`. Automated sync had to be disabled first:
  ```bash
  argocd app set bankapp --sync-policy none
  argocd app rollback bankapp 4
  ```
- Confirmed the app showed `OutOfSync` post-rollback — cluster reflected an older revision than what Git had.
- Re-enabled automated sync afterward.
- For the GitOps-correct rollback, identified the exact commit adding the Task 1 `APP_ENV` ConfigMap change (not `HEAD`, which was the separate Task 2 sync-wave commit — reverting `HEAD` would have undone the sync-wave annotations, which were deliberately kept since they're harmless for later tasks) and reverted that specific commit:
  ```bash
  git revert <task-1-configmap-commit>
  git push
  ```

**Document — ArgoCD rollback vs `git revert`:**
`argocd app rollback` only rewinds the **live cluster state** — Git still points at the newer commit, so the app immediately flips to `OutOfSync`, and the next automated sync (or a stray manual sync) would silently re-apply the "reverted" change. It also cannot be run at all while automated sync is enabled, since ArgoCD would instantly undo it. `git revert` instead changes the **source of truth** — the rollback is captured in Git history, auditable, and stays consistent under automated sync going forward.

**GitOps-correct approach: `git revert`.** `argocd rollback` is best used as a fast, temporary mitigation (with auto-sync paused) while a proper revert PR is prepared and merged.

![alt text](<md-screenshots/Screenshot From 2026-09-21 13-35-05.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-21 13-36-40.png>)

[⬆ Back to top](#day-85--argocd-deep-dive-sync-strategies-rollbacks-and-multi-app-management)

---

## Task 4: App of Apps Pattern

Created `argocd-apps/` with `bankapp.yml`, `monitoring.yml`, `envoy-gateway.yml`, and a parent `root-app.yaml`.

- Hit a `ComparisonError: repository not found` — traced to the `<your-username>` placeholder left unreplaced in `bankapp.yml` and `root-app.yaml`'s `repoURL`. Fixed with `sed`, committed, pushed, and reapplied.
- Applied the root app:
  ```bash
  kubectl apply -f argocd-apps/root-app.yaml
  ```
- Confirmed all children created:
  ```bash
  argocd app list
  ```
- **Note:** since `root-app`'s source path (`argocd-apps/`) includes its own manifest, it also creates a self-referencing `root-app` child in the tree view. Confirmed harmless (no sync loop, since it's the same manifest applying to itself) — left as-is rather than restructuring into a separate bootstrap path.

![alt text](<md-screenshots/Screenshot From 2026-09-21 13-58-07.png>)

[⬆ Back to top](#day-85--argocd-deep-dive-sync-strategies-rollbacks-and-multi-app-management)

---

## Task 5: ArgoCD Notifications

- Confirmed the notifications controller pod was running.
- Applied the `argocd-notifications-cm` ConfigMap with `on-sync-succeeded`, `on-sync-failed`, and `on-health-degraded` triggers/templates (the ConfigMap already existed from the Terraform/Helm install, so `kubectl apply` patched it — expected warning about a missing last-applied-configuration annotation, not an error).
- Subscribed `bankapp` to all three events:
  ```bash
  kubectl annotate application bankapp -n argocd \
    notifications.argoproj.io/subscribe.on-sync-succeeded.webhook="" \
    notifications.argoproj.io/subscribe.on-sync-failed.webhook="" \
    notifications.argoproj.io/subscribe.on-health-degraded.webhook=""
  ```

![alt text](<md-screenshots/Screenshot From 2026-09-21 14-10-51.png>)

[⬆ Back to top](#day-85--argocd-deep-dive-sync-strategies-rollbacks-and-multi-app-management)

---

## Task 6: Projects and RBAC

- Created `bankapp-team` project, scoped to the fork's repo and the `bankapp`/`monitoring` namespaces only.
- Moved `bankapp` into the project:
  ```bash
  argocd app set bankapp --project bankapp-team
  ```
- Applied the RBAC policy via `argocd-rbac-cm`:
  ```yaml
  policy.csv: |
    p, role:bankapp-dev, applications, get, bankapp-team/*, allow
    p, role:bankapp-dev, applications, sync, bankapp-team/*, allow
    p, role:bankapp-dev, applications, rollback, bankapp-team/*, deny
    g, bankapp-developers, role:bankapp-dev
  ```
- Verified the policy directly via the RBAC simulator (no real SSO/group-mapped user available in this lab setup):
  ```bash
  argocd admin settings rbac can bankapp-developers sync applications bankapp-team/bankapp --namespace argocd       # Yes
  argocd admin settings rbac can bankapp-developers get applications bankapp-team/bankapp --namespace argocd        # Yes
  argocd admin settings rbac can bankapp-developers rollback applications bankapp-team/bankapp --namespace argocd --strict=false   # No
  ```

**Document — how Projects and RBAC prevent cross-team impact:**
Projects scope **what** an Application is allowed to touch — which Git repos it can source from and which cluster/namespace combinations it can deploy to — so `bankapp-team` physically cannot deploy into `kube-system` or another team's namespace, even by mistake. RBAC then scopes **who** can perform which actions inside that project: `bankapp-developers` can view and sync their own apps but are explicitly denied `rollback`, keeping a risky action gated to senior team members. Together, Projects fence the blast radius by namespace/repo, and RBAC fences it by action/role — one team's mistake can't cross into another team's applications or shared infrastructure namespaces.

![alt text](<md-screenshots/Screenshot From 2026-09-21 14-24-22.png>)

[⬆ Back to top](#day-85--argocd-deep-dive-sync-strategies-rollbacks-and-multi-app-management)

---

## Infra Teardown

Following the established convention — delete non-Terraform-managed pieces before destroying the Terraform-managed base, so nothing gets orphaned (dangling ELBs/target groups, stuck finalizers, etc.):

1. **Delete the App of Apps root first** (cascades bankapp, monitoring, envoy-gateway child Applications and their namespaces via the `resources-finalizer.argocd.argoproj.io` finalizer):

   ```bash
   kubectl delete -f argocd-apps/root-app.yaml
   ```

   Confirm all four apps are gone:

   ```bash
   argocd app list
   ```

2. **Remove the Gateway resources** (releases the AWS NLB cleanly rather than letting Terraform try to fight over it):

   ```bash
   kubectl delete -f k8s/gateway.yml
   ```

   Confirm the LoadBalancer service and its NLB are gone:

   ```bash
   kubectl get svc -n envoy-gateway-system
   ```

3. **Uninstall Envoy Gateway:**

   ```bash
   helm uninstall eg -n envoy-gateway-system
   kubectl delete namespace envoy-gateway-system
   ```

4. **Uninstall cert-manager** (also removes its CRDs/webhooks):

   ```bash
   helm uninstall cert-manager -n cert-manager
   kubectl delete namespace cert-manager
   ```

5. **Remove any leftover Gateway API CRDs** (only if they were applied outside the Envoy Gateway chart — check first):

   ```bash
   kubectl get crd | grep gateway.networking.k8s.io
   # if any remain and aren't owned by the eg release:
   kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
   ```

6. **Revert the EKS node security group rules** added for the ACME HTTP-01 challenge (port 80/443/NodePort/health-check port) — optional cleanup, since the SG itself gets destroyed with the node group anyway in the next step, but tidy if reusing the SG:

   ```bash
   aws ec2 revoke-security-group-ingress --group-id sg-0c7dfef4916670a5e --protocol tcp --port 80 --cidr 0.0.0.0/0 --region us-west-2
   aws ec2 revoke-security-group-ingress --group-id sg-0c7dfef4916670a5e --protocol tcp --port 443 --cidr 0.0.0.0/0 --region us-west-2
   ```

7. **Destroy the Terraform-managed infra last** (VPC, EKS cluster, node group, ArgoCD, and the other Terraform add-ons):

   ```bash
   cd terraform/
   terraform destroy
   ```

8. **Verify nothing's left dangling:**
   ```bash
   aws eks list-clusters --region us-west-2
   aws elbv2 describe-load-balancers --region us-west-2
   ```

`[SCREENSHOT: terraform destroy completion output]`

[⬆ Back to top](#day-85--argocd-deep-dive-sync-strategies-rollbacks-and-multi-app-management)
