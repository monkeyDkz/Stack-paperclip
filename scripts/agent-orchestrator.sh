#!/bin/bash
# ============================================
# PAPERCLIP — Agent Orchestrator
# ============================================
# Gère les agents UN PAR UN pour éviter les
# conflits VRAM sur Mac 48GB.
#
# Usage:
#   ./agent-orchestrator.sh run          # Mode daemon continu
#   ./agent-orchestrator.sh once         # Un seul cycle
#   ./agent-orchestrator.sh status       # Statut de tous les agents
#   ./agent-orchestrator.sh queue        # Issues en attente
#   ./agent-orchestrator.sh wake <name>  # Wake manuel d'un agent
#   ./agent-orchestrator.sh stop         # Arrêter le daemon
#   ./agent-orchestrator.sh reset        # Tout remettre à idle
# ============================================

set -euo pipefail

PAPERCLIP_URL="http://localhost:8060"
COMPANY_ID="7c6f8a64-083b-4ff3-a478-b523b0b87b0d"
ADMIN_EMAIL="${PAPERCLIP_ADMIN_EMAIL:-admin@paperclip.local}"
ADMIN_PASSWORD="${PAPERCLIP_ADMIN_PASSWORD:-paperclip-admin}"
COOKIE_FILE="/tmp/pc-orchestrator.txt"
PID_FILE="/tmp/pc-orchestrator.pid"
LOG_FILE="/tmp/pc-orchestrator.log"

# Timeout par agent (seconds)
AGENT_TIMEOUT=1800  # 30 min max

# Priorité des agents (ordre de wake)
PRIORITY=(ceo cto cpo cfo growth-lead lead-backend lead-frontend devops security qa designer researcher seo content-writer data-analyst sales)

# Pause entre cycles (seconds)
CYCLE_PAUSE=30

# Colors
G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; R='\033[0;31m'; D='\033[0;90m'; NC='\033[0m'
ts() { date +%H:%M:%S; }

# === API ===

login() {
    curl -sf -X POST "$PAPERCLIP_URL/api/auth/sign-in/email" \
        -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
        -c "$COOKIE_FILE" \
        -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" > /dev/null 2>&1
}

api() {
    local method="$1" path="$2" data="${3:-}"
    if [ -n "$data" ]; then
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b "$COOKIE_FILE" -d "$data" 2>/dev/null || echo "{}"
    else
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b "$COOKIE_FILE" 2>/dev/null || echo "{}"
    fi
}

# === Helpers ===

get_agents_json() { api GET "/api/companies/$COMPANY_ID/agents"; }
get_issues_json() { api GET "/api/companies/$COMPANY_ID/issues?status=todo,in_progress"; }

get_agent_id() {
    local name="$1"
    get_agents_json | python3 -c "
import json,sys
agents = json.load(sys.stdin)
for a in agents:
    if a['name'] == '$name': print(a['id']); break
" 2>/dev/null
}

get_agent_status() {
    local aid="$1"
    api GET "/api/agents/$aid" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null
}

# === Core ===

wake_and_wait() {
    local name="$1"
    local agent_id
    agent_id=$(get_agent_id "$name")
    [ -z "$agent_id" ] && { echo -e "${Y}[$(ts)]${NC} $name: not found"; return 1; }

    local status
    status=$(get_agent_status "$agent_id")

    [ "$status" = "running" ] && { echo -e "${D}[$(ts)]${NC} $name: already running"; return 0; }
    [ "$status" = "error" ] && api PATCH "/api/agents/$agent_id" '{"status":"idle"}' > /dev/null

    local resp run_id
    resp=$(api POST "/api/agents/$agent_id/wakeup" \
        "{\"source\":\"on_demand\",\"triggerDetail\":\"manual\",\"reason\":\"Orchestrator\"}")
    run_id=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

    [ -z "$run_id" ] && { echo -e "${Y}[$(ts)]${NC} $name: wake failed"; return 1; }

    echo -e "${G}[$(ts)]${NC} $name: waked (run ${run_id:0:8}...)"

    local elapsed=0
    while [ $elapsed -lt $AGENT_TIMEOUT ]; do
        sleep 15
        elapsed=$((elapsed + 15))
        status=$(get_agent_status "$agent_id")

        case "$status" in
            running)
                local tools
                tools=$(docker exec paperclip grep -c "tool_use" \
                    "/paperclip/instances/default/data/run-logs/$COMPANY_ID/$agent_id/$run_id.ndjson" 2>/dev/null || echo "0")
                echo -e "${D}[$(ts)]${NC}   $name: running [${elapsed}s] tools=$tools"
                ;;
            idle)
                local run_info
                run_info=$(api GET "/api/heartbeat-runs/$run_id" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f\"{d.get('status','?')} exit={d.get('exitCode','?')}\")" 2>/dev/null)
                echo -e "${G}[$(ts)]${NC} $name: done in ${elapsed}s — $run_info"
                # Post-run logger: save to Mem0 + SiYuan
                local logger="$(cd "$(dirname "$0")" && pwd)/post-run-logger.py"
                if [ -f "$logger" ]; then
                    local run_status="${run_info%% *}"
                    python3 "$logger" "$name" "$run_id" --status "$run_status" 2>&1 | while read line; do
                        echo -e "${D}[$(ts)]${NC}   logger: $line"
                    done
                fi
                return 0
                ;;
            error)
                echo -e "${R}[$(ts)]${NC} $name: error after ${elapsed}s"
                api PATCH "/api/agents/$agent_id" '{"status":"idle"}' > /dev/null
                return 1
                ;;
        esac
    done

    echo -e "${Y}[$(ts)]${NC} $name: TIMEOUT ${AGENT_TIMEOUT}s, cancelling"
    api POST "/api/heartbeat-runs/$run_id/cancel" '{}' > /dev/null
    sleep 2
    api PATCH "/api/agents/$agent_id" '{"status":"idle"}' > /dev/null
    return 1
}

