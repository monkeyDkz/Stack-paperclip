#!/bin/sh
# ============================================
# PAPERCLIP — Auto-bootstrap admin user
# ============================================
# Cree automatiquement le compte admin au premier demarrage.
# Si un admin existe deja, ne fait rien.
# ============================================

PAPERCLIP_ADMIN_EMAIL="${PAPERCLIP_ADMIN_EMAIL:-admin@paperclip.local}"
PAPERCLIP_ADMIN_PASSWORD="${PAPERCLIP_ADMIN_PASSWORD:-paperclip-admin}"
PAPERCLIP_ADMIN_NAME="${PAPERCLIP_ADMIN_NAME:-Admin}"

# Attendre que le serveur soit pret
echo "[init-admin] Attente du serveur Paperclip..."
for i in $(seq 1 60); do
    if curl -sf http://127.0.0.1:3100/api/health -o /dev/null 2>/dev/null; then
        break
    fi
    [ "$i" -eq 60 ] && echo "[init-admin] WARN: timeout" && exit 0
    sleep 2
done
echo "[init-admin] Serveur pret."

# Verifier si bootstrap deja fait
HEALTH=$(curl -sf http://127.0.0.1:3100/api/health 2>/dev/null || echo '{}')
STATUS=$(echo "$HEALTH" | node -e "
try { const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d.bootstrapStatus||'unknown'); }
catch { process.stdout.write('unknown'); }
")

if [ "$STATUS" = "ready" ]; then
    echo "[init-admin] Admin existe deja. Rien a faire."
    exit 0
fi

echo "[init-admin] Premier demarrage detecte — creation admin..."

# Signup via Better Auth API
SIGNUP=$(curl -sf -X POST http://127.0.0.1:3100/api/auth/sign-up/email \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$PAPERCLIP_ADMIN_EMAIL\",\"password\":\"$PAPERCLIP_ADMIN_PASSWORD\",\"name\":\"$PAPERCLIP_ADMIN_NAME\"}" 2>&1) || true

USER_ID=$(echo "$SIGNUP" | node -e "
try { const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d.user?.id||''); }
catch { process.stdout.write(''); }
")

if [ -z "$USER_ID" ]; then
    echo "[init-admin] WARN: signup echoue ($SIGNUP)"
    exit 0
fi

echo "[init-admin] User cree: $USER_ID ($PAPERCLIP_ADMIN_EMAIL)"

# Promotion instance_admin directement en base
node -e "
const postgres = require('/app/node_modules/.pnpm/postgres@3.4.8/node_modules/postgres/cjs/src/index.js');
(async () => {
  const sql = postgres(process.env.DATABASE_URL);
  await sql\`INSERT INTO instance_user_roles (user_id, role) VALUES (\${process.argv[1]}, 'instance_admin') ON CONFLICT (user_id, role) DO NOTHING\`;
  console.log('[init-admin] Admin promu instance_admin.');
  await sql.end();
})().catch(e => { console.error('[init-admin] DB error:', e.message); process.exit(0); });
" "$USER_ID"

# Verification finale
sleep 1
HEALTH2=$(curl -sf http://127.0.0.1:3100/api/health 2>/dev/null || echo '{}')
STATUS2=$(echo "$HEALTH2" | node -e "
try { const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d.bootstrapStatus||'unknown'); }
catch { process.stdout.write('unknown'); }
")

if [ "$STATUS2" = "ready" ]; then
    echo "[init-admin] Admin cree avec succes!"
    echo "[init-admin]   Email:    $PAPERCLIP_ADMIN_EMAIL"
    echo "[init-admin]   Password: $PAPERCLIP_ADMIN_PASSWORD"
else
    echo "[init-admin] WARN: status=$STATUS2 — verifier manuellement"
fi
