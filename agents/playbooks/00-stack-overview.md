# Stack Complete - Vue d'ensemble

## Architecture globale

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PAPERCLIP (:8060)                           │
│  Orchestrateur — source de verite pour agents, taches, governance   │
│                                                                     │
│  Agents <-> Tasks <-> Goals <-> Projects <-> Approvals <-> Costs   │
│     │         │                                                     │
│     │    checkout/release                                           │
│     │         │                                                     │
│  Heartbeat -> Agent execute -> Resultat                             │
│     │                           │                                   │
└─────┼───────────────────────────┼───────────────────────────────────┘
      │                           │
      │  1. Agent lit contexte    │  4. Agent sauve resultat
      v                           v
┌─────────────────┐    ┌─────────────────────┐
│   MEM0 (:8050)  │<-->│   SIYUAN (:6806)    │
│   Memoire agent │    │   Knowledge humain  │
│   (machine->mach)│    │   (machine->humain)  │
│                 │    │                     │
│ Decisions       │    │ Docs structures    │
│ Conventions     │    │ Dashboards live    │
│ Bugs/patterns   │    │ Notifications mob  │
│ Graph memory    │    │ SQL search         │
│ System channels │    │ Query embeds       │
└────────┬────────┘    └─────────────────────┘
         │ webhooks              ^
         v                       │ auto-publish
┌────────────────────────────────┼────────────────────────────────────┐
│                         N8N (serveur)                               │
│              Event Bus + Automation + AI Agents                      │
│                                                                     │
│  Mem0 webhook -> format -> SiYuan publish + notification            │
│  Schedule -> dashboard refresh -> SiYuan updateBlock                │
│  Paperclip webhook -> cost tracking -> Mem0 save                   │
│  AI Agent -> LangChain + Ollama -> tool calling                    │
│  Error handling -> retry -> alert                                  │
│                                                                     │
│  Dokploy | Gitea | Twenty CRM | Firecrawl | ntfy | BillionMail    │
└─────────────────────────────────────────────────────────────────────┘
```

## Organigramme des agents (16 agents)

```
CEO (qwen3:32b)
├── CTO (qwen3:32b) → Lead Backend (qwen3-coder:30b), Lead Frontend (qwen3-coder:30b), DevOps (qwen3-coder:30b), Security (qwen3:14b), QA (qwen3:14b), Researcher (qwen3:14b)
├── CPO (qwen3:14b)
│   ├── Designer (qwen3:14b)
│   └── Growth Lead (qwen3:32b)
│       ├── SEO Specialist (qwen3:14b)
│       ├── Content Writer (qwen3:14b)
│       ├── Data Analyst (qwen3:14b)
│       └── Sales Automation (qwen3:14b)
└── CFO (qwen3:14b)
```

## Services et ports

| Service | Port | Role | API Base |
|---------|------|------|----------|
| **Ollama** | 11434 | LLM runtime | `http://host.docker.internal:11434` |
| **Chroma** | 8000 | Vector DB partagee | `http://host.docker.internal:8000` |
| **Mem0** | 8050 | Memoire persistante agents | `http://host.docker.internal:8050` |
| **SiYuan** | 6806 | Knowledge base structuree | `http://host.docker.internal:6806` |
| **LobeChat** | 3210 | Interface chat humain | `http://localhost:3210` |
| **Paperclip** | 8060 | Orchestration agents | `http://localhost:3100` (interne) |
| **n8n** | 5678 (serveur) | Automation workflows | `https://n8n.home/webhook` |

## 4 couches de memoire

### Couche 1 : Mem0 — Memoire de travail des agents (v3.1)
- **Quoi** : Memoire persistante par agent/user_id avec lifecycle et metadata structurees. Graph memory via Kuzu (DB graphe embedded) pour les relations automatiques entre entites
- **Pour** : Stocker decisions, contexte, apprentissages avec etat (active/deprecated/archived) et confiance (hypothesis/tested/validated)
- **API** : REST etendue — 21+ endpoints dont search/filtered, search/multi, lifecycle, stats, bulk, dedup, webhooks persistants, links persistants, graph memory
- **Webhooks** : Persistants sur disque, retry avec backoff exponentiel (3 tentatives : 1s, 2s, 4s)
- **Protocole** : Voir [13-memory-protocol.md](./13-memory-protocol.md) pour le schema obligatoire
- **Utilise par** : TOUS les agents

