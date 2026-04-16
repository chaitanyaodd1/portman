#!/usr/bin/env bash
# =============================================================================
#  portman — Port Manager for Linux / WSL / Kubernetes
#  Phase 1: Background process management, port reference, colored status view
# =============================================================================

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
PORTMAN_HOME="${PORTMAN_HOME:-$HOME/.portman}"
STATE_FILE="$PORTMAN_HOME/forwards.json"
LOG_DIR="$PORTMAN_HOME/logs"
VERSION="1.0.0"

# ── Colors ─────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD="\033[1m"
  DIM="\033[2m"
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[0;33m"
  BLUE="\033[0;34m"
  CYAN="\033[0;36m"
  MAGENTA="\033[0;35m"
  WHITE="\033[0;37m"
  RESET="\033[0m"
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" BLUE="" CYAN="" MAGENTA="" WHITE="" RESET=""
fi

# ── Port Reference Database ────────────────────────────────────────────────────
declare -A PORT_DB
PORT_DB=(
  [20]="FTP Data Transfer"
  [21]="FTP Control (Command)"
  [22]="SSH / SFTP / SCP"
  [23]="Telnet (unencrypted, avoid)"
  [25]="SMTP (email sending)"
  [53]="DNS (Domain Name System)"
  [67]="DHCP Server"
  [68]="DHCP Client"
  [80]="HTTP (web, unencrypted)"
  [110]="POP3 (email retrieval)"
  [143]="IMAP (email, unencrypted)"
  [389]="LDAP Directory"
  [443]="HTTPS (web, encrypted)"
  [445]="SMB / Windows File Sharing"
  [465]="SMTP over SSL"
  [587]="SMTP (email submission)"
  [636]="LDAPS (LDAP over SSL)"
  [993]="IMAPS (IMAP over SSL)"
  [995]="POP3S (POP3 over SSL)"
  [1433]="Microsoft SQL Server"
  [1521]="Oracle Database"
  [2181]="Apache ZooKeeper"
  [2375]="Docker daemon (unencrypted)"
  [2376]="Docker daemon (TLS)"
  [2379]="etcd Client (Kubernetes)"
  [2380]="etcd Peer (Kubernetes)"
  [3000]="Grafana / Node.js dev default"
  [3306]="MySQL / MariaDB"
  [3389]="RDP (Remote Desktop)"
  [4000]="Common dev/app default"
  [4200]="Angular dev server"
  [4369]="RabbitMQ EPMD"
  [5000]="Flask / Docker Registry"
  [5432]="PostgreSQL"
  [5601]="Kibana"
  [5672]="RabbitMQ AMQP"
  [5900]="VNC"
  [6379]="Redis"
  [6443]="Kubernetes API Server"
  [7077]="Apache Spark Master"
  [8000]="Django / Python HTTP default"
  [8080]="HTTP Alt / Tomcat / Jenkins"
  [8081]="Nexus Repository / Alt HTTP"
  [8082]="Alt HTTP"
  [8088]="YARN ResourceManager"
  [8161]="ActiveMQ Web Console"
  [8443]="HTTPS Alt / Kubernetes Dashboard"
  [8500]="Consul"
  [8600]="Consul DNS"
  [8888]="Jupyter Notebook"
  [9000]="SonarQube / Portainer / PHP-FPM"
  [9090]="Prometheus"
  [9092]="Apache Kafka"
  [9200]="Elasticsearch HTTP"
  [9300]="Elasticsearch Transport"
  [9418]="Git Protocol"
  [10250]="Kubernetes Kubelet API"
  [10251]="Kubernetes Scheduler"
  [10252]="Kubernetes Controller Manager"
  [10255]="Kubernetes Read-Only Kubelet"
  [15672]="RabbitMQ Management UI"
  [16443]="MicroK8s API Server"
  [27017]="MongoDB"
  [27018]="MongoDB shard"
  [27019]="MongoDB config server"
  [50000]="Jenkins Agent"
  [50070]="Hadoop NameNode"
)

# ── Helpers ────────────────────────────────────────────────────────────────────
_init() {
  mkdir -p "$PORTMAN_HOME" "$LOG_DIR"
  [[ -f "$STATE_FILE" ]] || echo "[]" > "$STATE_FILE"
}

_now() { date +"%Y-%m-%dT%H:%M:%S"; }

_print_header() {
  echo -e "${BOLD}${BLUE}
  ██████╗  ██████╗ ██████╗ ████████╗███╗   ███╗ █████╗ ███╗   ██╗
  ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝████╗ ████║██╔══██╗████╗  ██║
  ██████╔╝██║   ██║██████╔╝   ██║   ██╔████╔██║███████║██╔██╗ ██║
  ██╔═══╝ ██║   ██║██╔══██╗   ██║   ██║╚██╔╝██║██╔══██║██║╚██╗██║
  ██║     ╚██████╔╝██║  ██║   ██║   ██║ ╚═╝ ██║██║  ██║██║ ╚████║
  ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝${RESET}"
  echo -e "${DIM}  Port Manager v${VERSION} — manage forwarded ports like a pro${RESET}\n"
}

_die() { echo -e "${RED}✖ Error:${RESET} $*" >&2; exit 1; }
_ok()  { echo -e "${GREEN}✔${RESET} $*"; }
_warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }
_info(){ echo -e "${CYAN}→${RESET} $*"; }

