#!/bin/bash
# ============================================================
# CREATE AGENTS — Nouvelle stack Claude API
# Crée les 16 agents dans Paperclip avec modèles Claude
# ============================================================
# Usage : ./create-agents.sh
# Prérequis : bootstrap-paperclip.sh déjà exécuté
# ============================================================

set -euo pipefail

PAPERCLIP_URL="http://localhost:3100"
ADMIN_EMAIL="${PAPERCLIP_ADMIN_EMAIL:-admin@paperclip.local}"
ADMIN_PASSWORD="${PAPERCLIP_ADMIN_PASSWORD:-paperclip-admin}"

# ── Modèles Claude (optimisation coûts) ──────────────────────
# Opus  : CEO, CTO uniquement (raisonnement stratégique profond)
# Sonnet: Code, coordination, analyse (Lead*, DevOps, CFO, Researcher, Data)
# Haiku : Exécution structurée (CPO, Security, QA, Designer, SEO, Content, Sales, Growth)
OPUS="claude-opus-4-6"
SONNET="claude-sonnet-4-6"
HAIKU="claude-haiku-4-5-20251001"

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
    -c /tmp/pc-create.txt \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" > /dev/null \
    || fail "Login échoué — Paperclip démarré ? ($PAPERCLIP_URL)"

api() {
    local method="$1" path="$2" data="${3:-}"
    if [ -n "$data" ]; then
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b /tmp/pc-create.txt -d "$data" 2>/dev/null || echo "{}"
    else
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b /tmp/pc-create.txt 2>/dev/null || echo "{}"
    fi
}

# Récupérer company ID
COMPANIES=$(api GET "/api/companies")
COMPANY_ID=$(echo "$COMPANIES" | jq -r '.[0].id // empty')
[ -z "$COMPANY_ID" ] && fail "Aucune company trouvée dans Paperclip"
log "Company: $COMPANY_ID"

# Récupérer agents existants
AGENTS_JSON=$(api GET "/api/companies/$COMPANY_ID/agents")
CEO_ID=$(echo "$AGENTS_JSON" | jq -r '.[] | select(.role == "ceo") | .id // empty')
[ -z "$CEO_ID" ] && fail "Agent CEO introuvable — bootstrap-paperclip.sh exécuté ?"
log "CEO ID: $CEO_ID"

# ── Configs adapterConfig par tier (optimisation coûts) ───────
# Tier 1 — Opus : effort=high, 20 turns max, 5 min timeout + bootstrap court
adapter_opus() {
    local mem0_uid="$1"
    local role_label="$2"
    jq -n --arg uid "$mem0_uid" --arg bootstrap "Tu es $role_label. Checkout ta tâche ({{taskId}}), agis selon ton rôle. Tes skills sont disponibles." '{
        model: "claude-opus-4-6",
        effort: "high",
        mem0UserId: $uid,
        bootstrapPromptTemplate: $bootstrap,
        graceSec: 15,
        timeoutSec: 300,
        maxTurnsPerRun: 20,
        instructionsBundleMode: "managed",
        dangerouslySkipPermissions: true
    }'
}

# Tier 2 — Sonnet code : effort=medium, 60 turns, 15 min + git worktree
adapter_sonnet_code() {
    local mem0_uid="$1"
    jq -n --arg uid "$mem0_uid" '{
        model: "claude-sonnet-4-6",
        effort: "medium",
        mem0UserId: $uid,
        bootstrapPromptTemplate: "Tu es un ingénieur senior. Checkout ta tâche, implémente le changement demandé via tes skills Gitea.",
        graceSec: 15,
        timeoutSec: 900,
        maxTurnsPerRun: 60,
        instructionsBundleMode: "managed",
        dangerouslySkipPermissions: true
    }'
}

