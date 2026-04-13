#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     SETUP — NOUVELLE STACK               ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# 1. Clone Paperclip si pas déjà fait
if [ ! -d "paperclip-repo" ]; then
  echo "→ Clonage de Paperclip depuis GitHub..."
  git clone https://github.com/paperclipai/paperclip paperclip-repo
  echo "✅ Paperclip cloné"
else
  echo "→ Paperclip déjà cloné (paperclip-repo/)"
fi

# 2. Copier .env.example si pas de .env
if [ ! -f ".env" ]; then
  cp .env.example .env
  echo ""
  echo "⚠️  .env créé depuis .env.example"
  echo "   IMPORTANT : édite .env et remplis toutes les variables"
  echo "   En particulier : ANTHROPIC_API_KEY et tous les *_PASSWORD"
  echo ""
  echo "   Puis relance : ./setup.sh"
  exit 0
fi

# 3. Vérifier que la clé Anthropic est renseignée
if grep -q "sk-ant-api03-xxx" .env; then
  echo "❌ ANTHROPIC_API_KEY non configurée dans .env"
  echo "   Remplace sk-ant-api03-xxx par ta vraie clé API"
  exit 1
fi

echo ""
echo "→ Démarrage de la stack..."
docker compose up -d --build

echo ""
echo "✅ Stack démarrée !"
echo ""
echo "Services disponibles :"
echo "  Homarr (dashboard)  → http://localhost:7575"
echo "  Paperclip (agents)  → http://localhost:3100"
echo "  n8n (workflows)     → http://localhost:5678"
echo "  Gitea (git)         → http://localhost:3000"
echo "  Twenty CRM          → http://localhost:3003"
echo "  SiYuan (knowledge)  → http://localhost:6806"
echo "  Uptime Kuma         → http://localhost:3001"
echo "  ntfy                → http://localhost:8085"
echo "  Firecrawl           → http://localhost:3008"
echo "  Duplicati           → http://localhost:8200"
echo "  Chroma              → http://localhost:8000"
echo "  Mem0                → http://localhost:8050"
echo ""
echo "Logs : docker compose logs -f [service]"
echo "Stop : docker compose down"
