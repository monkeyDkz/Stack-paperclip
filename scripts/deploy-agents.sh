#!/bin/bash
# ============================================
# PAPERCLIP — Deploy Agents (unified)
# ============================================
# Replaces inject-prompts.sh + switch-to-opencode.sh
#
# For each of the 16 agents:
#   1. Read prompt from prompt-templates/{name}.txt
#   2. PATCH adapterConfig (model, prompt, skipPermissions, mem0)
#   3. PATCH runtimeConfig (heartbeat, timeout, maxTurns)
# ============================================

set -euo pipefail

PAPERCLIP_URL="http://localhost:8060"
ADMIN_EMAIL="${PAPERCLIP_ADMIN_EMAIL:-admin@paperclip.local}"
ADMIN_PASSWORD="${PAPERCLIP_ADMIN_PASSWORD:-paperclip-admin}"
COMPANY_ID="7c6f8a64-083b-4ff3-a478-b523b0b87b0d"
PROMPT_DIR="$(cd "$(dirname "$0")/prompt-templates" && pwd)"
MODEL="ollama/qwen3:14b"
COOKIE="/tmp/pc-deploy.txt"

AGENTS=(ceo cto cpo cfo lead-backend lead-frontend devops security qa designer researcher growth-lead seo content-writer data-analyst sales)

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
info() { echo -e "${BLUE}[>>]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

command -v jq &>/dev/null || fail "jq is required"
command -v curl &>/dev/null || fail "curl is required"

# --- Login ---
info "Logging in to Paperclip..."
curl -sf -X POST "$PAPERCLIP_URL/api/auth/sign-in/email" \
    -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
    -c "$COOKIE" \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" > /dev/null || fail "Login failed"
log "Authenticated"

api() {
    local method="$1" path="$2" data="${3:-}"
    if [ -n "$data" ]; then
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b "$COOKIE" -d "$data" 2>/dev/null || echo "{}"
    else
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b "$COOKIE" 2>/dev/null || echo "{}"
    fi
}

# --- Get agents ---
AGENTS_JSON=$(api GET "/api/companies/$COMPANY_ID/agents")
AGENT_COUNT=$(echo "$AGENTS_JSON" | jq 'length' 2>/dev/null)
log "Company: $COMPANY_ID — $AGENT_COUNT agents found"

get_agent_id() { echo "$AGENTS_JSON" | jq -r ".[] | select(.name == \"$1\") | .id"; }

echo ""
echo "========================================"
echo "  DEPLOY — 16 Agents (model: $MODEL)"
echo "========================================"
echo ""

# --- Deploy each agent ---
deploy_agent() {
    local name="$1"
    local prompt_file="$PROMPT_DIR/${name}.txt"

    # Get agent ID
    local agent_id
    agent_id=$(get_agent_id "$name")
    [ -z "$agent_id" ] && { warn "$name: agent not found"; return; }

    # Read prompt template
    if [ ! -f "$prompt_file" ]; then
        warn "$name: prompt file not found ($prompt_file)"
        return
    fi

    local prompt_len
    prompt_len=$(wc -c < "$prompt_file" | tr -d ' ')

    # Build adapter update JSON using --rawfile to handle newlines properly
    local adapter_json
    adapter_json=$(jq -n \
        --rawfile prompt "$prompt_file" \
        --arg model "$MODEL" \
        --arg mem0 "$name" \
        '{
            adapterConfig: {
                model: $model,
                promptTemplate: $prompt,
                dangerouslySkipPermissions: true
            },
            metadata: {
                mem0_user_id: $mem0
            }
        }')

    # PATCH adapterConfig
    local resp ok
    resp=$(api PATCH "/api/agents/$agent_id" "$adapter_json")
    ok=$(echo "$resp" | jq -r '.name // empty' 2>/dev/null)

    if [ -z "$ok" ]; then
        warn "$name: adapter PATCH failed — $(echo "$resp" | jq -r '.error // .message // "?"' 2>/dev/null)"
        return
    fi

    # Build runtimeConfig update JSON
    local runtime_json
    runtime_json=$(jq -n '{
        runtimeConfig: {
            heartbeat: {
                enabled: false,
                wakeOnDemand: true,
                wakeOnAssignment: false
            },
            timeoutSec: 300,
            maxTurnsPerRun: 10
        }
    }')

    # PATCH runtimeConfig
    local resp2 ok2
    resp2=$(api PATCH "/api/agents/$agent_id" "$runtime_json")
    ok2=$(echo "$resp2" | jq -r '.name // empty' 2>/dev/null)

    if [ -n "$ok2" ]; then
        log "$name: prompt=${prompt_len}B model=$MODEL runtime=ok"
    else
        warn "$name: adapter=ok runtime=FAILED"
    fi
}

for agent_name in "${AGENTS[@]}"; do
    deploy_agent "$agent_name"
done

# ============================================
# VERIFICATION
# ============================================
echo ""
info "=== Verification ==="
echo ""

FINAL=$(api GET "/api/companies/$COMPANY_ID/agents")

printf "%-18s %-22s %10s  %s\n" "AGENT" "MODEL" "PROMPT" "SKIP_PERMS"
printf "%-18s %-22s %10s  %s\n" "-----" "-----" "------" "----------"

echo "$FINAL" | jq -r '.[] | "\(.name)\t\(.adapterConfig.model // "?")\t\(.adapterConfig.promptTemplate | length) chars\t\(.adapterConfig.dangerouslySkipPermissions // false)"' 2>/dev/null | \
    sort | while IFS=$'\t' read -r name model plen skip; do
        printf "%-18s %-22s %10s  %s\n" "$name" "$model" "$plen" "$skip"
    done

echo ""
echo "========================================"
echo -e "  ${GREEN}DEPLOY COMPLETE${NC}"
echo "========================================"
echo ""
echo "  All agents configured with:"
echo "    - Model: $MODEL"
echo "    - Prompt from prompt-templates/{name}.txt"
echo "    - dangerouslySkipPermissions: true"
echo "    - mem0_user_id: agent name"
echo "    - heartbeat: disabled (wakeOnDemand)"
echo "    - timeout: 300s, maxTurns: 10"
echo ""

rm -f "$COOKIE"
