# Day 89 — Production AI Agents: KubeHealer and AIOps

**Modules 4–5** | Reference: [agentic-ai-for-devops](https://github.com/TrainWithShubham/agentic-ai-for-devops) | Repo: [kubehealer](https://github.com/TrainWithShubham/kubehealer)

## Navigation

- [AIOps Principles & Guardrails](#aiops-principles--guardrails)
- [KubeHealer Architecture](#kubehealer-architecture)
- [LLM Backend: AWS Bedrock instead of Anthropic API](#llm-backend-aws-bedrock-instead-of-anthropic-api)
- [The 3 Broken Apps & Diagnoses](#the-3-broken-apps--diagnoses)
- [Human Approval Gate](#human-approval-gate)
- [Crash Recovery (Temporal Durability)](#crash-recovery-temporal-durability)
- [AI Agents vs Traditional Automation](#ai-agents-vs-traditional-automation)
- [How This Connects to the 90-Day Challenge](#how-this-connects-to-the-90-day-challenge)
- [Screenshots](#screenshots)

---

## AIOps Principles & Guardrails

AIOps uses AI to automate IT operations — monitoring, diagnosis, remediation — augmenting human operators rather than replacing them. The agent handles routine issues (image typos, resource limits) and escalates anything it can't safely resolve.

**The 6 production guardrails, and how KubeHealer implements each:**

| Guardrail              | Why                                       | In KubeHealer                                                                                                                 |
| ---------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Human approval         | No destructive changes without permission | `HealerWorkflow`'s `auto_approve` flag + `approve_pod`/`reject_pod` signals gate `execute_fix`                                |
| Scope limits           | Restrict allowed namespaces/clusters      | Workflow only scans/patches the passed `--namespace`                                                                          |
| Audit trail            | Every action recorded                     | Temporal workflow history — every activity, input/output, decision                                                            |
| Rollback capability    | Every fix reversible                      | `execute_fix` uses `kubectl patch`-style targeted changes, not delete/recreate                                                |
| Timeout & retry limits | No infinite loops                         | `diagnose_pod` has `RetryPolicy(maximum_attempts=3)`; `execute_fix` and `scan_cluster` have explicit `start_to_close_timeout` |
| Escalation path        | Alert a human when it can't fix           | `config-app`'s missing ConfigMap is diagnosed with `action: skip` and reported, never guessed at                              |

Durable execution (Temporal) matters because a mid-diagnosis crash would otherwise lose all progress. With Temporal, every step is recorded in workflow history — on restart, it replays completed activities and resumes exactly where it left off, which is critical when the agent is actively modifying live infrastructure.

[↑ Back to top](#day-89--production-ai-agents-kubehealer-and-aiops)

---

## KubeHealer Architecture

```
scan_cluster → get_pod_details → diagnose_pod (Claude) → [approval gate] → execute_fix (kubectl patch)
```

- **Temporal** orchestrates the workflow (`HealerWorkflow` for one-shot healing, `ConversationWorkflow` for the interactive `cli.py` agent) and gives it durability.
- **Claude** (via `diagnose_pod` / `call_claude` activities) reasons over pod diagnostics and proposes a fix as structured JSON (`action`, `fix_details`, `explanation`).
- **kubectl / the Kubernetes Python client** executes the approved fix as a targeted patch on the owning Deployment.

![alt text](<md-screenshots/Screenshot From 2026-09-24 13-57-18.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-24 13-58-48.png>)

[↑ Back to top](#day-89--production-ai-agents-kubehealer-and-aiops)

---

## LLM Backend: AWS Bedrock instead of Anthropic API

Rather than an Anthropic Console API key, this run used **Amazon Bedrock** as the LLM backend — same underlying Claude model, routed through AWS instead of `api.anthropic.com`.

**Setup:**

1. Enabled Claude Sonnet 4.6 model access in Bedrock (`us-east-1`) via **Bedrock → Model access**.
2. Confirmed IAM permissions (`bedrock:InvokeModel`) on the existing AWS CLI identity.
3. Since Bedrock's Claude models require an **inference profile** rather than a bare model ID, resolved the profile:
   ```bash
   aws bedrock list-inference-profiles --region us-east-1 \
     --query "inferenceProfileSummaries[?contains(inferenceProfileId,'claude-sonnet-4-6')]"
   ```
   → used `us.anthropic.claude-sonnet-4-6`.
4. Installed `anthropic[bedrock]` and swapped the client in `activities/llm_activities.py` and `activities/chat_activities.py`:
   ```python
   from anthropic import AnthropicBedrock
   ai = AnthropicBedrock(aws_region="us-east-1")
   # model="us.anthropic.claude-sonnet-4-6"
   ```
5. Credentials resolved automatically from the active AWS CLI session — no separate key management needed in `.env` beyond `AWS_REGION`.
6. Updated `worker.py`'s preflight check to validate AWS credentials (`sts get-caller-identity`) instead of `ANTHROPIC_API_KEY`.

This is a real-world variant of the exercise worth calling out: routing an agent's LLM calls through Bedrock instead of the vendor's own API is a common production pattern for teams that want to consolidate billing/IAM/observability under their existing cloud account rather than manage a separate API key and invoice.

![alt text](<md-screenshots/Screenshot From 2026-09-24 15-36-33.png>)

[↑ Back to top](#day-89--production-ai-agents-kubehealer-and-aiops)

---

## The 3 Broken Apps & Diagnoses

| Pod          | Fault injected                            | Claude's diagnosis                                                                                             | Action taken                            |
| ------------ | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| `web-app`    | Image typo (`ngnix:latest`)               | Image name typo causing `ImagePullBackOff`                                                                     | `fix_image` → patched to `nginx:latest` |
| `memory-app` | Memory limit `1Mi`                        | Memory limit far below what the container needs, causing `OOMKilled`                                           | `patch_resources` → patched to `128Mi`  |
| `config-app` | References missing ConfigMap `app-config` | Pod cannot start without a ConfigMap that doesn't exist; creating arbitrary config data isn't safe to automate | `skip` — escalated for manual creation  |

**Note (found during the lab):** `web-app` and `memory-app` had to be deployed as **Deployments**, not bare Pods — `execute_fix`'s `fix_image`/`patch_resources` actions patch the owning Deployment via `ownerReferences` (Pod → ReplicaSet → Deployment), so a bare Pod has nothing to patch and the fix loops on a 404. `config-app` is fine as a bare Pod since its outcome is always `skip`.

![alt text](<md-screenshots/Screenshot From 2026-09-24 18-58-34.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-24 18-58-54.png>)

[↑ Back to top](#day-89--production-ai-agents-kubehealer-and-aiops)

---

## Human Approval Gate

`starter.py`, as shipped, hardcodes `auto_approve=True` — it always auto-heals with no prompt. The interactive "Approve all fixes? [yes/no]" flow described in the lab README only exists through **`cli.py`**'s conversational agent, or by driving `HealerWorkflow`'s existing `approve_pod`/`reject_pod` signals and `get_state` query directly.

Built a small companion script (`starter_interactive.py`) that starts the workflow with `auto_approve=False`, polls `get_state` until diagnosis completes, prints the same `Found N broken pods / Proposed fixes / Approve all fixes?` prompt as the README, and signals each pod's decision back into the running workflow based on the human's answer — closing the gap between the README's described behavior and `starter.py`'s actual one-shot design.

[↑ Back to top](#day-89--production-ai-agents-kubehealer-and-aiops)

---

## Crash Recovery (Temporal Durability)

Redeployed the broken apps, started the worker and a healing run, then killed the worker mid-diagnosis (`Ctrl+C` / `kill`). On restart, Temporal replayed the completed activities (scan, diagnose) from event history and resumed the workflow exactly where it left off — no lost state, no re-diagnosis, no duplicate Claude calls for already-completed steps.

Verified in the Temporal UI (`http://localhost:8233`): the workflow history shows every activity execution, its input/output, the crash point, and the resume — a complete audit trail generated automatically, with no logging code written by hand.

![alt text](<md-screenshots/Screenshot From 2026-09-24 19-22-41.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-24 19-24-14.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-24 19-24-19.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-24 19-25-07.png>)

[↑ Back to top](#day-89--production-ai-agents-kubehealer-and-aiops)

---

## AI Agents vs Traditional Automation

| Use AI Agents                          | Use Traditional Automation                |
| -------------------------------------- | ----------------------------------------- |
| Requires reasoning over unknown errors | Known, fixed solution exists              |
| Multiple possible causes/fixes         | One cause → one fix                       |
| Natural-language output helps humans   | No human in the loop                      |
| e.g. diagnosing _why_ a pod is broken  | e.g. scaling, restarts, scheduled deploys |

KubeHealer sits exactly at this boundary: diagnosis needs reasoning (Claude), but the actual fix — once known — is a deterministic `kubectl patch`. Good agent design keeps the LLM in the reasoning seat and hands mechanical execution to plain code with validation (`_validate_fix` in `k8s_activities.py` checks image names and memory values against regex before ever touching the cluster).

[↑ Back to top](#day-89--production-ai-agents-kubehealer-and-aiops)

---

## How This Connects to the 90-Day Challenge

| Day(s)                 | Connection                                                                                                 |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| 29–37 (Docker)         | Docker tools wrap the same commands KubeHealer's activities wrap for Kubernetes                            |
| 40–49 (GitHub Actions) | Same CI/CD Failure Analyzer pattern (Day 88) applies to pipeline diagnosis                                 |
| 50–67 (Kubernetes)     | KubeHealer's `k8s_activities.py` uses the same `kubectl`/Python client fundamentals                        |
| 73–77 (Observability)  | An agent could query Prometheus/Loki for metric-based diagnosis, same pattern as `get_pod_events_activity` |
| 84–86 (ArgoCD)         | An agent could trigger ArgoCD syncs or rollbacks the same way `execute_fix` patches Deployments            |

**Evolution across Days 87–89:** LLM explains errors (passive) → Agent diagnoses across Docker/K8s/CI (autonomous investigation) → Agent diagnoses **and** fixes with human approval (autonomous action, guarded).

[↑ Back to top](#day-89--production-ai-agents-kubehealer-and-aiops)

---

## Screenshots

1. **Temporal installation** — `temporal server start-dev` running locally
   `![Temporal installation](screenshots/01-temporal-install.png)`
2. **Temporal Web UI** — `http://localhost:8233` overview
   `![Temporal Web UI](screenshots/02-temporal-webui.png)`
3. **First `starter.py` healing run + Temporal workflow screen**
   `![starter.py healing pods](screenshots/03-starter-healing.png)`
4. **Worker screen** — `worker.py` running, preflight checks passing (AWS credentials + Kubernetes)
   `![Worker running](screenshots/04-worker-running.png)`
5. **Interrupt worker + resume screen** — crash recovery in the Temporal UI
   `![Crash recovery](screenshots/05-crash-recovery.png)`
6. **One worker interrupted, one running** — demonstrating durability mid-transition
   `![Interrupted and running](screenshots/06-worker-interrupted-running.png)`
7. **Workflows list** — Temporal UI showing all runs from the session
   `![Workflows list](screenshots/07-workflows-list.png)`
8. **CLI screen with `worker.py` interrupted** — `cli.py` behavior during a worker outage
   `![CLI with worker interrupted](screenshots/08-cli-worker-interrupted.png)`

[↑ Back to top](#day-89--production-ai-agents-kubehealer-and-aiops)

---

## Submission

1. Add `day-89-kubehealer-aiops.md` (with screenshots in `2026/day-89/screenshots/`) to `2026/day-89/`
2. Commit and push to your fork

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`
