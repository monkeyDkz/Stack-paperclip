#!/bin/bash
# ============================================================
# BOOTSTRAP PAPERCLIP — 100% non-interactif
# 1. onboard --yes  (config depuis env vars)
# 2. init-admin     (signup + promotion DB directement)
# ============================================================

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${BLUE}[>>]${NC} $1"; }
fail() { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }

docker ps --filter "name=paperclip" --filter "status=running" | grep -q paperclip \
  || fail "Container 'paperclip' non démarré — lance d'abord : docker compose up -d"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     BOOTSTRAP PAPERCLIP                  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Étape 1 : onboard --yes ───────────────────────────────────
info "Étape 1 : onboard (quickstart depuis env vars)..."

# Si la config existe déjà, on skip
if docker exec paperclip test -f /paperclip/instances/default/config.json 2>/dev/null; then
  log "Config déjà présente — skip onboard"
else
  echo "" | docker exec -i paperclip pnpm paperclipai onboard --yes 2>&1 \
    | grep -v "^$" | sed 's/^/  /' || true
  docker exec paperclip test -f /paperclip/instances/default/config.json \
    && log "Config créée" \
    || fail "onboard échoué"
fi

# ── Étape 2 : init-admin (signup API + promotion DB) ─────────
info "Étape 2 : création admin (sans browser)..."
docker cp "$(dirname "$0")/init-admin.sh" paperclip:/app/init-admin.sh
docker exec paperclip sh /app/init-admin.sh 2>&1 | sed 's/^/  /'

echo ""
log "Bootstrap terminé !"
echo ""
echo "  Paperclip → http://localhost:3100"
echo "  Email     : ${PAPERCLIP_ADMIN_EMAIL:-admin@paperclip.local}"
echo "  Password  : ${PAPERCLIP_ADMIN_PASSWORD:-paperclip-admin}"
echo ""
echo "  Étape suivante → ./inject-agents.sh"
