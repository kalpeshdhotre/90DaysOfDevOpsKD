# Day 30 – Docker Images & Container Lifecycle

> **#90DaysOfDevOps | #DevOpsKaJosh | TrainWithShubham**

---

## Concepts First

### What is a Docker Image?
A Docker image is a **read-only blueprint** used to create containers. It is built in **layers**, where each instruction in a Dockerfile adds a new layer on top of the previous one.

```
Dockerfile instruction → Layer
nginx image = base OS layer + nginx binaries layer + config layer + ...
```

### Image vs Container
| | Image | Container |
|---|---|---|
| State | Read-only | Read-write (adds a thin writable layer on top) |
| Role | Blueprint | Running instance of an image |
| Stored as | Layers on disk | Image layers + container layer |
| Lifecycle | `pull` → `build` → `push` | `create` → `start` → `stop` → `rm` |

### What are Image Layers?
Each layer represents a **filesystem diff** — only the changes from the previous layer. Docker uses a **Union File System** to stack these layers and present them as a single unified filesystem.

**Why layers?**
- **Caching:** Unchanged layers are reused across builds and pulls — much faster
- **Sharing:** Multiple images sharing the same base layer don't duplicate it on disk
- **Efficiency:** Only changed layers are pushed/pulled from registries

---

## Task 1: Docker Images

### Step 1.1 — Pull Images

```bash
docker pull nginx
docker pull ubuntu
docker pull alpine
```

<details>
<summary>💡 Expected output for each pull</summary>

```
Using default tag: latest
latest: Pulling from library/nginx
...
Status: Downloaded newer image for nginx:latest
```
</details>

---

### Step 1.2 — List All Images

```bash
docker images
# or the long form:
docker image ls
```

<details>
<summary>💡 Expected output</summary>

```
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
nginx        latest    a6bd71f48f68   2 weeks ago    192MB
ubuntu       latest    bf3dc08bfed0   4 weeks ago    77.9MB
alpine       latest    324bc02ae123   3 weeks ago    7.8MB
```
</details>

**Note the SIZE column.** Alpine is dramatically smaller than Ubuntu.

---

### Step 1.3 — Ubuntu vs Alpine: Why the Size Difference?

| | Ubuntu | Alpine |
|---|---|---|
| Base | Full Debian-derived Linux | Minimal musl libc + BusyBox |
| Package manager | `apt` | `apk` |
| Size | ~77 MB | ~7 MB |
| Use case | General-purpose, familiar tooling | Minimal containers, security-focused |

**Alpine is ~10× smaller** because it strips out everything non-essential: no systemd, no full glibc, no GNU coreutils — just the bare minimum to run a process.

---

### Step 1.4 — Inspect an Image

```bash
docker image inspect nginx
```

<details>
<summary>💡 Key fields to look for</summary>

```json
[
  {
    "Id": "sha256:a6bd71f48f68...",
    "RepoTags": ["nginx:latest"],
    "Created": "2024-...",
    "Architecture": "amd64",
    "Os": "linux",
    "RootFS": {
      "Type": "layers",
      "Layers": [
        "sha256:...",
        "sha256:...",
        "sha256:..."
      ]
    },
    "Config": {
      "ExposedPorts": { "80/tcp": {} },
      "Cmd": ["nginx", "-g", "daemon off;"],
      "Env": ["PATH=/usr/local/sbin:..."]
    }
  }
]
```

Key things visible:
- **RootFS.Layers** — the layer SHAs that make up this image
- **Config.ExposedPorts** — ports the image expects to expose
- **Config.Cmd** — default command run when container starts
- **Config.Env** — environment variables baked into the image
</details>

---

### Step 1.5 — Remove an Image

```bash
# Remove alpine (if not in use by a container)
docker image rm alpine
# or
docker rmi alpine
```

<details>
<summary>💡 Expected output</summary>

```
Untagged: alpine:latest
Untagged: alpine@sha256:...
Deleted: sha256:324bc02ae123...
Deleted: sha256:...         ← individual layers being freed
```
</details>

> ⚠️ If a container (even stopped) references the image, Docker will refuse to remove it. Use `docker rmi -f alpine` to force, or remove the container first.

---

## Task 2: Image Layers

### Step 2.1 — View Layer History

```bash
docker image history nginx
```

<details>
<summary>💡 Expected output</summary>

```
IMAGE          CREATED        CREATED BY                                      SIZE      COMMENT
a6bd71f48f68   2 weeks ago    CMD ["nginx" "-g" "daemon off;"]                0B        buildkit.dockerfile.v0
<missing>      2 weeks ago    STOPSIGNAL SIGQUIT                              0B
<missing>      2 weeks ago    EXPOSE 80                                       0B
<missing>      2 weeks ago    ENTRYPOINT ["/docker-entrypoint.sh"]            0B
<missing>      2 weeks ago    COPY 30-tune-worker-processes.sh /docker-en…   4.62kB
<missing>      2 weeks ago    COPY 20-envsubst-on-templates.sh /docker-en…   3.02kB
<missing>      2 weeks ago    RUN /bin/sh -c set -x && addgroup --system …   61.1MB
<missing>      2 weeks ago    ENV PKG_RELEASE=1~bookworm                      0B
<missing>      2 weeks ago    ENV NJS_RELEASE=3~bookworm                      0B
<missing>      2 weeks ago    ENV NJS_VERSION=0.8.3                           0B
<missing>      2 weeks ago    ENV NGINX_VERSION=1.27.0                        0B
<missing>      2 weeks ago    FROM debian:bookworm-slim                       74.8MB
```
</details>