### Couche 2 : SiYuan Note — Knowledge base structuree
- **Quoi** : Knowledge base structuree avec 40+ endpoints REST, block CRUD, SQL, attributs custom, query embeds
- **Pour** : Stocker et organiser la documentation, les notes, les specs, les rapports. Daily notes pour le suivi quotidien. Templates pour les formats recurrents
- **API** : REST complete (:6806) — notebooks, documents, blocs, recherche SQL, attributs custom
- **Notifications** : Push via ntfy + app mobile pour alerter les humains en temps reel
- **Utilise par** : Researcher, CTO, CPO, Designer

### Couche 3 : Chroma — Base vectorielle partagee
- **Quoi** : Base de donnees vectorielle (fondation)
- **Pour** : Stockage d'embeddings, recherche de similarite
- **API** : REST Chroma v2
- **Utilise par** : Mem0 (indirect), agents avances pour RAG custom

## Interactions entre services

```
Agent se reveille dans Paperclip
  │
  ├── 0. MEMOIRE : Charger le contexte (Protocole v2)
  │     a. Mes memoires actives :
  │        POST mem0:8050/search/filtered {user_id: "self", filters: {state: {$eq: "active"}}}
  │     b. Conventions CTO :
  │        POST mem0:8050/search/filtered {user_id: "cto", filters: {type: {$eq: "convention"}}}
  │     c. Cross-agent (selon matrice permissions) :
  │        POST mem0:8050/search/multi {query: "contexte", user_ids: [...]}
  │     d. System channels (v3) :
  │        POST mem0:8050/search/filtered {user_id: "monitoring", ...}
  │        POST mem0:8050/search/filtered {user_id: "analytics", ...}
  │     e. SiYuan context (SQL search) :
  │        POST siyuan:6806/api/query/sql {stmt: "SELECT ... WHERE updated > '...'"}
  │
  ├── 1. PAPERCLIP : Checkout de la tache
  │     POST paperclip/api/issues/{id}/checkout
  │
  ├── 2. RECHERCHE : Si besoin d'infos externes
  │     SiYuan → Mem0 researcher → Chroma (fallback cascade)
  │
  ├── 3. EXECUTION : Realiser la tache (code, analyse, etc.)
  │
  ├── 4. MEMOIRE : Sauvegarder les apprentissages (Protocole v2)
  │     a. Verifier dedup : POST mem0:8050/search {query: "contenu", user_id: "self"}
  │     b. Sauvegarder avec metadata obligatoires :
  │        POST mem0:8050/memories {text: "DECISION: ...", metadata: {type, project, confidence, source_task}}
  │     c. Si remplace une ancienne decision :
  │        PATCH mem0:8050/memories/{old_id}/state {state: "deprecated"}
  │
  ├── 5. REPORTING : Cost reporting + notifications
  │     a. Reporter les couts a Paperclip :
  │        PATCH paperclip/api/issues/{id} {cost: {...}}
  │     b. Notification push via SiYuan + ntfy :
  │        POST n8n.home/webhook/agent-event {event: "notify", payload: {channel: "push", ...}}
  │
  ├── 6. APPROVAL : Si la tache necessite une validation
  │     a. Soumettre pour approbation :
  │        POST paperclip/api/issues/{id}/approve
  │     b. Attendre la decision du reviewer ou continuer selon la politique de gouvernance
  │
  ├── 7. n8n : Actions infrastructure (v3)
  │     POST n8n.home/webhook/agent-event {event: "deploy|notify|git|scrape|crm-sync"}
  │
  ├── 8. PAPERCLIP : Reporter et clore
  │     PATCH paperclip/api/issues/{id} {status: "done", comment: "..."}
  │
  ├── FALLBACK : Si Mem0 down → continuer sans, sauvegarder en local, re-upload au prochain reveil
  │
  └── FALLBACK : Si SiYuan down → chercher dans Mem0, sauvegarder en local, re-upload au prochain reveil
```

