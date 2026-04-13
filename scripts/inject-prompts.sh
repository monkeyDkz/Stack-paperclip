#!/bin/bash
# ============================================
# PAPERCLIP — Injection des prompts COMPLETS
# ============================================
# Lit chaque playbook .md, extrait le Prompt Template,
# et l'injecte dans l'agent via PATCH /api/agents/{id}
# + configure le bon model pour chaque agent
# + stocke les skills dans SiYuan
# ============================================

set -euo pipefail

PAPERCLIP_URL="http://localhost:8060"
SIYUAN_URL="http://localhost:6806"
SIYUAN_TOKEN="paperclip-siyuan-token"
ADMIN_EMAIL="${PAPERCLIP_ADMIN_EMAIL:-admin@paperclip.local}"
ADMIN_PASSWORD="${PAPERCLIP_ADMIN_PASSWORD:-paperclip-admin}"
PLAYBOOK_DIR="$(cd "$(dirname "$0")/agents-playbook" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[!!]${NC} $1" >&2; }
info() { echo -e "${BLUE}[>>]${NC} $1" >&2; }
fail() { echo -e "${RED}[ERREUR]${NC} $1" >&2; exit 1; }

command -v jq &>/dev/null || fail "jq requis"

# --- Login Paperclip ---
curl -sf -X POST "$PAPERCLIP_URL/api/auth/sign-in/email" \
    -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
    -c /tmp/pc-inject.txt \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" > /dev/null || fail "Login echoue"

api() {
    local method="$1" path="$2" data="${3:-}"
    if [ -n "$data" ]; then
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b /tmp/pc-inject.txt -d "$data" 2>/dev/null || echo "{}"
    else
        curl -sf -X "$method" "$PAPERCLIP_URL$path" \
            -H "Content-Type: application/json" -H "Origin: $PAPERCLIP_URL" \
            -b /tmp/pc-inject.txt 2>/dev/null || echo "{}"
    fi
}

siyuan_api() {
    curl -sf -X POST "$SIYUAN_URL$1" \
        -H "Authorization: Token $SIYUAN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$2" 2>/dev/null || echo "{}"
}

# --- Get company & agents ---
COMPANIES=$(api GET "/api/companies")
COMPANY_ID=$(echo "$COMPANIES" | jq -r '.[0].id // empty')
[ -z "$COMPANY_ID" ] && fail "Aucune company"

AGENTS_JSON=$(api GET "/api/companies/$COMPANY_ID/agents")
log "Company: $COMPANY_ID — $(echo "$AGENTS_JSON" | jq 'length') agents"

get_agent_id() { echo "$AGENTS_JSON" | jq -r ".[] | select(.name == \"$1\") | .id"; }

# --- Extract prompt from playbook ---
# Extracts everything between "## Prompt Template\n\n```" and the closing "```"
extract_prompt() {
    local file="$1"
    [ ! -f "$file" ] && return
    # Use awk to extract between ``` blocks after "## Prompt Template"
    awk '/^## Prompt Template/{found=1; next} found && /^```$/ && !started{started=1; next} started && /^```$/{exit} started{print}' "$file"
}

# --- Get SiYuan notebook ID for skills ---
SKILLS_NOTEBOOK=$(siyuan_api "/api/notebook/lsNotebooks" '{}' | \
    python3 -c "import json,sys; nbs=json.load(sys.stdin).get('data',{}).get('notebooks',[]); [print(nb['id']) for nb in nbs if nb['name']=='global' and not nb['closed']]" 2>/dev/null | head -1)

echo ""
echo "========================================"
echo "  INJECTION PROMPTS COMPLETS + MODELS"
echo "========================================"
echo ""

