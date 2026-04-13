#!/bin/bash
# ============================================================
# SETUP ACCOUNTS — Nouvelle stack
# Crée les comptes admin pour tous les services
# ============================================================
# Usage : ./setup-accounts.sh
# Prérequis : stack démarrée (docker compose up -d)
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
info() { echo -e "${BLUE}[>>]${NC} $1"; }
fail() { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }

# ── Charger les variables d'env ───────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a; source "$SCRIPT_DIR/.env"; set +a
fi

ADMIN_EMAIL="${PAPERCLIP_ADMIN_EMAIL:-admin@paperclip.local}"
ADMIN_USER="${POSTGRES_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${PAPERCLIP_ADMIN_PASSWORD:-paperclip-admin}"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  SETUP ACCOUNTS — Tous les services      ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 1. GITEA ──────────────────────────────────────────────────
info "1/6 Gitea — création compte admin..."

# Attendre que Gitea soit prêt
for i in $(seq 1 30); do
    if curl -sf http://localhost:3000/api/v1/version > /dev/null 2>&1; then
        break
    fi
    [ "$i" -eq 30 ] && fail "Gitea non accessible après 30s"
    sleep 1
done

# Créer admin via gitea CLI dans le container
GITEA_ADMIN_RESULT=$(docker exec gitea gitea admin user create \
    --username "${GITEA_ADMIN_USERNAME:-admin}" \
    --password "$ADMIN_PASSWORD" \
    --email "$ADMIN_EMAIL" \
    --admin \
    --must-change-password=false 2>&1 || true)

if echo "$GITEA_ADMIN_RESULT" | grep -q "user already exists\|successfully\|created"; then
    log "Gitea admin: ${GITEA_ADMIN_USERNAME:-admin} / $ADMIN_PASSWORD → http://localhost:3000"
else
    warn "Gitea: $GITEA_ADMIN_RESULT"
fi

# Créer token API Gitea pour n8n/webhooks
GITEA_TOKEN=$(curl -sf -X POST "http://localhost:3000/api/v1/users/${GITEA_ADMIN_USERNAME:-admin}/tokens" \
    -H "Content-Type: application/json" \
    -u "${GITEA_ADMIN_USERNAME:-admin}:$ADMIN_PASSWORD" \
    -d '{"name":"stack-automation","scopes":["write:repository","write:issue","write:notification","read:user"]}' \
    2>/dev/null | jq -r '.sha1 // empty' || true)

if [ -n "$GITEA_TOKEN" ]; then
    log "Gitea API token créé: $GITEA_TOKEN"
    echo "  → Ajouter dans .env : GITEA_API_TOKEN=$GITEA_TOKEN"
else
    warn "Gitea: token déjà existant ou erreur (ignorer si premier run)"
fi

# ── 2. N8N ────────────────────────────────────────────────────
info "2/6 n8n — vérification accès..."

for i in $(seq 1 30); do
    if curl -sf http://localhost:5678/healthz > /dev/null 2>&1; then
        break
    fi
    [ "$i" -eq 30 ] && { warn "n8n non accessible — skip"; break; }
    sleep 1
done

if curl -sf http://localhost:5678/healthz > /dev/null 2>&1; then
    log "n8n accessible → http://localhost:5678 (setup via browser au 1er démarrage)"
    echo "  → Créer le compte via l'interface web (email + password)"
fi

# ── 3. TWENTY CRM ─────────────────────────────────────────────
info "3/6 Twenty CRM — initialisation DB..."

# Twenty exécute ses migrations automatiquement au démarrage
for i in $(seq 1 30); do
    if curl -sf http://localhost:3003/api/health > /dev/null 2>&1; then
        break
    fi
    [ "$i" -eq 30 ] && { warn "Twenty CRM non accessible — skip"; break; }
    sleep 1
done

if curl -sf http://localhost:3003/api/health > /dev/null 2>&1; then
    # Créer l'admin via script Twenty
    TWENTY_RESULT=$(docker exec twenty-server yarn workspace twenty-server command:prod workspace:create \
        --email "$ADMIN_EMAIL" \
        --password "$ADMIN_PASSWORD" \
        --name "Stack Pirates" 2>&1 || true)
    if echo "$TWENTY_RESULT" | grep -qi "created\|already\|exist\|success"; then
        log "Twenty CRM admin: $ADMIN_EMAIL → http://localhost:3003"
    else
        warn "Twenty: setup via browser → http://localhost:3003"
        echo "  Email: $ADMIN_EMAIL / Password: $ADMIN_PASSWORD"
    fi
