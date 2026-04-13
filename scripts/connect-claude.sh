#!/bin/bash
# ============================================================
# CONNECT CLAUDE — Injecte la session Claude Code dans Paperclip
# À lancer après "docker compose up -d"
# ============================================================
# Paperclip utilise "claude login" (subscription Max/Pro)
# au lieu de ANTHROPIC_API_KEY pour le billing.
# Ce script copie tes credentials Claude du Mac → volume Docker.
# ============================================================

set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${BLUE}→${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

COMPOSE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VOLUME_NAME="nouvelle-stack_claude_config"

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     CONNECT CLAUDE → PAPERCLIP (Docker)      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}\n"

# ── 1. Vérifier que Paperclip tourne ──────────────────────────
info "Vérification de Paperclip..."
if ! docker ps --format '{{.Names}}' | grep -q "^paperclip$"; then
  fail "Paperclip n'est pas démarré. Lance d'abord : cd $COMPOSE_DIR && docker compose up -d"
fi
ok "Paperclip est démarré"

# ── 2. Trouver les credentials Claude sur le Mac ───────────────
info "Recherche des credentials Claude..."

CLAUDE_DIR=""
if [ -f "$HOME/.claude.json" ]; then
  CLAUDE_DIR="$HOME"
  CLAUDE_FILE=".claude.json"
elif [ -f "$HOME/.config/claude/claude.json" ]; then
  CLAUDE_DIR="$HOME/.config/claude"
  CLAUDE_FILE="claude.json"
elif [ -d "$HOME/.config/claude" ]; then
  CLAUDE_DIR="$HOME/.config/claude"
else
  warn "Session Claude non trouvée. Lance d'abord : claude login"
  echo ""
  echo "  1. Installe Claude Code si pas déjà fait :"
  echo "     npm install -g @anthropic-ai/claude-code"
  echo ""
  echo "  2. Connecte-toi :"
  echo "     claude login"
  echo ""
  echo "  3. Relance ce script"
  exit 1
fi

ok "Credentials trouvés dans : $CLAUDE_DIR"

# ── 3. Copier dans le volume Docker ───────────────────────────
info "Injection dans le volume Docker ($VOLUME_NAME)..."

# Créer un container temporaire monté sur le volume
docker run --rm \
  -v "${CLAUDE_DIR}:/src:ro" \
  -v "${VOLUME_NAME}:/dest" \
  alpine sh -c "cp -r /src/. /dest/ && chmod -R 755 /dest"

ok "Credentials copiés dans le volume"

# ── 4. Redémarrer Paperclip pour prendre en compte ────────────
info "Redémarrage de Paperclip..."
cd "$COMPOSE_DIR"
docker compose restart paperclip
sleep 3

# ── 5. Vérifier que ça fonctionne ─────────────────────────────
info "Vérification de la connexion Claude..."
sleep 2
LOGS=$(docker logs paperclip --tail 20 2>&1)

if echo "$LOGS" | grep -qi "error\|failed\|claude.*auth"; then
  warn "Possible problème d'auth — vérifie les logs :"
  echo "$LOGS" | tail -10
else
  ok "Paperclip redémarré sans erreur"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           SESSION CLAUDE INJECTÉE ✓          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo "  Paperclip → http://localhost:3100"
echo "  Logs      → docker compose logs -f paperclip"
echo ""
echo "  Si les agents ont une erreur d'auth, relance :"
echo "    claude login  (pour rafraîchir le token)"
echo "    bash scripts/connect-claude.sh"
