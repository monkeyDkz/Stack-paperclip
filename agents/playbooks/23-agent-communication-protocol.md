# Protocole de communication inter-agents

> Reference complementaire : [13-memory-protocol.md](./13-memory-protocol.md), [14-knowledge-workflows.md](./14-knowledge-workflows.md), [16-n8n-agent-workflows.md](./16-n8n-agent-workflows.md)

Ce document definit les regles de communication entre les 16 agents Paperclip. Chaque agent DOIT suivre ces protocoles pour collaborer efficacement.

---

## Table des matieres

1. [Canaux de communication](#1-canaux-de-communication)
2. [Matrice de visibilite Mem0](#2-matrice-de-visibilite-mem0)
3. [Protocole de delegation](#3-protocole-de-delegation-5-etapes)
4. [Protocole d'escalade](#4-protocole-descalade)
5. [Pattern multi-agent](#5-pattern-multi-agent-collaboration)
6. [Anti-patterns a eviter](#6-anti-patterns-a-eviter)
7. [Timeouts et SLAs](#7-timeouts-et-slas)

---

## 1. Canaux de communication

### Les 4 canaux

| Canal | Usage | QUAND utiliser |
|-------|-------|----------------|
| **Paperclip Issues** | Delegation formelle : creation de tache, checkout, release, commentaires | Toute action executable — une tache concrete a accomplir |
| **Mem0 memories** | Partage de knowledge persistant : decisions, conventions, learnings | Information durable utile aux autres agents — doit survivre a la session |
| **SiYuan docs** | Documentation structuree long terme : specs, guidelines, rapports, dashboards | Contenu reference qui sera consulte regulierement — documentation officielle |
| **n8n webhooks** | Notifications event-driven : deploy, alerte securite, CRM, calendrier | Evenement necessitant une reaction immediate — pas de polling |

### Format n8n webhook

```bash
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "Content-Type: application/json" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -d '{
    "event": "deploy-completed",
    "agent": "devops",
    "task_id": "ea0bc1a8-xxxx",
    "payload": {
      "service": "api-backend",
      "version": "1.2.0",
      "status": "success"
    }
  }'
```

### Arbre de decision : quel canal utiliser ?

```
L'information concerne...

├── Une TACHE a realiser ?
│   └── → Paperclip Issue
│       Exemples : implementer une feature, corriger un bug, faire un deploy
│
├── Un SAVOIR a retenir ?
│   ├── Court et factuel (decision, learning, convention) ?
│   │   └── → Mem0 memory
│   │       Exemples : "on utilise PostgreSQL", "ce pattern cause des bugs"
│   │
│   └── Long et structure (spec, rapport, guide) ?
│       └── → SiYuan document
│           Exemples : PRD, ADR, rapport d'audit, dashboard metriques
│
└── Un EVENEMENT a signaler ?
    └── → n8n webhook
        Exemples : deploy termine, alerte securite, nouveau lead CRM
```

### Regles strictes

1. **Ne jamais utiliser un canal pour un usage qui ne lui correspond pas.** Pas de taches dans Mem0. Pas de knowledge ephemere dans SiYuan.
2. **Toujours associer un `task_id` Paperclip** quand une memory ou un webhook est lie a une tache en cours.
3. **Un seul canal par action.** Si une tache genere un learning, creer la tache dans Paperclip ET le learning dans Mem0 — deux actions distinctes.

---

## 2. Matrice de visibilite Mem0

Chaque agent lit les memories de certains `user_id` Mem0 (incluant les user_ids systeme alimentes par n8n). Cette matrice definit QUI lit QUI.

### Tableau complet

| Agent | Lit les memories de (`user_id`) |
|-------|-------------------------------|
| **CEO** | `cto`, `cpo`, `cfo`, `monitoring`, `analytics`, `crm` |
| **CTO** | `ceo`, `lead-backend`, `lead-frontend`, `devops`, `security`, `qa`, `monitoring`, `deployments`, `git-events` |
| **CPO** | `ceo`, `cto`, `designer`, `growth-lead`, `analytics`, `crm`, `calendar` |
| **CFO** | `ceo`, `analytics`, `crm` |
| **Lead Backend** | `cto`, `lead-frontend`, `qa`, `monitoring`, `git-events` |
| **Lead Frontend** | `cto`, `lead-backend`, `designer`, `qa`, `monitoring`, `git-events` |
| **DevOps** | `cto`, `security`, `monitoring`, `deployments`, `git-events`, `security-events` |
| **Security** | `cto`, `lead-backend`, `lead-frontend`, `devops`, `researcher`, `security-events`, `monitoring` |
| **QA** | `cto`, `lead-backend`, `lead-frontend`, `monitoring` |
| **Designer** | `cpo` |
| **Researcher** | `cto`, `monitoring` |
| **Growth Lead** | `cpo`, `seo`, `content-writer`, `data-analyst`, `sales-automation`, `analytics`, `crm`, `calendar` |
| **SEO Specialist** | `growth-lead`, `data-analyst`, `analytics` |
| **Content Writer** | `growth-lead`, `seo` |
| **Data Analyst** | `growth-lead`, `analytics`, `crm`, `calendar` |
| **Sales Automation** | `growth-lead`, `data-analyst`, `crm`, `calendar`, `analytics` |

### Lecture visuelle (qui voit qui)

```
                    monitoring  analytics  crm  calendar  deployments  git-events  security-events
CEO                     x          x        x
CTO                     x                                    x            x
CPO                                x        x      x
CFO                                x        x
Lead Backend            x                                                 x
Lead Frontend           x                                                 x
DevOps                  x                                    x            x              x
Security                x                                                                x
QA                      x
Designer
Researcher              x
Growth Lead                        x        x      x
SEO Specialist                     x
Data Analyst                       x        x      x
Sales Automation                   x        x      x
```

### Regles de visibilite

1. **Aucun agent ne lit ses propres memories** — il les connait deja.
2. **Les user_ids systeme** (`monitoring`, `analytics`, `crm`, `calendar`, `deployments`, `git-events`, `security-events`) sont alimentes par les workflows n8n, pas par des agents directement.
3. **La visibilite est unidirectionnelle.** Le CEO lit le CTO, mais le CTO ne lit pas forcement le CEO (sauf si c'est explicite dans la matrice).
4. **Pour partager un learning avec un agent qui ne vous lit pas**, passer par un intermediaire ou creer une Paperclip issue.

---

## 3. Protocole de delegation (5 etapes)

### Etape 1 — Recherche contexte

Le demandeur (requester) cherche dans Mem0 les memories liees au sujet avant de deleguer.

```bash
# Rechercher le contexte existant
curl -X POST "http://host.docker.internal:8050/memories/search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "authentication JWT implementation patterns",
    "user_id": "lead-backend",
    "limit": 10
  }'
```

**Objectif** : eviter de deleguer une tache deja resolue, et fournir le contexte pertinent a l'assignee.

### Etape 2 — Creation tache

Le demandeur cree une Paperclip issue avec tout le contexte necessaire.

```bash
curl -X POST "http://host.docker.internal:8060/api/issues" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Implementer authentification JWT pour API v2",
    "description": "Ajouter le middleware JWT sur toutes les routes protegees de l API v2.",
    "assignee": "lead-backend",
    "priority": "high",
    "context_memories": [
      "mem_a1b2c3d4",
      "mem_e5f6g7h8"
    ],
    "acceptance_criteria": [
      "Middleware JWT actif sur /api/v2/*",
      "Tests unitaires couvrant expiration et refresh",
      "Documentation OpenAPI mise a jour",
      "Aucune regression sur les routes existantes"
    ]
  }'
```

**Champs obligatoires** :
- `title` : titre clair et actionnable
- `description` : contexte suffisant pour que l'assignee comprenne sans poser de questions
- `context_memories` : liste des memory IDs pertinents trouves a l'etape 1
- `acceptance_criteria` : criteres mesurables de validation

### Etape 3 — Checkout

L'assignee prend en charge la tache et charge le contexte memoire.

```bash
# Checkout de la tache
curl -X POST "http://host.docker.internal:8060/api/issues/{issue_id}/checkout" \
  -H "Content-Type: application/json" \
  -d '{
    "agent": "lead-backend"
  }'

# Charger le contexte des memories referencees
for mem_id in mem_a1b2c3d4 mem_e5f6g7h8; do
  curl "http://host.docker.internal:8050/memories/$mem_id"
done
```

**Regles** :
- L'assignee DOIT lire les `context_memories` avant de commencer
- Le checkout marque la tache comme "en cours" — un seul agent a la fois

### Etape 4 — Execution et livraison

L'assignee travaille sur la tache. Pendant l'execution :

```bash
# Sauvegarder un learning en cours de route
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "LEARNING: Le middleware JWT doit etre place AVANT le rate-limiter dans la chaine Express, sinon les tokens expires ne sont pas interceptes correctement.",
    "user_id": "lead-backend",
    "metadata": {
      "type": "learning",
      "project": "api-v2",
      "confidence": "tested",
      "source_task": "issue-uuid-xxxx"
    }
  }'

# Livrer le resultat
curl -X POST "http://host.docker.internal:8060/api/issues/{issue_id}/deliver" \
  -H "Content-Type: application/json" \
  -d '{
    "agent": "lead-backend",
    "result": "JWT middleware implemente et teste. PR #42 prete.",
    "learnings_saved": ["mem_new_id_1"]
  }'
```

**Regles** :
- Toujours sauvegarder au moins un learning dans Mem0 (meme si tout s'est bien passe)
- Inclure les IDs des nouvelles memories dans la livraison
- Si la tache echoue, sauvegarder un learning de type `bug` ou `learning` expliquant l'echec

### Etape 5 — Validation

Le demandeur verifie le resultat contre les criteres d'acceptation.

```bash
# Valider la tache
curl -X POST "http://host.docker.internal:8060/api/issues/{issue_id}/validate" \
  -H "Content-Type: application/json" \
  -d '{
    "agent": "cto",
    "status": "accepted",
    "comment": "JWT fonctionne correctement. Learning pertinent sauvegarde."
  }'

# OU demander des corrections
curl -X POST "http://host.docker.internal:8060/api/issues/{issue_id}/validate" \
  -H "Content-Type: application/json" \
  -d '{
    "agent": "cto",
    "status": "changes_requested",
    "comment": "Le refresh token n est pas gere. Ajouter le endpoint /auth/refresh."
  }'
```

**Regles** :
- `accepted` : la tache est close, les memories restent actives
- `changes_requested` : la tache retourne a l'etape 4, l'assignee conserve le checkout
- Jamais plus de 2 cycles de corrections — au-dela, escalader

---

## 4. Protocole d'escalade

### Chemins d'escalade par domaine

```
TECHNIQUE
  Engineer (Backend/Frontend) → Lead (Backend/Frontend) → CTO → CEO

PRODUIT
  Designer / Lead → CPO → CEO

GROWTH
  SEO / Content Writer / Data Analyst / Sales Automation → Growth Lead → CPO → CEO

SECURITE (URGENT — bypass hierarchie)
  N'importe quel agent → Security → CTO → CEO

FINANCE
  N'importe quel agent → CFO → CEO
```

### Triggers d'escalade

| Trigger | Action |
|---------|--------|
| **Blocker** > 1 heartbeat cycle sans resolution | Escalader au niveau superieur |
| **Decision hors scope** du role de l'agent | Escalader au decideur competent |
| **Conflit** entre 2 agents de meme niveau | Escalader a leur superieur commun |
| **Incident securite** | Escalade IMMEDIATE a Security, puis CTO, puis CEO |

### Format d'escalade

```bash
# Creer une issue d'escalade
curl -X POST "http://host.docker.internal:8060/api/issues" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "[ESCALADE] Blocker sur migration DB - besoin decision CTO",
    "description": "La migration PostgreSQL 15 → 16 cause des incompatibilites avec pg_trgm. Bloque depuis 2 heartbeats. Besoin decision : rollback ou patch manuel.",
    "assignee": "cto",
    "priority": "urgent",
    "escalated_from": "lead-backend",
    "original_task": "issue-uuid-original",
    "context_memories": ["mem_xxx", "mem_yyy"]
  }'
```

### Regles d'escalade

1. **Toujours joindre le contexte** : memories, tentatives de resolution, options envisagees
2. **Ne jamais escalader a vide** — documenter ce qui a ete essaye
3. **Securite : pas besoin de justifier** — en cas de doute, escalader immediatement
4. **L'agent qui escalade reste disponible** pour fournir des informations supplementaires

---

## 5. Pattern multi-agent (collaboration)

Quand 2 ou plusieurs agents doivent collaborer sur un meme objectif.

### Roles

| Role | Responsabilite | Qui typiquement |
|------|---------------|-----------------|
| **Coordinateur** | Possede le workflow, decompose en sous-taches, aggrege les resultats | Lead (Backend/Frontend), CTO, CPO |
| **Contributeur** | Execute une sous-tache specifique, livre son resultat au coordinateur | Tout agent assigne |

### Deroulement

```
1. DECOMPOSITION
   Le coordinateur identifie les sous-taches et les assigne.

   Coordinateur (CTO)
   ├── Sous-tache A → Lead Backend
   ├── Sous-tache B → Lead Frontend
   └── Sous-tache C → DevOps

2. TAGGING PARTAGE
   Toutes les memories liees sont taguees avec le meme projet et la meme phase.

   metadata: {
     "project": "migration-api-v2",
     "phase": "implementation",
     "tags": "multi-agent,sprint-3"
   }

3. EXECUTION PARALLELE
   Chaque contributeur travaille sur sa sous-tache independamment.
   Les contributeurs sauvent leurs learnings dans Mem0.

4. POINT DE SYNCHRONISATION
   Le coordinateur verifie que TOUTES les sous-taches sont livrees
   avant de passer a la phase suivante.

   Checklist :
   ☐ Sous-tache A livree et validee
   ☐ Sous-tache B livree et validee
   ☐ Sous-tache C livree et validee

5. MERGE ET LIVRAISON
   Le coordinateur aggrege les resultats, resout les conflits eventuels,
   et livre le resultat final au demandeur initial.
```

### Exemple concret : nouvelle feature full-stack

```bash
# Le CTO cree la tache principale
curl -X POST "http://host.docker.internal:8060/api/issues" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Feature: tableau de bord utilisateur",
    "description": "Implementer le dashboard utilisateur (API + UI + deploy)",
    "assignee": "cto",
    "subtasks": [
      {
        "title": "API endpoints dashboard",
        "assignee": "lead-backend",
        "acceptance_criteria": ["GET /api/v1/dashboard", "Tests > 80%"]
      },
      {
        "title": "UI composants dashboard",
        "assignee": "lead-frontend",
        "acceptance_criteria": ["Composants React", "Responsive", "Tests Storybook"]
      },
      {
        "title": "Pipeline deploy dashboard",
        "assignee": "devops",
        "acceptance_criteria": ["CI/CD configure", "Staging deploye"]
      }
    ]
  }'
```

### Regles de collaboration

1. **Un seul coordinateur par workflow** — jamais de co-pilotage
2. **Les contributeurs ne communiquent pas directement entre eux** — tout passe par le coordinateur via Paperclip issues
3. **Le tag `project` doit etre identique** sur toutes les memories liees
4. **Le coordinateur est responsable des deadlines** et de l'escalade si un contributeur est bloque

---

## 6. Anti-patterns a eviter

### 6.1 Appels directs agent-a-agent

**Interdit** : un agent parle directement a un autre agent sans passer par Paperclip.

**Pourquoi** : pas de tracabilite, pas de priorisation, pas de visibilite pour les autres agents.

**Correct** : toujours creer une Paperclip issue, meme pour une petite demande.

### 6.2 Pollution memoire

**Interdit** : sauvegarder des etats intermediaires comme memories permanentes.

**Pourquoi** : le ratio signal/bruit degrade la qualite des recherches Mem0 pour tous les agents.

**Correct** : ne sauvegarder que les decisions finales, learnings confirmes, et conventions validees. Utiliser `confidence: "hypothesis"` si l'information n'est pas encore confirmee.

### 6.3 Echecs silencieux

**Interdit** : echouer sur une tache sans sauvegarder un learning.

**Pourquoi** : le meme echec sera repete par un autre agent (ou le meme agent plus tard).

**Correct** : toujours sauvegarder un learning de type `bug` ou `learning` expliquant ce qui a echoue et pourquoi.

```bash
# Exemple : sauvegarder un echec
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "LEARNING: La librairie X v3.2 est incompatible avec Node 20. Erreur: segfault au demarrage. Contournement: utiliser la v3.1 en attendant le fix upstream.",
    "user_id": "lead-backend",
    "metadata": {
      "type": "bug",
      "project": "api-v2",
      "confidence": "tested",
      "source_task": "issue-uuid-xxxx"
    }
  }'
```

### 6.4 Escalade prematuree

**Interdit** : escalader des le premier obstacle sans tenter de resoudre.

**Pourquoi** : surcharge les agents de niveau superieur et ralentit tout le systeme.

**Correct** : tenter au moins une solution, documenter la tentative, puis escalader avec le contexte complet.

### 6.5 Duplication de taches

**Interdit** : creer une tache sans verifier si elle existe deja.

**Pourquoi** : deux agents travaillent sur le meme probleme en parallele, gaspillage de ressources.

**Correct** : toujours rechercher dans Mem0 et les issues Paperclip existantes avant de creer une nouvelle tache.

```bash
# Verifier avant de creer
curl -X POST "http://host.docker.internal:8050/memories/search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "migration postgresql 16",
    "user_id": "lead-backend",
    "limit": 5
  }'
```

---

## 7. Timeouts et SLAs

### Delais de resolution

| Type de tache | SLA | Exemple |
|---------------|-----|---------|
| **Tache simple** | < 2 heartbeat cycles | Corriger un typo, ajouter un test, mettre a jour une config |
| **Tache complexe** | < 5 heartbeat cycles | Implementer une feature, refactorer un module, audit securite |
| **Incident securite** | Immediat | Vulnerabilite critique, fuite de donnees |

### Mecanisme de timeout

```
Tache creee
    │
    ▼
[Heartbeat 1] ─── En cours ? → Oui → Continuer
    │                           Non → Rappel a l'assignee
    ▼
[Heartbeat 2] ─── En cours ? → Oui → Continuer (tache simple : TIMEOUT)
    │                           Non → Escalade au superieur
    ▼
[Heartbeat 3-5] ── En cours ? → Oui → Continuer (tache complexe : TIMEOUT a HB5)
    │                            Non → Escalade au superieur
    ▼
[> 24h sans activite] ──────── → Notification CEO automatique
```

### Regles de timeout

1. **Heartbeat cycle** = intervalle defini dans la configuration Paperclip de chaque agent
2. **Tache simple depassant 2 cycles** : escalade automatique au superieur hierarchique
3. **Tache complexe depassant 5 cycles** : escalade automatique au superieur hierarchique
4. **Toute tache > 24h sans activite** : notification directe au CEO via n8n webhook
5. **L'agent en timeout doit sauvegarder un learning** expliquant pourquoi la tache n'a pas pu etre completee dans les delais

### Notification timeout (via n8n)

```bash
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "Content-Type: application/json" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -d '{
    "event": "task-timeout",
    "agent": "lead-backend",
    "task_id": "issue-uuid-xxxx",
    "payload": {
      "heartbeats_elapsed": 3,
      "sla_type": "simple",
      "escalated_to": "cto"
    }
  }'
```