# Tier 2 — Sonnet analyse : effort=medium, 30 turns, 10 min
adapter_sonnet_analysis() {
    local mem0_uid="$1"
    jq -n --arg uid "$mem0_uid" '{
        model: "claude-sonnet-4-6",
        effort: "medium",
        mem0UserId: $uid,
        bootstrapPromptTemplate: "Lis ta tâche et produis l'\''analyse ou le rapport demandé. Utilise Mem0 pour le contexte.",
        graceSec: 15,
        timeoutSec: 600,
        maxTurnsPerRun: 30,
        instructionsBundleMode: "managed",
        dangerouslySkipPermissions: true
    }'
}

# Tier 3 — Haiku : effort=low, 15 turns, 5 min
adapter_haiku() {
    local mem0_uid="$1"
    jq -n --arg uid "$mem0_uid" '{
        model: "claude-haiku-4-5-20251001",
        effort: "low",
        mem0UserId: $uid,
        bootstrapPromptTemplate: "Lis ta tâche et produis l'\''output structuré demandé.",
        graceSec: 10,
        timeoutSec: 300,
        maxTurnsPerRun: 15,
        instructionsBundleMode: "managed",
        dangerouslySkipPermissions: true
    }'
}

# Runtime config : heartbeat désactivé par défaut (wakeOnDemand seulement)
runtime_no_heartbeat() {
    echo '{"heartbeat":{"enabled":false,"wakeOnDemand":true,"maxConcurrentRuns":1}}'
}

# Runtime config : heartbeat activé avec session compaction (CEO=1h, CTO=2h)
runtime_heartbeat() {
    local interval_sec="$1"
    jq -n --argjson interval "$interval_sec" '{
        "heartbeat": {
            "enabled": true,
            "intervalSec": $interval,
            "cooldownSec": 30,
            "wakeOnDemand": true,
            "maxConcurrentRuns": 1,
            "sessionCompaction": {
                "enabled": true,
                "maxSessionRuns": 5,
                "maxRawInputTokens": 300000,
                "maxSessionAgeHours": 12
            }
        }
    }'
}

# ── Créer ou mettre à jour un agent ──────────────────────────
upsert_agent() {
    local name="$1"
    local role="$2"
    local title="$3"
    local capabilities="$4"
    local adapter_config="$5"
    local budget_cents="$6"
    local runtime_config="${7:-$(runtime_no_heartbeat)}"
    local icon="${8:-user}"

    # Vérifier si l'agent existe déjà
    local existing_id
    existing_id=$(echo "$AGENTS_JSON" | jq -r ".[] | select(.name == \"$name\") | .id // empty")

    if [ -n "$existing_id" ]; then
        local resp
        resp=$(api PATCH "/api/agents/$existing_id" \
            "$(jq -n \
                --arg name "$name" \
                --arg title "$title" \
                --arg capabilities "$capabilities" \
                --arg icon "$icon" \
                --argjson adapterConfig "$adapter_config" \
                --argjson runtimeConfig "$runtime_config" \
                --argjson budget "$budget_cents" \
                '{
                    name: $name,
                    title: $title,
                    capabilities: $capabilities,
                    icon: $icon,
                    adapterType: "claude_local",
                    adapterConfig: $adapterConfig,
                    runtimeConfig: $runtimeConfig,
                    budgetMonthlyCents: $budget
                }')")
        echo "$resp" | jq -e '.id' > /dev/null 2>&1 \
            && log "Updated $name ($(echo "$adapter_config" | jq -r '.model' | sed 's/claude-//'), effort=$(echo "$adapter_config" | jq -r '.effort // "default"'), maxTurns=$(echo "$adapter_config" | jq -r '.maxTurnsPerRun'))" \
            || warn "Update $name failed: $resp"
    else
        local resp
        resp=$(api POST "/api/companies/$COMPANY_ID/agents" \
            "$(jq -n \
                --arg name "$name" \
                --arg role "$role" \
                --arg title "$title" \
                --arg capabilities "$capabilities" \
                --arg icon "$icon" \
                --arg reportsTo "$CEO_ID" \
                --argjson adapterConfig "$adapter_config" \
                --argjson runtimeConfig "$runtime_config" \
                --argjson budget "$budget_cents" \
                '{
                    name: $name,
                    role: $role,
                    title: $title,
                    capabilities: $capabilities,
                    icon: $icon,
                    reportsTo: $reportsTo,
                    adapterType: "claude_local",
                    adapterConfig: $adapterConfig,
                    runtimeConfig: $runtimeConfig,
                    budgetMonthlyCents: $budget
                }')")
        echo "$resp" | jq -e '.id' > /dev/null 2>&1 \
            && log "Created $name ($(echo "$adapter_config" | jq -r '.model' | sed 's/claude-//'), effort=$(echo "$adapter_config" | jq -r '.effort // "default"'), budget=$(echo "$budget_cents")¢/mois)" \
            || warn "Create $name failed: $resp"
    fi
}

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  CREATE AGENTS — 16 agents Claude API    ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── T1 : Opus — CEO & CTO (heartbeat activé) ─────────────────
info "── T1 Opus (effort=high, maxTurns=20-30) ──"

