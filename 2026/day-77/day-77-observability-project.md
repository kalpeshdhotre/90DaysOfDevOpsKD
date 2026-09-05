# Day 77 — Observability Project: Full Stack with Docker Compose

## Overview

Brought together everything from Days 73–76 (Prometheus, Node Exporter, cAdvisor, Grafana, Loki, Promtail, OpenTelemetry Collector) by launching a complete 8-service reference observability stack with a single `docker compose up -d`, validating metrics, logs, and traces end to end, and building a unified "Production Overview" dashboard in Grafana.

Reference repo used: https://github.com/LondheShubham153/observability-for-devops

---

## Task 1: Clone and Launch the Reference Stack

Cloned the reference repo, removed its `.git` history, and copied the stack files into `2026/day-77/` to keep the submission self-contained and in sync with the daily repo push.

All 8 services came up successfully via `docker compose up -d`.

## ![alt text](<md-screenshots/Screenshot From 2026-09-04 20-37-51.png>)

## Task 2: Validate the Metrics Pipeline

All 4 Prometheus scrape jobs (`prometheus`, `node-exporter`, `cadvisor`, `otel-collector`) verified UP under Status > Targets.

![alt text](<md-screenshots/Screenshot From 2026-09-04 20-38-44.png>)

Ran the validation PromQL queries (`up`, host CPU/memory usage, container CPU per container, top 3 memory-hungry containers) — all returned expected data with no errors.

---

## Task 3: Validate the Logs Pipeline

Generated traffic against the notes-app (50 iterations of curl against `/` and `/api/`), then validated log ingestion in Grafana Explore using Loki.

**Deviation from reference README:** the shipped `promtail-config.yml` does not attach a `container_name` (or `container`) label to log streams — queries like `{container_name="notes-app"}` returned **No data**. Confirmed by inspecting label sets on returned log lines in Grafana's Explore panel. Worked around this using text-filtered queries against the `job` label instead:

- `{job="docker"} |= "notes-app"` — in place of `{container_name="notes-app"}`
- `{job="docker"} |= "notes-app" |= "GET"` — in place of `{container_name="notes-app"} |= "GET"`
- `{job="docker"} |= "error"` — worked as-is (already used `job`)

Also could not reach Promtail's debug endpoint (`curl http://localhost:9080/targets`) — port 9080 is not published to the host in this compose setup (confirmed via `docker compose ps promtail`, PORTS column empty). Log ingestion was instead verified end-to-end through Grafana Explore returning live data, which confirms Promtail is scraping and shipping successfully without needing the debug endpoint.

![alt text](<md-screenshots/Screenshot From 2026-09-05 19-58-49.png>)

---

## Task 4: Validate the Traces Pipeline

Sent a synthetic two-span OTLP trace (parent `GET /api/notes` HTTP span + child `SELECT notes FROM database` DB span) to the collector via `curl -X POST http://localhost:4318/v1/traces`. Response confirmed acceptance: `{"partialSuccess":{}}`.

**Deviation from reference README:** the shipped `otel-collector-config.yml` sets `debug.verbosity: basic`, which only logs span _counts_ (`"resource spans": 1, "spans": 2`), not span names or attributes — so `docker logs otel-collector | grep "GET /api/notes"` initially returned nothing even though the trace was received and processed correctly. Changed `verbosity: basic` → `verbosity: detailed` and restarted the `otel-collector` service to surface full span detail.

After the change, both spans appeared with full detail:

- **Span #0** — `GET /api/notes`, Kind: Server, Status: Ok, attributes `http.method=GET`, `http.route=/api/notes`, `http.status_code=200`
- **Span #1** — `SELECT notes FROM database`, Kind: Client, `Parent ID` matching Span #0's ID (confirms parent-child relationship), attributes `db.system=sqlite`, `db.statement=SELECT * FROM notes`

![alt text](<md-screenshots/Screenshot From 2026-09-05 19-43-10.png>)

---

## Task 5: Unified "Production Overview" Dashboard

Built a 4-row Grafana dashboard combining Prometheus (system + container metrics) and Loki (application logs) into a single pane of glass:

