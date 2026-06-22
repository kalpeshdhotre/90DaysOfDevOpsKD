# Day 31 – Dockerfile: Build Your Own Images

## What is a Dockerfile?

A **Dockerfile** is a plain-text script of instructions that Docker reads top-to-bottom to build a custom image. Each instruction creates a new **layer** in the image. You start from a base image, install dependencies, copy your code, and define how the container should run.

```
Host machine (build context)
        │
        ▼
  docker build
        │
        ▼
  Dockerfile (layer by layer)
  ├── FROM   → base layer
  ├── RUN    → new layer (packages, commands)
  ├── COPY   → new layer (your files)
  └── CMD    → metadata (no new layer)
        │
        ▼
  Custom Image (saved locally)
        │
        ▼
  docker run → Container
```

---

## Core Dockerfile Instructions

| Instruction  | Purpose |
|---|---|
| `FROM`        | Set the base image — every Dockerfile starts here |
| `RUN`         | Execute shell commands during the build |
| `COPY`        | Copy files from the build context into the image |
| `WORKDIR`     | Set the working directory for subsequent instructions |
| `EXPOSE`      | Document which port the app listens on |
| `CMD`         | Default command when a container starts (overridable) |
| `ENTRYPOINT`  | Main executable; arguments are appended, not replaced |
| `ENV`         | Set environment variables inside the image |
| `ARG`         | Build-time variables (not persisted in the image) |

---

## Task 1 – Your First Dockerfile

**Goal:** Build a minimal Ubuntu image that prints a message.

### Steps

```bash
# 1. Create the project folder and navigate into it
mkdir my-first-image && cd my-first-image

# 2. Create the Dockerfile
```

```dockerfile
# my-first-image/Dockerfile
FROM ubuntu

RUN apt-get update && apt-get install -y curl

CMD ["echo", "Hello from my custom image!"]
```

```bash
# 3. Build the image (the . means "current directory is the build context")
docker build -t my-ubuntu:v1 .

# 4. Run a container from your image
docker run my-ubuntu:v1
```

**Expected output:**
```
Hello from my custom image!
```

<details>
<summary>💡 Solution & Explanation</summary>

```dockerfile
FROM ubuntu
# Pull the official Ubuntu image from Docker Hub as the base layer.

RUN apt-get update && apt-get install -y curl
# RUN executes during the build, not at runtime.
# Combining update + install in one RUN keeps them in a single layer.
# If you split them, Docker might cache a stale package list.

CMD ["echo", "Hello from my custom image!"]
# CMD sets the default command for `docker run`.
# Exec form (JSON array) is preferred — avoids a shell wrapper process.
```

```bash
docker build -t my-ubuntu:v1 .
# -t  → tag the image as my-ubuntu:v1
# .   → build context is the current directory
#       Docker sends everything here to the daemon

docker run my-ubuntu:v1
# Starts a container, runs CMD, container exits immediately.
```

</details>

---

## Task 2 – All Core Instructions in One Dockerfile

**Goal:** Use `FROM`, `RUN`, `COPY`, `WORKDIR`, `EXPOSE`, and `CMD` together.

### Steps

```bash
mkdir my-app-image && cd my-app-image
```

Create `app.sh`:

```bash
#!/bin/bash
echo "App is running from WORKDIR: $(pwd)"
echo "Files here:"
ls -la
```

Create the Dockerfile:

```dockerfile
# my-app-image/Dockerfile
FROM ubuntu

RUN apt-get update && apt-get install -y bash

WORKDIR /app

COPY app.sh .

EXPOSE 8080

CMD ["bash", "app.sh"]
```

```bash
# Build and run
docker build -t my-app:v1 .
docker run my-app:v1
```

<details>
<summary>💡 Solution & Explanation</summary>

| Instruction | What it does here |
|---|---|
| `FROM ubuntu` | Starts with a minimal Ubuntu base |
| `RUN apt-get ...` | Installs bash during build (new layer created) |
| `WORKDIR /app` | All subsequent `COPY`, `RUN`, `CMD` paths are relative to `/app`. Also creates the directory if missing. |
| `COPY app.sh .` | Copies `app.sh` from the host's build context into `/app/app.sh` inside the image |
| `EXPOSE 8080` | Documentation only — tells readers (and tools) what port the app uses. Does NOT publish it. You still need `-p 8080:8080` at `docker run`. |
| `CMD ["bash", "app.sh"]` | The default command runs when a container starts |

**Verify the WORKDIR:**
```
App is running from WORKDIR: /app
Files here:
total 12
drwxr-xr-x 2 root root 4096 ...  .
drwxr-xr-x 1 root root 4096 ...  ..
-rw-r--r-- 1 root root   XX ...  app.sh
```

</details>

---

## Task 3 – CMD vs ENTRYPOINT

**Goal:** Understand what gets replaced and what doesn't.

### 3a — CMD behavior

```dockerfile
# cmd-demo/Dockerfile
FROM ubuntu
CMD ["echo", "hello"]
```

