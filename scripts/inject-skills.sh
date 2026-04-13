#!/bin/bash
# ============================================================
# INJECT SKILLS — Nouvelle stack Claude API
# Crée les company skills + les assigne aux agents
# ============================================================
# Usage : ./inject-skills.sh
# Prérequis : create-agents.sh déjà exécuté
# ============================================================

set -euo pipefail

PAPERCLIP_URL="http://localhost:3100"
ADMIN_EMAIL="${PAPERCLIP_ADMIN_EMAIL:-admin@paperclip.local}"
ADMIN_PASSWORD="${PAPERCLIP_ADMIN_PASSWORD:-paperclip-admin}"
SKILLS_DIR="$(cd "$(dirname "$0")/skills" && pwd)"
COMPANY_ID="858f703f-5eed-45fb-9794-37ddf1bd1d38"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
info() { echo -e "${BLUE}[>>]${NC} $1"; }
fail() { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }

command -v jq &>/dev/null || fail "jq requis"

info "Connexion à Paperclip..."
curl -sf -X POST "$PAPERCLIP_URL/api/auth/sign-in/email" \
    -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
    -c /tmp/pc-skills.txt \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" > /dev/null \
    || fail "Login échoué"

api() {
    local method="$1" path="$2" data="${3:-}"
    if [ -n "$data" ]; then
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b /tmp/pc-skills.txt -d "$data" 2>/dev/null || echo "{}"
    else
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b /tmp/pc-skills.txt 2>/dev/null || echo "{}"
    fi
}

# ── Créer ou mettre à jour un skill ───────────────────────────
create_skill() {
    local slug="$1"
    local name="$2"
    local desc="$3"
    local file="$4"

    [ -f "$SKILLS_DIR/$file" ] || { warn "Fichier skill manquant: $file"; return; }
    local markdown
    markdown=$(cat "$SKILLS_DIR/$file")

    # Vérifier si le skill existe déjà
    local existing
    existing=$(api GET "/api/companies/$COMPANY_ID/skills" | jq -r ".[] | select(.slug == \"$slug\") | .id // empty")

    if [ -n "$existing" ]; then
        # Mettre à jour le fichier SKILL.md
        api PATCH "/api/companies/$COMPANY_ID/skills/$existing/files" \
            "$(jq -n --arg content "$markdown" '{"path":"SKILL.md","content":$content}')" > /dev/null
        log "Updated skill: $name ($slug)"
    else
        # Créer le skill
        local resp
        resp=$(api POST "/api/companies/$COMPANY_ID/skills" \
            "$(jq -n \
                --arg slug "$slug" \
                --arg name "$name" \
                --arg desc "$desc" \
                --arg md "$markdown" \
                '{"slug":$slug,"name":$name,"description":$desc,"markdown":$md}')")
        if echo "$resp" | jq -e '.id' > /dev/null 2>&1; then
            log "Created skill: $name ($slug)"
        else
            warn "Skill create failed: $name — $resp"
        fi
    fi
}

# ── Assigner des skills à un agent ────────────────────────────
assign_skills() {
    local agent_name="$1"
    shift
    local skills=("$@")

    local agents_json
    agents_json=$(api GET "/api/companies/$COMPANY_ID/agents")
    local agent_id
    agent_id=$(echo "$agents_json" | jq -r ".[] | select(.name == \"$agent_name\") | .id // empty")

    if [ -z "$agent_id" ]; then
        warn "Agent '$agent_name' non trouvé — skip"
        return
    fi

    local desired_json
    desired_json=$(printf '%s\n' "${skills[@]}" | jq -R . | jq -s .)

    local resp
    resp=$(api POST "/api/agents/$agent_id/skills/sync" \
        "{\"desiredSkills\": $desired_json}")
    if echo "$resp" | jq -e '.desiredSkills' > /dev/null 2>&1; then
        log "$agent_name → skills: ${skills[*]}"
    else
        warn "$agent_name skills sync failed: $resp"
    fi
}

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  INJECT SKILLS — Stack Claude API        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Étape 1 : Créer les company skills ───────────────────────
info "Étape 1 : Création des company skills..."

