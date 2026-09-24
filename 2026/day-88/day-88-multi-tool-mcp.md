# Day 88 — Multi-Tool Agents, MCP, and CI/CD Analyzer

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`

---

## Task 1: Multi-Tool DevOps Agent (Docker + Kubernetes)

Extended yesterday's 3-tool Docker agent into a 6-tool agent spanning two domains.

**Tools:**

| Domain     | Tool                                | Wraps                                         |
| ---------- | ----------------------------------- | --------------------------------------------- |
| Docker     | `list_containers()`                 | `docker ps -a`                                |
| Docker     | `get_logs(container_name)`          | `docker logs`                                 |
| Docker     | `inspect_container(container_name)` | `docker inspect`                              |
| Kubernetes | `list_pods(namespace)`              | `kubectl get pods -n <ns>`                    |
| Kubernetes | `describe_pod(pod_name, namespace)` | `kubectl describe pod`                        |
| Kubernetes | `get_events(namespace)`             | `kubectl get events --sort-by=.lastTimestamp` |

Set up a Kind cluster (`devops-demo`) with a deliberately crash-looping `broken-pod`, and a matching broken Docker container, then ran the agent against both.

![alt text](<md-screenshots/Screenshot From 2026-09-23 17-20-15.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-23 17-23-30.png>)

**Observation:** the agent correctly routed Docker-only questions to Docker tools and Kubernetes-only questions to Kubernetes tools, and combined both toolsets when asked to compare across domains — no manual tool selection needed, the ReAct loop decided based on the question.

---

## Task 2 & 3: MCP — Server, Client, and Why It Matters

**What MCP is:** an open standard (created by Anthropic) for exposing tools to any AI client, instead of hardcoding them inside one agent's framework-specific code.

| Without MCP                                 | With MCP                                |
| ------------------------------------------- | --------------------------------------- |
| Tools locked to one framework (LangChain)   | Tools work with any MCP client          |
| Every client re-implements Docker/K8s tools | Write once, use everywhere              |
| Tool access tied to agent code              | Tools exposed as a discoverable service |

Built `mcp_server.py` using FastMCP, exposing the same 3 Kubernetes tools as an MCP stdio server (`@mcp.tool` instead of `@tool`), and `agent_with_mcp.py` as an MCP client using `langchain-mcp-adapters` — the client discovers tools at runtime from the server rather than defining them locally.

**Difference from Task 1's hardcoded tools:** the agent process no longer owns the tool implementations — it connects to a separate `mcp_server.py` process over stdio and calls whatever tools that process advertises. Same Kubernetes questions, same answers, but the tools are now a reusable service rather than code baked into one script.

Also wired `kubernetes-tools` into Claude Desktop's `claude_desktop_config.json` (via Settings → Developer → Edit config) to confirm the same MCP server is usable outside the Python agent entirely.

![alt text](<md-screenshots/Screenshot From 2026-09-23 17-27-54.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-23 17-29-00.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-23 17-29-27.png>)

**Debugging note:** the server wasn't showing up in Claude Desktop at first because the edits went into the wrong file (an internal app-state blob rather than the actual config Claude Desktop reads). Used the in-app "Edit config" button to get the real file, merged `mcpServers` in without touching existing keys, pointed `command` at the venv's `python3` directly (since Claude Desktop launches the server without any shell/venv activation), and did a full quit + relaunch for it to pick up the change.

![alt text](<md-screenshots/Screenshot From 2026-09-23 18-11-03.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-23 18-11-15.png>)

---

## Task 4: CI/CD Failure Analyzer

Built `ci_analyzer.py` with 3 tools wrapping the `gh` CLI:

| Tool                                   | Purpose                                                  |
| -------------------------------------- | -------------------------------------------------------- |
| `list_workflow_runs(status="failure")` | `gh run list --status failure --limit 5`                 |
| `get_failed_logs(run_id)`              | `gh run view <id> --log-failed`, truncated to 5000 chars |
| `get_workflow_file(workflow_name)`     | Reads `.github/workflows/<name>` from disk               |

Authenticated via `gh auth login`, confirmed with `gh auth status`. Ran the analyzer from inside the AI-BankApp-DevOps repo (the `gh` CLI infers the target repo from the current working directory's git remote, so the script must be invoked from there, not from its own script path).

Pushed a deliberately broken workflow, `.github/workflows/broken-ci.yml` (an `npm test` step with no `package.json` present), to trigger a real failure to diagnose.

![alt text](<md-screenshots/Screenshot From 2026-09-23 18-30-49.png>)

![alt text](<md-screenshots/Screenshot From 2026-09-23 18-37-33.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-23 18-42-14.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-23 18-40-39-1.png>)

**Debugging note:** first run returned "no runs to display" — not an auth issue, but a working-directory issue: `gh` resolves the repo from the CWD's git remote, and the script was run from outside the target repo. Fixed by `cd`-ing into `AI-BankApp-DevOps` before running the analyzer.

---

## Task 5: Custom Tool — Option B, AWS Resource Checker

Built and wired in the AWS EC2 checker tool:

```python
@tool
def list_ec2_instances() -> str:
    """List all EC2 instances with their state, type, and name."""
    result = subprocess.run(["aws", "ec2", "describe-instances",
        "--query", "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,Tags[?Key=='Name'].Value|[0]]",
        "--output", "table"], capture_output=True, text=True)
    return result.stdout or result.stderr
```

Added to the agent alongside the Docker/Kubernetes tools. Asking a question like "What EC2 instances do I have running?" triggered `list_ec2_instances()` — the agent picked it based on the docstring matching the intent of the question, same routing behavior as every other tool today.

![alt text](<md-screenshots/Screenshot From 2026-09-23 18-59-14.png>)

**How the agent decided when to use it:** same as every other tool today — the docstring is the only signal the ReAct loop has. `"List all EC2 instances with their state, type, and name."` was specific enough that AWS-flavored questions ("EC2", "instances", "running") routed here rather than to Docker or Kubernetes tools.

---

## Tool Pattern Template (works for any CLI)

```python
@tool
def my_tool(arg: str = "default") -> str:
    """Clear, specific docstring — this is the agent's only routing signal."""
    result = subprocess.run(
        ["some-cli", "subcommand", arg],
        capture_output=True, text=True,
    )
    output = result.stdout or result.stderr
    if len(output) > 5000:
        output = output[:5000] + "\n[...truncated]"
    return output
```

Any CLI command becomes an agent tool this way: wrap it in `subprocess.run`, write a docstring specific enough for the LLM to route correctly, and truncate output that could blow past token limits (critical for CI logs, verbose `describe` output, etc.).

---

## Recap

| Module                  | What                 | Tools                            | Pattern                 |
| ----------------------- | -------------------- | -------------------------------- | ----------------------- |
| 3 (`agent.py`)          | Multi-tool agent     | 3 Docker + 3 K8s                 | LangChain ReAct         |
| 3 (`mcp_server.py`)     | MCP server           | 3 K8s tools via MCP              | FastMCP                 |
| 3 (`agent_with_mcp.py`) | MCP client agent     | Tools discovered from MCP server | LangChain + MCP adapter |
| 6                       | CI/CD analyzer       | 3 GitHub Actions tools           | LangChain ReAct         |
| 5 (custom)              | AWS Resource Checker | `list_ec2_instances`             | LangChain ReAct         |