upsert_agent "CEO" "ceo" "Chief Executive Officer" \
    "Sets strategy, recruits agents, delegates all work, resolves conflicts. Never codes." \
    "$(adapter_opus ceo "CEO — Chief Executive Officer")" 5000 "$(runtime_heartbeat 3600)" "crown"

CTO_ID=$(echo "$AGENTS_JSON" | jq -r '.[] | select(.role == "cto") | .id // empty')
upsert_agent "CTO" "cto" "Chief Technology Officer" \
    "Owns all technical decisions, architecture, code standards, and agent technical onboarding." \
    "$(adapter_opus cto "CTO — Chief Technology Officer")" 5000 "$(runtime_heartbeat 7200)" "terminal"

# ── T2 : Sonnet code — Lead Backend, Lead Frontend ───────────
info "── T2a Sonnet code (effort=medium, maxTurns=60) ──"

upsert_agent "Lead Backend" "engineer" "Lead Backend Engineer" \
    "Owns all backend code: API, database, server logic, performance, security. Reviews PRs, resolves bugs, implements features." \
    "$(adapter_sonnet_code lead-backend)" 3000 "$(runtime_no_heartbeat)" "code"

upsert_agent "Lead Frontend" "engineer" "Lead Frontend Engineer" \
    "Owns all frontend code: React/Vue components, CSS, UX implementation, web performance, accessibility." \
    "$(adapter_sonnet_code lead-frontend)" 3000 "$(runtime_no_heartbeat)" "puzzle"

# ── T2 : Sonnet analyse — DevOps, CFO, Researcher, Data ──────
info "── T2b Sonnet analyse (effort=medium, maxTurns=30) ──"

upsert_agent "DevOps" "devops" "DevOps Engineer" \
    "Owns infrastructure: Docker, CI/CD, deployments, monitoring, backups, server configuration, security hardening." \
    "$(adapter_sonnet_analysis devops)" 2000 "$(runtime_no_heartbeat)" "database"

upsert_agent "CFO" "cfo" "Chief Financial Officer" \
    "Owns financial analysis: cost models, budget tracking, unit economics, pricing strategy, financial forecasting." \
    "$(adapter_sonnet_analysis cfo)" 2000 "$(runtime_no_heartbeat)" "zap"

upsert_agent "Researcher" "researcher" "Research Analyst" \
    "Performs deep research: competitive analysis, technical literature, market trends, synthesis and structured reporting." \
    "$(adapter_sonnet_analysis researcher)" 2000 "$(runtime_no_heartbeat)" "search"

upsert_agent "Data Analyst" "researcher" "Data Analyst" \
    "Analyzes data: metrics interpretation, statistical models, dashboards, KPI tracking, data pipeline oversight." \
    "$(adapter_sonnet_analysis data-analyst)" 2000 "$(runtime_no_heartbeat)" "target"

