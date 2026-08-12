# Day 69 — Ansible Playbooks and Modules

## Overview

Moved from ad-hoc commands to real automation with Ansible playbooks — YAML files that describe the desired state of servers. Covered playbook structure, the seven most-used modules, handlers, dry-run/diff/verbosity flags, and multi-play playbooks targeting different host groups.

**Environment:** Ubuntu control node (26.04) → 3x Ubuntu EC2 managed nodes (`web`, `app`, `db`) in AWS `us-east-1`, provisioned via Terraform (Day 68), managed via `apt` (not `yum`).

---

## Task 1: Your First Playbook

`install-nginx.yml` installs Nginx, starts/enables the service, and deploys a custom index page.

```yaml
---
- name: Install and start Nginx on web servers
  hosts: web
  become: true

  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: present
        update_cache: true

    - name: Start and enable Nginx
      service:
        name: nginx
        state: started
        enabled: true

    - name: Create a custom index page
      copy:
        content: "<h1>Deployed by Ansible - TerraWeek Server</h1>"
        dest: /var/www/html/index.html
```

**First run** — Nginx installed fresh, all tasks show `changed`:

**Second run** — idempotency check, all tasks show `ok`, `changed=0`:
![alt text](<md-screenshots/Screenshot From 2026-08-12 20-52-19.png>)

**Verification** — curl against the web server's public IP shows the custom page:
![alt text](<md-screenshots/Screenshot From 2026-08-12 21-00-02.png>)
![alt text](<md-screenshots/Screenshot From 2026-08-12 21-00-20.png>)

---

## Task 2: Playbook Structure — Annotated

```yaml
--- # YAML document start
- name: Play name # PLAY -- targets a group of hosts
  hosts: web # Which inventory group to run on
  become: true # Run tasks as root (sudo)

  tasks: # List of TASKS in this play
    - name: Task name # TASK -- one unit of work
      module_name: # MODULE -- what Ansible does
        key: value # Module arguments
```

**Q&A:**

1. **Play vs task** — A play maps a group of hosts to a set of actions to perform on them. A task is a single unit of work inside a play — one module call with its arguments.
2. **Multiple plays in one playbook?** — Yes. A playbook is just a YAML list of plays; each can target a different `hosts:` group (demonstrated in Task 6).
3. **`become: true` at play vs task level** — At play level, it's the default for every task in that play. At task level, it overrides the play default for that one task only (e.g., one task needs root, the rest don't).
4. **Task failure behavior** — By default, if a task fails on a host, Ansible stops running further tasks on _that host_ (other hosts in the play continue independently). This can be changed with `ignore_errors: true` or `block`/`rescue`.

---

## Task 3: Essential Modules

`essential-modules.yml` — one playbook, seven modules:

| Module       | What it does                                                                        |
| ------------ | ----------------------------------------------------------------------------------- |
| `apt`        | Installs/removes packages (`state: present` / `absent`); Ubuntu equivalent of `yum` |
| `service`    | Starts, stops, restarts, and enables/disables a service                             |
| `copy`       | Copies a file from the control node to the managed node                             |
| `file`       | Creates/manages directories, files, permissions, ownership                          |
| `command`    | Runs a command directly (no shell — no pipes/redirects)                             |
| `shell`      | Runs a command through `/bin/sh` (supports pipes, redirects)                        |
| `lineinfile` | Ensures a specific line exists (or is modified) in a file                           |

```yaml
---
- name: Practice essential Ansible modules
  hosts: web
  become: true

  tasks:
    - name: Install multiple packages
      apt:
        name: [git, curl, wget, tree]
        state: present
        update_cache: true

    - name: Ensure Nginx is running
      service:
        name: nginx
        state: started
        enabled: true

    - name: Copy config file
      copy:
        src: files/app.conf
        dest: /etc/app.conf
        owner: root
        group: root
        mode: "0644"

    - name: Create application directory
      file:
        path: /opt/myapp
        state: directory
        owner: ubuntu
        mode: "0755"

    - name: Check disk space
      command: df -h
      register: disk_output

    - name: Print disk space
      debug:
        var: disk_output.stdout_lines

    - name: Count running processes
      shell: ps aux | wc -l
      register: process_count

    - name: Show process count
      debug:
        msg: "Total processes: {{ process_count.stdout }}"

    - name: Set timezone in environment
      lineinfile:
        path: /etc/environment
        line: "TZ=Asia/Kolkata"
        create: true
```

![alt text](<md-screenshots/Screenshot From 2026-08-12 21-07-56.png>)

**command vs shell:**