# Check if a PID is alive
_pid_alive() {
  local pid="$1"
  [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

# Simple JSON manipulation without jq dependency
_state_read() { cat "$STATE_FILE"; }

_state_find() {
  local name="$1"
  python3 -c "
import json, sys
data = json.load(open('$STATE_FILE'))
for e in data:
    if e.get('name') == '$name':
        print(json.dumps(e))
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

_state_add() {
  local name="$1" type="$2" local_port="$3" remote="$4" pid="$5" started="$6" extra="$7"
  python3 -c "
import json
data = json.load(open('$STATE_FILE'))
data.append({
  'name':       '$name',
  'type':       '$type',
  'local_port': '$local_port',
  'remote':     '$remote',
  'pid':        '$pid',
  'started':    '$started',
  'extra':      '$extra',
  'log':        '$LOG_DIR/${name}.log'
})
json.dump(data, open('$STATE_FILE','w'), indent=2)
"
}

_state_remove() {
  local name="$1"
  python3 -c "
import json
data = json.load(open('$STATE_FILE'))
data = [e for e in data if e.get('name') != '$name']
json.dump(data, open('$STATE_FILE','w'), indent=2)
"
}

_state_all_names() {
  python3 -c "
import json
data = json.load(open('$STATE_FILE'))
for e in data: print(e.get('name',''))
" 2>/dev/null
}

_state_get_field() {
  local name="$1" field="$2"
  python3 -c "
import json
data = json.load(open('$STATE_FILE'))
for e in data:
    if e.get('name') == '$name':
        print(e.get('$field',''))
" 2>/dev/null
}

# ── Tab completion helper ──────────────────────────────────────────────────────
_completion_install() {
  local comp_script='
_portman_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local cmd="${COMP_WORDS[1]}"
  local cmds="forward kill status list info log check help version"
  local types="k8s ssh socat local"
  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$cmds" -- "$cur"))
  elif [[ "$cmd" == "kill" || "$cmd" == "log" || "$cmd" == "status" ]]; then
    local names=$(portman _names 2>/dev/null)
    COMPREPLY=($(compgen -W "$names" -- "$cur"))
  elif [[ "$cmd" == "forward" && $COMP_CWORD -eq 4 ]]; then
    COMPREPLY=($(compgen -W "--type" -- "$cur"))
  fi
}
complete -F _portman_completions portman
'
  local comp_file="/etc/bash_completion.d/portman"
  if [[ -w /etc/bash_completion.d ]]; then
    echo "$comp_script" > "$comp_file"
    _ok "Bash completion installed to $comp_file"
    _info "Restart your shell or run: source $comp_file"
  else
    local user_comp="$HOME/.bash_completion.d/portman"
    mkdir -p "$HOME/.bash_completion.d"
    echo "$comp_script" > "$user_comp"
    _ok "Bash completion installed to $user_comp"
    _info "Add this to ~/.bashrc if not already present:"
    echo -e "  ${DIM}for f in ~/.bash_completion.d/*; do source \"\$f\"; done${RESET}"
  fi
}

# ── Command: forward ──────────────────────────────────────────────────────────
cmd_forward() {
  local name="" ports="" type="k8s" extra=""
  local args=("$@")
  
  # Parse args: portman forward <name> <local:remote> [--type k8s|ssh|socat] [--extra "..."]
  [[ ${#args[@]} -lt 2 ]] && {
    echo -e "${BOLD}Usage:${RESET} portman forward <name> <local_port:remote_port> [--type k8s|ssh|socat|local] [--extra <args>]"
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo -e "  portman forward myapp 8080:80 --type k8s"
    echo -e "  portman forward myapp 8080:80 --type k8s --extra 'svc/myapp -n production'"
    echo -e "  portman forward db    5432:5432 --type k8s --extra 'pod/postgres-0'"
    echo -e "  portman forward remote-api 9000:9000 --type ssh --extra 'user@host'"
    echo -e "  portman forward localapp 3000:3000 --type local"
    return 1
  }

  name="${args[0]}"
  ports="${args[1]}"
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)  type="${2:-k8s}"; shift 2 ;;
      --extra) extra="${2:-}";   shift 2 ;;
      *)       shift ;;
    esac
  done

  # Validate name
  [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || _die "Name must be alphanumeric (hyphens/underscores ok)"

  # Check for duplicate name
  if _state_find "$name" &>/dev/null; then
    _die "A forward named '$name' already exists. Kill it first: portman kill $name"
  fi

  # Parse ports
  local local_port remote_port
  if [[ "$ports" == *:* ]]; then
    local_port="${ports%%:*}"
    remote_port="${ports##*:}"
  else
    local_port="$ports"
    remote_port="$ports"
  fi

  [[ "$local_port" =~ ^[0-9]+$ ]]  || _die "Invalid local port: $local_port"
  [[ "$remote_port" =~ ^[0-9]+$ ]] || _die "Invalid remote port: $remote_port"

  # Check if local port already in use
  if ss -tlnp 2>/dev/null | grep -q ":${local_port} " || \
     lsof -i ":${local_port}" &>/dev/null 2>&1; then
    _warn "Port $local_port appears to already be in use."
    read -rp "Continue anyway? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }
  fi

  local log_file="$LOG_DIR/${name}.log"
  local pid

  echo -e "${CYAN}→${RESET} Starting ${BOLD}$type${RESET} forward: ${BOLD}$name${RESET} (localhost:${local_port} → ${remote_port})"

  case "$type" in
    k8s)
      # Default k8s target: pod/<name> unless extra specifies otherwise
      local k8s_target="${extra:-pod/$name}"
      # shellcheck disable=SC2086
      nohup kubectl port-forward $k8s_target "${local_port}:${remote_port}" \
        > "$log_file" 2>&1 &
      pid=$!
      extra="$k8s_target"
      ;;

    ssh)
      [[ -z "$extra" ]] && _die "--extra <user@host> is required for SSH type"
      nohup ssh -N -L "${local_port}:localhost:${remote_port}" "$extra" \
        > "$log_file" 2>&1 &
      pid=$!
      ;;

    socat)
      command -v socat &>/dev/null || _die "socat not installed. Install with: sudo apt install socat"
      local dest="${extra:-localhost:$remote_port}"
      nohup socat "TCP-LISTEN:${local_port},fork,reuseaddr" "TCP:${dest}" \
        > "$log_file" 2>&1 &
      pid=$!
      extra="$dest"
      ;;

    local)
      # Just mark a local port as managed (no-op forward, useful for tracking)
      pid=0
      ;;

    *)
      _die "Unknown type '$type'. Valid: k8s | ssh | socat | local"
      ;;
  esac

  # Give it a moment to fail fast
  sleep 0.5
  if [[ "$type" != "local" ]] && ! _pid_alive "$pid"; then
    echo -e "${RED}✖ Forward failed to start. Last log output:${RESET}"
    tail -5 "$log_file" 2>/dev/null | sed 's/^/  /'
    return 1
  fi

  _state_add "$name" "$type" "$local_port" "$remote_port" "$pid" "$(_now)" "$extra"

  _ok "Forward '${BOLD}$name${RESET}' started (PID $pid)"
  _info "Log: $log_file"

  # Show port info if known
  if [[ -n "${PORT_DB[$remote_port]+_}" ]]; then
    echo -e "  ${DIM}ℹ  Port $remote_port is typically: ${PORT_DB[$remote_port]}${RESET}"
  fi
}

