#!/bin/sh
# init-admin.sh — Bootstrap premier admin Paperclip
# Tourne en arrière-plan pendant le démarrage du serveur

PORT="${PORT:-3100}"
PUBLIC_URL="${PAPERCLIP_PUBLIC_URL:-http://localhost:${PORT}}"
MAX_WAIT=60
INTERVAL=3

echo "[init-admin] Attente du démarrage de Paperclip (${PUBLIC_URL})..."

elapsed=0
while [ "$elapsed" -lt "$MAX_WAIT" ]; do
  if curl -sf "http://localhost:${PORT}/health" > /dev/null 2>&1; then
    echo "[init-admin] Serveur prêt après ${elapsed}s."
    break
  fi
  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

if [ "$elapsed" -ge "$MAX_WAIT" ]; then
  echo "[init-admin] Timeout — bootstrap ignoré."
  exit 0
fi

# Crée l'invite bootstrap CEO via la CLI (lit DATABASE_URL depuis l'env)
# Si un admin existe déjà, sort proprement sans rien faire
echo "[init-admin] Création du lien d'invite admin..."
node \
  --import ./server/node_modules/tsx/dist/loader.mjs \
  ./cli/src/index.ts \
  auth bootstrap-ceo \
  --base-url "$PUBLIC_URL" 2>&1 || true

echo "[init-admin] Bootstrap terminé."
