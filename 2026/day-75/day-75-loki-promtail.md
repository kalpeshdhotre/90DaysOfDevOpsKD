# Day 75 — Log Management with Loki and Promtail

## Architecture

```
[Docker Containers]
       |
       | (write JSON logs to /var/lib/docker/containers/)
       v
  [Promtail]
       |
       | (reads log files, adds labels, pushes to Loki)
       v
    [Loki]
       |
       | (stores logs, indexes by labels only — not full text)
       v
   [Grafana]
       |
       | (queries Loki with LogQL, displays logs)
       v
   [You]
```

Loki takes the "Prometheus, but for logs" approach — it indexes only labels (container name, job, filename), not the full log text. This keeps it far cheaper and simpler to run than a full-text engine like Elasticsearch. The trade-off: broad keyword search across all logs has to scan compressed chunks at query time, so it's slower for unstructured full-text search than ELK, but much lighter operationally for label-based filtering — which covers most day-to-day debugging.

---

## Task 2: Loki Configuration

`loki/loki-config.yml`:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory
  replication_factor: 1
  path_prefix: /loki

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  filesystem:
    directory: /loki/chunks
```

- `auth_enabled: false` — single-tenant mode, no auth needed for local learning
- `store: tsdb` — Loki's time-series index store
- `object_store: filesystem` — log chunks persisted to local disk
- `replication_factor: 1` — single instance, no replication needed

---

## Task 3: Promtail Configuration

`promtail/promtail-config.yml`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ["__meta_docker_container_name"]
        regex: "/(.*)"
        target_label: "container"
      - source_labels: ["__meta_docker_container_log_stream"]
        target_label: "stream"
    pipeline_stages:
      - docker: {}
      - drop:
          older_than: 168h
```

- `positions.yaml` — bookmarks which log lines have already been shipped
- `docker_sd_configs` — uses Docker service discovery (via the mounted socket) to auto-discover running containers, instead of a static file glob
- `relabel_configs` — promotes the container's real name to a `container` label, so logs can be filtered by container name in LogQL
- `pipeline_stages: docker: {}` — parses Docker's JSON log wrapper format
- `drop: older_than: 168h` — drops any log line older than 7 days before shipping, since Loki rejects entries outside its ingestion time window (relevant here because one long-running container — a kind cluster control-plane — had ~7 weeks of log history on disk)

---

## docker-compose.yml (services added)

```yaml
  loki:
    image: grafana/loki:latest
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./loki/loki-config.yml:/etc/loki/loki-config.yml
      - loki_data:/loki
    command: -config.file=/etc/loki/loki-config.yml
    restart: unless-stopped

  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    ports:
      - "9080:9080"
    volumes:
      - ./promtail/promtail-config.yml:/etc/promtail/promtail-config.yml
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock
    command: -config.file=/etc/promtail/promtail-config.yml
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
  loki_data:
```

Existing services from Days 73–74 (Prometheus, Grafana, Node Exporter, cAdvisor, notes-app) were kept unchanged — Loki and Promtail run alongside them, not in place of them.

---

## Task 4: Loki as Grafana Datasource

Added via Grafana UI: **Connections → Data sources → Add data source → Loki**, URL `http://loki:3100`, Save & Test.

![alt text](<md-screenshots/Screenshot From 2026-08-29 20-31-41.png>)

---

## Task 5: LogQL Queries

| Query                                                       | Purpose                           | Result                                                                                                   |
| ----------------------------------------------------------- | --------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `{job="docker"}`                                            | All Docker container logs         | Returned ~4.2K info-level entries across the time range, confirming Promtail → Loki shipping was working |
| `{container="notes-app"}`                                   | Filter logs to a single container | Returned notes-app request logs only, once the `container` label was added via Docker service discovery  |
| `{job="docker"} \|= "error"`                                | Keyword filter for error lines    | Returned error-level entries only (67 total in the observed window per the logs volume panel)            |
| `{job="docker"} != "health"`                                | Exclude health-check noise        | Filtered out routine health-check log lines                                                              |
| `count_over_time({container="notes-app"} \|= "error" [1m])` | Error count per minute            | Time-bucketed count of error lines for notes-app                                                         |

`[SCREENSHOT: Grafana Explore — Loki query results]`

---

## Task 6: Correlating Metrics and Logs

**Logs panel added to Day 74 dashboard** (Loki datasource, query `{job="docker"}`, Logs visualization):

![alt text](<md-screenshots/Screenshot From 2026-08-29 20-34-35.png>)

![alt text](<md-screenshots/Screenshot From 2026-08-29 20-35-33.png>)

![alt text](<md-screenshots/Screenshot From 2026-08-29 20-35-50.png>)

**Explore split view** — Prometheus (`rate(container_cpu_usage_seconds_total{...}[5m])`) alongside Loki (`{container="notes-app"}`):

Having metrics and logs in the same tool means an anomaly spotted on the metrics side (e.g. a CPU spike) can be immediately cross-referenced against the exact log lines from that same timestamp — no switching dashboards, no manually aligning timestamps across separate systems. This materially speeds up incident diagnosis compared to checking Prometheus and a separate log system independently.

---

## Loki vs ELK Stack

|                        | Loki                                                       | ELK (Elasticsearch)                                   |
| ---------------------- | ---------------------------------------------------------- | ----------------------------------------------------- |
| Indexing               | Labels only                                                | Full text                                             |
| Resource cost          | Low                                                        | High                                                  |
| Operational complexity | Simple (pairs naturally with Prometheus/Grafana)           | Complex (cluster management, shard tuning)            |
| Search power           | Fast label filtering; slower free-text grep                | Powerful full-text search, aggregations               |
| Best fit               | Cost-sensitive, label-structured logging (containers, k8s) | Deep full-text search, complex log analytics at scale |

**When to use each:** Loki for lean, Grafana-centric observability stacks where logs are naturally labeled (container/service/job) and cost matters. ELK when you need rich full-text search, complex aggregations, or are already invested in the Elastic ecosystem.

---

## Troubleshooting Notes (real issues hit today)

- **Promtail `/targets` unreachable** — the compose service didn't publish port 9080 to the host; added `ports: ["9080:9080"]`.
- **Grafana provisioning folder missing** — no provisioning volume mount existed from Day 74; added the Loki datasource manually via the UI instead.
- **`http://loki:3100` not opening in browser** — that hostname only resolves inside the Docker network; used `http://localhost:3100/ready` from the host, and `http://loki:3100` only inside Grafana's datasource config field.
- **Loki rejecting log batches — "timestamp too old"** — a long-running `kind` cluster control-plane container had ~7 weeks of log history on disk, older than Loki's ingestion window. Fixed with a `drop: older_than: 168h` pipeline stage in Promtail.
- **No `container` label on log streams** — the static file-glob scrape config doesn't auto-extract container names. Switched to `docker_sd_configs` with a `relabel_configs` block to promote `__meta_docker_container_name` into a `container` label.

---

## Submission

- [ ] Add screenshots to placeholders above
- [ ] Add `day-75-loki-promtail.md` to `2026/day-75/`
- [ ] Commit and push to fork
