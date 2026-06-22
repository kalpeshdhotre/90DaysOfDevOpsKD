# Day 31 – Dockerfile: Build Your Own Images

## Task Completed

Wrote Dockerfiles and built custom images — covering all core Dockerfile instructions, CMD vs ENTRYPOINT, Nginx static site, .dockerignore, and build layer caching.

---

## Task 1: My First Dockerfile

**Dockerfile (`my-first-image/Dockerfile`):**

```dockerfile
FROM ubuntu

RUN apt-get update && apt-get install -y curl

CMD ["echo", "Hello from my custom image!"]
```

**Commands:**

```bash
docker build -t my-ubuntu:v1 .
docker run my-ubuntu:v1
```

**Output:**

```
Hello from my custom image!
```

## ![alt text](<Screenshot From 2026-06-22 18-25-43.png>)

## Task 2: All Core Dockerfile Instructions

**`app.sh`:**

```bash
#!/bin/bash
echo "App is running from WORKDIR: $(pwd)"
echo "Files here:"
ls -la
```

**Dockerfile (`my-app-image/Dockerfile`):**

```dockerfile
FROM ubuntu

RUN apt-get update && apt-get install -y bash

WORKDIR /app

COPY app.sh .

EXPOSE 8080

CMD ["bash", "app.sh"]
```

**Commands:**

```bash
docker build -t my-app:v1 .
docker run my-app:v1
```

**Output:**

```
App is running from WORKDIR: /app
Files here:
total 12
drwxr-xr-x 2 root root 4096 ...  .
drwxr-xr-x 1 root root 4096 ...  ..
-rw-r--r-- 1 root root   XX ...  app.sh
```

**What each instruction does:**
| Instruction | Purpose |
|---|---|
| `FROM ubuntu` | Sets Ubuntu as the base image |
| `RUN apt-get ...` | Installs bash during build (creates a new layer) |
| `WORKDIR /app` | Sets working directory; creates it if missing |
| `COPY app.sh .` | Copies app.sh from host into /app inside the image |
| `EXPOSE 8080` | Documents the port — does NOT publish it |
| `CMD ["bash", "app.sh"]` | Default command when container starts |

---

## Task 3: CMD vs ENTRYPOINT

### CMD Demo

**Dockerfile (`cmd-demo/Dockerfile`):**

```dockerfile
FROM ubuntu
CMD ["echo", "hello"]
```

```bash
docker build -t cmd-demo:v1 .

docker run cmd-demo:v1
# Output: hello

docker run cmd-demo:v1 echo "world"
# Output: world  ← CMD is completely replaced
```

### ENTRYPOINT Demo

**Dockerfile (`ep-demo/Dockerfile`):**

```dockerfile
FROM ubuntu
ENTRYPOINT ["echo"]
```

```bash
docker build -t ep-demo:v1 .

docker run ep-demo:v1 "DevOps is awesome"
# Output: DevOps is awesome  ← argument APPENDED to entrypoint
```

### When to use which?

| Use Case                                    | Choice                        |
| ------------------------------------------- | ----------------------------- |
| Default command users will often override   | `CMD`                         |
| Image behaves like a dedicated executable   | `ENTRYPOINT`                  |
| Fixed executable + overridable default args | `ENTRYPOINT` + `CMD` together |

---

## Task 4: Simple Web App Image (Nginx)

**`index.html`:**

```html
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <title>My Docker Site</title>
    </head>
    <body>
        <h1>Hello from Docker!</h1>
        <p>Served by Nginx inside a container.</p>
        <p>Built on Day 31 of #90DaysOfDevOps</p>
    </body>
</html>
```

**Dockerfile (`my-website/Dockerfile`):**

```dockerfile
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

**Commands:**

```bash
docker build -t my-website:v1 .
docker run -d -p 8080:80 --name my-site my-website:v1
curl http://localhost:8080

# Cleanup
docker stop my-site && docker rm my-site
```

**Why `nginx:alpine`?** Minimal base (~5 MB vs ~140 MB for full nginx). Always prefer slim images.

---

## Task 5: .dockerignore

**`.dockerignore`:**

```
node_modules
.git
*.md
.env
*.log
__pycache__
.DS_Store
```

**Verified:** Build log confirmed ignored files were not sent to the daemon or copied into the image.

**Why it matters:**

- Reduces build context size → faster builds
- Prevents secrets (`.env`) from leaking into image layers
- Avoids unnecessary cache invalidation from unrelated file changes

---

## Task 6: Build Optimization & Layer Caching

**Dockerfile (optimized ordering):**

```dockerfile
FROM ubuntu

# Stable, slow step — stays cached across most rebuilds
RUN apt-get update && apt-get install -y python3

# Volatile, fast step — cache only invalidates when code changes
WORKDIR /app
COPY app.py .

CMD ["python3", "app.py"]
```

**Experiment:**

```bash
# Build 1 — all steps execute
docker build -t cache-demo:v1 .

# Build 2 — no changes → all steps show "Using cache"
docker build -t cache-demo:v1 .

# Edit app.py, then build again
echo 'print("Updated!")' > app.py
docker build -t cache-demo:v1 .
# Only COPY and CMD re-execute; RUN apt-get uses cache
```

**Why layer order matters:**
Docker cache invalidates at the first changed layer and rebuilds everything after it. Keeping slow, stable steps early (deps install) and fast, changing steps late (source code copy) ensures most rebuilds only re-run the fast steps.

![alt text](<Screenshot From 2026-06-22 19-09-07.png>)

---

## Key Learnings

- A Dockerfile is a repeatable recipe — same input always produces the same image
- Every `RUN`, `COPY`, `ADD` creates a new layer; `CMD`/`EXPOSE` do not
- **CMD** = overridable default command; **ENTRYPOINT** = fixed executable
- Layer order is a performance decision: stable first, volatile last
- `.dockerignore` is as important as `.gitignore` — use it on every project
- `nginx:alpine` is the go-to for static file serving: tiny, fast, production-ready