- **Row 1 — System Health:** CPU/Memory/Disk gauges, Targets Up stat (Prometheus)
- **Row 2 — Container Metrics:** Container CPU time series, Container Memory bar chart, Container Count stat (cAdvisor)
- **Row 3 — Application Logs:** App Logs, Error Rate, Log Volume (Loki)
- **Row 4 — Service Overview:** Prometheus scrape duration, OTEL metrics received

**Deviations applied (carried over from Task 3):**

- Row 3 panel datasource must be explicitly set to **Loki** — copying/duplicating panels from Rows 1–2 defaults to Prometheus, which throws a LogQL parse error (`unexpected character: '|'`) since Prometheus can't parse `|=`.
- App Logs panel: `{job="docker"} |= "notes-app"` used in place of `{container_name="notes-app"}` (label unavailable, see Task 3).
- Log Volume panel: `sum(rate({job="docker"}[5m]))` used in place of `sum by (container_name) (rate({job="docker"}[5m]))` — per-container breakdown isn't possible without a working container-identifying label in this Promtail config.

Saved as **"Production Overview — Observability Stack"**, time range set to Last 30 minutes, auto-refresh every 10s.

![alt text](<md-screenshots/Screenshot From 2026-09-05 20-25-47.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-05 20-25-57.png>)

---

## Task 6: Comparison — Your Stack (Days 73–76) vs Reference Repo

| Component                   | Your Version | Reference Repo              | Notable Differences                                                                                                                             |
| --------------------------- | ------------ | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `prometheus.yml`            | Day 73–74    | Root directory              | _(fill in scrape job/interval diffs)_                                                                                                           |
| `loki-config.yml`           | Day 75       | `loki/` directory           | _(fill in storage config diffs)_                                                                                                                |
| `promtail-config.yml`       | Day 75       | `promtail/` directory       | Reference config lacks a working `container_name`/`container` label on Docker SD relabeling — required query workarounds throughout Tasks 3 & 5 |
| `otel-collector-config.yml` | Day 76       | `otel-collector/` directory | Reference ships `debug.verbosity: basic` by default — insufficient for inspecting span content, required change to `detailed`                   |
| `datasources.yml`           | Day 74       | `grafana/provisioning/`     | _(fill in provisioned source diffs)_                                                                                                            |
| `docker-compose.yml`        | Days 73–76   | Root directory              | Reference bundles all 8 services + sample notes-app in one file; Promtail's debug port (9080) not published to host by default                  |

### Concept-to-day map

| Day | What I Built                                  |
| --- | --------------------------------------------- |
| 73  | Prometheus, PromQL, metrics fundamentals      |
| 74  | Node Exporter, cAdvisor, Grafana dashboards   |
| 75  | Loki, Promtail, LogQL, log-metric correlation |
| 76  | OTEL Collector, traces, alerting rules        |
| 77  | Full stack integration, unified dashboard     |

### What I'd add for production

- Alertmanager for routing alerts to Slack/PagerDuty
- Grafana Tempo for trace storage (replacing the debug exporter used here)
- HTTPS/TLS for all endpoints
- Authentication on Grafana and Prometheus
- Log retention policies and storage limits
- High availability (multiple Prometheus/Loki replicas)
- Proper label enrichment in Promtail's relabel_configs — the missing container-identifying label encountered today would be a real gap in a production logging setup, not just an exercise inconvenience

### Managed alternatives (Datadog / New Relic / AWS CloudWatch)

_(fill in your own comparison — cost, operational overhead, vendor lock-in, feature completeness)_

---

## Key Takeaways from the 5-Day Observability Block

- Metrics (Prometheus), logs (Loki), and traces (OTEL) are complementary, not redundant — each answers a different debugging question, and a unified dashboard is what makes them usable together.
- Label design in the ingestion layer (Promtail relabeling, in this case) matters as much as the queries — a missing label breaks otherwise-correct LogQL silently ("No data" gives no hint why).
- Exporter verbosity settings (like OTEL's `debug.verbosity`) can make a fully working pipeline look broken if not tuned for what you're trying to inspect.
- Debug/inspection endpoints (Promtail's `/targets`) are easy to forget to publish in Docker Compose — worth checking `ports:` early when a debug curl "returns nothing."

---

## Config Files

- `docker-compose.yml`
- `prometheus.yml`
- `loki-config.yml`
- `promtail-config.yml`
- `otel-collector-config.yml`

_(attached alongside this file in `2026/day-77/`)_
