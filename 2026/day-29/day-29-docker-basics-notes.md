# Day 29 – Introduction to Docker
**90 Days of DevOps** | TrainWithShubham

---

## What is a Container?

A container packages an app + its dependencies + its config into a single portable unit. Eliminates the "works on my machine" problem — same behavior on any host.

Containers share the **host kernel** — they don't each need their own OS. This makes them lightweight and fast compared to VMs.

---

## Containers vs Virtual Machines

| Feature | Virtual Machine | Container |
|---|---|---|
| Boots | Full OS (minutes) | Process-level (seconds) |
| Size | GBs | MBs |
| Isolation | Hardware-level (hypervisor) | OS-level (kernel namespaces) |
| Overhead | High | Near-zero |

**VMs** virtualize *hardware*. **Containers** virtualize the *OS*.

---

## Docker Architecture

```
┌─────────────────────────────────────────────────────┐
│                  DOCKER HOST                        │
│                                                     │
│  ┌────────────┐      ┌──────────────────────────┐  │
│  │   Docker   │─────▶│      Docker Daemon        │  │
│  │   Client   │      │      (dockerd)            │  │
│  │ (docker CLI)│     │                           │  │
│  └────────────┘      │  ┌──────────┐ ┌────────┐  │  │
│                      │  │Container │ │Container│  │  │
│                      │  │    A     │ │   B    │  │  │
│                      │  └──────────┘ └────────┘  │  │
│                      │  ┌──────┐ ┌──────┐        │  │
│                      │  │Image │ │Image │        │  │
│                      │  └──────┘ └──────┘        │  │
│                      └──────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                              ▲ pull
                              │
                    ┌─────────────────┐
                    │  Docker Hub     │
                    │  (Registry)     │
                    └─────────────────┘
```

| Component | Role |
|---|---|
| **Docker Client** | CLI — you type commands, it talks to the daemon |
| **Docker Daemon** (`dockerd`) | Does the actual work — builds, runs, manages containers |
| **Image** | Read-only blueprint (like a class in OOP) |
| **Container** | Running instance of an image (like an object) |
| **Registry** | Remote store for images — Docker Hub is the default |

**Flow:** `docker run nginx` → client → daemon → pull from Hub if not local → start container.

---

## Task 2: Install Docker (RHEL)

```bash
# Remove old versions
sudo dnf remove docker docker-client docker-client-latest \
  docker-common docker-latest docker-engine podman runc

# Add Docker repo
sudo dnf config-manager --add-repo \
  https://download.docker.com/linux/rhel/docker-ce.repo

# Install
sudo dnf install docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin -y

# Start and enable
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (no sudo required after this)
sudo usermod -aG docker $USER
newgrp docker
```

### Verify

```bash
docker --version
docker info
```

### Hello World

```bash
docker run hello-world
```

What happened:
1. Client contacted the daemon
2. Daemon pulled `hello-world` image from Docker Hub (not found locally)
3. Daemon created a container and ran it
4. Container printed output and exited

---

## Task 3: Run Real Containers

### Nginx

```bash
docker run -d -p 8080:80 --name my-nginx nginx
```

Accessed via browser at `http://localhost:8080` — Nginx welcome page confirmed.

```bash
docker ps
# STATUS: Up — port 0.0.0.0:8080->80/tcp
```

### Ubuntu Interactive

```bash
docker run -it --name explore-ubuntu ubuntu bash
```

Inside the container:

```bash
cat /etc/os-release     # confirms Ubuntu
ls /                    # minimal filesystem
hostname                # = container ID
exit                    # stops the container
```

Key observation: no systemd, no GUI, barely any packages — lean by design.

### List Containers

```bash
docker ps          # running only
docker ps -a       # all (including stopped)
docker ps -aq      # just IDs
```

### Stop and Remove

```bash
docker stop my-nginx          # graceful stop (SIGTERM)
docker rm my-nginx            # remove stopped container
docker rm -f my-nginx         # force remove running container
docker container prune        # remove all stopped containers
```

---

## Task 4: Explore Docker Features

### Detached Mode (`-d`)

```bash
# Without -d: terminal attached, live output, Ctrl+C kills it
docker run nginx

# With -d: runs in background, returns container ID
docker run -d nginx
```

### Custom Name (`--name`)

```bash
docker run -d --name webserver nginx
docker run -d --name mydb redis
```

Always name long-lived containers — every subsequent command becomes cleaner.

### Port Mapping (`-p`)

```bash
# Format: -p <host_port>:<container_port>
docker run -d --name site -p 8080:80 nginx
docker run -d --name db   -p 5432:5432 postgres

# Multiple ports
docker run -d -p 80:80 -p 443:443 nginx
```

Containers are isolated — ports don't reach the host unless explicitly mapped with `-p`.

### Logs

```bash
docker logs webserver            # all logs
docker logs -f webserver         # live follow (like tail -f)
docker logs --tail 50 webserver  # last 50 lines
docker logs -t webserver         # with timestamps
```

### Exec Into Running Container

```bash
# Open a shell inside a running container
docker exec -it webserver bash

# Run a one-off command
docker exec webserver cat /etc/nginx/nginx.conf
```

`run` starts a *new* container. `exec` enters an *already running* one.

---

## Cheat Sheet

```bash
# Lifecycle
docker run -d --name <name> -p <h>:<c> <image>
docker start <name>
docker stop <name>
docker restart <name>
docker rm <name>
docker rm -f <name>

# Inspect
docker ps
docker ps -a
docker logs -f <name>
docker inspect <name>
docker stats

# Shell access
docker exec -it <name> bash
docker exec -it <name> sh       # if bash not available

# Images
docker images
docker pull nginx
docker rmi nginx
docker image prune

# Cleanup
docker container prune
docker system prune
```

---

## Key Takeaways

- Container = isolated process sharing the host kernel, not a separate OS
- Image = immutable blueprint; Container = running instance
- Docker Hub = public registry (GitHub for images)
- Port mapping is explicit — nothing exposed unless you `-p` it
- `-it` for interactive shell at start; `exec -it` to enter a running container
- `-d` runs detached; terminal stays free

---

*Day 29/90 complete — Docker is the foundation everything else (Kubernetes, CI/CD, microservices) is built on.*
