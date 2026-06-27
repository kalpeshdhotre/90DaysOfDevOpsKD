# Day 36 – Docker Project: Dockerizing a Full-Stack Todo API

## What App I Chose and Why

I built a **Node.js Express + MongoDB Todo REST API** from scratch and Dockerized it end-to-end.

**Why this app?**
- Familiar stack (JS/Node) — so all mental energy went into Docker, not app logic
- Represents a real-world pattern: stateless API + stateful database
- Covers every Compose requirement: multi-service, volumes, networking, healthchecks

---

## Project Structure

```
day-36-docker-project/
├── app/
│   ├── server.js
│   ├── package.json
│   ├── Dockerfile
│   └── .dockerignore
├── docker-compose.yml
├── .env.example
└── day-36-docker-project.md
```

---

## The Application

A simple REST API with three endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/todos` | List all todos |
| POST | `/todos` | Create a todo |

---

## Dockerfile (with comments)

```dockerfile
# ─── Stage 1: Build — install production dependencies ─────────────────────────
FROM node:20-alpine AS builder

# Set working directory inside container
WORKDIR /app

# Copy package files first (layer cache: only re-runs npm ci if package.json changes)
COPY package*.json ./

# Install only production dependencies — no devDependencies
RUN npm ci --omit=dev

# ─── Stage 2: Final runtime image ─────────────────────────────────────────────
FROM node:20-alpine AS runner

# Create a non-root group and user — never run apps as root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy node_modules from builder stage — not from host machine
COPY --from=builder /app/node_modules ./node_modules

# Copy only the app source file
COPY server.js .

# Transfer ownership of /app to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user for all subsequent commands
USER appuser

# Inform Docker which port the app listens on (documentation + -P flag support)
EXPOSE 3000

# Health check — Docker will probe this to mark container healthy/unhealthy
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Start the Node.js server
CMD ["node", "server.js"]
```

---

## docker-compose.yml

```yaml
name: todo-app

networks:
  app-net:
    driver: bridge             # Custom isolated network — services talk by name

volumes:
  mongo-data:                  # Named volume — data persists across container restarts

services:
  mongo:
    image: mongo:7-jammy
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_INITDB_ROOT_USERNAME}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_INITDB_ROOT_PASSWORD}
    volumes:
      - mongo-data:/data/db    # Persist MongoDB data to named volume
    networks:
      - app-net
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s        # Give Mongo time to initialize before first probe

  api:
    image: kalpeshdhotre/todo-api:latest   # Pulled from Docker Hub
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      MONGO_URI: ${MONGO_URI}
      PORT: ${PORT}
    networks:
      - app-net
    depends_on:
      mongo:
        condition: service_healthy   # API waits until Mongo passes healthcheck
```

---

## .env.example

```env
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=your_password_here
MONGO_URI=mongodb://admin:your_password_here@mongo:27017/todos?authSource=admin
PORT=3000
```

---

## Challenges Faced and How I Solved Them

### Challenge 1: Port Conflict on 3000
When running the container, port 3000 was already occupied by another process on the host.

**Fix:** Identified the conflicting process using:
```bash
# On Windows
netstat -ano | findstr :3000

# Killed the process or remapped the port
docker compose up  # after freeing the port
```

### Challenge 2: `docker run` fails without MongoDB
Running `docker run kalpeshdhotre/todo-api:latest` directly caused an immediate crash:
```
MongooseServerSelectionError: connect ECONNREFUSED 127.0.0.1:27017
```
The app fell back to `localhost:27017` — but there was no MongoDB inside the container.

**Fix:** Understood that this image is designed to run via `docker compose`, not standalone. The `.env` supplies `MONGO_URI` pointing to the `mongo` service by its Compose service name — which only resolves inside the custom Docker network.

### Challenge 3: `depends_on` alone isn't enough
Initially used `depends_on: mongo` without a health condition. The API started before MongoDB was ready, causing connection errors.

**Fix:** Added `condition: service_healthy` with a proper `mongosh ping` healthcheck on the mongo service. API now waits until Mongo is genuinely ready.

---

## Final Image Size

| Stage | Base Image | Compressed (Docker Hub) |
|-------|-----------|--------------------------|
| Builder | node:20-alpine | — |
| **Final (runner)** | **node:20-alpine** | **51.85 MB** |

Multi-stage build kept the final image lean — only production `node_modules` and `server.js` make it into the runtime image.

---

## How to Run This App

### Prerequisites
- Docker + Docker Compose installed

### Steps

```bash
# 1. Copy the compose file from the repo
git clone https://github.com/kalpeshdhotre/90DaysOfDevOps
cd 2026/day-36/

# 2. Create your .env from the example
cp .env.example .env
# Edit .env with your passwords

# 3. Run
docker compose up

# 4. Test
curl http://localhost:3000/health
curl -X POST http://localhost:3000/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "My first todo"}'
curl http://localhost:3000/todos
```

---

## Docker Hub

🐳 **Image:** `kalpeshdhotre/todo-api:latest`
🔗 **Link:** https://hub.docker.com/r/kalpeshdhotre/todo-api

Pull it directly:
```bash
docker pull kalpeshdhotre/todo-api:latest
```

---

## Key Learnings

- **Multi-stage builds** are powerful — builder stage does the heavy lifting, runner stage stays lean
- **Non-root users** in containers are a security baseline, not optional
- **`depends_on` + `condition: service_healthy`** is the correct pattern for service startup ordering — not just `depends_on` alone
- **`.env` never goes into the image or Docker Hub** — it's infrastructure config supplied at runtime
- **`docker run` vs `docker compose up`** — bare `docker run` is for single self-contained images; multi-service apps always need Compose
- An image on Docker Hub + a `docker-compose.yml` on GitHub = everything someone needs to run your app

---

*Day 36 of #90DaysOfDevOps | TrainWithShubham*
