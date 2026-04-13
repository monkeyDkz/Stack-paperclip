# Paperclip Stack

Multi-agent AI system powered by [Paperclip](https://paperclip.ing) + Claude Code + Gitea.

A CEO agent receives missions and autonomously orchestrates a team of 17 specialized agents to deliver complete projects (websites, apps, content) with Git workflow, PR reviews, and quality gates.

## Architecture

```
CEO (Opus) ── orchestrates phases, wakes agents, tracks progress
├── CTO (Opus) ── architecture, PR review + merge
├── CPO (Haiku) ── product specs
├── Designer (Haiku) ── design system (uses design skills)
├── Lead Frontend (Sonnet) ── implementation (uses redesign-existing-projects audit)
├── Lead Backend (Sonnet) ── APIs
├── Content Writer (Haiku) ── copywriting
├── SEO (Haiku) ── meta tags, structured data
├── QA (Haiku) ── testing, Lighthouse
├── Security (Haiku) ── audit, headers, CSP
├── DevOps (Sonnet) ── Docker, CI/CD, deploy
└── ... (CFO, Growth Lead, Scraper, etc.)
```

## Pipeline

```
Mission → CEO
  ├── Phase 1: CTO (repo setup) + CPO (specs) + Designer (design system)
  ├── Phase 2: Content Writer + SEO
  ├── Phase 3: Lead Frontend (branch → PR) + Lead Backend (branch → PR)
  │             └── CTO reviews + merges PRs
  ├── Phase 4: QA + Security + DevOps
  └── Phase 5: CEO validation + close
```

Each agent:
- Works on a Git branch, creates PRs (never commits to main)
- Notifies @CEO on the parent task when done
- CEO wakes the next phase agents sequentially (rate limit aware)

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Paperclip | 3100 | Agent orchestration |
| Gitea | 3000 | Git hosting + PRs |
| PostgreSQL | 5432 | Shared database |
| Redis | 6379 | Cache + queues |
| Mem0 | 8050 | Agent persistent memory |
| Chroma | 8000 | Vector embeddings |
| SiYuan | 6806 | Knowledge base |
| Playwright | 3333 | Browser automation API |
| n8n | 5678 | Workflow automation |

## Quick Start

```bash
# 1. Clone
git clone <repo-url> && cd paperclip-stack

# 2. Configure
cp .env.example .env
# Fill in secrets (see comments in .env.example)

# 3. Launch
docker compose -f docker/docker-compose.yml up -d

# 4. Bootstrap agents
./scripts/bootstrap-paperclip.sh

# 5. Setup credential auto-refresh (macOS)
cp tools/refresh-claude-credentials ~/bin/
chmod +x ~/bin/refresh-claude-credentials
cp tools/com.stack.claude-refresh.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.stack.claude-refresh.plist

# 6. Give a mission to the CEO
# Via Paperclip UI at http://localhost:3100
# Or via API (see scripts/create-mission.sh)
```

## Agent Prompts

Live prompts are in `agents/prompts/`. Each agent has:
- Paperclip checkout/close workflow
- Gitea branch + PR workflow
- @CEO notification on completion
- Rate limit awareness
- Role-specific skills (Designer uses design skills, devs use frontend-design + redesign audit)

Agent manifest with models: `agents/agents.json`

## Claude Code Skills Used

### Designer
- `/ui-ux-pro-max` — design system foundation (161 palettes, 57 font pairings)
- `/frontend-design` — creative direction
- `/high-end-visual-design` — premium component patterns
- `/design-taste-frontend` — anti-generic audit (dials: variance 8, motion 6, density 4)
- `/stitch-design-taste` — DESIGN.md generation

### Lead Frontend
- `/frontend-design` — code each page
- `/redesign-existing-projects` — 20-point audit before every PR
- `/design-taste-frontend` — anti-generic finitions

## Rate Limit Management

All agents share one Claude Max subscription. The CEO:
- Wakes max 2 agents at a time
- Waits for completion before waking the next
- Stops waking if rate limit is hit
- Agents set status to `in_progress` (not blocked) on rate limit

## File Structure

```
paperclip-stack/
├── docker/
│   ├── docker-compose.yml    # Full stack
│   └── init-admin.sh         # Paperclip admin bootstrap
├── configs/
│   ├── mem0/                  # Memory service (Ollama + Chroma)
│   └── postgres/              # DB init script
├── agents/
│   ├── prompts/               # Live agent prompts (v3)
│   ├── prompts-legacy/        # Old v1 prompts (reference)
│   ├── playbooks/             # Agent role documentation
│   └── agents.json            # Agent manifest (name, model, prompt file)
├── scripts/
│   ├── bootstrap-paperclip.sh # Full agent setup
│   ├── agent-orchestrator.sh  # Wake daemon
│   ├── agent-control.sh       # Manual agent control
│   └── ...
├── tools/
│   ├── refresh-claude-credentials  # OAuth token refresh
│   ├── com.stack.claude-refresh.plist  # LaunchAgent (macOS)
│   └── playwright-api.js      # Playwright HTTP API
├── .env.example
└── README.md
```