run_cycle() {
    login || { echo -e "${R}[$(ts)]${NC} Login failed"; return 1; }

    # Check no agent is running
    local running
    running=$(get_agents_json | python3 -c "
import json,sys
for a in json.load(sys.stdin):
    if a['status'] == 'running': print(a['name']); break
" 2>/dev/null)

    if [ -n "$running" ]; then
        echo -e "${D}[$(ts)]${NC} $running is running, waiting..."
        return 0
    fi

    # Find agents with pending issues
    local work_agents
    work_agents=$(python3 -c "
import json,subprocess,sys

agents_raw = subprocess.run(['curl','-sf','$PAPERCLIP_URL/api/companies/$COMPANY_ID/agents',
    '-H','Origin: $PAPERCLIP_URL','-b','$COOKIE_FILE'], capture_output=True, text=True).stdout
issues_raw = subprocess.run(['curl','-sf','$PAPERCLIP_URL/api/companies/$COMPANY_ID/issues?status=todo,in_progress',
    '-H','Origin: $PAPERCLIP_URL','-b','$COOKIE_FILE'], capture_output=True, text=True).stdout

agents = {a['id']: a['name'] for a in json.loads(agents_raw)}
issues = json.loads(issues_raw)

work = set()
for i in issues:
    aid = i.get('assigneeAgentId','')
    if aid and aid in agents:
        work.add(agents[aid])
for w in work: print(w)
" 2>/dev/null)

    if [ -z "$work_agents" ]; then
        echo -e "${D}[$(ts)]${NC} No pending work"
        return 0
    fi

    # Wake first agent in priority order that has work
    for name in "${PRIORITY[@]}"; do
        if echo "$work_agents" | grep -q "^${name}$"; then
            echo -e "${B}[$(ts)]${NC} === $name has pending work ==="
            wake_and_wait "$name"
            return 0
        fi
    done

    echo -e "${D}[$(ts)]${NC} No prioritized agent matched"
}

# === Commands ===

cmd_status() {
    login || exit 1
    echo ""
    echo "========================================"
    echo "  PAPERCLIP AGENTS"
    echo "========================================"
    python3 -c "
import json,subprocess
agents_raw = subprocess.run(['curl','-sf','$PAPERCLIP_URL/api/companies/$COMPANY_ID/agents',
    '-H','Origin: $PAPERCLIP_URL','-b','$COOKIE_FILE'], capture_output=True, text=True).stdout
issues_raw = subprocess.run(['curl','-sf','$PAPERCLIP_URL/api/companies/$COMPANY_ID/issues?status=todo,in_progress',
    '-H','Origin: $PAPERCLIP_URL','-b','$COOKIE_FILE'], capture_output=True, text=True).stdout

agents = json.loads(agents_raw)
issues = json.loads(issues_raw)
issue_count = {}
for i in issues:
    aid = i.get('assigneeAgentId','')
    issue_count[aid] = issue_count.get(aid, 0) + 1

for a in sorted(agents, key=lambda x: x['name']):
    s = a['status']
    model = a.get('adapterConfig',{}).get('model','?')
    n = issue_count.get(a['id'], 0)
    icon = '🟢' if s == 'running' else '🟡' if n > 0 else '⚪' if s == 'idle' else '🔴'
    issues_str = f'{n} issues' if n > 0 else ''
    print(f'  {icon} {a[\"name\"]:20s} {s:10s} {model:25s} {issues_str}')
print()
"
}

cmd_queue() {
    login || exit 1
    echo ""
    echo "========================================"
    echo "  ISSUE QUEUE"
    echo "========================================"
    python3 -c "
import json,subprocess
agents_raw = subprocess.run(['curl','-sf','$PAPERCLIP_URL/api/companies/$COMPANY_ID/agents',
    '-H','Origin: $PAPERCLIP_URL','-b','$COOKIE_FILE'], capture_output=True, text=True).stdout
issues_raw = subprocess.run(['curl','-sf','$PAPERCLIP_URL/api/companies/$COMPANY_ID/issues?status=todo,in_progress',
    '-H','Origin: $PAPERCLIP_URL','-b','$COOKIE_FILE'], capture_output=True, text=True).stdout

agents = {a['id']: a['name'] for a in json.loads(agents_raw)}
issues = json.loads(issues_raw)

if not issues:
    print('  (empty)')
else:
    for i in sorted(issues, key=lambda x: x.get('createdAt','')):
        aid = i.get('assigneeAgentId','')
        aname = agents.get(aid, 'UNASSIGNED')
        s = i.get('status','?')
        title = i.get('title','?')[:55]
        ident = i.get('identifier','?')
        proj = 'P' if i.get('projectId') else ' '
        icon = '⏳' if s == 'todo' else '🔄'
        print(f'  {icon} {ident:8s} [{aname:15s}] {s:12s} {proj} {title}')
print()
"
}

cmd_wake() {
    local name="${1:-}"
    [ -z "$name" ] && { echo "Usage: $0 wake <agent-name>"; exit 1; }
    login || exit 1

    local running
    running=$(get_agents_json | python3 -c "
import json,sys
for a in json.load(sys.stdin):
    if a['status'] == 'running': print(a['name']); break
" 2>/dev/null)

    if [ -n "$running" ]; then
        echo -e "${R}Cannot wake $name: $running is running${NC}"
        echo "  Wait for it to finish, or use: $0 reset"
        exit 1
    fi

    wake_and_wait "$name"
}

cmd_run() {
    echo "========================================"
    echo "  PAPERCLIP ORCHESTRATOR"
    echo "========================================"
    echo "  Timeout: ${AGENT_TIMEOUT}s per agent"
    echo "  Cycle: every ${CYCLE_PAUSE}s"
    echo "  Priority: ${PRIORITY[*]}"
    echo "  Log: $LOG_FILE"
    echo "  Stop: $0 stop (or Ctrl+C)"
    echo "========================================"

    echo $$ > "$PID_FILE"
    trap 'rm -f "$PID_FILE"; echo -e "\n${G}[$(ts)]${NC} Orchestrator stopped"; exit 0' INT TERM

    echo -e "${G}[$(ts)]${NC} Started (PID $$)"

    while true; do
        run_cycle 2>&1 | tee -a "$LOG_FILE"
        sleep "$CYCLE_PAUSE"
    done
}

cmd_once() {
    login || exit 1
    run_cycle
}

cmd_stop() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            echo -e "${G}Stopped (PID $pid)${NC}"
        else
            rm -f "$PID_FILE"
            echo "PID $pid not running, cleaned up"
        fi
    else
        echo "No orchestrator running"
    fi
}

cmd_reset() {
    login || exit 1
    echo "=== Resetting all agents to idle ==="
    get_agents_json | python3 -c "
import json,sys
for a in json.load(sys.stdin):
    if a['status'] in ('running','error','queued'):
        print(a['id'], a['name'])
" 2>/dev/null | while read aid name; do
        api PATCH "/api/agents/$aid" '{"status":"idle"}' > /dev/null
        echo "  Reset $name"
    done
    echo "Done"
}

# === Main ===

case "${1:-status}" in
    run)    cmd_run ;;
    once)   cmd_once ;;
    status) cmd_status ;;
    queue)  cmd_queue ;;
    wake)   cmd_wake "${2:-}" ;;
    stop)   cmd_stop ;;
    reset)  cmd_reset ;;
    *)      echo "Usage: $0 {run|once|status|queue|wake <name>|stop|reset}"; exit 1 ;;
esac
