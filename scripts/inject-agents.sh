#!/bin/bash
# ============================================================
# INJECT AGENTS — Nouvelle stack Claude API
# Injecte prompts + assigne les modèles Claude par agent
# ============================================================
# Usage : ./inject-agents.sh
# Prérequis : stack démarrée (./setup.sh), Paperclip accessible
# ============================================================

set -euo pipefail

PAPERCLIP_URL="http://localhost:3100"
SIYUAN_URL="http://siyuan:6806"
ADMIN_EMAIL="${PAPERCLIP_ADMIN_EMAIL:-admin@paperclip.local}"
ADMIN_PASSWORD="${PAPERCLIP_ADMIN_PASSWORD:-paperclip-admin}"
PLAYBOOK_DIR="$(cd "$(dirname "$0")/agents-playbook" && pwd)"

# ── Modèles Claude ────────────────────────────────────────────
OPUS="claude-opus-4-6"          # Stratégie & raisonnement profond
SONNET="claude-sonnet-4-6"      # Code, coordination, analyse
HAIKU="claude-haiku-4-5-20251001" # Exécution, tâches structurées

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
info() { echo -e "${BLUE}[>>]${NC} $1"; }
fail() { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }

command -v jq &>/dev/null || fail "jq requis (brew install jq)"
command -v curl &>/dev/null || fail "curl requis"

info "Connexion à Paperclip..."
curl -sf -X POST "$PAPERCLIP_URL/api/auth/sign-in/email" \
    -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
    -c /tmp/pc-inject.txt \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" > /dev/null \
    || fail "Login échoué — Paperclip démarré ? (http://localhost:3100)"

api() {
    local method="$1" path="$2" data="${3:-}"
    if [ -n "$data" ]; then
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b /tmp/pc-inject.txt -d "$data" 2>/dev/null || echo "{}"
    else
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b /tmp/pc-inject.txt 2>/dev/null || echo "{}"
    fi
}

COMPANIES=$(api GET "/api/companies")
COMPANY_ID=$(echo "$COMPANIES" | jq -r '.[0].id // empty')
[ -z "$COMPANY_ID" ] && fail "Aucune company trouvée dans Paperclip"

AGENTS_JSON=$(api GET "/api/companies/$COMPANY_ID/agents")
AGENT_COUNT=$(echo "$AGENTS_JSON" | jq 'length')
log "Company: $COMPANY_ID — $AGENT_COUNT agents"

get_agent_id() { echo "$AGENTS_JSON" | jq -r ".[] | select(.name == \"$1\") | .id"; }

inject_agent() {
    local name="$1"
    local model="$2"
    local playbook_file="$3"
    local mem0_uid="$4"

    local agent_id
    agent_id=$(get_agent_id "$name")

    if [ -z "$agent_id" ]; then
        warn "$name: agent non trouvé dans Paperclip (créé ?)"
        return
    fi

    # Extraire le prompt template du playbook
    local prompt=""
    if [ -f "$PLAYBOOK_DIR/$playbook_file" ]; then
        prompt=$(awk '/^## Prompt Template$/,/^---$/' "$PLAYBOOK_DIR/$playbook_file" \
            | grep -v "^## Prompt Template$" | grep -v "^---$" | head -200 || true)
        [ -z "$prompt" ] && prompt=$(cat "$PLAYBOOK_DIR/$playbook_file")
    fi
    local prompt_len=${#prompt}

    local update_json
    update_json=$(jq -n \
        --arg model "$model" \
        --arg uid "$mem0_uid" \
        --arg prompt "$prompt" \
        '{
            model: $model,
            adapterConfig: {
                promptTemplate: $prompt,
                mem0UserId: $uid
            }
        }')

    local resp
    resp=$(api PATCH "/api/agents/$agent_id" "$update_json")

    if echo "$resp" | jq -e '.id' > /dev/null 2>&1; then
        log "$name → model=$model mem0=$mem0_uid ($prompt_len chars)"
    else
        warn "$name: injection partielle — $resp"
    fi
}

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  INJECTION AGENTS — CLAUDE API           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── OPUS 4.6 — Stratégie & Raisonnement ──────────────────────
info "── Opus 4.6 (stratégie) ──"
inject_agent "CEO"          "$OPUS"   "01-ceo.md"         "ceo"
inject_agent "CTO"          "$OPUS"   "02-cto.md"         "cto"

# ── SONNET 4.6 — Code, Coordination & Analyse ────────────────
info "── Sonnet 4.6 (code + coordination) ──"
inject_agent "Growth Lead"   "$SONNET" "29-growth-lead.md"   "growth-lead"
inject_agent "Lead Backend"  "$SONNET" "05-lead-backend.md"  "lead-backend"
inject_agent "Lead Frontend" "$SONNET" "06-lead-frontend.md" "lead-frontend"
inject_agent "DevOps"        "$SONNET" "07-devops.md"        "devops"
inject_agent "CFO"           "$SONNET" "04-cfo.md"           "cfo"
inject_agent "Researcher"    "$SONNET" "11-researcher.md"    "researcher"
inject_agent "Data Analyst"  "$SONNET" "27-data-analyst.md"  "data-analyst"

# ── HAIKU 4.5 — Exécution & Tâches structurées ───────────────
info "── Haiku 4.5 (exécution) ──"
inject_agent "CPO"            "$HAIKU" "03-cpo.md"            "cpo"
inject_agent "Security"       "$HAIKU" "08-security.md"       "security"
inject_agent "QA"             "$HAIKU" "09-qa.md"             "qa"
inject_agent "Designer"       "$HAIKU" "10-designer.md"       "designer"
inject_agent "SEO"            "$HAIKU" "25-seo.md"            "seo"
inject_agent "Content Writer" "$HAIKU" "26-content-writer.md" "content-writer"
inject_agent "Sales"          "$HAIKU" "28-sales.md"          "sales"

echo ""
log "Injection terminée — 16 agents configurés"
echo ""
echo "Récap modèles :"
echo "  Opus 4.6    → CEO, CTO"
echo "  Sonnet 4.6  → Growth Lead, Lead Backend, Lead Frontend, DevOps, CFO, Researcher, Data Analyst"
echo "  Haiku 4.5   → CPO, Security, QA, Designer, SEO, Content Writer, Sales"