## Lifecycle des memoires

```
[creation] ──→ active ──→ deprecated ──→ archived ──→ [deletion]
                              ↑
                   (quand supersedee par
                    une nouvelle decision)
```

Voir [13-memory-protocol.md](./13-memory-protocol.md) pour les regles de transition.

## Knowledge Workflows

- **Onboarding** : chaque nouvel agent charge les conventions et l'architecture avant de travailler
- **Propagation** : quand une decision change, deprecier l'ancienne + notifier les agents impactes
- **Conflits** : escalade vers CTO/CEO, decision finale supersede les deux positions
- **Review** : mensuelle par le CTO, archiver les memoires obsoletes
- **Task ↔ Memory** : chaque tache terminee genere un learning, chaque nouvelle tache reference les memoires pertinentes

Voir [14-knowledge-workflows.md](./14-knowledge-workflows.md) pour les procedures detaillees.

## Paperclip Governance

Paperclip est la source de verite pour la gouvernance des agents. Les mecanismes principaux :

- **Goals & Projects** : structure hierarchique pour organiser les objectifs et les projets. Chaque tache est rattachee a un goal et un projet
- **Approval workflows** : certaines taches ou decisions necessitent une validation humaine ou hierarchique avant execution. Les politiques d'approbation sont configurables par projet
- **Cost tracking** : suivi des couts par agent et par tache (tokens LLM, temps d'execution, ressources). Rapports consolides par projet
- **Config revisions & rollback** : chaque modification de configuration est versionnee. Rollback possible vers une revision anterieure en cas de regression
- **Task sessions** : les agents travaillent dans des sessions isolees avec checkout/release pour eviter les conflits de concurrence

Voir [21-paperclip-setup.md](./21-paperclip-setup.md) pour la configuration detaillee.

## n8n Integration (v3)

n8n est le **Event Bus** qui connecte les agents (Mac) aux services serveur :

```
Agent → POST $N8N_WEBHOOK_URL/agent-event → n8n → Services serveur
                                                    ├── Dokploy (deploy)
                                                    ├── Gitea (git)
                                                    ├── Firecrawl (scrape)
                                                    ├── Twenty CRM
                                                    ├── BillionMail (email)
                                                    └── ntfy (notifications)
```

### System Memory Channels

n8n alimente Mem0 sous des user_ids virtuels que tous les agents lisent :

| user_id | Source | Contenu | Frequence |
|---------|--------|---------|-----------|
| `monitoring` | Uptime Kuma | Status services, uptimes, incidents | 5 min |
| `analytics` | Umami | Pages vues, visitors, top pages | 1h |
| `calendar` | Cal.com | RDV, bookings | Temps reel |
| `crm` | Twenty CRM | Contacts, deals, pipeline | Temps reel |
| `security-events` | CrowdSec | Attaques, IPs bloquees | Temps reel |
| `deployments` | Dokploy + Duplicati | Deploys, backups | Temps reel |
| `git-events` | Gitea | Commits, PRs, issues | Temps reel |

Convention : agents READ only, n8n WRITES.

Voir [16-n8n-agent-workflows.md](./16-n8n-agent-workflows.md) pour les 19 workflows :

- 12 workflows infrastructure existants (deploy, git, scrape, notify, crm-sync, etc.)
- SiYuan auto-publish : publication automatique des decisions Mem0 vers SiYuan
- SiYuan dashboard refresh : mise a jour periodique des dashboards dans SiYuan
- SiYuan daily notes : generation des notes quotidiennes avec resume d'activite
- Paperclip cost sync : synchronisation des couts Paperclip vers Mem0 et SiYuan
- AI Agent research : agent LangChain + Ollama pour recherche autonome avec tool calling
- AI Agent code review : agent IA pour review de code automatique via Gitea webhooks
- Error retry pipeline : gestion des erreurs avec retry, backoff et alertes ntfy
