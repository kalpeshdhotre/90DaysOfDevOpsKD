# Day 45 – Docker Build & Push in GitHub Actions

## Overview

Built a complete CI/CD pipeline: pushing code to GitHub automatically builds a Docker image and pushes it to Docker Hub — no manual steps.

## Workflow: `.github/workflows/docker-publish.yml`

```yaml
name: Docker Build & Push

on:
  push:
    branches:
      - main
      - "**" # runs on all branches; push step is skipped for non-main via `if:` conditions

env:
  IMAGE_NAME: kalpeshdhotre/todo-api

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set short SHA
        id: vars
        run: echo "sha_short=$(git rev-parse --short HEAD)" >> "$GITHUB_OUTPUT"

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Build Docker image
        uses: docker/build-push-action@v7
        with:
          context: ./2026/day-45/app
          push: false
          load: true
          tags: |
            ${{ env.IMAGE_NAME }}:latest
            ${{ env.IMAGE_NAME }}:sha-${{ steps.vars.outputs.sha_short }}

      - name: Log in to Docker Hub
        if: github.ref == 'refs/heads/main'
        uses: docker/login-action@v4
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_TOKEN }}

      - name: Push to Docker Hub
        if: github.ref == 'refs/heads/main'
        uses: docker/build-push-action@v7
        with:
          context: ./2026/day-45/app
          push: true
          tags: |
            ${{ env.IMAGE_NAME }}:latest
            ${{ env.IMAGE_NAME }}:sha-${{ steps.vars.outputs.sha_short }}
```

## Docker Hub Image

🔗 https://hub.docker.com/r/kalpeshdhotre/todo-api

Tags pushed:

- `latest`
- `sha-<short-commit-hash>`

## Pipeline Run Screenshots

![alt text](<Screenshot From 2026-07-06 19-59-16.png>)

![alt text](<Screenshot From 2026-07-06 20-10-26.png>)

![alt text](<Screenshot From 2026-07-06 19-59-16-1.png>)

![alt text](<Screenshot From 2026-07-06 20-40-49.png>)

## Task 4 Verification

- Push to `main` → build + login + push all run ✅
- Push to a feature branch → build runs, login/push steps skipped (condition `github.ref == 'refs/heads/main'` not met) ✅

![alt text](<Screenshot From 2026-07-06 20-17-03.png>)

## Debugging Notes

- **Push failed on first attempt** — Docker Hub access token was scoped Read-only by default. Assigned the token with Read & Write access under Account Settings → Security → Personal Access Tokens, and the push succeeded on retry.

## Task 6: The Full Journey (git push → running container)

1. `git push origin main` triggers the `Docker Build & Push` workflow via GitHub's webhook.
2. GitHub Actions spins up an `ubuntu-latest` runner, checks out the repo.
3. Buildx builds the Docker image from `2026/day-45/app/Dockerfile`, tagging it `latest` and `sha-<hash>`.
4. Since the push was to `main`, the runner logs into Docker Hub using the `DOCKER_USERNAME`/`DOCKER_TOKEN` secrets and pushes both tags.
5. Locally, `docker pull kalpeshdhotre/todo-api:latest` fetches the exact image built in CI.
6. `docker run` (or `docker compose up` using the copied `docker-compose.yml`) starts the container — same image, same behavior, no manual build step anywhere in the chain.

## Biggest Realization

The build/push separation (build first with `push: false`, then push only on `main`) caught the real failure — a Read-only token — at the login/push step instead of silently failing mid-build. It made debugging a one-line fix instead of a guessing game. Also: the `sha-<hash>` tag means every commit has a traceable, pinned image — rollback is just pulling an older tag, no rebuild needed.
