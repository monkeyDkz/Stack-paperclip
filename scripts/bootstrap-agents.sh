#!/bin/bash
# ============================================
# PAPERCLIP — Bootstrap complet des 16 agents
# ============================================
# Usage : ./bootstrap-agents.sh
# Pre-requis : Paperclip running, admin cree, jq installe
# ============================================

set -euo pipefail

PAPERCLIP_URL="http://localhost:8060"
ADMIN_EMAIL="${PAPERCLIP_ADMIN_EMAIL:-admin@paperclip.local}"
ADMIN_PASSWORD="${PAPERCLIP_ADMIN_PASSWORD:-paperclip-admin}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
info() { echo -e "${BLUE}[>>]${NC} $1"; }
fail() { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }

command -v jq &>/dev/null || fail "jq requis : brew install jq"

# --- Login ---
info "Connexion a Paperclip..."
curl -sf -X POST "$PAPERCLIP_URL/api/auth/sign-in/email" \
    -H "Content-Type: application/json" \
    -H "Origin: $PAPERCLIP_URL" \
    -c /tmp/pc-boot.txt \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" > /dev/null || fail "Login echoue"
log "Connecte"

api() {
    local method="$1" path="$2" data="${3:-}"
    if [ -n "$data" ]; then
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" \
            -H "Origin: $PAPERCLIP_URL" \
            -b /tmp/pc-boot.txt \
            -d "$data" 2>/dev/null || echo "{}"
    else
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" \
            -H "Origin: $PAPERCLIP_URL" \
            -b /tmp/pc-boot.txt 2>/dev/null || echo "{}"
    fi
}

extract_id() { echo "$1" | jq -r '.id // .data.id // empty' 2>/dev/null; }

# --- Check existing ---
EXISTING=$(api GET "/api/companies")
COMPANY_COUNT=$(echo "$EXISTING" | jq 'if type == "array" then length elif .data then (.data | length) else 0 end' 2>/dev/null || echo "0")

if [ "$COMPANY_COUNT" -gt 0 ]; then
    COMPANY_ID=$(echo "$EXISTING" | jq -r 'if type == "array" then .[0].id elif .data then .data[0].id else empty end' 2>/dev/null)
    AGENTS=$(api GET "/api/companies/$COMPANY_ID/agents")
    AGENT_COUNT=$(echo "$AGENTS" | jq 'if type == "array" then length elif .data then (.data | length) else 0 end' 2>/dev/null || echo "0")
    if [ "$AGENT_COUNT" -ge 16 ]; then
        log "$AGENT_COUNT agents deja configures. Rien a faire."
        exit 0
    fi
    warn "Company existante ($COMPANY_ID) avec $AGENT_COUNT agents."
else
    info "Creation de la company..."
    RESP=$(api POST "/api/companies" '{"name":"Startup SaaS","description":"16 agents IA — produit SaaS self-hosted"}')
    COMPANY_ID=$(extract_id "$RESP")
    [ -z "$COMPANY_ID" ] && fail "Creation company echouee: $RESP"
    log "Company: $COMPANY_ID"
fi

echo ""
echo "========================================"
echo "  BOOTSTRAP — 16 Agents Paperclip"
echo "========================================"