fi

# ── 4. UPTIME KUMA ────────────────────────────────────────────
info "4/6 Uptime Kuma — configuration initiale..."

for i in $(seq 1 15); do
    if curl -sf http://localhost:3001 > /dev/null 2>&1; then
        break
    fi
    [ "$i" -eq 15 ] && { warn "Uptime Kuma non accessible — skip"; break; }
    sleep 1
done

if curl -sf http://localhost:3001 > /dev/null 2>&1; then
    # Créer admin via API socket.io (setup automatique)
    KUMA_SETUP=$(curl -sf -X POST "http://localhost:3001/api/setup" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"admin\",\"password\":\"$ADMIN_PASSWORD\"}" \
        2>/dev/null || true)
    if echo "$KUMA_SETUP" | grep -qi "ok\|success\|already"; then
        log "Uptime Kuma admin: admin / $ADMIN_PASSWORD → http://localhost:3001"
    else
        warn "Uptime Kuma: setup via browser → http://localhost:3001"
        echo "  Username: admin / Password: $ADMIN_PASSWORD"
    fi
fi

# ── 5. PAPERCLIP ─────────────────────────────────────────────
info "5/6 Paperclip — vérification..."

if curl -sf http://localhost:3100/api/auth/session \
    -H "Content-Type: application/json" > /dev/null 2>&1; then
    log "Paperclip → http://localhost:3100"
    echo "  Email: $ADMIN_EMAIL / Password: $ADMIN_PASSWORD"
    echo "  → Exécuter ./bootstrap-paperclip.sh si pas encore fait"
fi

# ── 6. HOMARR ────────────────────────────────────────────────
info "6/6 Homarr — ajout tiles..."

for i in $(seq 1 15); do
    if curl -sf http://localhost:7575 > /dev/null 2>&1; then
        break
    fi
    [ "$i" -eq 15 ] && { warn "Homarr non accessible — skip"; break; }
    sleep 1
done

if curl -sf http://localhost:7575 > /dev/null 2>&1; then
    log "Homarr → http://localhost:7575 (configuration via interface graphique)"
    echo "  → Ajouter les tiles manuellement pour chaque service"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  RÉCAP ACCÈS                                             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
printf "  %-20s %-35s %s\n" "Service" "URL" "Accès"
printf "  %-20s %-35s %s\n" "-------" "---" "-----"
printf "  %-20s %-35s %s\n" "Paperclip (agents)" "http://localhost:3100" "$ADMIN_EMAIL"
printf "  %-20s %-35s %s\n" "n8n (automation)" "http://localhost:5678" "setup browser"
printf "  %-20s %-35s %s\n" "Gitea (git)" "http://localhost:3000" "${GITEA_ADMIN_USERNAME:-admin}"
printf "  %-20s %-35s %s\n" "Twenty CRM" "http://localhost:3003" "$ADMIN_EMAIL"
printf "  %-20s %-35s %s\n" "Uptime Kuma" "http://localhost:3001" "admin"
printf "  %-20s %-35s %s\n" "Homarr (dashboard)" "http://localhost:7575" "no auth"
printf "  %-20s %-35s %s\n" "SiYuan (notes)" "http://localhost:6806" "token"
printf "  %-20s %-35s %s\n" "Chroma (vectors)" "http://localhost:8000" "no auth"
printf "  %-20s %-35s %s\n" "Mem0 (memory)" "http://localhost:8050" "no auth"
printf "  %-20s %-35s %s\n" "ntfy (notifs)" "http://localhost:8085" "no auth"
printf "  %-20s %-35s %s\n" "Duplicati (backup)" "http://localhost:8200" "no auth"
echo ""
echo "  Mot de passe: $ADMIN_PASSWORD"
echo ""
echo "  Étapes suivantes :"
echo "  1. ./create-agents.sh     (créer les 16 agents Paperclip)"
echo "  2. ./inject-agents.sh     (injecter les prompts)"
echo "  3. Configurer n8n manuellement (browser setup)"
echo "  4. Ajouter GITEA_API_TOKEN dans .env si généré"
