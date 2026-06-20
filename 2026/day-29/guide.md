# Day 29 – Introduction to Docker

> **90 Days of DevOps** | TrainWithShubham / DevOpsKaJosh

---

## Task 1: What is Docker?

### Why Containers Exist

Before containers, deploying an app meant: *"It works on my machine"* — and then spending hours debugging why it fails in production. The issue is that software depends on specific OS libraries, runtimes, and environment configs that differ between machines.

**Containers** package your app + its dependencies + its config into a single, portable unit. Run it anywhere — laptop, VM, cloud — same behavior guaranteed.

### Containers vs Virtual Machines

| Feature | Virtual Machine | Container |
|---|---|---|
| Boots | Full OS (minutes) | Process-level (seconds) |
| Size | GBs | MBs |
| Isolation | Hardware-level (hypervisor) | OS-level (kernel namespaces) |
| Overhead | High | Near-zero |
| Portability | Heavy (image includes full OS) | Lightweight |

**The key insight:** VMs virtualize *hardware*. Containers virtualize the *OS*. Containers share the host kernel — they don't each need their own.

```
VM Model                    Container Model
┌──────────────────┐        ┌──────────────────────────┐
│  App A  │  App B │        │  App A  │  App B │  App C │
│  Libs   │  Libs  │        │  Libs   │  Libs  │  Libs  │
│  Guest OS│ Guest OS│      ├──────────────────────────┤
├──────────────────┤        │       Container Runtime   │
│    Hypervisor    │        ├──────────────────────────┤
├──────────────────┤        │         Host OS           │
│     Host OS      │        ├──────────────────────────┤
├──────────────────┤        │         Hardware          │
│     Hardware     │        └──────────────────────────┘
└──────────────────┘
```

### Docker Architecture

Docker follows a **client-server architecture**:

```
┌─────────────────────────────────────────────────────┐
│                  DOCKER HOST                        │
│                                                     │
│  ┌────────────┐      ┌──────────────────────────┐  │
│  │            │      │      Docker Daemon        │  │
│  │   Docker   │─────▶│      (dockerd)           │  │
│  │   Client   │      │                          │  │
│  │ (docker CLI)│     │  ┌────────┐ ┌────────┐  │  │
│  └────────────┘      │  │  Con-  │ │  Con-  │  │  │
│                      │  │tainer A│ │tainer B│  │  │
│                      │  └────────┘ └────────┘  │  │
│                      │                          │  │
│                      │  ┌──────┐ ┌──────┐      │  │
│                      │  │Image │ │Image │      │  │
│                      │  │  A   │ │  B   │      │  │
│                      │  └──────┘ └──────┘      │  │
│                      └──────────────────────────┘  │
└─────────────────────────────────────────────────────┘
          │                        ▲
          ▼                        │
┌──────────────────────────────────┘
│         Docker Registry (Docker Hub)
│  ┌──────────┐ ┌──────────┐ ┌──────────┐
│  │  nginx   │ │  ubuntu  │ │  redis   │
│  └──────────┘ └──────────┘ └──────────┘
└──────────────────────────────────────────
```

**Components:**

| Component | What it does |
|---|---|
| **Docker Client** | CLI tool — you type `docker run`, it sends commands to the daemon |
| **Docker Daemon** (`dockerd`) | Background service that does the actual work — builds, runs, manages containers |
| **Images** | Read-only blueprint for a container (like a class in OOP) |
| **Containers** | Running instance of an image (like an object/instance) |
| **Registry** | Remote store for images — Docker Hub is the default public registry |

**Flow:** `docker run nginx` → client tells daemon → daemon checks if `nginx` image exists locally → if not, pulls from Docker Hub → creates and starts a container from that image.

---

## Task 2: Install Docker

### Installation (RHEL / Rocky / Fedora)

```bash
# Remove old versions if any
sudo dnf remove docker docker-client docker-client-latest \
  docker-common docker-latest docker-latest-logrotate \
  docker-logrotate docker-engine podman runc

# Add Docker's official repo
sudo dnf config-manager --add-repo \
  https://download.docker.com/linux/rhel/docker-ce.repo

# Install Docker Engine
sudo dnf install docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin -y

# Start and enable the daemon
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to the docker group (avoid sudo every time)
sudo usermod -aG docker $USER
newgrp docker   # apply group change in current session
```

### Verify Installation

```bash
docker --version
# Docker version 26.x.x, build ...

docker info
# Shows daemon details — storage driver, number of containers, images, etc.
```

### Run Hello World

```bash
docker run hello-world
```

**What just happened (the output tells you):**
1. Docker client contacted the daemon
2. Daemon didn't find `hello-world` image locally → pulled from Docker Hub
3. Daemon created a container from the image and ran it
4. Container printed the message and exited

```bash
# Confirm it ran and exited
docker ps -a
# CONTAINER ID   IMAGE         COMMAND    CREATED         STATUS                     
# a1b2c3d4e5f6   hello-world   "/hello"   5 seconds ago   Exited (0) 4 seconds ago
```

