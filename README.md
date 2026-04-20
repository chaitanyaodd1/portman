# portman

> A terminal-native port manager for Linux, WSL, and Kubernetes workflows.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)
[![Shell: Bash](https://img.shields.io/badge/shell-bash%205%2B-green.svg)]()
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20WSL-lightgrey.svg)]()

```
  ██████╗  ██████╗ ██████╗ ████████╗███╗   ███╗ █████╗ ███╗   ██╗
  ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝████╗ ████║██╔══██╗████╗  ██║
  ██████╔╝██║   ██║██████╔╝   ██║   ██╔████╔██║███████║██╔██╗ ██║
  ██╔═══╝ ██║   ██║██╔══██╗   ██║   ██║╚██╔╝██║██╔══██║██║╚██╗██║
  ██║     ╚██████╔╝██║  ██║   ██║   ██║ ╚═╝ ██║██║  ██║██║ ╚████║
  ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
```

---

## The Problem

If you've ever run multiple `kubectl port-forward` sessions, you know the pain:

- Each forward blocks a terminal — so you reach for tmux
- tmux sessions multiply, names get forgotten, ports clash
- A pod restarts and silently kills your forward — you find out only when your app breaks
- You can't remember if `8080` was your API, your dashboard, or last week's debug session
- There's no single place to see what's forwarded, what's dead, and what's free

**portman** fixes this. One tool to forward, track, inspect, and kill ports — all in the background, all with a clean terminal interface.

---

## Features

- **Background forwarding** — `kubectl`, `ssh`, and `socat` tunnels run as daemon processes. No blocked terminals, no tmux required
- **Named forwards** — refer to ports by name (`myapi`, `postgres-prod`) not numbers
- **Live status view** — see every managed port, its PID, type, and health at a glance
- **Port reference guide** — 60+ well-known ports built-in; search by number or keyword (`portman info redis`)
- **Kill by name or port** — `portman kill myapi` or `portman kill 8080` or `portman kill all`
- **Per-forward logs** — every background process logs to `~/.portman/logs/<name>.log`
- **System port view** — see what non-portman ports are also listening, inline
- **WSL-aware** — works with Docker Desktop's Kind clusters in WSL2 out of the box
- **Zero external dependencies** — only needs `bash 5+`, `python3` (standard on all distros), and whatever tool you're forwarding with (`kubectl`, `ssh`, `socat`)

---

## Installation

### Quick install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/chaitanyaodd1/portman/main/portman \
  -o /usr/local/bin/portman && chmod +x /usr/local/bin/portman
```


### Manual install

```bash
git clone https://github.com/chaitanyaodd1/portman.git
cd portman
chmod +x portman
sudo mv portman /usr/local/bin/portman
```

### Install without sudo (user-local)

```bash
mkdir -p "$HOME/.local/bin"
curl -fsSL https://raw.githubusercontent.com/chaitanyaodd1/portman/main/portman \
  -o "$HOME/.local/bin/portman" && chmod +x "$HOME/.local/bin/portman"

# Make sure ~/.local/bin is in your PATH (add to ~/.bashrc if needed)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

### Verify

```bash
portman version
# portman v1.0.0
```

### Tab completion (optional but recommended)

```bash
portman completion
# Restart your shell, then tab-complete commands and forward names
```

---

## Quick Start

### Forward a Kubernetes service

```bash
# Forward a service in the default namespace
portman forward myapi 8080:80 --type k8s --extra "svc/myapi"

# Forward a pod in a specific namespace
portman forward myapi 8080:80 --type k8s --extra "svc/myapi -n staging"

# Forward a specific pod
portman forward pg 5432:5432 --type k8s --extra "pod/postgres-0 -n databases"
```

### Forward via SSH tunnel

```bash
portman forward remote-db 5433:5432 --type ssh --extra "ubuntu@10.0.0.5"
```

### Forward via socat (TCP relay)

```bash
portman forward localrelay 9000:9000 --type socat --extra "10.0.0.10:9000"
```

### See everything

```bash
portman list
```

```
  Forwarded Ports   total: 3   dead: 0

  NAME                 TYPE     LOCAL    REMOTE   STATUS       PID      STARTED              TARGET
  ──────────────────────────────────────────────────────────────────────────────────────────────────────
  myapi                k8s      8080     80       ● running    48291    2026-04-15 10:22     svc/myapi -n staging
  pg                   k8s      5432     5432     ● running    48310    2026-04-15 10:22     pod/postgres-0 -n databases
  remote-db            ssh      5433     5432     ● running    48334    2026-04-15 10:23     ubuntu@10.0.0.5

  System Ports In Use (ss -tlnp)
  ──────────────────────────────────────────────────────────────────────────────
  22       sshd
  5432     kubectl
  8080     kubectl
```

### Kill a forward

```bash
portman kill myapi        # by name
portman kill 8080         # by local port
portman kill all          # everything
```

### Look up a port

```bash
portman info 5432
# Port 5432 — PostgreSQL
# ● Port 5432 is free

portman info kafka
# 9092     Apache Kafka
```

### Check a port before using it

```bash
portman check 8080
# ● Port 8080 is currently in use
# ℹ  Well-known: HTTP Alt / Tomcat / Jenkins
```

