# Paperclip Agents Playbook

Guide complet de tous les agents avec integration des 4 couches de memoire/knowledge.

## Architecture de l'equipe

```
                    ┌─────────┐
                    │   CEO   │
                    │ (32b)   │
                    └────┬────┘
                         │
              ┌──────────┼──────────┐
              │          │          │
         ┌────▼───┐ ┌───▼────┐ ┌───▼────┐
         │  CTO   │ │  CPO   │ │  CFO   │
         │ (32b)  │ │ (14b)  │ │ (14b)  │
         └───┬────┘ └───┬────┘ └────────┘
             │          │
    ┌────────┼────────┐ │
    │        │        │ │
┌───▼──┐ ┌──▼───┐ ┌──▼─▼──┐
│Lead  │ │Lead  │ │DevOps │
│Back  │ │Front │ │       │
│(33b) │ │(33b) │ │(33b)  │
└──┬───┘ └──┬───┘ └──┬────┘
   │        │        │
┌──▼───┐ ┌──▼───┐ ┌──▼───┐
│  QA  │ │Desig │ │Secu  │
│(14b) │ │(14b) │ │(14b) │
└──────┘ └──────┘ └──────┘
              │
         ┌────▼─────┐
         │Researcher│
         │ (14b)    │
         └──────────┘
```

## 4 couches de memoire

```
┌─────────────────────────────────────────────────────┐
│                COUCHE 1 : Mem0 (:8050)               │
│   Memoire de travail persistante par agent           │
│   Decisions, patterns, bugs, conventions             │
│   Chaque agent lit/ecrit sous son user_id            │
│   Cross-agent: CTO lit CEO, Frontend lit Backend...  │
├─────────────────────────────────────────────────────┤
│              COUCHE 2 : SiYuan Note (:6806)          │
│   Knowledge base structuree, 40+ endpoints REST      │
│   Block CRUD, SQL, attributs custom                  │
│   CTO, CPO, Researcher, Designer l'utilisent         │
├─────────────────────────────────────────────────────┤
│              COUCHE 3 : Chroma (:8000)               │
│   Vector DB pour RAG avance                          │
│   Collections : architecture, conventions, codebase  │
│   CTO et Researcher indexent, devs requetent         │
└─────────────────────────────────────────────────────┘
```

## Flux de memoire entre agents

```
CEO decisions ──→ Mem0 "ceo" ──→ CTO, CPO lisent
                                    │
CTO architecture ──→ Mem0 "cto" ──→ Tous les devs lisent
                                    │
CPO specs ──→ Mem0 "cpo" ──→ CTO, Designer lisent
                                    │
Designer tokens ──→ Mem0 "designer" ──→ Lead Frontend lit
                                    │
Lead Backend bugs ──→ Mem0 "lead-backend" ──→ QA, Frontend lisent
                                    │
Researcher findings ──→ Mem0 + SiYuan + Chroma ──→ TOUS lisent
```

## Index des fichiers

| # | Fichier | Description |
|---|---------|-------------|
| 0 | [00-stack-overview.md](./00-stack-overview.md) | Architecture complete de la stack |
| 1 | [01-ceo.md](./01-ceo.md) | CEO : recrutement, strategie, Mem0 |
| 2 | [02-cto.md](./02-cto.md) | CTO : architecture, knowledge base, Mem0+Chroma+SiYuan |
| 3 | [03-cpo.md](./03-cpo.md) | CPO : specs produit, Mem0+SiYuan |
| 4 | [04-cfo.md](./04-cfo.md) | CFO : couts, budgets, Mem0 |
| 5 | [05-lead-backend.md](./05-lead-backend.md) | Backend : code, Mem0+SiYuan+Chroma |
| 6 | [06-lead-frontend.md](./06-lead-frontend.md) | Frontend : UI, cross-agent Mem0 |
| 7 | [07-devops.md](./07-devops.md) | DevOps : infra, Mem0+SiYuan |
| 8 | [08-security.md](./08-security.md) | Security : audit, Mem0+SiYuan+Chroma |
| 9 | [09-qa.md](./09-qa.md) | QA : tests, Mem0 cross-agent |
| 10 | [10-designer.md](./10-designer.md) | Designer : UI/UX, Mem0+SiYuan |
| 11 | [11-researcher.md](./11-researcher.md) | Researcher : veille, alimente TOUTES les couches |
| 12 | [12-memory-api-reference.md](./12-memory-api-reference.md) | Reference API complete des 3 couches memoire (21+ endpoints, graph memory, persistent webhooks/links) |
| 13 | [13-memory-protocol.md](./13-memory-protocol.md) | Protocole memoire v2 : metadata, lifecycle, Decision Records, permissions |
| 14 | [14-knowledge-workflows.md](./14-knowledge-workflows.md) | 7 workflows knowledge : onboarding, propagation, conflits, review, digest |
| 16 | [16-n8n-agent-workflows.md](./16-n8n-agent-workflows.md) | 19 workflows n8n : deploy, notify, scrape, git, CRM, analytics, monitoring, SiYuan auto-publish, dashboards, AI Agent |
| 17 | [17-mem0-v3-endpoints.md](./17-mem0-v3-endpoints.md) | Nouveaux endpoints Mem0 v3 : webhooks, links, timeline, conflits |
| 18 | [18-server-agents-design.md](./18-server-agents-design.md) | Design agents serveur (Phase 2) : sysadmin, marketing, scheduler |
| 19 | [19-siyuan-api-reference.md](./19-siyuan-api-reference.md) | Reference API SiYuan Note |
| 20 | [20-siyuan-bootstrap.md](./20-siyuan-bootstrap.md) | Bootstrap SiYuan : notebooks, dashboards, daily notes, templates, conventions |
| 21 | [21-paperclip-setup.md](./21-paperclip-setup.md) | Setup Paperclip avance : goals, projects, approvals, costs, config revisions |