# --- Goals ---
info "Goals..."
CG=$(extract_id "$(api POST "/api/companies/$COMPANY_ID/goals" '{"title":"Produit SaaS rentable","level":"company"}')")
TG_CTO=$(extract_id "$(api POST "/api/companies/$COMPANY_ID/goals" "{\"title\":\"Architecture scalable\",\"level\":\"team\",\"parentGoalId\":\"$CG\"}")")
TG_CPO=$(extract_id "$(api POST "/api/companies/$COMPANY_ID/goals" "{\"title\":\"Product-market fit\",\"level\":\"team\",\"parentGoalId\":\"$CG\"}")")
TG_CFO=$(extract_id "$(api POST "/api/companies/$COMPANY_ID/goals" "{\"title\":\"Runway > 18 mois\",\"level\":\"team\",\"parentGoalId\":\"$CG\"}")")
TG_GRW=$(extract_id "$(api POST "/api/companies/$COMPANY_ID/goals" "{\"title\":\"Croissance & acquisition\",\"level\":\"team\",\"parentGoalId\":\"$TG_CPO\"}")")
log "Goals crees"

# --- Projects ---
info "Projets..."
for p in '{"name":"Backend API"}' '{"name":"Frontend App"}' '{"name":"Infrastructure"}' '{"name":"MVP Features"}' '{"name":"Cost Optimization"}' '{"name":"Growth"}'; do
    api POST "/api/companies/$COMPANY_ID/projects" "$p" > /dev/null
done
log "6 projets crees"

# --- Agent creation helper ---
# Roles valides: ceo, cto, cmo, cfo, engineer, designer, pm, qa, devops, researcher, general
create_agent() {
    local name="$1" role="$2" title="$3" model="$4" reports_to="$5" hb="$6"
    local can_create="false"
    if [ "$role" = "ceo" ] || [ "$role" = "cto" ]; then
        can_create="true"
    fi

    local json="{\"name\":\"$name\",\"role\":\"$role\",\"title\":\"$title\",\"adapterType\":\"claude_local\",\"adapterConfig\":{\"model\":\"$model\"},\"runtimeConfig\":{\"heartbeat\":{\"enabled\":true,\"intervalSec\":$hb,\"wakeOnDemand\":true,\"wakeOnAssignment\":true}},\"permissions\":{\"canCreateAgents\":$can_create}}"

    # Add reportsTo if valid UUID
    if [ -n "$reports_to" ] && [ "$reports_to" != "null" ] && echo "$reports_to" | grep -qE '^[0-9a-f-]{36}$'; then
        json=$(echo "$json" | jq --arg rt "$reports_to" '. + {reportsTo: $rt}')
    fi

    local resp
    resp=$(api POST "/api/companies/$COMPANY_ID/agents" "$json")
    local id
    id=$(echo "$resp" | jq -r '.id // empty' 2>/dev/null)

    if [ -z "$id" ]; then
        warn "$name: echec — $(echo "$resp" | jq -r '.error // .details[0].message // "unknown"' 2>/dev/null)" >&2
        echo ""
    else
        log "$name ($title) → $id" >&2
        echo "$id"
    fi
}

# ============================================
# CREATE 16 AGENTS
# ============================================

info "=== Phase 1 : CEO ==="
CEO=$(create_agent "ceo" "ceo" "Chief Executive Officer" "qwen3:32b" "null" 600)

info "=== Phase 2 : C-Suite ==="
CTO=$(create_agent "cto" "cto" "Chief Technology Officer" "qwen3:32b" "$CEO" 300)
CPO=$(create_agent "cpo" "pm" "Chief Product Officer" "qwen3:14b" "$CEO" 600)
CFO=$(create_agent "cfo" "cfo" "Chief Financial Officer" "qwen3:14b" "$CEO" 900)

info "=== Phase 3 : Tech Team ==="
BK=$(create_agent "lead-backend" "engineer" "Lead Backend Engineer" "qwen3-coder:30b" "$CTO" 300)
FR=$(create_agent "lead-frontend" "engineer" "Lead Frontend Engineer" "qwen3-coder:30b" "$CTO" 300)
DO=$(create_agent "devops" "devops" "DevOps Engineer" "qwen3-coder:30b" "$CTO" 600)

info "=== Phase 4 : Support ==="
SEC=$(create_agent "security" "engineer" "Security Engineer" "qwen3:14b" "$CTO" 900)
QA=$(create_agent "qa" "qa" "QA Engineer" "qwen3:14b" "$CTO" 300)
DES=$(create_agent "designer" "designer" "UI/UX Designer" "qwen3:14b" "$CPO" 600)
RES=$(create_agent "researcher" "researcher" "Technical Researcher" "qwen3:14b" "$CTO" 900)

info "=== Phase 5 : Growth Team ==="
GL=$(create_agent "growth-lead" "general" "Growth Lead" "qwen3:32b" "$CPO" 600)
SEO=$(create_agent "seo" "general" "SEO Specialist" "qwen3:14b" "$GL" 900)
CW=$(create_agent "content-writer" "general" "Content Writer" "qwen3:14b" "$GL" 900)
DA=$(create_agent "data-analyst" "general" "Data Analyst" "qwen3:14b" "$GL" 3600)
SA=$(create_agent "sales" "general" "Sales Automation" "qwen3:14b" "$GL" 900)

# --- Assign goals to owners ---
info "Association goals → agents..."
[ -n "$CTO" ] && api PATCH "/api/companies/$COMPANY_ID/goals/$TG_CTO" "{\"ownerAgentId\":\"$CTO\"}" > /dev/null
[ -n "$CPO" ] && api PATCH "/api/companies/$COMPANY_ID/goals/$TG_CPO" "{\"ownerAgentId\":\"$CPO\"}" > /dev/null
[ -n "$CFO" ] && api PATCH "/api/companies/$COMPANY_ID/goals/$TG_CFO" "{\"ownerAgentId\":\"$CFO\"}" > /dev/null
[ -n "$GL" ] && api PATCH "/api/companies/$COMPANY_ID/goals/$TG_GRW" "{\"ownerAgentId\":\"$GL\"}" > /dev/null
log "Goals associes"

# --- Summary ---
echo ""
info "=== Verification ==="
FINAL=$(api GET "/api/companies/$COMPANY_ID/agents")
COUNT=$(echo "$FINAL" | jq 'if type == "array" then length elif .data then (.data | length) else 0 end' 2>/dev/null || echo "0")

echo "$FINAL" | jq -r '
    (if type == "array" then . elif .data then .data else [] end)
    | .[] | "\(.name)\t\(.role)\t\(.adapterConfig.model // "?")\t\(.status)"
' 2>/dev/null | column -t -s $'\t'

echo ""
echo "========================================"
echo -e "  ${GREEN}BOOTSTRAP TERMINE — $COUNT agents${NC}"
echo "========================================"
echo "  Company: $COMPANY_ID"
echo ""

rm -f /tmp/pc-boot.txt