create_skill "mem0"       "Mem0 — Mémoire agents"          "API mémoire persistante (lecture/écriture)"          "mem0.md"
create_skill "siyuan"     "SiYuan — Knowledge base"         "API base de connaissance structurée"                 "siyuan.md"
create_skill "gitea"      "Gitea — Code repos"              "API git (lecture/écriture fichiers, PR, issues)"     "gitea.md"
create_skill "twenty-crm" "Twenty CRM"                      "API CRM GraphQL (contacts, deals, companies)"        "twenty-crm.md"
create_skill "n8n-notify" "n8n — Notifications & webhooks"  "Webhooks n8n (notify, scrape, deploy, crm-sync)"     "n8n-notify.md"
create_skill "dokploy"    "Dokploy — Déploiement"           "API Dokploy (deploy, restart, status)"               "dokploy.md"
create_skill "playwright"       "Playwright — Scraping web"        "Scripts scraping (public + authentifié), extraction données" "playwright.md"
create_skill "project-context" "Contexte Projet"                  "Stack, variables d'env, règles, architecture agents"         "project-context.md"
create_skill "website-cloner" "Website Cloner"                    "Reproduire un site web en Next.js 16 via Claude Code skills"  "website-cloner.md"

echo ""

# ── Étape 2 : Assigner les skills par agent ───────────────────
info "Étape 2 : Assignation des skills par agent..."

# C-levels : mémoire + knowledge + notifications
assign_skills "CEO"          "project-context" "mem0" "siyuan" "n8n-notify"
assign_skills "CTO"          "project-context" "mem0" "siyuan" "n8n-notify" "gitea"
assign_skills "CPO"          "project-context" "mem0" "siyuan" "n8n-notify"
assign_skills "CFO"          "project-context" "mem0" "siyuan" "n8n-notify" "twenty-crm"

# Agents techniques : +gitea (+dokploy pour devops)
assign_skills "Lead Backend"  "project-context" "mem0" "siyuan" "n8n-notify" "gitea"
assign_skills "Lead Frontend" "project-context" "mem0" "siyuan" "n8n-notify" "gitea" "website-cloner"
assign_skills "DevOps"        "project-context" "mem0" "siyuan" "n8n-notify" "gitea" "dokploy"
assign_skills "Security"      "project-context" "mem0" "siyuan" "n8n-notify" "gitea"
assign_skills "QA"            "project-context" "mem0" "siyuan" "n8n-notify" "gitea"

# Agents recherche/data
assign_skills "Researcher"    "project-context" "mem0" "siyuan" "n8n-notify"
assign_skills "Data Analyst"  "project-context" "mem0" "siyuan" "n8n-notify"
assign_skills "Designer"      "project-context" "mem0" "siyuan" "n8n-notify" "website-cloner"

# Scraper : accès Playwright
assign_skills "Scraper"       "project-context" "mem0" "siyuan" "n8n-notify" "playwright"

# Agents business/growth : +CRM
assign_skills "SEO"           "project-context" "mem0" "siyuan" "n8n-notify"
assign_skills "Content Writer" "project-context" "mem0" "siyuan" "n8n-notify"
assign_skills "Sales"         "project-context" "mem0" "siyuan" "n8n-notify" "twenty-crm"
assign_skills "Growth Lead"   "project-context" "mem0" "siyuan" "n8n-notify" "twenty-crm"
assign_skills "CMO"           "project-context" "mem0" "siyuan" "n8n-notify" "twenty-crm"

echo ""
log "Injection skills terminée"
echo ""
echo "Récap skills par catégorie :"
echo "  Tous les agents    → mem0, siyuan, n8n-notify"
echo "  Agents techniques  → +gitea"
echo "  DevOps             → +gitea, +dokploy"
echo "  Business/Sales/CFO → +twenty-crm"
echo "  Scraping           → playwright (Scraper)"
echo ""
echo "  Étape suivante → ./inject-agents.sh (prompts playbook)"
