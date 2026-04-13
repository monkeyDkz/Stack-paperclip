#!/bin/bash
# ============================================
# PAPERCLIP — Controle des agents
# ============================================
# Usage:
#   ./agent-control.sh status              — voir l'etat de tous les agents
#   ./agent-control.sh start               — activer tous les agents (idle)
#   ./agent-control.sh stop                — pauser tous les agents
#   ./agent-control.sh start ceo cto       — activer seulement CEO et CTO
#   ./agent-control.sh stop ceo            — pauser seulement le CEO
#   ./agent-control.sh wake ceo            — reveiller le CEO immediatement
#   ./agent-control.sh cascade             — CEO puis chaque agent avec des taches (sequentiel)
#   ./agent-control.sh cascade --no-ceo    — cascade sans re-reveiller le CEO
#   ./agent-control.sh cascade --loop      — boucle infinie (Ctrl+C pour arreter)
# ============================================

PAPERCLIP_URL="http://localhost:8060"
COMPANY_ID="7c6f8a64-083b-4ff3-a478-b523b0b87b0d"
MAX_WAIT=600  # timeout 10 min par agent
POLL_INTERVAL=10

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

# Login
curl -sf -X POST "$PAPERCLIP_URL/api/auth/sign-in/email" \
    -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
    -c /tmp/pc-ctl.txt \
    -d '{"email":"admin@paperclip.local","password":"paperclip-admin"}' > /dev/null 2>&1

api() {
    curl -s -X "$1" "$PAPERCLIP_URL$2" \
        -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
        -b /tmp/pc-ctl.txt ${3:+-d "$3"} 2>/dev/null
}

# Ordre de priorite pour la cascade (1 agent a la fois)
PRIORITY_ORDER="ceo cto cpo cfo lead-backend lead-frontend devops designer qa security researcher growth-lead seo content-writer data-analyst sales"
ALL_AGENTS="$PRIORITY_ORDER"

get_id() {
    api GET "/api/agents/$1?companyId=$COMPANY_ID" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null
}

get_status() {
    api GET "/api/agents/$1?companyId=$COMPANY_ID" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null
}

# Reveiller un agent et attendre qu'il finisse
wake_and_wait() {
    local name="$1"
    local reason="${2:-Cascade}"
    local aid
    aid=$(get_id "$name")
    [ -z "$aid" ] && return 1

    # Unpause if needed
    api PATCH "/api/agents/$aid" '{"status":"idle"}' > /dev/null

    # Wake
    local result
    result=$(api POST "/api/agents/$aid/wakeup" "{\"source\":\"on_demand\",\"triggerDetail\":\"cascade\",\"reason\":\"$reason\"}")
    local runid
    runid=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id','?'))" 2>/dev/null)

    if [ "$runid" = "?" ] || [ -z "$runid" ]; then
        echo -e "  ${YELLOW}[SKIP]${NC} $name — impossible de reveiller"
        return 1
    fi

    local start_time=$SECONDS
    echo -e "  ${BLUE}[RUN]${NC}  $name — run $runid"

    # Poll until done
    while true; do
        sleep $POLL_INTERVAL
        local elapsed=$(( SECONDS - start_time ))
        local status
        status=$(get_status "$name")

        if [ "$status" = "idle" ] || [ "$status" = "error" ]; then
            if [ "$status" = "error" ]; then
                echo -e "  ${RED}[ERR]${NC}  $name — erreur apres ${elapsed}s"
            else
                echo -e "  ${GREEN}[OK]${NC}   $name — termine en ${elapsed}s"
            fi
            return 0
        fi

        if [ $elapsed -ge $MAX_WAIT ]; then
            echo -e "  ${RED}[TIMEOUT]${NC} $name — force reset apres ${MAX_WAIT}s"
            api PATCH "/api/agents/$aid" '{"status":"idle"}' > /dev/null
            return 1
        fi

        printf "\r  ${CYAN}[...]${NC}  $name — en cours (${elapsed}s)    "
    done
}

# Trouver les agents qui ont des issues todo assignees
agents_with_work() {
    api GET "/api/companies/$COMPANY_ID/issues?status=todo,in_progress" | python3 -c "
import json, sys, re
raw = re.sub(r'[\x00-\x1f\x7f]', ' ', sys.stdin.read())
data = json.loads(raw)
# Map agent IDs to names
id_to_name = {
    'bd91f3cc-472e-4add-b480-1b1f4dabb042': 'ceo',
    '0d3160d7-6fea-4633-944a-0ca41210d8e2': 'cto',
    '6b800922-3d71-4ddb-896c-bb20d81a4116': 'cpo',
    '44499293-c6bd-4b02-ad23-4274842e679f': 'cfo',
    '30388859-12b5-4907-8c77-c1fb2a520e78': 'lead-backend',
    '45861453-a2e2-4044-94af-abffe6e72a54': 'lead-frontend',
    'cf87ed4e-21a3-424a-b8d1-29e5436f643a': 'devops',
    '882a767a-8295-4f35-9865-14a0142adb26': 'security',
    '436026bf-b23c-4e0b-a952-94ad0a577fac': 'qa',
    'c3146739-1ca8-455b-87cb-c5f8841ab5c2': 'designer',
    '0400e565-6dc4-434c-be96-d8735eec4a2b': 'researcher',
    '3ebd54af-e9b1-40db-94d5-2bb0824799f4': 'growth-lead',
    '4626220e-c5b6-44b5-9f6c-eed11e64bee1': 'seo',
    'b708cea0-22fa-44ca-92d8-c5cc033d2991': 'content-writer',
    '049131ad-7030-4950-9dc2-ea09ba813f45': 'data-analyst',
    'ab8d419a-72b9-4b62-9b9f-c5d61bf8543e': 'sales',
}
agents_with_tasks = set()
for issue in data:
    aid = issue.get('assigneeAgentId', '')
    name = id_to_name.get(aid, '')
    if name:
        agents_with_tasks.add(name)
for name in agents_with_tasks:
    print(name)
" 2>/dev/null
}