---

## Task 3: Run Real Containers

### Nginx Container

```bash
# Run Nginx, map port 8080 on host to port 80 in container
docker run -d -p 8080:80 --name my-nginx nginx
```

```bash
# Verify it's running
docker ps
# CONTAINER ID   IMAGE   COMMAND                  CREATED         STATUS         PORTS                  NAMES
# abc123def456   nginx   "/docker-entrypoint.…"   10 seconds ago  Up 9 seconds   0.0.0.0:8080->80/tcp   my-nginx
```

Open your browser: `http://localhost:8080` → You should see the Nginx welcome page.

---

### Ubuntu Container (Interactive Mode)

```bash
# -it = interactive + pseudo-TTY (gives you a shell inside the container)
docker run -it --name explore-ubuntu ubuntu bash
```

You're now *inside* the container — a minimal Ubuntu environment:

```bash
# Inside the container
cat /etc/os-release        # confirm it's Ubuntu
ls /                        # minimal filesystem
apt list --installed 2>/dev/null | wc -l  # very few packages
hostname                   # container's hostname = container ID
exit                       # leave the container (container stops)
```

**Key observation:** This Ubuntu has no systemd, no GUI, barely any packages. It's lean by design.

---

### List Containers

```bash
# Only running containers
docker ps

# All containers (running + stopped)
docker ps -a

# Compact view — just IDs
docker ps -aq
```

---

### Stop and Remove a Container

```bash
# Stop a running container gracefully (SIGTERM → waits → SIGKILL)
docker stop my-nginx

# Remove a stopped container
docker rm my-nginx

# Remove a running container forcefully
docker rm -f my-nginx

# Remove all stopped containers at once
docker container prune
```

---

## Task 4: Explore Docker Features

### Detached Mode (`-d`)

```bash
# Without -d: terminal is attached, you see live output, Ctrl+C kills it
docker run nginx

# With -d: runs in background, returns the container ID
docker run -d nginx
# 7f3a8c2e1d09b4...
```

Detached = container runs as a background process. Your terminal is free.

---

### Custom Name (`--name`)

```bash
docker run -d --name webserver nginx
docker run -d --name mydb redis

docker ps
# Names: webserver, mydb  (instead of random adjective_noun combos)
```

Always name long-lived containers — it makes every subsequent command cleaner.

---

### Port Mapping (`-p`)

```bash
# Format: -p <host_port>:<container_port>
docker run -d --name site -p 8080:80 nginx     # host:8080 → container:80
docker run -d --name api  -p 3000:3000 node:18  # same port both sides
docker run -d --name db   -p 5432:5432 postgres # expose postgres

# Multiple ports
docker run -d -p 80:80 -p 443:443 nginx
```

**Why this matters:** Containers are isolated — their ports don't automatically reach your host. `-p` punches a hole through.

---

### Logs

```bash
# Print all logs so far
docker logs webserver

# Follow live (like tail -f)
docker logs -f webserver

# Last 50 lines only
docker logs --tail 50 webserver

# With timestamps
docker logs -t webserver
```

---

### Exec Into a Running Container

```bash
# Open a bash shell inside a running container
docker exec -it webserver bash

# Run a one-off command without entering a shell
docker exec webserver cat /etc/nginx/nginx.conf
docker exec webserver ls /usr/share/nginx/html
```

**`exec` vs `-it` at run time:** `run` starts a *new* container. `exec` enters an *already running* one.

---

## Quick Reference Cheat Sheet

```bash
# Lifecycle
docker run -d --name <name> -p <h>:<c> <image>   # run container
docker start <name>                                # start stopped container
docker stop <name>                                 # graceful stop
docker restart <name>                              # stop + start
docker rm <name>                                   # remove stopped container
docker rm -f <name>                                # force remove running

# Inspect
docker ps                    # running containers
docker ps -a                 # all containers
docker logs -f <name>        # live logs
docker inspect <name>        # full JSON metadata
docker stats                 # live resource usage (CPU/RAM)

# Shell access
docker exec -it <name> bash  # enter running container
docker exec -it <name> sh    # if bash not available

# Images
docker images                # list local images
docker pull nginx             # pull without running
docker rmi nginx              # remove image
docker image prune            # remove dangling images

# Cleanup
docker container prune       # remove all stopped containers
docker system prune          # remove stopped containers + unused images + networks
```

---

## Key Takeaways

- **Container** = isolated process on the host kernel, not a separate OS
- **Image** = immutable blueprint; **Container** = running instance of that blueprint
- **Docker Hub** = default public registry — think GitHub but for images
- **Port mapping** is explicit — nothing is exposed to your host unless you `-p` it
- **`-it`** gives you an interactive shell; **`-d`** runs detached in background
- `docker exec` is how you get into a running container after the fact

---

*Day 29/90 — Docker is the foundation everything else (Kubernetes, CI/CD, microservices) is built on. Today's commands will be muscle memory by Day 90.*