```bash
docker build -t cmd-demo:v1 .

# Run without arguments → CMD executes
docker run cmd-demo:v1
# Output: hello

# Run WITH a custom command → CMD is completely REPLACED
docker run cmd-demo:v1 echo "world"
# Output: world

docker run cmd-demo:v1 ls /
# Output: the root directory listing — CMD is gone
```

### 3b — ENTRYPOINT behavior

```dockerfile
# ep-demo/Dockerfile
FROM ubuntu
ENTRYPOINT ["echo"]
```

```bash
docker build -t ep-demo:v1 .

# Run without arguments
docker run ep-demo:v1
# Output: (blank line — echo with no args)

# Run with arguments → they are APPENDED to ENTRYPOINT
docker run ep-demo:v1 "DevOps is awesome"
# Output: DevOps is awesome
```

### 3c — Combined (best practice pattern)

```dockerfile
FROM ubuntu
ENTRYPOINT ["echo"]
CMD ["default message"]
# CMD provides the default argument to ENTRYPOINT
# Override CMD at runtime: docker run myimage "custom message"
```

<details>
<summary>💡 CMD vs ENTRYPOINT — Decision Guide</summary>

```
Use CMD when:
  → The command is just a sensible default
  → Users will frequently want to run something else
  → Example: a toolbox image where users run different commands

Use ENTRYPOINT when:
  → The image IS that command (it's a dedicated tool)
  → You want the image to behave like an executable
  → Example: docker run myimage --help feels natural

Use ENTRYPOINT + CMD together when:
  → ENTRYPOINT = the fixed executable
  → CMD = default arguments (overridable without touching the entrypoint)
  → Example: nginx, ffmpeg, curl-based utility images
```

| Scenario | `docker run myimage` | `docker run myimage arg` |
|---|---|---|
| Only `CMD` | Runs CMD | Replaces CMD entirely |
| Only `ENTRYPOINT` | Runs ENTRYPOINT | ENTRYPOINT + arg |
| Both | ENTRYPOINT + CMD args | ENTRYPOINT + your args |

</details>

---

## Task 4 – Build a Simple Web App Image

**Goal:** Serve a static HTML page with Nginx inside a container.

### Steps

```bash
mkdir my-website && cd my-website
```

Create `index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>My Docker Site</title>
  <style>
    body { font-family: sans-serif; background: #1a1a2e; color: #eee;
           display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
    .card { background: #16213e; padding: 2rem; border-radius: 1rem; text-align: center; }
    h1 { color: #0f3460; color: #e94560; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🐳 Hello from Docker!</h1>
    <p>Served by Nginx inside a container.</p>
    <p>Built on Day 31 of #90DaysOfDevOps</p>
  </div>
</body>
</html>
```

Create the Dockerfile:

```dockerfile
# my-website/Dockerfile
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

# No CMD needed — nginx:alpine already defines it
```

```bash
# Build
docker build -t my-website:v1 .

# Run with port mapping: host:container
docker run -d -p 8080:80 --name my-site my-website:v1

# Verify it's running
docker ps

# Access in browser (or curl)
curl http://localhost:8080
```

Open `http://localhost:8080` in your browser.

```bash
# Cleanup
docker stop my-site && docker rm my-site
```

<details>
<summary>💡 Solution & Explanation</summary>

**Why `nginx:alpine`?**
- `alpine` is a minimal Linux distro (~5 MB) — much smaller than `nginx:latest` (~140 MB)
- Always prefer slim/alpine base images in production when possible

**Port mapping explained:**
```
-p 8080:80
    │     │
    │     └── Container port (Nginx listens here)
    └──────── Host port (you browse to this)
```

**Why no CMD?**  
The `nginx:alpine` image already has `CMD ["nginx", "-g", "daemon off;"]` defined. Your `FROM` inherits it. You only override if you need to change it.

**Nginx web root:** `/usr/share/nginx/html/`  
Any file you `COPY` here is served automatically.

</details>

---

## Task 5 – .dockerignore

**Goal:** Prevent unnecessary files from being sent to the Docker daemon during build.

### What is the build context?

When you run `docker build .`, Docker **tars up the entire current directory** and sends it to the daemon before it even reads the Dockerfile. Large or sensitive files slow down every build and can accidentally end up in the image.

### Steps

In any project folder, create `.dockerignore`:

```
# .dockerignore
node_modules
.git
*.md
.env
*.log
__pycache__
.DS_Store
```

### Verify ignored files are excluded

```dockerfile
# test-ignore/Dockerfile
FROM ubuntu
COPY . /app
RUN ls -la /app
```

```bash
# Create some files to test
mkdir test-ignore && cd test-ignore
echo "secret=abc123" > .env
echo "# readme" > README.md
touch notes.md

cat > .dockerignore << 'EOF'
*.md
.env
EOF

cat > Dockerfile << 'EOF'
FROM ubuntu
COPY . /app
RUN ls -la /app
EOF

docker build -t ignore-test:v1 .
# Watch the RUN ls output — .env and *.md files won't appear
```

<details>
<summary>💡 Common .dockerignore Patterns</summary>