**Reading the output:**
- Lines with **0B** = metadata-only instructions (`CMD`, `ENV`, `EXPOSE`, `ENTRYPOINT`) — they don't add filesystem data
- Lines with **sizes** = instructions that actually wrote files (`RUN`, `COPY`, `ADD`)
- `<missing>` in the IMAGE column = intermediate layers not stored as named images locally (normal)

**Notes to write:**

> **What are layers?**
> Each layer is an immutable filesystem snapshot representing the delta (diff) from the layer below it. Docker instructions like `RUN`, `COPY`, and `ADD` create new layers with actual data. Instructions like `CMD`, `ENV`, and `EXPOSE` create metadata-only layers with 0B size.
>
> **Why does Docker use layers?**
> 1. **Build cache** — if a layer hasn't changed, Docker reuses the cached version, making rebuilds fast
> 2. **Storage efficiency** — shared base layers (e.g., debian:bookworm-slim) are stored once and shared across many images
> 3. **Transfer efficiency** — when pushing/pulling, only missing layers are transferred

---

## Task 3: Container Lifecycle

Practice the full lifecycle on one container. Use `docker ps -a` after each step to observe state changes.

```
Created → Running → Paused → Running → Stopped → Running → Dead → (removed)
```

### Step 3.1 — Create (without starting)

```bash
docker create --name lifecycle-test nginx
docker ps -a
```

<details>
<summary>💡 Expected state</summary>

```
CONTAINER ID   IMAGE   COMMAND                  CREATED         STATUS    PORTS   NAMES
abc123def456   nginx   "/docker-entrypoint.…"   5 seconds ago   Created           lifecycle-test
```
Status = **Created** — filesystem allocated, not running yet.
</details>

---

### Step 3.2 — Start

```bash
docker start lifecycle-test
docker ps -a
```

<details>
<summary>💡 Expected state</summary>

```
STATUS
Up 3 seconds
```
</details>

---

### Step 3.3 — Pause

```bash
docker pause lifecycle-test
docker ps -a
```

<details>
<summary>💡 Expected state</summary>

```
STATUS
Up 30 seconds (Paused)
```

`docker pause` uses Linux **cgroups freezer** — the process is still in memory but the kernel stops scheduling it. No CPU cycles, no I/O — but memory is preserved.
</details>

---

### Step 3.4 — Unpause

```bash
docker unpause lifecycle-test
docker ps -a
```

<details>
<summary>💡 Expected state</summary>

```
STATUS
Up 45 seconds
```
Resumes exactly where it left off.
</details>

---

### Step 3.5 — Stop

```bash
docker stop lifecycle-test
docker ps -a
```

<details>
<summary>💡 Expected state</summary>

```
STATUS
Exited (0) 2 seconds ago
```

`docker stop` sends **SIGTERM** (graceful shutdown signal), waits 10 seconds, then sends **SIGKILL** if the process hasn't stopped.
</details>

---

### Step 3.6 — Restart

```bash
docker restart lifecycle-test
docker ps -a
```

<details>
<summary>💡 Expected state</summary>

```
STATUS
Up 2 seconds
```
</details>

---

### Step 3.7 — Kill

```bash
docker kill lifecycle-test
docker ps -a
```

<details>
<summary>💡 Expected state</summary>

```
STATUS
Exited (137) 1 second ago
```

`docker kill` sends **SIGKILL** immediately — no graceful shutdown. Exit code 137 = 128 + 9 (SIGKILL signal number).

`stop` vs `kill`:
| | `docker stop` | `docker kill` |
|---|---|---|
| Signal | SIGTERM → SIGKILL (after timeout) | SIGKILL immediately |
| Graceful? | Yes | No |
| Use when | Normal shutdown | Process is hung / unresponsive |
</details>

---

### Step 3.8 — Remove

```bash
docker rm lifecycle-test
docker ps -a
```

<details>
<summary>💡 Expected</summary>

Container is gone from `docker ps -a` entirely.
</details>

---

## Task 4: Working with Running Containers

### Step 4.1 — Run Nginx in Detached Mode

```bash
docker run -d --name webserver -p 8080:80 nginx
docker ps
```

<details>
<summary>💡 Flags explained</summary>

| Flag | Meaning |
|---|---|
| `-d` | Detached — runs in background, returns container ID |
| `--name webserver` | Give it a human-readable name |
| `-p 8080:80` | Map host port 8080 → container port 80 |
</details>