# --- Inject function ---
inject_agent() {
    local name="$1"
    local model="$2"
    local playbook_file="$3"
    local skills="$4"
    local mem0_uid="$5"

    local agent_id
    agent_id=$(get_agent_id "$name")
    [ -z "$agent_id" ] && { warn "$name: non trouve"; return; }

    # Extract the full prompt
    local prompt
    prompt=$(extract_prompt "$playbook_file")
    if [ -z "$prompt" ]; then
        warn "$name: pas de prompt dans $playbook_file"
        return
    fi

    local prompt_len=${#prompt}

    # Build update JSON with jq (handles escaping properly)
    local update_json
    update_json=$(jq -n \
        --arg prompt "$prompt" \
        --arg model "$model" \
        --arg skills "$skills" \
        --arg mem0 "$mem0_uid" \
        --arg caps "$skills" \
        '{
            capabilities: $caps,
            adapterConfig: {
                model: $model,
                promptTemplate: $prompt,
                dangerouslySkipPermissions: true
            },
            metadata: {
                mem0_user_id: $mem0,
                skills: $skills
            }
        }')

    local resp
    resp=$(api PATCH "/api/agents/$agent_id" "$update_json")
    local ok
    ok=$(echo "$resp" | jq -r '.name // empty' 2>/dev/null)

    if [ -n "$ok" ]; then
        log "$name: prompt ($prompt_len chars) + model=$model"
    else
        warn "$name: echec — $(echo "$resp" | jq -r '.error // .message // "?"' 2>/dev/null)"
    fi

    # Store skills in SiYuan
    if [ -n "$SKILLS_NOTEBOOK" ]; then
        local skills_md="# Skills: $name\n\n**Model:** \`$model\`\n**Mem0 user_id:** \`$mem0_uid\`\n\n## Capabilities\n$skills\n\n## Prompt ($prompt_len chars)\nStored in Paperclip adapterConfig.promptTemplate"
        siyuan_api "/api/filetree/createDocWithMd" \
            "{\"notebook\":\"$SKILLS_NOTEBOOK\",\"path\":\"/agents/$name\",\"markdown\":\"$(echo -e "$skills_md" | sed 's/"/\\"/g' | tr '\n' ' ')\"}" > /dev/null 2>&1 || true
    fi
}

# ============================================
# INJECT ALL 16 AGENTS
# ============================================
# Format: name model playbook_file skills mem0_user_id

inject_agent "ceo" "qwen3:32b" \
    "$PLAYBOOK_DIR/01-ceo.md" \
    "Vision strategique, recrutement agents, delegation, arbitrage conflits, knowledge review, memoire strategique (Decision Records)" \
    "ceo"

inject_agent "cto" "qwen3:32b" \
    "$PLAYBOOK_DIR/02-cto.md" \
    "Architecture systeme, stack technique, recrutement tech, code review, knowledge management, decision propagation, cross-agent status, resolution conflits techniques" \
    "cto"

inject_agent "cpo" "qwen3:14b" \
    "$PLAYBOOK_DIR/03-cpo.md" \
    "Product discovery, specification produit (PRD), roadmap et planification, coordination produit, analyse feedback, memoire produit" \
    "cpo"

inject_agent "cfo" "qwen3:14b" \
    "$PLAYBOOK_DIR/04-cfo.md" \
    "Suivi des couts par agent/projet, budget et planification financiere, ROI et analyse, audit financier, reporting au CEO" \
    "cfo"

inject_agent "lead-backend" "qwen3-coder:30b" \
    "$PLAYBOOK_DIR/05-lead-backend.md" \
    "API design (REST/GraphQL), base de donnees PostgreSQL, logique metier, integration services, testing (unit/integration), performance backend, TypeScript/Python" \
    "lead-backend"

inject_agent "lead-frontend" "qwen3-coder:30b" \
    "$PLAYBOOK_DIR/06-lead-frontend.md" \
    "Architecture frontend React/Next.js, composants UI shadcn/Radix, integration API TanStack Query, styling Tailwind CSS, performance, accessibilite WCAG, tests Playwright" \
    "lead-frontend"

inject_agent "devops" "qwen3-coder:30b" \
    "$PLAYBOOK_DIR/07-devops.md" \
    "Docker multi-stage, CI/CD Gitea Actions, infrastructure as code, monitoring et logging, gestion environnements, securite infra, Dockerfiles et docker-compose" \
    "devops"

inject_agent "security" "qwen3:14b" \
    "$PLAYBOOK_DIR/08-security.md" \
    "Audit code OWASP Top 10, securite dependances (CVE), securite infrastructure, auth et autorisations, protection donnees, reporting securite" \
    "security"

inject_agent "qa" "qwen3:14b" \
    "$PLAYBOOK_DIR/09-qa.md" \
    "Test planning, tests unitaires Vitest/Jest, tests integration, tests e2e Playwright, code review qualite, regression testing, metriques coverage" \
    "qa"

inject_agent "designer" "qwen3:14b" \
    "$PLAYBOOK_DIR/10-designer.md" \
    "UX research, wireframing textuel ASCII, design system tokens, specifications interface composants, accessibilite WCAG 2.1 AA, review design" \
    "designer"

inject_agent "researcher" "qwen3:14b" \
    "$PLAYBOOK_DIR/11-researcher.md" \
    "Veille technologique, recherche solutions, analyse libraries, documentation technique, benchmarking, competitive analysis, alimenteur knowledge base (Mem0+SiYuan+Chroma)" \
    "researcher"

inject_agent "growth-lead" "qwen3:32b" \
    "$PLAYBOOK_DIR/29-growth-lead.md" \
    "Growth strategy, channel orchestration (SEO/Content/Sales/Data), experiment design A/B, growth audit funnel, coordination cross-agent, reporting CPO" \
    "growth-lead"

inject_agent "seo" "qwen3:14b" \
    "$PLAYBOOK_DIR/25-seo.md" \
    "Keyword research, on-page SEO audit, SERP monitoring hebdomadaire, competitor SEO analysis, technical SEO, content brief generation pour Content Writer" \
    "seo"

inject_agent "content-writer" "qwen3:14b" \
    "$PLAYBOOK_DIR/26-content-writer.md" \
    "Blog articles SEO-optimises, email copywriting, landing page copy, content repurposing multi-format, calendrier editorial" \
    "content-writer"

inject_agent "data-analyst" "qwen3:14b" \
    "$PLAYBOOK_DIR/27-data-analyst.md" \
    "Funnel analysis, cross-service correlation (Umami+CRM+Calendar), cohort analysis, anomaly detection proactive, weekly business dashboard, ROI attribution" \
    "data-analyst"

inject_agent "sales" "qwen3:14b" \
    "$PLAYBOOK_DIR/28-sales.md" \
    "Lead scoring, outbound prospecting, email sequences nurturing, pipeline management CRM, meeting-to-deal, win/loss analysis" \
    "sales"

# ============================================
# VERIFICATION
# ============================================
echo ""
info "=== Verification ==="
FINAL=$(api GET "/api/companies/$COMPANY_ID/agents")
echo "$FINAL" | jq -r '.[] | "\(.name)\t\(.adapterConfig.model // "?")\t\(.adapterConfig.promptTemplate | length) chars\t\(.adapterConfig.dangerouslySkipPermissions // false)"' 2>/dev/null | \
    sort | column -t -s $'\t'

echo ""
echo "========================================"
echo -e "  ${GREEN}INJECTION TERMINEE${NC}"
echo "========================================"
echo ""
echo "  Chaque agent a maintenant :"
echo "    - Prompt complet (3-5 KB) depuis son playbook"
echo "    - Model correct (qwen3:32b / qwen3-coder:30b / qwen3:14b)"
echo "    - dangerouslySkipPermissions: true"
echo "    - Skills stockees dans SiYuan (global/agents/)"
echo "    - Mem0 user_id dans metadata"
echo ""
echo "  La commande executee par Paperclip sera :"
echo "    claude --model <model> --dangerously-skip-permissions --print - ..."
echo "    avec le prompt complet en stdin"
echo ""

rm -f /tmp/pc-inject.txt
