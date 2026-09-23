# Day 87 — Introduction to Agentic AI for DevOps

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`

## What are AI Agents and How They Differ From Chatbots

A chatbot only generates text — it answers from what it already knows. An AI agent is an LLM wired up with **tools**: Python functions that actually execute commands (`docker ps`, `docker logs`, `docker inspect`, etc.) and return real output back to the LLM. The agent decides on its own which tool to call, with what arguments, and in what order, based on the question — it isn't told the steps in advance.

## The ReAct Pattern (Reason → Act → Observe)

Applied to the `broken-app` example:

```
User: "I have spinned broken-app with docker, its crashed. check why?"

Agent REASONS: I should check which containers exist and their state
Agent ACTS:    list_containers()
Agent OBSERVES: broken-app has exited with code 1

Agent REASONS: I should check the logs for a root cause
Agent ACTS:    get_logs("broken-app")
Agent OBSERVES: "app starting..." then the process exits

Agent REASONS: I should confirm the exit code and config
Agent ACTS:    inspect_container("broken-app")
Agent OBSERVES: ExitCode: 1

Agent ANSWERS: The container's entrypoint runs "echo 'app starting...'
&& sleep 2 && exit 1" — it deliberately exits with code 1 after 2 seconds,
which is why Docker shows it as Exited (1).
```

The tool sequence above was never hardcoded — the agent worked it out itself from the question and the `@tool` docstrings.

## Environment Setup

- Ollama installed and running (as a background/systemd service — `ollama serve` only needed if not already running)
- Model pulled: `gemma4:latest` (9.6 GB)
- Python 3.14 venv created after installing `python3.14-venv`, dependencies installed via `pip install -r requirements.txt`

![alt text](<md-screenshots/Screenshot From 2026-09-22 18-34-13.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-22 19-04-22.png>)

## Docker Error Explainer (Module 1)

Ran `module-1/explainer.py` against all three sample errors (container name conflict, port already allocated, private repo pull access denied). Low `temperature=0.3` kept explanations consistent and technical rather than creative.

![alt text](<md-screenshots/Screenshot From 2026-09-22 19-07-51.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-22 19-08-43.png>)

**System prompt observation:** the explainer's quality depends entirely on the system prompt's structure — telling the LLM to answer in three fixed parts (what went wrong / likely cause / fix with commands) kept responses short and actionable instead of rambling. Loosening or removing that structure produced longer, less scannable answers.

## Docker Troubleshooter Agent (Module 2)

Created `broken-app` (`nginx:alpine` container that echoes, sleeps 2s, exits 1) and diagnosed it via the agent.

![alt text](<md-screenshots/Screenshot From 2026-09-22 19-31-23.png>)

**Tool set used by the agent:**

- `list_containers()` → `docker ps -a`
- `get_logs(container_name)` → `docker logs --tail 50 <name>`
- `inspect_container(container_name)` → `docker inspect <name>`

Each tool is a thin wrapper around `subprocess.run(...)`; the `@tool` docstring is what the LLM reads to decide when to invoke it.

## Agent Architecture

```
[User Question]
      |
      v
[LLM: Gemma via Ollama]
      |
      | (ReAct: Reason what tool to use)
      v
[Tool Selection]
      |
      +---> list_containers()   --> docker ps -a
      +---> get_logs()          --> docker logs
      +---> inspect_container() --> docker inspect
      |
      v
[Tool Output (text)]
      |
      v
[LLM reads output, reasons again]
      |
      | (repeat until answer is ready)
      v
[Final Answer to User]
```

Same architecture, different CLI tools = Kubernetes agent (Day 88), Terraform agent, AWS CLI agent, etc.

## Tool Added: `list_images` / `restart_container`

Extended `module-2/agent.py` with a `list_images` tool (`docker images`) and a `restart_container` tool (`docker restart <name>`).

![alt text](<md-screenshots/Screenshot From 2026-09-22 19-35-39.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-22 19-38-42.png>)

**Safety note:** `restart_container` will restart _any_ container by name with zero guardrails — no confirmation, no allow-list. Fine for a local learning sandbox; not something to ship as-is. Production versions need explicit confirmation prompts and/or a restricted container allow-list — a topic for Day 89's guardrails coverage.

## System Prompt and Temperature

- **System prompt** — sets the LLM's persona and output contract (what to include, how to format it). In Module 1 it's the only thing enforcing structure, since there's no tool loop to ground the answer.
- **Temperature** — controls randomness in generation. `0.3` in the explainer keeps answers close to deterministic but allows minor phrasing variation; `0` in the agent (`ChatOllama(model=..., temperature=0)`) makes tool-selection reasoning as repeatable as possible, which matters more once the LLM is driving real actions rather than just producing prose.

## Debugging Notes

- `ollama serve &` failing with `address already in use` just meant Ollama was already running as a background/systemd service — no fix needed, just skip manual `serve`.
- `python3 -m venv .venv` failed on Python 3.14 until `python3.14-venv` was installed via `apt`.
- venv activation doesn't persist across new terminal tabs (Ghostty) — needs `source .venv/bin/activate` per tab, or a `direnv`/alias workaround for convenience.
- `gemma4:latest` (9.6 GB) is noticeably heavier than the ~5 GB estimated in the reference notes — expect slower agent-loop round trips (multiple LLM calls per question) vs. a single-shot explainer call.
- First agent run returned no output ("Thinking..." with nothing after) — traced to potential tool-calling/response-length limits rather than a hang; `num_predict` (Ollama's max output tokens) is worth raising if responses cut off mid-sentence.

## Submission

- `day-87-agentic-ai-intro.md` added to `2026/day-87/`
- Committed and pushed to fork