### Read a forward's log

```bash
portman log myapi
portman log myapi 100     # last 100 lines
tail -f ~/.portman/logs/myapi.log   # live stream
```

---

## Command Reference

| Command | Short | Description |
|---|---|---|
| `portman forward <name> <local:remote> [--type ...] [--extra "..."]` | `f` | Start a background forward |
| `portman kill <name\|port\|all>` | `k` | Stop and remove a forward |
| `portman list` | `l` | Full overview: forwards + system ports |
| `portman status [name\|port]` | `s` | Table of managed forwards |
| `portman info <port\|keyword>` | `i` | Port reference lookup |
| `portman check <port>` | `c` | Is this port free right now? |
| `portman log <name> [lines]` | — | View a forward's log output |
| `portman clean` | — | Remove dead forwards from state |
| `portman completion` | — | Install bash tab completion |
| `portman version` | `-v` | Print version |
| `portman help` | `-h` | Show help |

### `forward` types

| Type | Requires | What it runs |
|---|---|---|
| `k8s` (default) | `kubectl` in PATH, valid kubeconfig | `kubectl port-forward <extra> <local>:<remote>` |
| `ssh` | SSH access to host | `ssh -N -L <local>:localhost:<remote> <extra>` |
| `socat` | `socat` installed | `socat TCP-LISTEN:<local>,fork TCP:<extra>` |
| `local` | nothing | Registers a port for tracking only, no process started |

---

## WSL2 + Docker Desktop / Kind

This tool was built specifically for this workflow. When using Kind inside WSL2 with Docker Desktop:

```bash
# Your kubectl context should already point to kind
kubectl config current-context
# kind-kind

# Forward your service — works identically to native Linux
portman forward dashboard 8080:80 --type k8s --extra "svc/kubernetes-dashboard -n kubernetes-dashboard"
portman forward api       3000:3000 --type k8s --extra "svc/my-api -n default"
portman forward db        5432:5432 --type k8s --extra "pod/postgres-0 -n default"

# Check everything at once
portman list
```

No tmux. No `&` dangling in your shell history. Everything tracked, named, and killable.

---

## File Structure

After first run, portman creates:

```
~/.portman/
├── forwards.json        # state: all managed forwards with PIDs, ports, metadata
└── logs/
    ├── myapi.log        # stdout+stderr of each background process
    ├── pg.log
    └── remote-db.log
```

You can inspect or back up `forwards.json` directly. It's plain JSON:

```json
[
  {
    "name": "myapi",
    "type": "k8s",
    "local_port": "8080",
    "remote": "80",
    "pid": "48291",
    "started": "2026-04-15T10:22:14",
    "extra": "svc/myapi -n staging",
    "log": "/home/user/.portman/logs/myapi.log"
  }
]
```

---

## Configuration

portman respects one environment variable:

| Variable | Default | Description |
|---|---|---|
| `PORTMAN_HOME` | `~/.portman` | Override the state/log directory |

Example — store state in a shared location:
```bash
export PORTMAN_HOME="/mnt/shared/portman"
```

---

## Troubleshooting

### Forward shows `✖ dead` immediately after starting

The background process crashed on launch. Check its log:
```bash
portman log <name>
```
Common causes: wrong pod name, wrong namespace, no `kubectl` context, SSH auth failure.

### Port conflict warning on `forward`

portman detected the port is already in use. Either kill the existing process or choose a different local port:
```bash
portman check 8080        # see what's using it
portman forward myapi 8081:80 --type k8s --extra "svc/myapi"   # use 8081 instead
```

### State has stale/dead entries after a reboot

Forwards don't survive reboots (background processes are killed by the OS). Clean the state:
```bash
portman clean
```

### `portman list` shows ports I didn't forward

The system ports section (bottom of `list`) shows *all* TCP listeners on your machine, not just portman-managed ones. This is intentional — gives you a full picture.

---

## Roadmap

| Phase | Status | Features |
|---|---|---|
| **Phase 1** | ✅ Done | Background forwarding, named ports, state management, port reference, `list`/`kill`/`info`/`log` |
| **Phase 2** | 🔜 Planned | Interactive TUI with arrow keys (whiptail or Python curses), switch port on the fly, `portman watch` live-refresh |
| **Phase 3** | 💡 Ideas | Auto-restart on pod crash (watch loop), `portman restore` to re-establish all forwards after reboot, config file for saved forward profiles |

---

## Requirements

- **bash 5+** (check: `bash --version`)
- **python3** (check: `python3 --version`) — used for JSON state management and display
- **ss** — socket statistics (part of `iproute2`, installed on all modern Linux distros)
- For `k8s` forwards: `kubectl` with a valid kubeconfig
- For `ssh` forwards: `ssh` client
- For `socat` forwards: `socat` (`sudo apt install socat`)

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Found a bug? [Open an issue](https://github.com/chaitanyaodd1/portman/issues/new?template=bug_report.md).

Have an idea? [Request a feature](https://github.com/chaitanyaodd1/portman/issues/new?template=feature_request.md).

---

## License

[MIT](LICENSE) © 2026 portman contributors
