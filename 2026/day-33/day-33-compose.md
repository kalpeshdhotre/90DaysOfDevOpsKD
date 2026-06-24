# Day 33 – Docker Compose: Multi-Container Basics

## Overview

Today I learned how Docker Compose simplifies running multi-container applications. Instead of manually creating networks, volumes, and running containers one by one — a single `docker-compose.yml` file and one command handles everything.

---

## Task 1: Install & Verify

Checked Docker Compose availability:

```bash
docker compose version
```

**Output:**

```
Docker Compose version v2.x.x
```

Docker Compose v2 is built into the Docker CLI — no separate install needed.

---

## Task 2: First Compose File – Nginx

Created folder `compose-basics/` with the following `docker-compose.yml`:

```yaml
services:
    web:
        image: nginx
        ports:
            - "8080:80"
```

**Commands used:**

```bash
docker compose up        # started, verified Nginx at http://localhost:8080
docker compose up -d     # restarted in detached mode
docker compose down      # stopped and removed container + network
```

**Result:** Nginx welcome page accessible at `http://localhost:8080` ✅

---

## Task 3: Two-Container Setup – WordPress + MySQL

Created `wordpress-compose/docker-compose.yml`:

```yaml
services:
    db:
        image: mysql:8.0
        environment:
            MYSQL_ROOT_PASSWORD: rootpass
            MYSQL_DATABASE: wordpress
            MYSQL_USER: wpuser
            MYSQL_PASSWORD: wppass
        volumes:
            - db_data:/var/lib/mysql

    wordpress:
        image: wordpress:latest
        ports:
            - "8080:80"
        depends_on:
            - db
        environment:
            WORDPRESS_DB_HOST: db
            WORDPRESS_DB_USER: wpuser
            WORDPRESS_DB_PASSWORD: wppass
            WORDPRESS_DB_NAME: wordpress

volumes:
    db_data:
```

![alt text](<Screenshot From 2026-06-24 19-39-24.png>)

**Key observations:**

- `WORDPRESS_DB_HOST: db` — the service name `db` acts as the DNS hostname inside the Compose network. No manual network creation needed.
- `depends_on: db` — ensures MySQL container starts before WordPress.
- Named volume `db_data` stores MySQL data independently of the container lifecycle.

**Data persistence test:**

```bash
docker compose up -d     # started both containers
# completed WordPress setup in browser at http://localhost:8080
docker compose down      # stopped and removed containers + network
docker compose up -d     # restarted
# visited http://localhost:8080 — WordPress setup was still there ✅
```

**Result:** WordPress data persisted across `down` + `up` cycle because the named volume `db_data` was not removed. `docker compose down` removes containers and networks — NOT volumes. Only `docker compose down -v` removes volumes.

![alt text](<Screenshot From 2026-06-24 19-39-10.png>)

---

## Task 4: Compose Commands Reference

| Command                            | What it does                                     |
| ---------------------------------- | ------------------------------------------------ |
| `docker compose up -d`             | Start all services in detached (background) mode |
| `docker compose ps`                | List running services and their status           |
| `docker compose logs -f`           | Stream logs from all services                    |
| `docker compose logs -f wordpress` | Stream logs from a specific service              |
| `docker compose stop`              | Stop containers without removing them            |
| `docker compose down`              | Stop + remove containers and network             |
| `docker compose down -v`           | Also removes named volumes (destroys data)       |
| `docker compose build`             | Rebuild images (when using custom Dockerfiles)   |
| `docker compose up -d --build`     | Rebuild images then start services               |

---

## Task 5: Environment Variables

Used environment variables directly in `docker-compose.yml` via the `environment:` block (shown in Task 3 above).

**Key learning:** The `environment:` block passes variables directly into the container at runtime — same as using `-e` flags with `docker run`, but declared cleanly in the YAML.

**Alternative — `.env` file method** (for keeping secrets out of version control):

Create a `.env` file in the same directory as `docker-compose.yml`:

```bash
# .env
MYSQL_ROOT_PASSWORD=rootpass
MYSQL_DATABASE=wordpress
WP_PORT=8080
```

Reference in `docker-compose.yml`:

```yaml
services:
    db:
        environment:
            MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
            MYSQL_DATABASE: ${MYSQL_DATABASE}
    wordpress:
        ports:
            - "${WP_PORT}:80"
```

Verify variable substitution:

```bash
docker compose config   # prints the resolved YAML with all variables filled in
```

> Always add `.env` to `.gitignore` to avoid committing credentials.

---

## Key Concepts Learned

**Service name = internal hostname.** Whatever you name a service in Compose, other containers on the same Compose network can reach it using that name. `db`, `redis`, `backend` — these resolve automatically without any manual DNS setup.

**Named volumes outlive containers.** `docker compose down` removes containers and the default network, but named volumes stay. This is intentional — your data survives restarts and redeployments.

**`depends_on` controls start order, not readiness.** The DB container starts first, but MySQL might still be initializing when WordPress tries to connect. For production, pair it with a `healthcheck:` block.

**Compose auto-creates a network.** Every Compose project gets a default bridge network automatically. All services join it — no `docker network create` needed.

---

## Files

```
2026/day-33/
├── day-33-compose.md
├── compose-basics/
│   └── docker-compose.yml        # Task 2 — Nginx single container
└── wordpress-compose/
    └── docker-compose.yml        # Task 3, 4, 5 — WordPress + MySQL
```

---

_Day 33 of #90DaysOfDevOps | #DevOpsKaJosh | #TrainWithShubham_