# ── Command: kill ─────────────────────────────────────────────────────────────
cmd_kill() {
  local target="${1:-}"
  [[ -z "$target" ]] && { echo -e "${BOLD}Usage:${RESET} portman kill <name|port|all>"; return 1; }

  if [[ "$target" == "all" ]]; then
    local names
    names=$(_state_all_names)
    if [[ -z "$names" ]]; then
      _warn "No active forwards to kill."
      return 0
    fi
    while IFS= read -r n; do
      [[ -n "$n" ]] && _kill_one "$n"
    done <<< "$names"
    return 0
  fi

  # Try by name first, then by port
  if _state_find "$target" &>/dev/null; then
    _kill_one "$target"
  else
    # Search by port
    local matched
    matched=$(python3 -c "
import json
data = json.load(open('$STATE_FILE'))
for e in data:
    if e.get('local_port') == '$target' or e.get('remote') == '$target':
        print(e.get('name',''))
" 2>/dev/null)
    if [[ -n "$matched" ]]; then
      _kill_one "$matched"
    else
      _die "No forward found with name or port: $target"
    fi
  fi
}

_kill_one() {
  local name="$1"
  local pid
  pid=$(_state_get_field "$name" "pid")
  local type
  type=$(_state_get_field "$name" "type")

  if [[ "$type" != "local" ]] && _pid_alive "$pid"; then
    kill "$pid" 2>/dev/null && _ok "Killed forward '${BOLD}$name${RESET}' (PID $pid)"
  else
    _warn "Forward '${BOLD}$name${RESET}' was not running (PID $pid)"
  fi
  _state_remove "$name"
  _info "Removed from state."
}

# ── Command: status ────────────────────────────────────────────────────────────
cmd_status() {
  local filter="${1:-}"

  python3 -c "
import json, os, signal
data = json.load(open('$STATE_FILE'))
if '$filter':
    data = [e for e in data if e.get('name') == '$filter' or e.get('local_port') == '$filter']
print(json.dumps(data))
" 2>/dev/null | python3 -c "
import json, sys, os

data = json.load(sys.stdin)
if not data:
    print('  No forwards registered.')
    sys.exit(0)

def pid_alive(pid):
    try:
        if not pid or pid == '0': return None
        os.kill(int(pid), 0)
        return True
    except (OSError, ValueError):
        return False

GREEN  = '\033[0;32m'
RED    = '\033[0;31m'
YELLOW = '\033[0;33m'
CYAN   = '\033[0;36m'
DIM    = '\033[2m'
BOLD   = '\033[1m'
RESET  = '\033[0m'
BLUE   = '\033[0;34m'

# Header
print(f'{BOLD}{BLUE}  {\"NAME\":<20} {\"TYPE\":<8} {\"LOCAL\":<8} {\"REMOTE\":<8} {\"STATUS\":<12} {\"PID\":<8} {\"STARTED\":<20} TARGET{RESET}')
print(f'  {DIM}{\"─\"*110}{RESET}')

for e in data:
    name  = e.get('name', '?')
    typ   = e.get('type', '?')
    lp    = e.get('local_port', '?')
    rp    = e.get('remote', '?')
    pid   = e.get('pid', '?')
    start = e.get('started', '?')[:16].replace('T',' ')
    extra = e.get('extra', '')

    if typ == 'local':
        status = f'{CYAN}tracked{RESET}'
    elif pid_alive(pid):
        status = f'{GREEN}● running{RESET}'
    else:
        status = f'{RED}✖ dead{RESET}'

    typ_color = {
        'k8s':   CYAN,
        'ssh':   YELLOW,
        'socat': BLUE,
        'local': DIM,
    }.get(typ, RESET)

    print(f'  {BOLD}{name:<20}{RESET} {typ_color}{typ:<8}{RESET} {lp:<8} {rp:<8} {status:<20} {DIM}{pid:<8}{RESET} {DIM}{start:<20}{RESET} {DIM}{extra}{RESET}')

print()
"
}

# ── Command: list (alias for status) ──────────────────────────────────────────
cmd_list() {
  _print_header

  local total dead
  total=$(python3 -c "import json; print(len(json.load(open('$STATE_FILE'))))" 2>/dev/null || echo 0)
  dead=$(python3 -c "
import json, os
data = json.load(open('$STATE_FILE'))
count = 0
for e in data:
    pid = e.get('pid','')
    if pid and pid != '0':
        try: os.kill(int(pid), 0)
        except: count += 1
print(count)
" 2>/dev/null || echo 0)

  echo -e "  ${BOLD}Forwarded Ports${RESET}   total: ${CYAN}$total${RESET}   dead: ${dead:+${RED}}$dead${dead:+${RESET}}"
  echo ""
  cmd_status

  echo -e "  ${DIM}Commands: forward · kill <name|port|all> · info <port> · log <name>${RESET}"
  echo ""

  # Also show system ports in use
  echo -e "  ${BOLD}System Ports In Use${RESET} ${DIM}(ss -tlnp)${RESET}"
  echo -e "  ${DIM}$(printf '─%.0s' {1..70})${RESET}"
  ss -tlnp 2>/dev/null | awk 'NR>1 {
    split($4, a, ":")
    port = a[length(a)]
    proc = $6
    gsub(/.*pid=/, "", proc); gsub(/,.*/, "", proc)
    if (port+0 > 0) printf "  \033[2m%-8s\033[0m %s\n", port, proc
  }' | sort -t: -k1 -n | head -30
  echo ""
}

# ── Command: info ─────────────────────────────────────────────────────────────
cmd_info() {
  local query="${1:-}"
  [[ -z "$query" ]] && {
    echo -e "${BOLD}Usage:${RESET} portman info <port_number|keyword>"
    echo ""
    echo -e "  ${DIM}Examples:  portman info 5432   portman info postgres   portman info 80${RESET}"
    return 1
  }

  _print_header
  echo -e "  ${BOLD}Port Reference Manual${RESET}\n"

  if [[ "$query" =~ ^[0-9]+$ ]]; then
    # Exact port lookup
    local desc="${PORT_DB[$query]:-}"
    if [[ -n "$desc" ]]; then
      echo -e "  ${BOLD}${CYAN}Port $query${RESET}"
      echo -e "  ${GREEN}$desc${RESET}"
      echo ""
    else
      echo -e "  ${YELLOW}Port $query${RESET} — not in portman's reference database."
      echo -e "  ${DIM}Try: grep -i $query /etc/services${RESET}"
    fi

    # Show live usage
    echo -e "  ${BOLD}Live status:${RESET}"
    local live
    live=$(ss -tlnp 2>/dev/null | awk -v p=":$query" '$4 ~ p {print}')
    if [[ -n "$live" ]]; then
      echo -e "  ${RED}● Port $query is currently in use${RESET}"
      echo "$live" | sed 's/^/    /'
    else
      echo -e "  ${GREEN}● Port $query is free${RESET}"
    fi

    # Show if we have a forward on this port
    local fwd
    fwd=$(python3 -c "
import json
data = json.load(open('$STATE_FILE'))
for e in data:
    if e.get('local_port') == '$query':
        print('portman: forwarded as \"' + e.get('name','?') + '\" → remote:' + e.get('remote','?'))
" 2>/dev/null)
    [[ -n "$fwd" ]] && echo -e "  ${CYAN}$fwd${RESET}"

  else
    # Keyword search
    echo -e "  ${BOLD}Search results for '${CYAN}$query${RESET}${BOLD}':${RESET}\n"
    local found=0
    for port in $(echo "${!PORT_DB[@]}" | tr ' ' '\n' | sort -n); do
      local desc="${PORT_DB[$port]}"
      if echo "$desc" | grep -qi "$query" || echo "$port" | grep -q "$query"; then
        printf "  ${CYAN}%-8s${RESET} %s\n" "$port" "$desc"
        found=1
      fi
    done
    [[ $found -eq 0 ]] && echo -e "  ${YELLOW}No ports found matching '$query'${RESET}"
  fi

  echo ""
  echo -e "  ${DIM}Full reference: /etc/services   |   portman info <port>${RESET}\n"
}

# ── Command: log ──────────────────────────────────────────────────────────────
cmd_log() {
  local name="${1:-}"
  local lines="${2:-50}"
  [[ -z "$name" ]] && { echo -e "${BOLD}Usage:${RESET} portman log <name> [lines]"; return 1; }

  local log_file="$LOG_DIR/${name}.log"
  [[ -f "$log_file" ]] || _die "No log file found for '$name' at $log_file"

  echo -e "${BOLD}${CYAN}── Log: $name ──────────────────────────────────────${RESET}"
  echo -e "${DIM}$log_file${RESET}\n"
  tail -n "$lines" "$log_file"
  echo ""
  echo -e "${DIM}Tip: tail -f $log_file  (live stream)${RESET}"
}

# ── Command: check ────────────────────────────────────────────────────────────
cmd_check() {
  local port="${1:-}"
  [[ -z "$port" ]] && { echo -e "${BOLD}Usage:${RESET} portman check <port>"; return 1; }
  [[ "$port" =~ ^[0-9]+$ ]] || _die "Port must be a number"

  echo -e "${CYAN}→${RESET} Checking port ${BOLD}$port${RESET}..."

  local used=0
  if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
    echo -e "  ${RED}● In use${RESET} (TCP listening)"
    ss -tlnp 2>/dev/null | awk -v p=":$port " '$4 ~ p {print "    " $0}'
    used=1
  fi

  if lsof -i ":${port}" &>/dev/null 2>&1; then
    echo -e "  ${RED}● In use${RESET} (lsof)"
    lsof -i ":${port}" | sed 's/^/    /'
    used=1
  fi

  [[ $used -eq 0 ]] && echo -e "  ${GREEN}● Port $port is free${RESET}"

  # Description
  if [[ -n "${PORT_DB[$port]+_}" ]]; then
    echo -e "  ${DIM}ℹ  Well-known: ${PORT_DB[$port]}${RESET}"
  fi

  # Is it forwarded by portman?
  local fwd
  fwd=$(python3 -c "
import json
data = json.load(open('$STATE_FILE'))
for e in data:
    if e.get('local_port') == '$port':
        print('portman forward: \"' + e.get('name','?') + '\"')
" 2>/dev/null)
  [[ -n "$fwd" ]] && echo -e "  ${CYAN}ℹ  $fwd${RESET}"
  echo ""
}

# ── Command: clean ────────────────────────────────────────────────────────────
cmd_clean() {
  echo -e "${CYAN}→${RESET} Cleaning dead forwards from state..."
  local removed=0
  local names
  names=$(_state_all_names)

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local pid
    pid=$(_state_get_field "$name" "pid")
    local type
    type=$(_state_get_field "$name" "type")

    if [[ "$type" != "local" ]] && ! _pid_alive "$pid"; then
      _warn "Removing dead forward: '${BOLD}$name${RESET}' (PID $pid)"
      _state_remove "$name"
      removed=$((removed + 1))
    fi
  done <<< "$names"

  [[ $removed -eq 0 ]] && _ok "Nothing to clean — all forwards are alive." \
                        || _ok "Removed $removed dead forward(s)."
}

# ── Command: help ─────────────────────────────────────────────────────────────
cmd_help() {
  _print_header
  cat << EOF
${BOLD}USAGE${RESET}
  portman <command> [arguments]

${BOLD}COMMANDS${RESET}

  ${GREEN}forward${RESET} <name> <local:remote> [--type k8s|ssh|socat|local] [--extra "..."]
      Start a background port forward.
      Types:
        ${CYAN}k8s${RESET}    kubectl port-forward (default). Use --extra to set target
               e.g. --extra "svc/myapp -n production"
        ${CYAN}ssh${RESET}    SSH local tunnel. --extra must be "user@host"
        ${CYAN}socat${RESET}  TCP relay via socat. --extra sets destination "host:port"
        ${CYAN}local${RESET}  Register/track a port without starting a process

  ${GREEN}kill${RESET} <name|port|all>
      Terminate and remove a forwarded port. Use 'all' to kill everything.

  ${GREEN}list${RESET}
      Show an overview: active forwards + system ports in use.

  ${GREEN}status${RESET} [name|port]
      Tabular view of managed forwards with live PID status.

  ${GREEN}info${RESET} <port|keyword>
      Port reference manual. Lookup a port number or search by keyword.
      Examples: portman info 5432   portman info postgres   portman info http

  ${GREEN}check${RESET} <port>
      Quick check: is this port free or in use right now?

  ${GREEN}log${RESET} <name> [lines]
      Show last N lines of a forward's log (default: 50).

  ${GREEN}clean${RESET}
      Remove dead/crashed forwards from state.

  ${GREEN}completion${RESET}
      Install bash tab completion for portman.

${BOLD}EXAMPLES${RESET}

  # Forward a Kubernetes pod
  portman forward myapi 8080:80 --type k8s --extra "svc/myapi -n staging"

  # Forward a k8s database pod
  portman forward pg 5432:5432 --type k8s --extra "pod/postgres-0"

  # SSH tunnel to a remote service
  portman forward remote-db 5433:5432 --type ssh --extra "ubuntu@10.0.0.5"

  # Check what port 8080 is
  portman info 8080

  # Kill a specific forward
  portman kill myapi

  # Kill by port number
  portman kill 8080

  # See everything
  portman list

${BOLD}STATE & LOGS${RESET}
  State:  $STATE_FILE
  Logs:   $LOG_DIR/<name>.log

EOF
}

# ── Entry Point ────────────────────────────────────────────────────────────────
_init

cmd="${1:-help}"
shift 2>/dev/null || true

case "$cmd" in
  forward|fwd|f)    cmd_forward "$@" ;;
  kill|k)           cmd_kill    "$@" ;;
  list|ls|l)        cmd_list    "$@" ;;
  status|st|s)      cmd_status  "$@" ;;
  info|i)           cmd_info    "$@" ;;
  log|logs)         cmd_log     "$@" ;;
  check|c)          cmd_check   "$@" ;;
  clean)            cmd_clean   "$@" ;;
  completion)       _completion_install ;;
  _names)           _state_all_names ;;   # internal, used by completion
  version|-v|--version) echo "portman v$VERSION" ;;
  help|-h|--help|"") cmd_help ;;
  *) echo -e "${RED}✖ Unknown command:${RESET} $cmd\n"; cmd_help; exit 1 ;;
esac