- `command` executes the binary directly — no shell is invoked, so pipes (`|`), redirects (`>`), and env var expansion don't work. Safer (no shell injection risk), no dependency on `/bin/sh`.
- `shell` runs through `/bin/sh` — pipes, redirects, and globbing all work. Use only when shell features are genuinely needed; `command` (or a dedicated module) is preferred otherwise.

---

## Task 4: Handlers

`nginx-config.yml` deploys a custom `nginx.conf` and only restarts Nginx when the config actually changes, via `notify` → `handlers`.

```yaml
---
- name: Configure Nginx with a custom config
  hosts: web
  become: true

  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: present
        update_cache: true

    - name: Deploy Nginx config
      copy:
        src: files/nginx.conf
        dest: /etc/nginx/nginx.conf
        owner: root
        mode: "0644"
      notify: Restart Nginx

    - name: Deploy custom index page
      copy:
        content: "<h1>Managed by Ansible</h1><p>Server: {{ inventory_hostname }}</p>"
        dest: /var/www/html/index.html

    - name: Ensure Nginx is running
      service:
        name: nginx
        state: started
        enabled: true

  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
```

**Run 1** — config file is new → `Deploy Nginx config` shows `changed` → handler fires (`RUNNING HANDLER [Restart Nginx]` appears):

**Run 2** — nothing changed → `Deploy Nginx config` shows `ok` → no notify → no handler section at all:

![alt text](<md-screenshots/Screenshot From 2026-08-12 21-12-48.png>)

**How handlers work:** A handler is a task that only runs if a `notify` from another task fires it, and it runs once at the very end of the play — even if multiple tasks notify the same handler. This avoids redundant service restarts when nothing actually needs one.

---

## Task 5: Dry Run, Diff, and Verbosity

| Command                                                            | Purpose                                                                |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `ansible-playbook install-nginx.yml --check`                       | Dry run — simulates changes, applies nothing                           |
| `ansible-playbook nginx-config.yml --check --diff`                 | Dry run + shows exact file content differences                         |
| `ansible-playbook install-nginx.yml -v` / `-vv` / `-vvv`           | Increasing verbosity — task results, module args, connection debugging |
| `ansible-playbook install-nginx.yml --limit web-server`            | Restricts run to a specific host                                       |
| `ansible-playbook install-nginx.yml --list-hosts` / `--list-tasks` | Previews affected hosts/tasks without running                          |

![alt text](<md-screenshots/Screenshot From 2026-08-12 21-14-43.png>)
![alt text](<md-screenshots/Screenshot From 2026-08-12 21-17-34.png>)

**Why `--check --diff` matters most for production:** `--check` guarantees a pure simulation — nothing is actually applied to the target hosts. `--diff` layers on top of that by showing the literal line-by-line file changes that _would_ happen. Together they let you review a change fully before committing to it — the same safety net `terraform plan` provides for infrastructure changes.

---

## Task 6: Multiple Plays — `multi-play.yml`

One playbook, three plays, each targeting a different inventory group (`web`, `app`, `db`):

```yaml
---
- name: Configure web servers
  hosts: web
  become: true
  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: present
        update_cache: true
    - name: Start Nginx
      service:
        name: nginx
        state: started
        enabled: true

- name: Configure app servers
  hosts: app
  become: true
  tasks:
    - name: Install build dependencies
      apt:
        name: [gcc, make]
        state: present
        update_cache: true
    - name: Create app directory
      file:
        path: /opt/app
        state: directory
        mode: "0755"

- name: Configure database servers
  hosts: db
  become: true
  tasks:
    - name: Install MySQL client
      apt:
        name: mysql-client
        state: present
        update_cache: true
    - name: Create data directory
      file:
        path: /var/lib/appdata
        state: directory
        mode: "0700"
```

![alt text](<md-screenshots/Screenshot From 2026-08-12 21-22-45.png>)

**Verification** — confirmed each group only got its own packages:

```bash
ansible -i inventory.ini web -m command -a "nginx -v"
ansible -i inventory.ini app -m command -a "which gcc"
ansible -i inventory.ini db -m command -a "which mysql"
```

![alt text](<md-screenshots/Screenshot From 2026-08-12 21-24-38.png>)

---

## Key Takeaways

- Playbooks describe **desired state**, not step-by-step imperative commands — Ansible figures out what needs to change.
- **Idempotency** is the core value: running the same playbook twice produces the same result, with zero unnecessary changes the second time.
- **Handlers + notify** prevent redundant service restarts — only fire when something actually changed.
- **`--check --diff`** should be habitual before any production run, same discipline as `terraform plan`.
- A single playbook can orchestrate multiple host groups with completely different task sets via multiple plays.

---

## Repo

`2026/day-69/` in [kalpeshdhotre/github-action-practice-90days-challenge](https://github.com/kalpeshdhotre/github-action-practice-90days-challenge)

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`
