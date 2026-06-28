# Docker Cheat Sheet
> Days 29–36 consolidated | kalpeshdhotre | 90DaysOfDevOps

---

## Container Commands

```bash
# Run
docker run nginx                                 # run in foreground
docker run -d nginx                              # detached (background)
docker run -it ubuntu bash                       # interactive + TTY
docker run -d -p 8080:80 --name web nginx        # named, with port mapping
docker run --rm alpine echo "hello"              # auto-remove on exit
docker run -e ENV_VAR=value nginx                # pass environment variable
docker run -v myvolume:/data nginx               # named volume mount
docker run -v $(pwd):/app node                   # bind mount

# Inspect & monitor
docker ps                                        # running containers
docker ps -a                                     # all containers (including stopped)
docker logs web                                  # stdout/stderr of container
docker logs -f web                               # follow live logs
docker exec -it web bash                         # shell into running container
docker exec web ls /app                          # run single command inside
docker inspect web                               # full JSON metadata
docker stats                                     # live CPU/mem usage

# Lifecycle
docker stop web                                  # graceful stop (SIGTERM → SIGKILL)
docker kill web                                  # immediate kill (SIGKILL)
docker start web                                 # restart a stopped container
docker restart web                               # stop + start
docker rm web                                    # remove stopped container
docker rm -f web                                 # force remove running container
docker rm $(docker ps -aq)                       # remove all stopped containers
```

---

## Image Commands

```bash
docker pull nginx                                # pull from Docker Hub
docker pull nginx:1.25-alpine                    # pull specific tag

docker build -t myapp:v1 .                       # build from Dockerfile in CWD
docker build -t myapp:v1 -f Dockerfile.prod .    # use alternate Dockerfile
docker build --no-cache -t myapp:v1 .            # force rebuild all layers

docker images                                    # list local images
docker image ls                                  # same as above
docker image inspect nginx                       # full image metadata
docker image history nginx                       # show layer history

docker tag myapp:v1 kalpeshdhotre/myapp:v1       # tag for Hub push
docker push kalpeshdhotre/myapp:v1               # push to Docker Hub
docker pull kalpeshdhotre/myapp:v1               # pull your own image

docker rmi nginx                                 # remove image
docker rmi -f nginx                              # force remove (even if tagged)
docker image prune                               # remove dangling images only
docker image prune -a                            # remove all unused images
```

---

## Volume Commands

```bash
docker volume create mydata                      # create named volume
docker volume ls                                 # list volumes
docker volume inspect mydata                     # show mountpoint + metadata
docker volume rm mydata                          # remove volume
docker volume prune                              # remove all unused volumes

# Mount syntax in docker run
-v mydata:/app/data                              # named volume
-v $(pwd)/data:/app/data                         # bind mount (absolute path required)
-v $(pwd)/data:/app/data:ro                      # read-only bind mount
--mount type=volume,src=mydata,dst=/app/data     # explicit --mount syntax
```

---

## Network Commands

```bash
docker network create mynet                      # create custom bridge network
docker network create --driver bridge mynet      # explicit driver (default)
docker network ls                                # list networks
docker network inspect mynet                     # show connected containers + config
docker network rm mynet                          # remove network

docker run -d --network mynet --name app nginx   # connect at run time
docker network connect mynet web                 # connect running container
docker network disconnect mynet web              # disconnect container

# Containers on same custom network → reach each other by name (DNS)
# Default bridge network → only by IP, no DNS
```

---

## Compose Commands

```bash
docker compose up                                # start all services (foreground)
docker compose up -d                             # start detached
docker compose up --build                        # rebuild images before starting
docker compose up --build service_name           # rebuild one service only

docker compose down                              # stop + remove containers & networks
docker compose down -v                           # also remove named volumes
docker compose down --rmi all                    # also remove images

docker compose ps                                # list compose-managed containers
docker compose logs                              # all service logs
docker compose logs -f app                       # follow one service's logs
docker compose exec app bash                     # shell into running service
docker compose run --rm app node script.js       # one-off command in new container

docker compose build                             # build/rebuild images
docker compose pull                              # pull latest images
docker compose restart app                       # restart one service
docker compose stop                              # stop without removing
docker compose start                             # start stopped services
```

---

## Cleanup Commands

```bash
docker system df                                 # disk usage summary (images/containers/volumes/cache)
docker system df -v                              # verbose breakdown

docker container prune                           # remove all stopped containers
docker image prune                               # remove dangling images
docker image prune -a                            # remove all unused images
docker volume prune                              # remove unused volumes
docker network prune                             # remove unused networks
docker builder prune                             # remove build cache

docker system prune                              # containers + networks + dangling images
docker system prune -a                           # + all unused images
docker system prune -a --volumes                 # + volumes (nuclear option)
```

---

## Dockerfile Instructions

```dockerfile
FROM node:20-alpine              # base image — always the first instruction
WORKDIR /app                     # set working directory (creates it if missing)
COPY package*.json ./            # copy files from host → container (preferred over ADD)
ADD archive.tar.gz /app/         # like COPY but also extracts tarballs and fetches URLs
RUN npm install                  # runs during build, creates a new layer
RUN apt-get update && \
    apt-get install -y curl      # chain commands to keep layers lean
ENV NODE_ENV=production          # set env variable (available at build + runtime)
ARG BUILD_VERSION=1.0            # build-time variable only (not in final image)
EXPOSE 3000                      # documents the port (doesn't actually publish it)
VOLUME ["/data"]                 # declares a mount point (prefer explicit -v at runtime)
USER node                        # switch to non-root user (security best practice)
HEALTHCHECK --interval=30s \
  CMD curl -f http://localhost/  # container health probe
CMD ["node", "server.js"]        # default command — overridable at docker run
ENTRYPOINT ["node"]              # fixed executable — args appended at docker run
```

**CMD vs ENTRYPOINT quick rule:**
- `CMD` alone → fully replaceable default
- `ENTRYPOINT` alone → locked executable, user adds args
- `ENTRYPOINT` + `CMD` together → fixed binary + overridable default args

---

## Multi-Stage Build Pattern

```dockerfile
# Stage 1: Build
FROM node:20 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Runtime (lean)
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER node
CMD ["node", "dist/index.js"]
```

---

## Docker Compose File Reference

```yaml
version: "3.9"

services:
  app:
    build: .                          # build from local Dockerfile
    image: myapp:latest               # or pull this image
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    env_file:
      - .env                          # load vars from .env file
    volumes:
      - ./src:/app/src                # bind mount for dev hot-reload
      - uploads:/app/uploads          # named volume for persistent data
    networks:
      - backend
    depends_on:
      db:
        condition: service_healthy    # wait for healthcheck to pass
    restart: unless-stopped

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: ${DB_PASS}   # value from .env
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      retries: 5

volumes:
  pgdata:
  uploads:

networks:
  backend:
    driver: bridge
```

---

*Last updated: Day 37 | #90DaysOfDevOps #DevOpsKaJosh #TrainWithShubham*