```gitignore
# Dependencies — never copy these, install fresh inside the image
node_modules/
vendor/
__pycache__/
*.pyc

# Version control
.git/
.gitignore

# Secrets and local config
.env
.env.*
*.pem
*.key

# Documentation (usually not needed at runtime)
*.md
docs/

# Build artifacts
dist/
build/
*.log

# OS junk
.DS_Store
Thumbs.db
```

**Rules match the same syntax as `.gitignore`.**

Key point: `.dockerignore` reduces:
1. Build context size (faster uploads to daemon)
2. Risk of leaking secrets into image layers
3. Cache invalidation from irrelevant file changes

</details>

---

## Task 6 – Build Optimization & Layer Caching

**Goal:** Understand Docker's layer cache and write cache-friendly Dockerfiles.

### How layer caching works

Docker caches each layer. On rebuild, it reuses cached layers until it hits a change — then it rebuilds that layer **and every layer after it**.

### Experiment: watch the cache

```dockerfile
# cache-demo/Dockerfile  (bad ordering)
FROM ubuntu
COPY . /app          # ← app code changes often → cache miss here
RUN apt-get update && apt-get install -y python3  # rebuilds every time!
```

```dockerfile
# cache-demo/Dockerfile  (good ordering)
FROM ubuntu
RUN apt-get update && apt-get install -y python3  # rarely changes → stays cached
COPY . /app          # changes often → cache miss here, but only pip install is skipped
```

### Steps

```bash
mkdir cache-demo && cd cache-demo

cat > app.py << 'EOF'
print("Hello DevOps!")
EOF

cat > Dockerfile << 'EOF'
FROM ubuntu

# Dependencies first (slow, rarely changes)
RUN apt-get update && apt-get install -y python3

# App code last (fast, changes often)
WORKDIR /app
COPY app.py .

CMD ["python3", "app.py"]
EOF

# First build — no cache, watch all steps execute
docker build -t cache-demo:v1 .

# Second build — no changes, everything comes from cache
docker build -t cache-demo:v1 .
# You'll see "Using cache" on every step

# Change app.py, rebuild
echo 'print("Updated!")' > app.py
docker build -t cache-demo:v1 .
# Steps before COPY are cached; only COPY and CMD re-execute
```

<details>
<summary>💡 Layer Order Rules</summary>

**Stable → volatile ordering:**
```
1. FROM           ← never changes
2. Install OS deps (RUN apt/yum)  ← changes rarely
3. Install language deps (pip/npm) ← changes occasionally
4. COPY source code               ← changes frequently
5. RUN build commands             ← must run after source changes
6. CMD/ENTRYPOINT                 ← metadata, no new layer
```

**Real-world Node.js example:**
```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy only package files first — npm install is cached if deps don't change
COPY package.json package-lock.json ./
RUN npm ci --only=production

# Copy source code last — this changes every commit
COPY . .

EXPOSE 3000
CMD ["node", "index.js"]
```

Without this pattern, every code change → full `npm ci` re-run (~minutes).  
With this pattern, only code changes → `npm ci` uses cache (~seconds).

**Why does layer order matter?**  
Docker cache invalidates at the first changed layer and rebuilds everything after it. Keeping slow, stable steps early means they stay cached. Putting fast, frequently-changing steps last means rebuilds are minimal.

</details>

---

## Dockerfile Best Practices Summary

```
✅ Use specific base image tags (nginx:1.25-alpine, not nginx:latest)
✅ Combine RUN commands with && to reduce layers
✅ Put COPY before RUN only when needed for that RUN
✅ Use .dockerignore to exclude secrets, docs, and build artifacts
✅ Order layers: stable → volatile (deps before source code)
✅ Prefer alpine/slim base images for smaller, faster images
✅ Use exec form for CMD/ENTRYPOINT: ["cmd", "arg"] not cmd arg
✅ One concern per image (don't pack multiple services into one)

❌ Don't run as root in production (add a non-root USER)
❌ Don't store secrets in ENV or image layers
❌ Don't use COPY . . before installing dependencies
❌ Don't install debug tools in production images
```

---

## Quick Reference — Commands Used Today

```bash
# Build
docker build -t name:tag .          # build from current directory
docker build -t name:tag -f path/Dockerfile .  # specify Dockerfile path

# Inspect
docker images                        # list local images
docker history my-ubuntu:v1          # show layers and sizes
docker inspect my-ubuntu:v1          # full image metadata

# Run
docker run name:tag                  # run with defaults
docker run name:tag custom-command   # override CMD
docker run -d -p host:container name:tag  # detached with port mapping
docker run --rm name:tag             # auto-remove container on exit

# Cleanup
docker rmi name:tag                  # remove image
docker system prune                  # remove all unused images, containers, networks
```

---

## Key Takeaways

- A Dockerfile is a repeatable recipe — same input always produces the same image
- Every `RUN`, `COPY`, and `ADD` creates a new layer; `CMD`/`EXPOSE` do not
- **CMD** = overridable default; **ENTRYPOINT** = fixed executable
- Layer order is a performance decision: stable layers first, changing layers last
- `.dockerignore` is as important as `.gitignore` — use it on every project
- `nginx:alpine` is the go-to for serving static files: tiny, fast, production-ready
