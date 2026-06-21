# Day 30 – Docker Images & Container Lifecycle

## What I Did Today

Practised the full Docker image and container workflow — pulling images, inspecting layers, running through every container state, exec-ing into live containers, and cleaning up.

---

## Task 1: Docker Images

### Pulled images and compared sizes

```bash
docker pull nginx
docker pull ubuntu
docker pull alpine
docker images
```

| Image  | Size    |
| ------ | ------- |
| nginx  | ~192 MB |
| ubuntu | ~78 MB  |
| alpine | ~7.8 MB |

**Ubuntu vs Alpine:**
Alpine uses `musl libc` + `BusyBox` instead of the full GNU toolchain — no systemd, no apt, no extra utilities. That's why it's ~10× smaller. Ubuntu is better for familiarity and tooling; Alpine is the default choice when you want the smallest possible image.

### Inspected nginx image

```bash
docker image inspect nginx
```

![alt text](<Screenshot From 2026-06-21 17-47-40.png>)

Found: layer SHAs under `RootFS.Layers`, default `Cmd`, `ExposedPorts` (80/tcp), and baked-in `Env` variables.

### Removed alpine

```bash
docker rmi alpine
```

---

## Task 2: Image Layers

```bash
docker image history nginx
```

![alt text](<Screenshot From 2026-06-21 17-49-11.png>)

**What I saw:** Layers with 0B size = metadata instructions (`CMD`, `ENV`, `EXPOSE`). Layers with actual sizes = instructions that wrote files (`RUN`, `COPY`).

**What are layers and why does Docker use them?**

Each layer is an immutable filesystem diff stacked on the one below it using a Union File System. Docker uses layers for three reasons:

1. **Build cache** – unchanged layers are reused on rebuild, making subsequent builds fast
2. **Storage efficiency** – shared base layers (e.g. `debian:bookworm-slim`) are stored once on disk even if used by many images
3. **Transfer efficiency** – only missing layers are pushed or pulled from a registry

---

## Task 3: Container Lifecycle

Cycled one container through every state, running `docker ps -a` after each step.

```bash
docker create --name lifecycle-test nginx   # Status: Created
docker start lifecycle-test                 # Status: Up
docker pause lifecycle-test                 # Status: Up (Paused)
docker unpause lifecycle-test               # Status: Up
docker stop lifecycle-test                  # Status: Exited (0)
docker restart lifecycle-test               # Status: Up
docker kill lifecycle-test                  # Status: Exited (137)
docker rm lifecycle-test                    # Gone from ps -a
```

**`docker stop` vs `docker kill`:**

- `stop` sends SIGTERM first, waits 10s, then SIGKILL — graceful shutdown
- `kill` sends SIGKILL immediately — exit code 137 (128 + signal 9)

**`docker pause`** uses the Linux cgroups freezer — process stays in memory, kernel stops scheduling it. Resumes exactly where it left off after `unpause`.
![alt text](<Screenshot From 2026-06-21 17-53-04.png>)

![alt text](<Screenshot From 2026-06-21 17-54-28.png>)

## ![alt text](<Screenshot From 2026-06-21 17-55-22.png>)

## Task 4: Working with Running Containers

```bash
docker run -d --name webserver -p 8080:80 nginx

# Logs
docker logs webserver
docker logs -f webserver          # real-time follow mode, Ctrl+C to exit

# Exec into container
docker exec -it webserver bash
# explored: /etc/nginx/nginx.conf, /usr/share/nginx/html/, ps aux

# Single command without entering
docker exec webserver nginx -v

# Inspect
docker inspect webserver
docker inspect webserver --format '{{.NetworkSettings.IPAddress}}'
docker inspect webserver --format '{{json .NetworkSettings.Ports}}'
```

`docker inspect` gives full metadata: container IP, port mappings, mounts, state, start time, image config.
![alt text](<Screenshot From 2026-06-21 17-58-06.png>)

![alt text](<Screenshot From 2026-06-21 18-00-18.png>)

## ![alt text](<Screenshot From 2026-06-21 18-01-56.png>)

## Task 5: Cleanup

```bash
docker stop $(docker ps -q)            # stop all running containers
docker container prune                 # remove all stopped containers
docker image prune -a                  # remove all unused images
docker system df                       # check disk usage
```

`docker system df` output columns: Images, Containers, Local Volumes, Build Cache — with reclaimable size shown for each.

---

## Discovery: Why Docker Always Asked for sudo

The Docker daemon runs as root and exposes a socket at `/var/run/docker.sock` owned by the `docker` group (`660` permissions). My user wasn't in that group, so every `docker` command got Permission denied.

**Fix:**

```bash
sudo usermod -aG docker $USER
newgrp docker          # apply in current shell without logout
```

After a full logout/login, group membership is permanent — no more `sudo`.

> **Security note:** The `docker` group is effectively passwordless root on the host — a container can mount the host filesystem. Fine for a personal RHEL VM; something to be aware of on shared machines.

---

## Key Takeaways

| Concept                        | What to Remember                                           |
| ------------------------------ | ---------------------------------------------------------- |
| Image layers                   | Immutable diffs — cached, shared, only deltas transferred  |
| Alpine vs Ubuntu               | ~7 MB (musl+BusyBox) vs ~78 MB (full GNU toolchain)        |
| `docker stop` vs `docker kill` | SIGTERM graceful vs SIGKILL immediate (exit 137)           |
| `docker pause`                 | cgroups freezer — process frozen in memory, not killed     |
| `docker exec -it`              | Interactive shell inside a running container               |
| `docker inspect`               | Full metadata: IP, ports, mounts, state, config            |
| `docker system df`             | Disk usage across images, containers, volumes, cache       |
| docker group                   | Grants socket access — no sudo needed, but root-equivalent |