# ── T3 : Haiku — Exécution & Tâches structurées ──────────────
info "── T3 Haiku (effort=low, maxTurns=15, budget=5€) ──"

upsert_agent "CPO" "pm" "Chief Product Officer" \
    "Owns product vision: PRDs, roadmap, backlog prioritization, user stories, feature specs, product strategy." \
    "$(adapter_haiku cpo)" 500 "$(runtime_no_heartbeat)" "package"

upsert_agent "CMO" "cmo" "Chief Marketing Officer" \
    "Owns marketing strategy: campaigns, brand positioning, growth marketing, content calendar, performance metrics." \
    "$(adapter_haiku cmo)" 500 "$(runtime_no_heartbeat)" "message-square"

upsert_agent "Growth Lead" "cmo" "Growth Lead" \
    "Owns growth strategy: acquisition funnels, conversion optimization, A/B testing, retention, referral programs." \
    "$(adapter_haiku growth-lead)" 500 "$(runtime_no_heartbeat)" "rocket"

upsert_agent "Security" "devops" "Security Engineer" \
    "Performs security audits: vulnerability scanning, dependency review, OWASP compliance, incident response checklists." \
    "$(adapter_haiku security)" 500 "$(runtime_no_heartbeat)" "shield"

upsert_agent "QA" "qa" "QA Engineer" \
    "Owns quality assurance: test plans, bug reports, regression testing, test automation specs, release sign-offs." \
    "$(adapter_haiku qa)" 500 "$(runtime_no_heartbeat)" "bug"

upsert_agent "Designer" "designer" "UI/UX Designer" \
    "Creates design specs: wireframes, component guidelines, design system tokens, UX flows, accessibility standards." \
    "$(adapter_haiku designer)" 500 "$(runtime_no_heartbeat)" "wand"

upsert_agent "SEO" "general" "SEO Specialist" \
    "Optimizes search: keyword research, on-page recommendations, technical SEO audits, backlink strategy, content briefs." \
    "$(adapter_haiku seo)" 500 "$(runtime_no_heartbeat)" "globe"

upsert_agent "Content Writer" "general" "Content Writer" \
    "Produces content: blog articles, landing pages, email sequences, social copy, product descriptions." \
    "$(adapter_haiku content-writer)" 500 "$(runtime_no_heartbeat)" "sparkles"

upsert_agent "Sales" "general" "Sales Representative" \
    "Manages sales: CRM pipeline, prospect outreach, email sequences, objection handling, deal tracking." \
    "$(adapter_haiku sales)" 500 "$(runtime_no_heartbeat)" "gem"

upsert_agent "Scraper" "researcher" "Web Scraper" \
    "Executes web scraping missions: Firecrawl (public pages, crawl, extract), Playwright (authenticated sites). Reports results to Mem0 + SiYuan." \
    "$(adapter_haiku scraper)" 500 "$(runtime_no_heartbeat)" "globe"

echo ""
log "Création terminée — 17 agents configurés"
echo ""
echo "Récap optimisation coûts :"
echo "  T1 Opus   (effort=high,   maxTurns=20-30, heartbeat 1-2h) → CEO, CTO              budget: 50€/mois chacun"
echo "  T2 Sonnet (effort=medium, maxTurns=30-60, wakeOnDemand)   → Lead*, DevOps, CFO... budget: 20-30€/mois"
echo "  T3 Haiku  (effort=low,    maxTurns=15,    wakeOnDemand)   → 9 agents exec+Scraper  budget: 5€/mois chacun"
echo ""
echo "  Budget total max : ~290€/mois | Réel estimé : ~45€/mois (10-30% utilisation)"
echo ""
echo "  Étapes suivantes :"
echo "  1. ./inject-skills.sh   (skills mem0/siyuan/gitea/crm/dokploy/firecrawl/playwright)"
echo "  2. ./inject-agents.sh   (prompts depuis agents-playbook/)"