ACTION="${1:-status}"
shift 2>/dev/null || true
TARGETS="${*:-$ALL_AGENTS}"

case "$ACTION" in
    status)
        printf "%-18s %-10s %-40s %s\n" "AGENT" "STATUS" "MODEL" "HEARTBEAT"
        printf "%-18s %-10s %-40s %s\n" "-----" "------" "-----" "---------"
        for name in $ALL_AGENTS; do
            info=$(api GET "/api/agents/$name?companyId=$COMPANY_ID")
            status=$(echo "$info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null)
            model=$(echo "$info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('adapterConfig',{}).get('model','?'))" 2>/dev/null)
            hb=$(echo "$info" | python3 -c "import json,sys; rc=json.load(sys.stdin).get('runtimeConfig',{}); hb=rc.get('heartbeat',{}); print('ON' if hb.get('enabled') else 'scheduler')" 2>/dev/null)
            printf "%-18s %-10s %-40s %s\n" "$name" "$status" "$model" "$hb"
        done
        ;;
    start)
        for name in $TARGETS; do
            aid=$(get_id "$name")
            [ -n "$aid" ] && api PATCH "/api/agents/$aid" '{"status":"idle"}' > /dev/null && echo "Started $name"
        done
        ;;
    stop)
        for name in $TARGETS; do
            aid=$(get_id "$name")
            [ -n "$aid" ] && api PATCH "/api/agents/$aid" '{"status":"paused"}' > /dev/null && echo "Paused $name"
        done
        ;;
    wake)
        for name in $TARGETS; do
            aid=$(get_id "$name")
            if [ -n "$aid" ]; then
                api PATCH "/api/agents/$aid" '{"status":"idle"}' > /dev/null
                result=$(api POST "/api/agents/$aid/wakeup" '{"source":"on_demand","triggerDetail":"manual","reason":"Manual wake"}')
                runid=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id','?'))" 2>/dev/null)
                echo "Woke $name → run $runid"
            fi
        done
        ;;
    cascade)
        NO_CEO=false
        LOOP=false
        for arg in "$@"; do
            case "$arg" in
                --no-ceo) NO_CEO=true ;;
                --loop) LOOP=true ;;
            esac
        done

        run_cascade() {
            local cycle="$1"
            echo ""
            echo -e "${CYAN}========================================${NC}"
            echo -e "${CYAN}  CASCADE #$cycle — $(date '+%H:%M:%S')${NC}"
            echo -e "${CYAN}========================================${NC}"
            echo ""

            # Step 1: Wake CEO (unless --no-ceo)
            if [ "$NO_CEO" = false ]; then
                echo -e "${BLUE}[PHASE 1]${NC} CEO — strategie et delegation"
                wake_and_wait "ceo" "Cascade: planification"
                echo ""
            fi

            # Step 2: Find agents with work
            echo -e "${BLUE}[PHASE 2]${NC} Detection des agents avec des taches..."
            local workers
            workers=$(agents_with_work)

            if [ -z "$workers" ]; then
                echo -e "  ${YELLOW}[INFO]${NC} Aucun agent n'a de taches assignees"
                return 0
            fi

            # Step 3: Wake each agent in priority order, one at a time
            local count=0
            for name in $PRIORITY_ORDER; do
                # Skip CEO (already done)
                [ "$name" = "ceo" ] && continue

                # Only wake agents that have work
                if echo "$workers" | grep -q "^${name}$"; then
                    count=$((count + 1))
                    echo ""
                    echo -e "${BLUE}[AGENT $count]${NC} $name"
                    wake_and_wait "$name" "Cascade: traitement taches"
                fi
            done

            echo ""
            echo -e "${GREEN}========================================${NC}"
            echo -e "${GREEN}  CASCADE #$cycle TERMINEE${NC}"
            echo -e "${GREEN}  $count agents ont travaille${NC}"
            echo -e "${GREEN}========================================${NC}"
        }

        if [ "$LOOP" = true ]; then
            cycle=1
            echo -e "${CYAN}Mode boucle active (Ctrl+C pour arreter)${NC}"
            while true; do
                run_cascade $cycle
                cycle=$((cycle + 1))
                echo ""
                echo -e "${YELLOW}Prochaine cascade dans 60s...${NC}"
                sleep 60
            done
        else
            run_cascade 1
        fi
        ;;
    *)
        echo "Usage: $0 {status|start|stop|wake|cascade} [options]"
        echo ""
        echo "  status              — voir l'etat de tous les agents"
        echo "  start [agents...]   — activer des agents (idle)"
        echo "  stop [agents...]    — pauser des agents"
        echo "  wake [agents...]    — reveiller des agents immediatement"
        echo "  cascade             — CEO puis agents avec taches (1 a la fois)"
        echo "    --no-ceo          — sans re-reveiller le CEO"
        echo "    --loop            — boucle infinie (Ctrl+C pour arreter)"
        ;;
esac

rm -f /tmp/pc-ctl.txt
