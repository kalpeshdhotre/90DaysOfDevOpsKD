Day 48/90 of #90DaysOfDevOps — the GitHub Actions capstone 🎯

Took everything from Day 40–47 and wired it into one real CI/CD pipeline:

→ Reusable workflow for build & test (Node.js, curl-based health test)
→ Reusable workflow for Docker build & push (Buildx, dual tags: latest + short SHA)
→ PR pipeline that runs tests only — zero Docker Hub calls on a PR
→ Main pipeline: test → build/push → Trivy scan → deploy, gated behind a production environment approval
→ Cron health check every 12 hours pinging the live container's /health endpoint
→ Brownie points: Trivy fails the pipeline on any CRITICAL CVE, report uploaded as an artifact

Biggest lesson today: workflow_call outputs only come from step outputs, not job conclusions — so passing a short commit SHA between jobs meant a small "prep" job just to compute it before the reusable workflows could use it.

This is the first pipeline I've built where a bad PR literally can't touch Docker Hub, and a bad image literally can't reach production. That separation feels like the actual point of all 47 days before this one.

Day 49 up next: going deeper on the DevSecOps scanning step.

#90DaysOfDevOps #DevOpsKaJosh #TrainWithShubham