## Guides

- [models-config.md](./models-config.md) — Configuration LiteLLM multi-modeles (8GB et 48GB)
- [deployment-order.md](./deployment-order.md) — Ordre de deploiement des agents et workflow type

## Protocole memoire v2

Chaque agent suit le [protocole memoire](./13-memory-protocol.md) obligatoire :

- **Metadata obligatoires** : `type`, `project`, `state`, `confidence` sur chaque memoire
- **Lifecycle** : `active` → `deprecated` → `archived` (via `PATCH /memories/{id}/state`)
- **Decision Records** : format structure `DECISION/CONTEXT/CHOICE/ALTERNATIVES/CONSEQUENCES/STATUS/LINKED_TASK`
- **Confiance** : `hypothesis` → `tested` → `validated` (QA/Security promeuvent)
- **Deduplication** : `deduplicate: true` cote serveur (cosine > 0.92)
- **Cross-agent** : `POST /search/multi` pour lire plusieurs agents, `POST /search/filtered` avec `state: active`

Les [7 workflows knowledge](./14-knowledge-workflows.md) couvrent : onboarding, propagation de decisions, resolution de conflits, review periodique, boucle task↔memory, digest researcher, et fallback services down.

## n8n Integration

Les agents communiquent avec l'infrastructure serveur via n8n (Event Bus) :

```
Agent → POST $N8N_WEBHOOK_URL/agent-event → n8n → Services serveur
                                                    ├── Dokploy (deploy)
                                                    ├── Gitea (git)
                                                    ├── Firecrawl (scrape)
                                                    ├── Twenty CRM
                                                    ├── BillionMail (email)
                                                    └── ntfy (notifications)
```

n8n alimente aussi Mem0 sous des **user_ids systeme** que tous les agents lisent :
`monitoring`, `analytics`, `calendar`, `crm`, `security-events`, `deployments`, `git-events`

Voir [16-n8n-agent-workflows.md](./16-n8n-agent-workflows.md) pour les 19 workflows.

## Paperclip Governance

Paperclip gere la gouvernance complete de l'equipe d'agents :

- **Goals & Projects** : structure hierarchique Company Goal → Team Goals → Projects → Tasks
- **Approvals** : workflow d'approbation pour decisions critiques, recrutement, deploys
- **Cost Tracking** : suivi des couts par agent/task/project
- **Config Revisions** : versioning des configs agents avec rollback
- **Task Sessions** : contexte persistant entre heartbeats

Voir [21-paperclip-setup.md](./21-paperclip-setup.md) pour la reference complete.

## SiYuan Bootstrap

Le script `mac/siyuan/bootstrap.sh` initialise SiYuan avec :

- 8 notebooks : architecture, engineering, produit, design-system, research, operations, security, global
- ~40 documents pre-peuples (guidelines, tech docs, templates, best practices)
- 3 dashboards live (rafraichis par n8n) : services, analytics, team-activity
- Daily notes configurees sur le notebook "global"
- Tech docs : TypeScript, Python, Docker, PostgreSQL, Ollama, Chroma, Mem0
- Guidelines : testing, performance, API design, git workflow, code review
- Securite : OWASP Top 10, politiques auth, gestion dependances
- Operations : runbooks deploy, migration DB, post-mortem, alerting

Voir [20-siyuan-bootstrap.md](./20-siyuan-bootstrap.md) pour les details.

## Modeles recommandes (48GB RAM)

| Role | Modele | RAM | Pourquoi |
|------|--------|-----|----------|
| CEO, CTO | `qwen3:32b` | ~20GB | Raisonnement, tool calling, management |
| Devs | `qwen3-coder:30b` | ~20GB | Code haute qualite |
| CPO, CFO, QA, Security, Designer, Researcher | `qwen3:14b` | ~9GB | Taches structurees |
| Embeddings | `nomic-embed-text` | 274MB | Mem0, Chroma |
