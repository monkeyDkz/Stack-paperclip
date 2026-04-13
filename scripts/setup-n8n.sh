#!/bin/bash
# ============================================================
# SETUP N8N — Credentials pour la stack
# ============================================================
# Usage : ./setup-n8n.sh
# Prérequis : n8n démarré, compte admin créé
# ============================================================

set -euo pipefail

N8N_URL="http://localhost:5678"
N8N_EMAIL="${N8N_ADMIN_EMAIL:-admin@stack.local}"
N8N_PASSWORD="${N8N_ADMIN_PASSWORD:-Stack2026!}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
info() { echo -e "${BLUE}[>>]${NC} $1"; }
fail() { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }

# Login
info "Connexion à n8n..."
LOGIN=$(curl -sf -X POST "$N8N_URL/rest/login" \
    -H "Content-Type: application/json" \
    -c /tmp/n8n-creds.txt \
    -d "{\"emailOrLdapLoginId\":\"$N8N_EMAIL\",\"password\":\"$N8N_PASSWORD\"}" 2>/dev/null) \
    || fail "Login n8n échoué ($N8N_URL)"

# Récupère le CSRF token si besoin
CSRF=$(echo "$LOGIN" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('token',''))" 2>/dev/null || true)

api_post() {
    local path="$1" data="$2"
    curl -sf -X POST "$N8N_URL$path" \
        -H "Content-Type: application/json" \
        -H "browser-id: setup-script" \
        -b /tmp/n8n-creds.txt \
        -d "$data" 2>/dev/null || echo "{}"
}

create_credential() {
    local name="$1" type="$2" data="$3"
    local resp
    resp=$(api_post "/rest/credentials" \
        "{\"name\":\"$name\",\"type\":\"$type\",\"data\":$data}")
    local id
    id=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || true)
    if [ -n "$id" ]; then
        log "Credential créé : $name (id=$id)"
    else
        warn "Credential $name : $(echo "$resp" | head -c 100)"
    fi
}

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  SETUP N8N — Credentials stack           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

info "── Création des credentials ──"

# Anthropic API
create_credential "Anthropic (Claude)" "anthropicApi" \
    "{\"apiKey\":\"${ANTHROPIC_API_KEY}\"}"

# Gitea API
create_credential "Gitea (stack-pirates)" "giteeApi" \
    "{\"accessToken\":\"${GITEA_API_TOKEN}\",\"server\":\"http://gitea:3000\"}"

# Paperclip webhook key (httpHeaderAuth)
create_credential "Paperclip Webhook Key" "httpHeaderAuth" \
    "{\"name\":\"X-Paperclip-Key\",\"value\":\"${N8N_AGENT_KEY}\"}"

# Mem0 (HTTP)
create_credential "Mem0 API" "httpBasicAuth" \
    "{\"user\":\"\",\"password\":\"\"}"

# SiYuan token (httpHeaderAuth)
create_credential "SiYuan Token" "httpHeaderAuth" \
    "{\"name\":\"Authorization\",\"value\":\"Token ${SIYUAN_API_TOKEN}\"}"

# ntfy (HTTP — pas d'auth par défaut)
create_credential "ntfy" "httpHeaderAuth" \
    "{\"name\":\"Content-Type\",\"value\":\"text/plain\"}"

# Twenty CRM — on récupère le token après setup Twenty
if [ -n "${TWENTY_API_TOKEN:-}" ]; then
    create_credential "Twenty CRM" "httpHeaderAuth" \
        "{\"name\":\"Authorization\",\"value\":\"Bearer ${TWENTY_API_TOKEN}\"}"
else
    warn "TWENTY_API_TOKEN non défini — credential Twenty CRM ignoré"
    warn "  → Créer le token dans Twenty (Settings > API) puis relancer"
fi

echo ""
log "Setup credentials terminé"
echo ""
echo "Récap :"
echo "  Anthropic, Gitea, Paperclip webhook, Mem0, SiYuan, ntfy"
echo ""
echo "Étape suivante : créer les workflows n8n"
echo "  WF-00 : Context Prefetch (Paperclip issue → Mem0 → Haiku → body enrichi)"
echo "  WF-01 : Notification ntfy (agent → push mobile)"
echo "  WF-02 : Deploy Dokploy (DevOps → déploiement)"
echo "  WF-03 : Scrape web → Markdown (firecrawl)"
echo "  WF-04 : CRM sync (Twenty GraphQL)"
