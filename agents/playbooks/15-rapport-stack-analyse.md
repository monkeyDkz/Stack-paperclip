# Rapport : Analyse Complete de la Stack & Ameliorations Memoire/Protocoles

> Date : 2026-03-10 | Scope : 34 outils, 2 machines, 11 agents, 4 couches memoire + n8n

---

## Table des matieres

1. [Cartographie actuelle](#1-cartographie-actuelle)
2. [Diagnostic : forces et faiblesses](#2-diagnostic)
3. [n8n : le chaignon manquant](#3-n8n-le-chaignon-manquant)
4. [Ameliorations memoire inter-agents](#4-ameliorations-memoire-inter-agents)
5. [Nouveau protocole propose](#5-nouveau-protocole-propose)
6. [Plan d'implementation](#6-plan-dimplementation)

---

## 1. Cartographie actuelle

### 1.1 Flux de donnees complet (etat actuel)

```
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║   COUCHE ORCHESTRATION                                                    ║
║   ┌──────────────┐     ┌──────────┐                                       ║
║   │  Paperclip   │────>│  LiteLLM │───> Ollama (LLM inference)           ║
║   │  (port 8060) │     │  (4000)  │                                       ║
║   │              │     └──────────┘                                       ║
║   │  11 agents   │                                                        ║
║   │  heartbeat   │───> Mem0 (8050) ───> Chroma (8000)                    ║
║   └──────┬───────┘          │                │                            ║
║          │                  │                │                            ║
║          │                             ┌──────────┐                       ║
║          │                             │  Ollama   │                      ║
║          │                             │ embeddings│                      ║
║          │                             │  (11434)  │                      ║
║          │                             └──────────┘                       ║
║          │                                                                ║
║   ───────┼──── NetBird VPN / Reseau local ────────────────────────        ║
║          │                                                                ║
║          ▼                                                                ║
║   ┌──────────────┐                                                        ║
║   │     n8n      │◄──── Gitea webhooks                                   ║
║   │   (5678)     │◄──── Uptime Kuma alertes                              ║
║   │              │◄──── Cal.com bookings                                  ║
║   │              │◄──── Twenty CRM events                                ║
║   │              │◄──── CrowdSec alertes                                 ║
║   │              │                                                        ║
║   │              │────> Dokploy (deploy)                                  ║
║   │              │────> Playwright (tests)                                ║
║   │              │────> Firecrawl (scraping)                              ║
║   │              │────> BillionMail (emails)                              ║
║   │              │────> ntfy (notifications)                              ║
║   │              │────> Twenty CRM (sync)                                 ║
║   └──────────────┘                                                        ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

### 1.2 Matrice des 4+1 couches de connaissance

| Couche | Service | Port | Stockage | Qui ecrit | Qui lit | Latence |
|--------|---------|------|----------|-----------|---------|---------|
| **L1 Memoire** | Mem0 | 8050 | Chroma vectors | Tous agents | Tous agents | ~100ms |
| **L2 Vectors** | Chroma | 8000 | Persistent disk | Mem0, CTO, Researcher | RAG queries | ~50ms |
| **L3 Automation** | **n8n** | 5678 | PostgreSQL | Webhooks, schedules | Tous services | ~200ms |

### 1.3 Ce que chaque agent utilise REELLEMENT

| Agent | Mem0 | Chroma | n8n | Gitea | Firecrawl |
|-------|------|--------|-----|-------|-----------|
| CEO | R/W | - | - | - | - |
| CTO | R/W | R/W | - | - | - |
| CPO | R/W | - | - | - | - |
| CFO | R/W | - | - | - | - |
| Backend | R/W | R | - | R/W | - |
| Frontend | R/W | R | - | R/W | - |
| DevOps | R/W | - | **?** | R/W | - |
| Security | R/W | R | **?** | R | - |
| QA | R/W | - | **?** | R | - |
| Designer | R/W | - | - | - | - |
| Researcher | R/W | **R/W** | **?** | - | **?** |

**Legende** : R = lecture, W = ecriture, **?** = devrait utiliser mais pas configure

---

## 2. Diagnostic

### 2.1 Forces actuelles

| # | Force | Detail |
|---|-------|--------|
| 1 | **Protocole memoire v2** | Metadata structurees, lifecycle, Decision Records, deduplication |
| 2 | **Cross-agent search** | `/search/multi` permet la lecture inter-agents |
| 3 | **14 endpoints Mem0** | API riche : filtres, stats, bulk, lifecycle |
| 4 | **4 couches memoire** | Separation des concerns (travail, recherche, docs, vectors) |
| 5 | **Heartbeat agents** | Execution periodique autonome |
| 6 | **Hierarchy claire** | CEO > CTO/CPO/CFO > Leads > Support |

### 2.2 Faiblesses critiques

#### F1 : n8n est invisible pour les agents

**Probleme** : n8n est decrit comme "le ciment de tout" dans STACK.md (connexions 22-43), mais AUCUN agent ne l'utilise. C'est le plus gros trou de la stack.

**Impact** :
- Les agents ne peuvent pas declencher de workflows automatises
- Pas de CI/CD depuis les agents (Gitea → Dokploy passe par n8n)
- Pas de notifications push (ntfy passe par n8n)
- Pas de scraping web orchestre (Firecrawl passe par n8n)
- Les agents vivent dans une bulle isolee du reste de l'infra

#### F2 : Pas de notification inter-agents

**Probleme** : Quand le CTO deprecie une memoire, les agents impactes ne le savent pas jusqu'a leur prochain reveil. Avec des heartbeats de 5-15 min, un agent peut travailler avec des infos obsoletes.

**Impact** : Decisions basees sur des memoires depreciees, conflits non detectes.

#### F3 : Memoire "write-heavy, read-lazy"

**Probleme** : Les agents sauvegardent beaucoup (patterns, decisions, bugs) mais ne cherchent que lors du reveil (Etape 0). Pendant l'execution, ils ne re-consultent pas.

**Impact** : Si un autre agent sauvegarde une info pertinente pendant l'execution d'une tache, elle est ignoree.

#### F4 : Pas de memoire partagee "temps reel"

**Probleme** : Mem0 est un store vectoriel, pas un bus d'evenements. Il n'y a pas de mecanisme publish/subscribe. Les agents poll au reveil, point.

**Impact** : Latence de propagation des decisions = max(heartbeat intervals de tous les agents impactes).

#### F5 : Chroma sous-utilise

**Probleme** :
- Chroma direct : seuls CTO et Researcher y accedent directement, les autres passent par Mem0

**Impact** : Chroma est sous-exploite — les agents ne l'utilisent pas reellement en dehors de Mem0.

#### F6 : Pas de contexte serveur

**Probleme** : Les agents n'ont aucune visibilite sur :
- L'etat des services (Uptime Kuma)
- Les metriques business (Umami analytics)
- Les contacts CRM (Twenty)
- Les emails (BillionMail)
- Le calendrier (Cal.com)

**Impact** : Le CFO ne peut pas calculer de couts reels. Le CPO ne peut pas voir les stats d'usage. Le DevOps ne sait pas si un service est down.

#### F7 : Ollama model switching bottleneck

**Probleme** : 11 agents utilisent 4 modeles differents (32b, 33b, 14b, 3b). Ollama charge 1-2 modeles max en RAM. Switch = 10-30s.

**Impact** : Si CEO (32b) et Backend (33b) executent en parallele, l'un bloque l'autre.

---

## 3. n8n : le chaignon manquant

### 3.1 Pourquoi n8n est critique

n8n est le **seul service** qui connecte le Mac (IA) au serveur (infra/business). Sans n8n dans la boucle des agents, Paperclip est un cerveau sans corps.

```
AVANT (actuel) :
  Agent ──> Mem0 ──> (fin)

APRES (avec n8n) :
  Agent ──> Mem0 ──> n8n webhook ──> Action dans le monde reel
                                      ├── Deploy
                                      ├── Email
                                      ├── Notification
                                      ├── Scrape
                                      ├── Test
                                      └── CRM update
```

### 3.2 Architecture proposee : n8n comme Event Bus

```
┌─────────────────────────────────────────────────────────────────────┐
│                       n8n EVENT BUS                                  │
│                                                                      │
│   WEBHOOKS ENTRANTS (Mac → n8n)                                     │
│   ┌──────────────────────────────────────────┐                      │
│   │ POST https://n8n.home/webhook/agent-event │                     │
│   │                                           │                      │
│   │ {                                         │                      │
│   │   "agent": "devops",                      │                      │
│   │   "event": "deploy_requested",            │                      │
│   │   "payload": {                            │                      │
│   │     "repo": "frontend",                   │                      │
│   │     "branch": "main",                     │                      │
│   │     "task_id": "PAPER-42"                 │                      │
│   │   }                                       │                      │
│   │ }                                         │                      │
│   └──────────────────────────────────────────┘                      │
│                                                                      │
│   WORKFLOWS AUTOMATISES                                             │
│   ┌─────────────────────┐  ┌─────────────────────┐                  │
│   │ agent-deploy         │  │ agent-notify          │                │
│   │ → Dokploy API        │  │ → ntfy push           │                │
│   │ → Playwright tests   │  │ → BillionMail email   │                │
│   │ → ntfy result        │  │                       │                │
│   │ → Mem0 save result   │  │                       │                │
│   └─────────────────────┘  └─────────────────────┘                  │
│                                                                      │
│   ┌─────────────────────┐  ┌─────────────────────┐                  │
│   │ agent-scrape         │  │ agent-memory-event    │                │
│   │ → Firecrawl          │  │ → Mem0 read change    │                │
│   │ → Chroma index        │  │ → ntfy notify agent   │                │
│   │ → Mem0 save          │  │ → Paperclip create    │                │
│   └─────────────────────┘  │   issue if needed      │                │
│                             └─────────────────────┘                  │
│                                                                      │
│   ┌─────────────────────┐  ┌─────────────────────┐                  │
│   │ agent-crm-sync       │  │ agent-analytics       │                │
│   │ → Twenty CRM API     │  │ → Umami API           │                │
│   │ → Mem0 save contact  │  │ → Mem0 save metrics   │                │
│   └─────────────────────┘  └─────────────────────┘                  │
│                                                                      │
│   WEBHOOKS SORTANTS (n8n → Mac)                                     │
│   ┌──────────────────────────────────────────┐                      │
│   │ POST http://host.docker.internal:8050/... │ (Mem0)              │
│   │ POST http://host.docker.internal:8060/... │ (Paperclip)         │
│   └──────────────────────────────────────────┘                      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.3 Workflows n8n a creer pour les agents

| # | Workflow n8n | Trigger | Actions | Agents concernes |
|---|-------------|---------|---------|-----------------|
| 1 | **agent-deploy** | Webhook POST | Dokploy build → Playwright test → ntfy result → Mem0 save | DevOps |
| 2 | **agent-notify** | Webhook POST | ntfy push + optionnel BillionMail | Tous |
| 3 | **agent-scrape** | Webhook POST | Firecrawl URL → Chroma index → Mem0 save | Researcher |
| 4 | **agent-git** | Webhook POST | Gitea create branch/PR/issue | Backend, Frontend, DevOps |
| 5 | **agent-crm-sync** | Webhook POST | Twenty CRM create/update contact/deal | CPO, CFO |
| 6 | **agent-analytics** | Schedule 1h | Umami API → agrege → Mem0 save sous "analytics" | CFO, CPO |
| 7 | **agent-status** | Schedule 5min | Uptime Kuma API → Mem0 save sous "monitoring" | DevOps, CTO |
| 8 | **agent-calendar** | Cal.com webhook | Sauvegarde RDV dans Mem0 sous "calendar" | CEO, CPO |
| 9 | **memory-propagation** | Mem0 webhook/poll | Detecte decisions CTO → cree issues Paperclip | CTO → tous |
| 10 | **knowledge-digest** | Schedule hebdo | Mem0 stats → resume → Chroma index | Researcher |
| 11 | **security-alert** | CrowdSec webhook | ntfy alerte → Mem0 save incident → issue Paperclip | Security |
| 12 | **backup-report** | Duplicati webhook | Mem0 save status backup | DevOps |

### 3.4 URL du webhook n8n pour les agents

Chaque agent aura dans son prompt :
```
### n8n (automatisation)
- Webhook: https://n8n.home/webhook/agent-event
- Auth: Header X-N8N-Agent-Key: $N8N_AGENT_KEY
- Format:
  {
    "agent": "ton_user_id",
    "event": "deploy|notify|scrape|git|crm|...",
    "task_id": "$PAPERCLIP_TASK_ID",
    "payload": { ... }
  }
```

---

## 4. Ameliorations memoire inter-agents

### 4.1 Probleme central : pas de "reactive memory"

Actuellement les agents font du **polling** (lecture au reveil). Il faut passer a un modele **event-driven** :

```
POLLING (actuel) :                    EVENT-DRIVEN (propose) :

Agent wake up                         Agent wake up
  ↓                                     ↓
Search Mem0                           Search Mem0
  ↓                                     ↓
Execute task                          Execute task
  ↓                                     ↓
Save to Mem0                          Save to Mem0
  ↓                                     ↓
Sleep                                 n8n detecte le save
                                        ↓
                                      n8n verifie qui est impacte
                                        ↓
                                      n8n cree issue Paperclip
                                      pour chaque agent impacte
                                        ↓
                                      Agent impacte se reveille
                                      (wakeOnAssignment)
```

### 4.2 Nouveau endpoint Mem0 : webhooks

Ajouter a `server.py` :

```
POST /webhooks/register
{
  "url": "https://n8n.home/webhook/memory-event",
  "events": ["memory.created", "memory.updated", "memory.state_changed"],
  "filter": {
    "user_ids": ["cto", "ceo"],      // optionnel : seulement certains agents
    "types": ["decision", "architecture"]  // optionnel : seulement certains types
  }
}

// Quand un event se produit, Mem0 POST vers l'URL :
{
  "event": "memory.state_changed",
  "memory_id": "xxx",
  "user_id": "cto",
  "metadata": { "type": "architecture", "state": "deprecated", "supersedes": "yyy" },
  "timestamp": "2026-03-10T15:00:00Z"
}
```

### 4.3 Nouveau endpoint Mem0 : relations entre memoires

```
POST /memories/{id}/link
{
  "target_id": "other_memory_id",
  "relation": "supersedes|depends_on|contradicts|implements|refines"
}

GET /memories/{id}/graph
// Retourne le graphe de relations d'une memoire
{
  "memory_id": "xxx",
  "links": [
    {"target": "yyy", "relation": "supersedes", "direction": "outgoing"},
    {"target": "zzz", "relation": "depends_on", "direction": "incoming"}
  ]
}
```

### 4.4 Nouveau endpoint Mem0 : timeline

```
GET /timeline/{user_id}?since=2026-03-09&types=decision,architecture
// Retourne les memoires recentes triees par date
[
  {"id": "xxx", "text": "...", "metadata": {...}, "created": "2026-03-10T14:00:00Z"},
  {"id": "yyy", "text": "...", "metadata": {...}, "created": "2026-03-10T10:00:00Z"}
]
```

### 4.5 Nouveau endpoint Mem0 : conflicts

```
GET /conflicts?user_ids=lead-backend,lead-frontend
// Detecte les memoires actives contradictoires entre agents
[
  {
    "memory_a": {"id": "xxx", "user_id": "lead-backend", "text": "REST API with versioning"},
    "memory_b": {"id": "yyy", "user_id": "lead-frontend", "text": "GraphQL single endpoint"},
    "similarity": 0.85,
    "conflict_type": "contradicts"
  }
]
```

### 4.6 Score de pertinence contextuel

Ajouter au `/search/filtered` un scoring qui prend en compte :

```python
score = (
    semantic_similarity * 0.4      # pertinence semantique
    + recency_score * 0.2          # memoires recentes > anciennes
    + confidence_score * 0.2       # validated > tested > hypothesis
    + cross_reference_score * 0.2  # memoires tres referencees > isolees
)
```

---

## 5. Nouveau protocole propose

### 5.1 Protocole v3 : "Reactive Knowledge Network"

#### Principes

1. **Event-driven** : chaque ecriture memoire declenche une reaction (via n8n)
2. **Contextual** : les agents chargent le contexte serveur (analytics, monitoring, CRM) pas seulement Mem0
3. **Linked** : les memoires sont liees entre elles (graphe, pas liste)
4. **Multi-layer read** : chaque agent lit les 3 couches (Mem0 + Chroma + n8n data)
5. **Real-world actions** : les agents peuvent agir sur le serveur via n8n

#### Procedure agent v3 (remplace v2)

```
## PROCEDURE A CHAQUE REVEIL (v3)

### Etape 0 : Charger le contexte COMPLET

# 0a. Tes memoires actives (Mem0 L1)
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -d '{"query": "...", "user_id": "TON_ID", "filters": {"state": {"$eq": "active"}}, "limit": 10}'

# 0b. Contexte cross-agent (Mem0 L1)
curl -X POST "http://host.docker.internal:8050/search/multi" \
  -d '{"query": "...", "user_ids": ["cto", "..."], "limit_per_user": 3}'

# 0c. Timeline recente (NOUVEAU — ce qui a change depuis ton dernier reveil)
curl "http://host.docker.internal:8050/timeline/ALL?since=LAST_WAKE_TIME&types=decision,architecture"

# 0d. Etat des services (via n8n → Mem0 "monitoring")
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -d '{"query": "service status health", "user_id": "monitoring", "filters": {"state": {"$eq": "active"}}, "limit": 5}'

# 0e. Donnees business si pertinent (via n8n → Mem0 "analytics")
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -d '{"query": "analytics metriques usage", "user_id": "analytics", "filters": {"state": {"$eq": "active"}}, "limit": 3}'

### Etape 1 : Checkout tache Paperclip (inchange)

### Etape 2 : Recherche multi-couche AVANT d'implementer
# 2a. Mem0 (memoire de travail)
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -d '{"query": "[sujet de la tache]", "user_id": "TON_ID", ...}'

# 2b. Chroma direct (code, conventions, architecture)
# Via Ollama embedding → Chroma query sur collection "project-docs"

### Etape 3 : Implementer (inchange)

### Etape 4 : Sauvegarder avec LIENS
# 4a. Sauvegarder dans Mem0 (dedup + metadata obligatoires)
# 4b. Si c'est une decision : lier aux memoires impactees
curl -X POST "http://host.docker.internal:8050/memories/NEW_ID/link" \
  -d '{"target_id": "OLD_ID", "relation": "supersedes"}'

### Etape 5 : Declencher des actions via n8n (NOUVEAU)
# Si deploiement necessaire :
curl -X POST "https://n8n.home/webhook/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -d '{"agent": "TON_ID", "event": "deploy", "task_id": "$TASK_ID", "payload": {"repo": "...", "branch": "main"}}'

# Si notification necessaire :
curl -X POST "https://n8n.home/webhook/agent-event" \
  -d '{"agent": "TON_ID", "event": "notify", "payload": {"message": "...", "channel": "ntfy|email", "to": "zahid"}}'

# Si scraping necessaire :
curl -X POST "https://n8n.home/webhook/agent-event" \
  -d '{"agent": "TON_ID", "event": "scrape", "payload": {"url": "...", "index_in": "chroma"}}'

### Etape 6 : Reporter (inchange, Paperclip)
```

### 5.2 Matrice d'utilisation des couches par agent (v3)

| Agent | Mem0 (L1) | Chroma (L2) | n8n (L3) |
|-------|-----------|-------------|----------|
| **CEO** | R/W decisions | - | notify, calendar |
| **CTO** | R/W architecture | R/W conventions | notify, status, memory-propagation |
| **CPO** | R/W specs | - | notify, crm-sync, analytics, calendar |
| **CFO** | R/W budgets | - | analytics, crm-sync |
| **Backend** | R/W patterns | R codebase | git, deploy, notify |
| **Frontend** | R/W composants | R codebase | git, deploy, notify |
| **DevOps** | R/W configs | - | **deploy, git, status, backup, notify** |
| **Security** | R/W vulns | R codebase | security-alert, notify |
| **QA** | R/W bugs | - | deploy (test), notify |
| **Designer** | R/W tokens | - | notify |
| **Researcher** | R/W findings | R/W rapports | **scrape, notify, digest** |

### 5.3 Agents "systeme" dans Mem0 (user_ids virtuels)

n8n alimente Mem0 sous des user_ids speciaux que tous les agents peuvent lire :

| user_id | Alimente par | Contenu | Frequence |
|---------|-------------|---------|-----------|
| `monitoring` | n8n ← Uptime Kuma | Status services, uptimes, incidents | Toutes les 5 min |
| `analytics` | n8n ← Umami | Pages vues, visitors, top pages, conversions | Toutes les heures |
| `calendar` | n8n ← Cal.com | RDV a venir, bookings recents | Webhook temps reel |
| `crm` | n8n ← Twenty | Nouveaux leads, deals en cours, pipeline | Webhook temps reel |
| `security-events` | n8n ← CrowdSec | Attaques detectees, IPs bloquees | Webhook temps reel |
| `deployments` | n8n ← Dokploy | Deployments recents, status, logs | Webhook temps reel |
| `git-events` | n8n ← Gitea | Commits, PRs, issues recentes | Webhook temps reel |

### 5.4 Workflow de propagation automatique (via n8n)

```
Etape 1 : Agent CTO sauvegarde une decision "architecture" dans Mem0
  ↓
Etape 2 : Mem0 webhook → n8n (workflow "memory-propagation")
  ↓
Etape 3 : n8n lit la decision :
  - metadata.type == "decision" || "architecture"
  - metadata.user_id == "cto"
  ↓
Etape 4 : n8n determine les agents impactes (matrice permissions)
  - CTO decision → impacte : backend, frontend, devops, security, qa
  ↓
Etape 5 : Pour chaque agent impacte, n8n cree une issue Paperclip :
  POST /api/companies/{id}/issues
  {
    "title": "[AUTO] Architecture modifiee : [titre decision]",
    "body": "Le CTO a modifie l'architecture. Memory ID: xxx.\n\nACTION: Lire la memoire et adapter ton travail.",
    "assignee": "lead-backend",
    "status": "todo",
    "labels": ["auto-propagation", "architecture"]
  }
  ↓
Etape 6 : Paperclip reveille l'agent (wakeOnAssignment: true)
  ↓
Etape 7 : L'agent lit la decision du CTO et s'adapte
```

**Temps de propagation** : ~30 secondes (vs 5-15 min avec le polling actuel)

---

## 6. Plan d'implementation

### Phase A : Connecter n8n aux agents (priorite 1)

| # | Tache | Effort | Impact |
|---|-------|--------|--------|
| A1 | Creer 12 workflows n8n (Section 3.3) | Moyen | **ENORME** — debloque tout |
| A2 | Ajouter section "n8n" dans chaque prompt agent | Leger | Les agents savent appeler n8n |
| A3 | Configurer les webhooks Gitea → n8n (si pas deja fait) | Leger | CI/CD |
| A4 | Configurer Uptime Kuma → n8n (si pas deja fait) | Leger | Monitoring reactif |
| A5 | Creer les user_ids systeme dans Mem0 (monitoring, analytics, etc.) | Leger | Contexte reel |

### Phase B : Ameliorer Mem0 server.py (priorite 2)

| # | Tache | Effort | Impact |
|---|-------|--------|--------|
| B1 | `POST /webhooks/register` — notifications sortantes | Moyen | Event-driven |
| B2 | `POST /memories/{id}/link` — relations entre memoires | Moyen | Graphe de connaissances |
| B3 | `GET /memories/{id}/graph` — visualiser les liens | Leger | Debug et comprehension |
| B4 | `GET /timeline/{user_id}` — memoires recentes | Leger | "Quoi de neuf" |
| B5 | `GET /conflicts` — detection automatique | Moyen | Qualite |
| B6 | Scoring contextuel dans `/search/filtered` | Moyen | Pertinence |

### Phase C : Exploiter Chroma (priorite 3)

| # | Tache | Effort | Impact |
|---|-------|--------|--------|
| C1 | Creer des collections Chroma par projet (pas juste "mem0") | Leger | Separation |
| C2 | Workflow n8n : Firecrawl → Chroma (scraping auto) | Moyen | Knowledge enrichie |

### Phase D : Optimisations (priorite 4)

| # | Tache | Effort | Impact |
|---|-------|--------|--------|
| D1 | Rate limiting dans server.py (eviter flood d'un agent) | Leger | Stabilite |
| D2 | TTL/expiration automatique des memoires temporaires | Leger | Nettoyage |
| D3 | Dashboard Mem0 (vue web des stats, graphe, timeline) | Lourd | Observabilite |
| D4 | Permission enforcement cote serveur (pas juste agent honor) | Moyen | Securite |

---

## Annexe A : Impact de chaque amelioration sur les workflows STACK.md

| Workflow STACK.md | Etat actuel | Avec n8n integre |
|-------------------|-------------|-------------------|
| WF1 Dictee→Code→Deploy | Agents codent mais ne deploient pas | Agent DevOps → n8n → Dokploy → Playwright → ntfy |
| WF2 CI/CD | Gitea→n8n→Dokploy sans agents | Agent push → Gitea → n8n → Dokploy → Agent QA teste |
| WF3 Lead→CRM→Email | n8n seul | Agent CPO → n8n → Twenty CRM → BillionMail |
| WF4 Monitoring→Alerte | Uptime Kuma→n8n→ntfy sans agents | + Mem0 "monitoring" → Agent DevOps reagit |
| WF5 Scraping→Knowledge | n8n→Firecrawl sans agents | Agent Researcher → n8n → Firecrawl → Chroma |
| WF6 Securite | CrowdSec→n8n→ntfy sans agents | + Mem0 "security-events" → Agent Security reagit |
| WF7 Backup | Duplicati seul | + Mem0 "deployments" → Agent DevOps verifie |
| WF8 Planning→CRM | Cal.com→n8n sans agents | + Mem0 "calendar" → Agent CEO/CPO voient les RDV |

## Annexe B : Vue synthetique des protocoles

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROTOCOLE AGENT v3                             │
│                                                                   │
│  ┌───────────┐    ┌───────────┐    ┌───────────┐               │
│  │ v1 (base) │ +  │ v2 (mem)  │ +  │ v3 (event)│               │
│  │           │    │           │    │           │               │
│  │ • Checkout│    │ • Metadata│    │ • n8n bus │               │
│  │ • Execute │    │ • Lifecycle│    │ • Webhooks│               │
│  │ • Report  │    │ • Dedup   │    │ • Links   │               │
│  │           │    │ • Decision│    │ • Timeline│               │
│  │           │    │ • Cross-  │    │ • Conflicts│              │
│  │           │    │   agent   │    │ • Scoring │               │
│  │           │    │ • Confiden│    │ • 5 layers│               │
│  └───────────┘    └───────────┘    └───────────┘               │
│                                                                   │
│  13-memory-protocol.md    14-knowledge-workflows.md              │
│  15-rapport-stack-analyse.md (ce fichier)                        │
│  16-n8n-agent-workflows.md (a creer)                             │
│  17-mem0-v3-endpoints.md (a creer)                               │
└─────────────────────────────────────────────────────────────────┘
```

## Annexe C : Metriques de succes

| Metrique | Actuel (v2) | Cible (v3) | Comment mesurer |
|----------|-------------|------------|-----------------|
| Temps de propagation d'une decision | 5-15 min (heartbeat) | < 1 min (webhook) | Timestamp decision → timestamp issue creee |
| Couches memoire utilisees par agent | 1 (Mem0 seulement) | 3 (toutes) | GET /stats + logs n8n |
| Actions serveur par agent | 0 (aucune) | 3-5 par tache | Logs n8n webhooks |
| Memoires avec liens | 0% | > 50% des decisions | GET /memories/{id}/graph |
| Conflits detectes automatiquement | 0 | 100% | GET /conflicts |
| Contexte serveur dans decisions | 0% | > 80% | Mem0 metadata source=monitoring/analytics |
