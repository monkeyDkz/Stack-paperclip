#!/bin/bash
# ============================================================
# REFRESH CLAUDE CREDENTIALS
# Extrait le token depuis le keychain macOS → volume Docker
# Planifié via LaunchAgent (~/.launchd/com.stack.claude-refresh.plist)
# ============================================================

set -euo pipefail

VOLUME_PATH="/Users/kayszahidi/OrbStack/docker/volumes/nouvelle-stack_claude_config"
CREDS_FILE="$VOLUME_PATH/.credentials.json"
LOG_FILE="/tmp/claude-credentials-refresh.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

log "Refresh credentials..."

CREDS=$(security find-generic-password -s "Claude Code-credentials" -g 2>&1 \
    | grep "^password:" \
    | sed 's/^password: "//' \
    | sed 's/"$//')

if [ -z "$CREDS" ]; then
    log "ERREUR : credentials introuvables dans le keychain (claude auth login requis)"
    exit 1
fi

echo "$CREDS" | python3 -m json.tool > /dev/null 2>&1 || {
    log "ERREUR : JSON invalide"
    exit 1
}

EXPIRES=$(echo "$CREDS" | python3 -c "
import sys, json, datetime
d = json.load(sys.stdin)
exp = d['claudeAiOauth']['expiresAt'] / 1000
print(datetime.datetime.fromtimestamp(exp).strftime('%Y-%m-%d %H:%M:%S'))
" 2>/dev/null || echo "?")

echo "$CREDS" > "$CREDS_FILE"
chmod 666 "$CREDS_FILE"

log "OK — token écrit (expire le $EXPIRES)"