---

### Step 4.2 — View Logs

```bash
docker logs webserver
```

<details>
<summary>💡 Expected</summary>

Shows nginx startup logs and any HTTP request logs accumulated so far.
</details>

---

### Step 4.3 — Real-Time Logs (Follow Mode)

```bash
docker logs -f webserver
```

Open a browser or run `curl http://localhost:8080` in another terminal — you'll see new log lines appear in real time.

Press `Ctrl+C` to exit follow mode (container keeps running).

---

### Step 4.4 — Exec Into the Container

```bash
docker exec -it webserver bash
```

<details>
<summary>💡 Inside the container — things to explore</summary>

```bash
# Where is nginx installed?
which nginx
nginx -v

# View nginx config
cat /etc/nginx/nginx.conf
cat /etc/nginx/conf.d/default.conf

# See what's being served
ls /usr/share/nginx/html/

# Check running processes (PID 1 = nginx master)
ps aux

# Check network
cat /etc/hosts
hostname -i

# Exit
exit
```
</details>

---

### Step 4.5 — Run a Single Command Without Entering

```bash
docker exec webserver nginx -v
docker exec webserver cat /etc/nginx/nginx.conf
docker exec webserver ls /usr/share/nginx/html/
```

<details>
<summary>💡 When to use this vs exec -it</summary>

Use `exec -it` (interactive) when you need a shell session to explore.
Use `exec <cmd>` (non-interactive) for scripting, one-off checks, or automation.
</details>

---

### Step 4.6 — Inspect the Container

```bash
docker inspect webserver
```

<details>
<summary>💡 Key fields to find</summary>

**IP Address:**
```bash
docker inspect webserver --format '{{.NetworkSettings.IPAddress}}'
# e.g., 172.17.0.2
```

**Port Mappings:**
```bash
docker inspect webserver --format '{{json .NetworkSettings.Ports}}'
# {"80/tcp":[{"HostIp":"0.0.0.0","HostPort":"8080"}]}
```

**Mounts:**
```bash
docker inspect webserver --format '{{json .Mounts}}'
# [] — no volumes mounted for this container
```

**Full inspect gives you:**
- `State` — running/paused/stopped, PID, start time, exit code
- `NetworkSettings` — IP, MAC address, ports, networks
- `HostConfig` — resource limits, restart policy, port bindings
- `Mounts` — volume and bind mount mappings
- `Config` — image, cmd, env vars, labels
</details>

---

## Task 5: Cleanup

### Step 5.1 — Stop All Running Containers

```bash
docker stop $(docker ps -q)
```

<details>
<summary>💡 How it works</summary>

`docker ps -q` outputs only container IDs of **running** containers (quiet mode).
`$()` passes those IDs as arguments to `docker stop`.
</details>

---

### Step 5.2 — Remove All Stopped Containers

```bash
docker container prune
# Confirm with 'y'

# Or the subshell approach:
docker rm $(docker ps -aq)
```

<details>
<summary>💡 Difference</summary>

`docker container prune` — removes only **stopped** containers, prompts for confirmation.
`docker rm $(docker ps -aq)` — attempts to remove ALL containers (will error on running ones unless you add `-f`).
</details>

---

### Step 5.3 — Remove Unused Images

```bash
docker image prune
# Removes dangling images (untagged, not referenced by any container)

docker image prune -a
# Removes ALL unused images (not just dangling — also tagged but unreferenced)
```

> ⚠️ Be careful with `-a` — it removes images you might want to keep for future containers.

---

### Step 5.4 — Check Docker Disk Usage

```bash
docker system df
```

<details>
<summary>💡 Expected output</summary>

```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          3         0         277MB     277MB (100%)
Containers      0         0         0B        0B
Local Volumes   0         0         0B        0B
Build Cache     12        0         45MB      45MB
```
</details>

For a detailed breakdown:

```bash
docker system df -v
```

To reclaim everything at once (nuclear option):

```bash
docker system prune -a
# Removes: stopped containers + unused images + unused networks + build cache
```

---

## Key Takeaways

| Concept | What to Remember |
|---|---|
| Image layers | Immutable, cached, shared — only diffs are stored |
| Alpine vs Ubuntu | Alpine ~7MB (musl+BusyBox) vs Ubuntu ~78MB (full GNU toolchain) |
| `docker stop` vs `docker kill` | SIGTERM (graceful) vs SIGKILL (immediate) |
| `docker pause` | Freezes process in memory — cgroups freezer, not killed |
| `docker exec -it` | Interactive shell inside running container |
| `docker inspect` | Full metadata: IP, ports, mounts, state, config |
| `docker system df` | See disk usage across images, containers, volumes, cache |

---

> **LinkedIn post idea:** "Docker image layers aren't just a caching trick — they're why `docker pull` skips layers you already have, and why Alpine at 7MB can replace Ubuntu at 78MB for most container workloads. Day 30 of #90DaysOfDevOps 🐳 #DevOpsKaJosh #TrainWithShubham"
