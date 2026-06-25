# Day 34 – Docker Compose: Real-World Multi-Container Apps

## Overview

Built a production-like 3-service stack using Docker Compose covering healthchecks, restart policies, named networks, named volumes, and `.env`-based configuration.

---

## Task 1: 3-Service Stack

| Service | Image / Source | Role |
|---|---|---|
| `web` | Custom Dockerfile (Flask) | Web app — connects to DB and cache |
| `db` | `postgres:16-alpine` | Relational database |
| `cache` | `redis:7-alpine` | In-memory cache (visit counter) |

- Flask app reads `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` from environment
- Redis tracks visit count via `INCR`
- Postgres returns its version string on each request
- All credentials managed via `.env` file; compose file references them using `${VARIABLE}`

---

## Task 2: `depends_on` & Healthchecks

**Healthcheck on Postgres:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
  interval: 5s
  timeout: 5s
  retries: 5
  start_period: 10s
```

**Web service dependency:**
```yaml
depends_on:
  db:
    condition: service_healthy
  cache:
    condition: service_started
```

**Observation:** Without `condition: service_healthy`, the Flask app crashed on startup because Postgres wasn't ready to accept connections yet even though the container had started. With the healthcheck condition, Compose held the `web` service in waiting state until `pg_isready` passed.

**Verify healthcheck status:**
```bash
docker inspect <db-container> --format='{{json .State.Health}}'
```

---

## Task 3: Restart Policies

| Policy | Applied To | Behaviour |
|---|---|---|
| `always` | `db` | Restarts on internal crashes; does not restart on operator `docker kill`/`docker stop` |
| `on-failure` | `web`, `cache` | Restarts only on non-zero exit (crash); respects `docker stop` |

**Hands-on Finding — Real `restart: always` Behavior:**

Tested multiple approaches to trigger a restart. Results:

| Command | Signal | Restarted? | Why |
|---|---|---|---|
| `docker kill <id>` | SIGKILL (default) | ❌ No | Docker treats it as operator intervention, not a crash |
| `docker stop <id>` | SIGTERM → SIGKILL | ❌ No | Graceful operator stop, ignored by restart policy |
| `docker kill --signal=SIGTERM <id>` | SIGTERM | ✅ Yes | Postgres handles SIGTERM as internal crash, triggers restart |
| `docker exec kill -9 1` | SIGKILL to PID 1 | ❌ No | PID 1 inside container is immune to SIGKILL by Linux design |
| `docker exec kill -9 <child-pid>` | SIGKILL to worker | ✅ Yes | Child crash bubbles up, container exits, restart triggers |

**Key insight:** `restart: always` is designed for containers that **crash on their own** — not for containers killed by the operator. `docker kill` (SIGKILL) is treated as a manual intervention and bypasses the restart policy.

**Correct way to test restart policy:**
```bash
# Send SIGTERM from outside — simulates a real crash
docker kill --signal=SIGTERM <container-id>

# Watch it come back
docker ps -a
```

**When to use each:**

- `no` — Dev/testing where you control start/stop manually
- `always` — Core infrastructure (DB) that must always be running; restarts on daemon reboot too
- `on-failure` — App services that should recover from crashes but respect intentional stops
- `unless-stopped` — Like `always` but does not restart containers that were manually stopped before a daemon reboot

---

## Task 4: Custom Dockerfile in Compose

Used `build:` block instead of a pre-built image for the web service:

```yaml
web:
  build:
    context: ./app
    dockerfile: Dockerfile
```

**Rebuild and restart with one command:**
```bash
docker compose up --build
```

Compose rebuilds only the `web` image (detects source change), restarts only that service — `db` and `cache` keep running uninterrupted.

---

## Task 5: Named Networks & Volumes

**Networks:**
```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
```

- `web` is on both `frontend` and `backend` — accessible from outside and can reach DB/cache
- `db` and `cache` are on `backend` only — isolated from host, not directly reachable externally

**Volumes:**
```yaml
volumes:
  pgdata:
    driver: local
  redisdata:
    driver: local
```

- `pgdata` persists Postgres data across `docker compose down`
- To wipe data: `docker compose down -v` (the `-v` flag removes named volumes)

**Labels:**
```yaml
labels:
  com.myapp.service: "db"
  com.myapp.env: "dev"
```

Filter containers by label:
```bash
docker ps --filter "label=com.myapp.service=db"
```

---

## Task 6: Scaling (Bonus)

```bash
docker compose up --scale web=3
```

**What broke:** Port conflict. Three replicas all tried to bind to host port `5000` — only one process can hold a host port at a time.

**Why simple scaling doesn't work with port mapping:**
Port numbers on the host are an exclusive resource. `N replicas × 1 static port = conflict`. Production orchestrators (Kubernetes, ECS) solve this by routing through their own networking layer — containers expose ports internally, and a load balancer / ingress handles the host-facing port.

**Fix:** Remove `ports:` from `web`, use `expose:` instead, and put an Nginx or Traefik reverse proxy in front. Docker's internal DNS automatically load-balances across replicas by service name.

---

## `.env` File

```env
DB_NAME=myapp
DB_USER=myuser
DB_PASSWORD=mypassword
POSTGRES_VERSION=16-alpine
REDIS_VERSION=7-alpine
FLASK_PORT=5000
```

Variables are referenced in `docker-compose.yml` as `${VARIABLE_NAME}`.

Verify full resolution before bringing up:
```bash
docker compose config
```

---

## Key Commands Used Today

```bash
# Build and start
docker compose up --build

# Start detached
docker compose up -d --build

# Watch logs
docker compose logs -f web

# Check all service states
docker compose ps

# Verify restart policy on a container
docker inspect <id> --format='{{.HostConfig.RestartPolicy.Name}}'

# Verify healthcheck state
docker inspect <id> --format='{{json .State.Health}}'

# Verify .env substitution
docker compose config

# Scale (bonus)
docker compose up --scale web=3

# Tear down (keep volumes)
docker compose down

# Tear down (wipe volumes)
docker compose down -v
```

---

## Files in This Submission

```
2026/day-34/
├── docker-compose.yml
├── .env
├── app/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
└── day-34-compose-advanced.md
```
