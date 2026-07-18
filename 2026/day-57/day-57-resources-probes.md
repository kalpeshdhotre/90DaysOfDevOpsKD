# Day 57 – Resource Requests, Limits, and Probes

Cluster: `kind` on Ubuntu 26.04 LTS

---

## Requests vs Limits — Scheduling vs Enforcement

- **Requests** are what the scheduler uses to decide _where_ a Pod can fit. Every node needs enough allocatable CPU/memory left to cover the sum of requests of the Pods already placed on it plus the new one.
- **Limits** are what the kubelet enforces at _runtime_ once the Pod is already running, capping how much CPU/memory the container is allowed to actually use.
- Requests are a promise to the scheduler. Limits are a ceiling enforced by the node.

**QoS classes**, derived automatically from how requests/limits compare:
| Requests vs Limits | QoS Class |
|---|---|
| Not set | `BestEffort` |
| Set and equal | `Guaranteed` |
| Set and requests < limits | `Burstable` |

Deployed a Pod with `requests: cpu 100m / memory 128Mi` and `limits: cpu 250m / memory 256Mi`. Since requests and limits differ, `kubectl describe pod` reported:

**QoS Class: `Burstable`**
![alt text](<Screenshot From 2026-07-18 18-34-35.png>)

---

## What Happens When Limits Are Exceeded

CPU and memory are enforced very differently:

- **CPU is compressible.** Going over the CPU limit doesn't kill anything — the kernel just throttles the container's CPU time via cgroups. The process slows down but keeps running.
- **Memory is incompressible.** There's no way to "throttle" memory the same way. If a container exceeds its memory limit, the kernel OOM-killer terminates it immediately — no warning, no grace period.

Ran `polinux/stress` with a `100Mi` memory limit and told it to allocate `200M`. The container was killed almost instantly. `kubectl describe pod` showed:

```
State:      Terminated
Reason:     OOMKilled
Exit Code:  137
```

**Exit code 137 = 128 + 9 (SIGKILL)** — this is the standard signature of an OOM kill anywhere in Linux, not just Kubernetes.

Also tested the opposite failure mode: requested `cpu: 100` and `memory: 128Gi` on a single-node cluster with nowhere near that capacity. The Pod stayed `Pending` forever. The scheduler's event explained exactly why:

```
Warning  FailedScheduling  46s  default-scheduler
0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory.
no new claims to deallocate, preemption: 0/1 nodes are available:
1 Preemption is not helpful for scheduling.
```

![alt text](<Screenshot From 2026-07-18 18-34-35-1.png>)

Unlike an OOMKilled Pod, an unschedulable Pod never even starts — it just sits at `Pending` with zero containers running, since the scheduler can't find a node that can honor the resource request.

---

## Liveness vs Readiness vs Startup Probes

These three probes look similar but control completely different behavior:

| Probe         | Failure means                             | Action taken                                                                                                     |
| ------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Liveness**  | "Container is stuck/deadlocked"           | Kubernetes **restarts** the container                                                                            |
| **Readiness** | "Container can't serve traffic right now" | Pod is **removed from Service endpoints** — container keeps running                                              |
| **Startup**   | "Container hasn't finished starting yet"  | Liveness/readiness are **disabled** until it succeeds, or the container is killed if the startup budget runs out |

### Liveness probe test

Container touched `/tmp/healthy` on start, slept 30s, then deleted the file. The liveness probe (`cat /tmp/healthy`, `periodSeconds: 5`, `failureThreshold: 3`) started failing once the file disappeared, and after 3 consecutive failures (~15s) Kubernetes restarted the container.

Because the container's command re-runs from scratch on every restart (touch → sleep 30 → delete → sleep), this repeats indefinitely: ~30s healthy, ~15s to detect failure, restart, repeat. Restart count climbed every ~75s in the watch log, and `CrashLoopBackOff` briefly appeared between later restarts — kubelet applies an increasing back-off delay between repeated restarts of the same container once several have accumulated, whether the restart was triggered by a crash or a failed liveness probe.

**Restart count observed: climbing continuously (0 → 7+) as the probe kept firing every cycle** — confirms the liveness → restart pipeline is working as designed.

![alt text](<Screenshot From 2026-07-18 18-44-21-1.png>)
![alt text](<Screenshot From 2026-07-18 18-51-08-1.png>)

### Readiness probe test

Exposed an nginx Pod as a Service and confirmed the Pod IP appeared in `kubectl get endpoints`. Deleted `index.html` inside the container to break the readiness check. After ~15s the Pod flipped to `0/1 READY`, and the endpoints list went empty — but **the container was never restarted**. Readiness failure only pulls traffic away; it doesn't touch the container's lifecycle at all.

![alt text](<Screenshot From 2026-07-18 18-53-54.png>)
![alt text](<Screenshot From 2026-07-18 18-52-23.png>)

### Startup probe test

Container needed 20s before touching `/tmp/started`. `startupProbe` checked for that file every 5s with `failureThreshold: 12` (a 60s budget) — comfortably covering the 20s startup. Liveness/readiness probes stayed disabled the whole time. `kubectl describe pod` confirmed:

```
Started:        18:54:43
Ready:          True
Restart Count:  0
Startup:  exec [cat /tmp/started] delay=0s timeout=1s period=5s #success=1 #failure=12
Liveness: exec [cat /tmp/started] delay=0s timeout=1s period=5s #success=1 #failure=3
```

The Pod went `1/1 Running` around the 26s mark (20s sleep + one probe interval), with **zero restarts**, confirming the startup probe correctly gated the liveness probe until the container was actually ready.

**If `failureThreshold` had been `2` instead of `12`:** the startup budget would shrink from 60s to just 10s (`2 × periodSeconds: 5`). Since the container needs 20s to create `/tmp/started`, the startup probe would exhaust its failure budget before the file ever appears, and Kubernetes would kill the container for failing to start — even though it just needed more time. This is exactly the scenario the startup probe exists to prevent for slow-starting apps (e.g. JVM apps with long init).

![alt text](<Screenshot From 2026-07-18 18-57-13.png>)
![alt text](<Screenshot From 2026-07-18 18-57-09.png>)

---

## Summary

| Task         | Result                                                              |
| ------------ | ------------------------------------------------------------------- |
| 1. Resources | QoS Class = `Burstable`                                             |
| 2. OOMKilled | Exit Code = `137` (SIGKILL)                                         |
| 3. Pending   | `FailedScheduling`: insufficient cpu, insufficient memory           |
| 4. Liveness  | Container restarted repeatedly, restart count climbing every ~75s   |
| 5. Readiness | Endpoints emptied on failure, container restart count unchanged (0) |
| 6. Startup   | Pod ready at ~26s, 0 restarts, liveness gated correctly             |
| 7. Cleanup   | All pods/services removed                                           |

Requests get you scheduled. Limits get you killed (memory) or throttled (CPU) if you go over. And the three probe types each own a different failure response — restart, remove-from-service, or hold-off — which is what makes self-healing in Kubernetes actually predictable instead of chaotic.

![alt text](<Screenshot From 2026-07-18 18-58-21.png>)
