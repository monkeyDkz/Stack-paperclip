# Workflows n8n pour les agents — Reference complete

Ce document definit les 21 workflows n8n qui connectent les agents IA (Mac via Paperclip) aux services d'infrastructure reels (serveur via n8n a `https://n8n.home`).

---

## Table des matieres

1. [Architecture globale](#1-architecture-globale)
2. [Authentification](#2-authentification)
3. [Pattern webhook unique](#3-pattern-webhook-unique)
4. [User IDs systeme dans Mem0](#4-user-ids-systeme-dans-mem0)
5. [Les 21 workflows](#5-les-21-workflows)
   - [5.1 agent-deploy](#51-agent-deploy)
   - [5.2 agent-notify](#52-agent-notify)
   - [5.3 agent-scrape](#53-agent-scrape)
   - [5.4 agent-git](#54-agent-git)
   - [5.5 agent-crm-sync](#55-agent-crm-sync)
   - [5.6 agent-analytics](#56-agent-analytics)
   - [5.7 agent-status](#57-agent-status)
   - [5.8 agent-calendar](#58-agent-calendar)
   - [5.9 memory-propagation](#59-memory-propagation)
   - [5.10 knowledge-digest](#510-knowledge-digest)
   - [5.11 security-alert](#511-security-alert)
   - [5.12 backup-report](#512-backup-report)
   - [5.13 memory-to-siyuan](#513-memory-to-siyuan)
   - [5.14 siyuan-dashboard-services](#514-siyuan-dashboard-services)
   - [5.15 siyuan-dashboard-analytics](#515-siyuan-dashboard-analytics)
   - [5.16 siyuan-dashboard-activity](#516-siyuan-dashboard-activity)
   - [5.17 siyuan-lifecycle-sync](#517-siyuan-lifecycle-sync)
   - [5.18 siyuan-weekly-digest](#518-siyuan-weekly-digest)
   - [5.19 ai-agent-workflow](#519-ai-agent-workflow)
   - [5.20 agent-email-sequence](#520-agent-email-sequence)
   - [5.21 agent-lead-score](#521-agent-lead-score)
6. [Gestion des erreurs](#6-gestion-des-erreurs)

---

## 1. Architecture globale

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              MAC (local)                                │
│                                                                         │
│   ┌──────────────────────────────────────────┐                         │
│   │            Paperclip (port 8060)          │                         │
│   │                                           │                         │
│   │   CEO ─ CTO ─ CPO ─ CFO                  │                         │
│   │   Backend ─ Frontend ─ DevOps             │                         │
│   │   Security ─ QA ─ Designer ─ Researcher   │
│   │   Growth Lead ─ SEO ─ Content Writer      │
│   │   Data Analyst ─ Sales Automation          │                         │
│   └────────────────────┬─────────────────────┘                         │
│                        │                                                │
│          curl POST     │   (webhook sortant)                           │
│          X-N8N-Agent-Key                                               │
│                        │                                                │
│   ┌────────────────────▼─────────────────────┐                         │
│   │           Mem0 (port 8050)                │  ◄── n8n ecrit ici     │
│   │   user_ids systeme :                      │      via NetBird VPN   │
│   │   monitoring, analytics, calendar,        │                         │
│   │   crm, security-events, deployments,      │                         │
│   │   git-events                              │                         │
│   └──────────────────────────────────────────┘                         │
│                                                                         │
├─────────────────── NetBird VPN ─────────────────────────────────────────┤
│                                                                         │
│                            SERVEUR                                      │
│                                                                         │
│   ┌──────────────────────────────────────────┐                         │
│   │             n8n (port 5678)               │                         │
│   │         https://n8n.home                  │                         │
│   │                                           │                         │
│   │   21 workflows :                          │                         │
│   │   agent-deploy, agent-notify,             │                         │
│   │   agent-scrape, agent-git,                │                         │
│   │   agent-crm-sync, agent-analytics,        │                         │
│   │   agent-status, agent-calendar,           │                         │
│   │   memory-propagation, knowledge-digest,   │                         │
│   │   security-alert, backup-report,          │                         │
│   │   memory-to-siyuan, siyuan-dashboards,   │                         │
│   │   siyuan-lifecycle-sync,                  │                         │
│   │   siyuan-weekly-digest, ai-agent-workflow,│                         │
│   │   agent-email-sequence, agent-lead-score  │                         │
│   └────────────────────┬─────────────────────┘                         │
│                        │                                                │
│          ┌─────────────┼─────────────────────────────┐                 │
│          ▼             ▼             ▼                ▼                 │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│   │ Dokploy  │  │  ntfy    │  │ Firecrawl│  │ Twenty   │             │
│   │ (deploy) │  │ (notif)  │  │ (scrape) │  │  (CRM)   │             │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘             │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│   │Playwright│  │BillionMail│ │  Gitea   │  │  Umami   │             │
│   │ (tests)  │  │ (email)  │  │  (git)   │  │(analytics│             │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘             │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐                           │
│   │UptimeKuma│  │ Cal.com  │  │ CrowdSec │                           │
│   │(monitor) │  │(calendar)│  │(security)│                           │
│   └──────────┘  └──────────┘  └──────────┘                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Flux de donnees

```
Agent (Mac) ──POST webhook──► n8n (serveur) ──► Service cible (serveur)
                                    │
                                    └──POST Mem0──► Mem0 (Mac) sous user_id systeme
```

---

## 2. Authentification

Toute communication agent → n8n utilise le header `X-N8N-Agent-Key`.

### Configuration dans les prompts agents

Chaque agent a dans ses variables d'environnement :

```
N8N_WEBHOOK_URL=https://n8n.home/webhook
N8N_AGENT_KEY=$N8N_AGENT_KEY
```

### Validation cote n8n

Chaque workflow n8n commence par un noeud "Header Auth" qui verifie :
- Presence du header `X-N8N-Agent-Key`
- Valeur correspond a la cle configuree dans n8n
- Si invalide : retourne `401 Unauthorized` et log l'IP

### Securite

- La cle est partagee par tous les agents (pas de cle par agent)
- Le champ `agent` dans le payload identifie l'agent appelant
- Le trafic passe par NetBird VPN (chiffre)
- n8n n'est pas expose sur internet, seulement sur le reseau NetBird

---

## 3. Pattern webhook unique

**TOUS** les appels agent → n8n utilisent le meme endpoint et le meme format :

```bash
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "EVENT_TYPE",
    "agent": "USER_ID",
    "task_id": "PAPERCLIP_TASK_ID",
    "payload": { ... }
  }'
```

### Champs du message

| Champ | Obligatoire | Description |
|-------|:-----------:|-------------|
| `event` | Oui | Type d'evenement : `deploy`, `notify`, `scrape`, `git`, `crm-sync` |
| `agent` | Oui | Le `user_id` Mem0 de l'agent appelant (ex: `devops`, `cto`, `researcher`) |
| `task_id` | Non | L'ID de l'issue Paperclip en cours (pour tracabilite) |
| `payload` | Oui | Donnees specifiques au workflow (voir chaque workflow ci-dessous) |

### Routage dans n8n

n8n recoit tous les appels sur `/agent-event` et route vers le bon workflow via un noeud Switch sur `event` :
- `event: "deploy"` → workflow agent-deploy
- `event: "notify"` → workflow agent-notify
- `event: "scrape"` → workflow agent-scrape
- `event: "git"` → workflow agent-git
- `event: "crm-sync"` → workflow agent-crm-sync

---

## 4. User IDs systeme dans Mem0

n8n alimente Mem0 sous des `user_id` speciaux. Ces user_ids ne correspondent a aucun agent reel — ce sont des namespaces pour les donnees d'infrastructure.

| user_id | Alimente par | Contenu | Frequence |
|---------|-------------|---------|-----------|
| `monitoring` | n8n ← Uptime Kuma | Status services, uptimes, temps de reponse | Toutes les 5 min |
| `analytics` | n8n ← Umami | Pages vues, visiteurs, top pages, conversions | Toutes les heures |
| `calendar` | n8n ← Cal.com | RDV, bookings, noms, emails, types | Webhook temps reel |
| `crm` | n8n ← Twenty CRM | Contacts, deals, pipeline | Webhook temps reel |
| `security-events` | n8n ← CrowdSec | Attaques detectees, IPs bloquees, actions | Webhook temps reel |
| `deployments` | n8n ← Dokploy + Duplicati | Deployments recents, backups, status | Webhook temps reel |
| `git-events` | n8n ← Gitea | Branches creees, PRs, issues | Webhook temps reel |

### Lecture par les agents

Tout agent peut lire ces user_ids systeme :

```bash
# Exemple : DevOps verifie l'etat des services
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "service status health", "user_id": "monitoring", "filters": {"state": {"$eq": "active"}}, "limit": 5}'

# Exemple : CFO consulte les analytics
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "analytics visitors pages", "user_id": "analytics", "filters": {"state": {"$eq": "active"}}, "limit": 3}'
```

---

## 5. Les 19 workflows

---

### 5.1 agent-deploy

**Description** : Declenche un deploiement complet — build, tests e2e, notification, sauvegarde du resultat.

**Trigger** : Webhook POST depuis un agent (event: `deploy`)

**Agents qui l'utilisent** : DevOps, Backend, Frontend, QA

**Mem0 user_id ecrit** : `deployments`

#### Payload d'entree

```json
{
  "event": "deploy",
  "agent": "devops",
  "task_id": "PAPER-42",
  "payload": {
    "repo": "frontend-app",
    "branch": "main",
    "run_tests": true
  }
}
```

#### Etapes de traitement dans n8n

1. Recevoir le webhook et valider l'authentification
2. Appeler l'API Dokploy pour declencher le build et le deploiement du repo/branch
3. Attendre la fin du build (polling status Dokploy)
4. Si `run_tests: true` : lancer Playwright pour les tests e2e sur l'URL deployee
5. Collecter les resultats (build status, test results, URL deployee, duree)
6. Envoyer une notification ntfy avec le resultat (succes/echec)
7. Sauvegarder le resultat dans Mem0 sous `deployments`

#### Sauvegarde Mem0

```bash
# n8n execute cet appel automatiquement
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "DEPLOY: frontend-app branch main. Status: success. Tests: 42/42 passed. URL: https://app.home. Duree: 3min12s. Agent: devops. Task: PAPER-42",
    "user_id": "deployments",
    "metadata": {
      "type": "config",
      "project": "frontend-app",
      "confidence": "validated",
      "source_task": "PAPER-42",
      "tags": "deploy,success,tests-passed"
    }
  }'
```

#### Sortie / effets de bord

- Application deployee sur Dokploy
- Tests e2e executes (si demande)
- Notification ntfy envoyee a Zahid
- Memoire creee dans Mem0 sous `deployments`

#### Exemple curl pour les agents

```bash
# DevOps declenche un deploiement avec tests
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "deploy",
    "agent": "devops",
    "task_id": "'$PAPERCLIP_TASK_ID'",
    "payload": {
      "repo": "frontend-app",
      "branch": "main",
      "run_tests": true
    }
  }'

# Backend deploie sans tests
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "deploy",
    "agent": "lead-backend",
    "task_id": "'$PAPERCLIP_TASK_ID'",
    "payload": {
      "repo": "api-backend",
      "branch": "main",
      "run_tests": false
    }
  }'
```

---

### 5.2 agent-notify

**Description** : Envoie une notification push (ntfy) et/ou un email (BillionMail).

**Trigger** : Webhook POST depuis n'importe quel agent (event: `notify`)

**Agents qui l'utilisent** : Tous les agents

**Mem0 user_id ecrit** : Aucun

#### Payload d'entree

```json
{
  "event": "notify",
  "agent": "cto",
  "task_id": "PAPER-15",
  "payload": {
    "message": "Architecture modifiee : migration vers CockroachDB validee",
    "channel": "both",
    "to": "zahid",
    "priority": "high"
  }
}
```

#### Champs du payload

| Champ | Obligatoire | Valeurs | Description |
|-------|:-----------:|---------|-------------|
| `message` | Oui | texte libre | Le contenu de la notification |
| `channel` | Oui | `ntfy`, `email`, `both` | Canal de diffusion |
| `to` | Oui | `zahid` | Destinataire |
| `priority` | Non | `default`, `high`, `urgent` | Priorite ntfy (defaut: `default`) |

#### Etapes de traitement dans n8n

1. Recevoir le webhook et valider l'authentification
2. Si `channel` est `ntfy` ou `both` : envoyer notification push via ntfy avec le `priority` specifie
3. Si `channel` est `email` ou `both` : envoyer email via BillionMail API
4. Retourner `200 OK` avec confirmation

#### Sortie / effets de bord

- Notification push ntfy envoyee (si demande)
- Email BillionMail envoye (si demande)
- Pas de sauvegarde Mem0

#### Exemple curl pour les agents

```bash
# Notification push urgente
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "notify",
    "agent": "security",
    "task_id": "'$PAPERCLIP_TASK_ID'",
    "payload": {
      "message": "Vulnerabilite critique detectee dans la dependance jsonwebtoken",
      "channel": "ntfy",
      "to": "zahid",
      "priority": "urgent"
    }
  }'

# Email simple
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "notify",
    "agent": "cfo",
    "task_id": "'$PAPERCLIP_TASK_ID'",
    "payload": {
      "message": "Rapport mensuel des couts genere. Voir Mem0 user_id cfo, type report.",
      "channel": "email",
      "to": "zahid",
      "priority": "default"
    }
  }'
```

---

### 5.3 agent-scrape

**Description** : Scrape une URL en markdown via Firecrawl, sauvegarde dans Mem0 (memories) et cree un doc dans SiYuan.

**Trigger** : Webhook POST depuis un agent (event: `scrape`)

**Agents qui l'utilisent** : Researcher

**Mem0 user_id ecrit** : `researcher` (l'agent qui a declenche)

#### Payload d'entree

```json
{
  "event": "scrape",
  "agent": "researcher",
  "task_id": "PAPER-88",
  "payload": {
    "url": "https://blog.pragmaticengineer.com/data-infra-at-scale/",
    "title": "Data Infrastructure at Scale",
    "save_to": "both"
  }
}
```

#### Champs du payload

| Champ | Obligatoire | Valeurs | Description |
|-------|:-----------:|---------|-------------|
| `url` | Oui | URL valide | Page a scraper |
| `title` | Non | texte | Titre pour l'indexation (sinon extrait de la page) |
| `save_to` | Oui | `mem0`, `siyuan`, `both` | Ou sauvegarder le contenu |

#### Etapes de traitement dans n8n

1. Recevoir le webhook et valider l'authentification
2. Appeler l'API Firecrawl pour scraper l'URL en markdown
3. Nettoyer le contenu (supprimer navigation, footers, pubs)
4. Sauvegarder un resume dans Mem0 sous le user_id de l'agent (ex: `researcher`)
5. Si `save_to` est `siyuan` ou `both` : creer un doc dans SiYuan (notebook `research`)

#### Sauvegarde Mem0

```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "RESEARCH: Data Infrastructure at Scale (https://blog.pragmaticengineer.com/data-infra-at-scale/). Resume: [resume auto du contenu scrape]. Doc cree dans SiYuan.",
    "user_id": "researcher",
    "metadata": {
      "type": "research",
      "project": "global",
      "confidence": "hypothesis",
      "source_task": "PAPER-88",
      "tags": "scrape,article,data-infra"
    }
  }'
```

#### Sortie / effets de bord

- Contenu scrape et converti en markdown
- Resume sauvegarde dans Mem0 sous le user_id de l'agent
- Doc cree dans SiYuan (notebook `research`, accessible par tous les agents via recherche SQL)

#### Exemple curl pour les agents

```bash
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "scrape",
    "agent": "researcher",
    "task_id": "'$PAPERCLIP_TASK_ID'",
    "payload": {
      "url": "https://blog.pragmaticengineer.com/data-infra-at-scale/",
      "title": "Data Infrastructure at Scale",
      "save_to": "both"
    }
  }'
```

---

### 5.4 agent-git

**Description** : Execute des actions Gitea — creation de branche, pull request, ou issue.

**Trigger** : Webhook POST depuis un agent (event: `git`)

**Agents qui l'utilisent** : Backend, Frontend, DevOps

**Mem0 user_id ecrit** : `git-events`

#### Payload d'entree

```json
{
  "event": "git",
  "agent": "lead-backend",
  "task_id": "PAPER-33",
  "payload": {
    "action": "pr",
    "repo": "api-backend",
    "title": "feat: add user authentication endpoints",
    "body": "Implements JWT auth with refresh tokens.\n\nCloses PAPER-33",
    "base_branch": "main"
  }
}
```

#### Champs du payload

| Champ | Obligatoire | Valeurs | Description |
|-------|:-----------:|---------|-------------|
| `action` | Oui | `branch`, `pr`, `issue` | Type d'action Gitea |
| `repo` | Oui | nom du repo | Repository Gitea cible |
| `title` | Oui (pr, issue) | texte | Titre de la PR ou issue |
| `body` | Non | texte | Description de la PR ou issue |
| `base_branch` | Non | nom branche | Branche de base pour PR (defaut: `main`) |

#### Etapes de traitement dans n8n

1. Recevoir le webhook et valider l'authentification
2. Selon `action` :
   - `branch` : Gitea API — creer une branche depuis `base_branch`
   - `pr` : Gitea API — creer une pull request
   - `issue` : Gitea API — creer une issue
3. Sauvegarder l'evenement dans Mem0 sous `git-events`

#### Sauvegarde Mem0

```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "GIT EVENT: PR creee sur api-backend. Titre: feat: add user authentication endpoints. Agent: lead-backend. Task: PAPER-33",
    "user_id": "git-events",
    "metadata": {
      "type": "config",
      "project": "api-backend",
      "confidence": "validated",
      "source_task": "PAPER-33",
      "tags": "git,pr,api-backend"
    }
  }'
```

#### Sortie / effets de bord

- Branche, PR, ou issue creee dans Gitea
- Evenement sauvegarde dans Mem0 sous `git-events`

#### Exemple curl pour les agents

```bash
# Creer une PR
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "git",
    "agent": "lead-backend",
    "task_id": "'$PAPERCLIP_TASK_ID'",
    "payload": {
      "action": "pr",
      "repo": "api-backend",
      "title": "feat: add user authentication endpoints",
      "body": "Implements JWT auth with refresh tokens.",
      "base_branch": "main"
    }
  }'

# Creer une issue
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "git",
    "agent": "devops",
    "task_id": "'$PAPERCLIP_TASK_ID'",
    "payload": {
      "action": "issue",
      "repo": "infra-config",
      "title": "bug: Docker build cache invalidation on ARM",
      "body": "Le cache Docker se purge a chaque build sur les runners ARM64."
    }
  }'
```

---

### 5.5 agent-crm-sync

**Description** : Synchronise les donnees avec Twenty CRM — creation/mise a jour de contacts et deals.

**Trigger** : Webhook POST depuis un agent (event: `crm-sync`)

**Agents qui l'utilisent** : CPO, CFO

**Mem0 user_id ecrit** : `crm`

#### Payload d'entree

```json
{
  "event": "crm-sync",
  "agent": "cpo",
  "task_id": "PAPER-55",
  "payload": {
    "action": "create_contact",
    "data": {
      "first_name": "Jean",
      "last_name": "Dupont",
      "email": "jean.dupont@example.com",
      "company": "Acme Corp",
      "phone": "+33612345678",
      "notes": "Rencontre au meetup AI Paris. Interesse par notre solution."
    }
  }
}
```

#### Champs du payload

| Champ | Obligatoire | Valeurs | Description |
|-------|:-----------:|---------|-------------|
| `action` | Oui | `create_contact`, `update_contact`, `create_deal` | Type d'operation CRM |
| `data` | Oui | objet | Donnees specifiques a l'action |

#### Etapes de traitement dans n8n

1. Recevoir le webhook et valider l'authentification
2. Selon `action` :
   - `create_contact` : Twenty API — creer un contact avec les champs fournis
   - `update_contact` : Twenty API — mettre a jour un contact existant (match par email)
   - `create_deal` : Twenty API — creer un deal associe a un contact
3. Sauvegarder l'operation dans Mem0 sous `crm`

#### Sauvegarde Mem0

```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "CRM: Contact cree — Jean Dupont (jean.dupont@example.com), Acme Corp. Source: meetup AI Paris. Agent: cpo. Task: PAPER-55",
    "user_id": "crm",
    "metadata": {
      "type": "decision",
      "project": "global",
      "confidence": "validated",
      "source_task": "PAPER-55",
      "tags": "crm,contact,acme-corp"
    }
  }'
```

#### Sortie / effets de bord

- Contact ou deal cree/mis a jour dans Twenty CRM
- Evenement sauvegarde dans Mem0 sous `crm`

#### Exemple curl pour les agents

```bash
# Creer un contact
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "crm-sync",
    "agent": "cpo",
    "task_id": "'$PAPERCLIP_TASK_ID'",
    "payload": {
      "action": "create_contact",
      "data": {
        "first_name": "Jean",
        "last_name": "Dupont",
        "email": "jean.dupont@example.com",
        "company": "Acme Corp"
      }
    }
  }'

# Creer un deal
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "crm-sync",
    "agent": "cfo",
    "task_id": "'$PAPERCLIP_TASK_ID'",
    "payload": {
      "action": "create_deal",
      "data": {
        "contact_email": "jean.dupont@example.com",
        "title": "Contrat SaaS Acme Corp",
        "amount": 15000,
        "currency": "EUR",
        "stage": "negotiation"
      }
    }
  }'
```

---

### 5.6 agent-analytics

**Description** : Collecte les statistiques Umami et les sauvegarde dans Mem0 pour que les agents puissent les consulter.

**Trigger** : Schedule n8n — toutes les heures

**Agents qui l'utilisent** : Aucun (workflow automatique). Les agents **lisent** le resultat dans Mem0.

**Mem0 user_id ecrit** : `analytics`

#### Pas de payload d'entree (schedule automatique)

#### Etapes de traitement dans n8n

1. Declenchement automatique toutes les heures par le scheduler n8n
2. Appeler l'API Umami pour recuperer les stats de la derniere heure
3. Agreger les donnees : pages vues, visiteurs uniques, top pages, evenements de conversion
4. Sauvegarder l'agregation dans Mem0 sous `analytics`
5. Deprecier l'ancien snapshot (garder uniquement le plus recent actif)

#### Sauvegarde Mem0

```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "ANALYTICS SNAPSHOT [2026-03-10 14:00]: Pages vues derniere heure: 1,247. Visiteurs uniques: 389. Top pages: /pricing (23%), /docs (18%), /dashboard (15%). Conversions: 12 signups, 3 upgrades. Tendance: +15% vs meme heure hier.",
    "user_id": "analytics",
    "metadata": {
      "type": "metrics",
      "project": "global",
      "confidence": "validated",
      "tags": "analytics,hourly,umami"
    }
  }'
```

#### Sortie / effets de bord

- Snapshot analytics sauvegarde dans Mem0 sous `analytics`
- Ancien snapshot deprecie (un seul actif a la fois)

#### Consultation par les agents

```bash
# CFO consulte les metriques
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "analytics visitors conversions", "user_id": "analytics", "filters": {"state": {"$eq": "active"}}, "limit": 1}'

# CPO verifie l'usage des features
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "top pages usage features", "user_id": "analytics", "filters": {"state": {"$eq": "active"}}, "limit": 1}'
```

---

### 5.7 agent-status

**Description** : Collecte l'etat de tous les services via Uptime Kuma et sauvegarde dans Mem0.

**Trigger** : Schedule n8n — toutes les 5 minutes

**Agents qui l'utilisent** : Aucun (workflow automatique). Les agents **lisent** le resultat dans Mem0.

**Mem0 user_id ecrit** : `monitoring`

#### Pas de payload d'entree (schedule automatique)

#### Etapes de traitement dans n8n

1. Declenchement automatique toutes les 5 minutes par le scheduler n8n
2. Appeler l'API Uptime Kuma pour recuperer l'etat de tous les monitors
3. Pour chaque service : nom, status (up/down), temps de reponse, uptime %
4. Sauvegarder dans Mem0 sous `monitoring`
5. Deprecier l'ancien snapshot

#### Sauvegarde Mem0

```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "MONITORING [2026-03-10 14:05]: Tous services UP. Gitea: 120ms (99.98%). Dokploy: 85ms (99.99%). Twenty CRM: 200ms (99.95%). ntfy: 45ms (100%). BillionMail: 150ms (99.90%). Umami: 90ms (99.97%). Cal.com: 180ms (99.92%). SiYuan: 120ms (99.95%).",
    "user_id": "monitoring",
    "metadata": {
      "type": "metrics",
      "project": "global",
      "confidence": "validated",
      "tags": "monitoring,status,uptime-kuma"
    }
  }'
```

#### Sortie / effets de bord

- Snapshot monitoring sauvegarde dans Mem0 sous `monitoring`
- Ancien snapshot deprecie (un seul actif a la fois)

#### Consultation par les agents

```bash
# DevOps verifie l'etat des services avant un deploiement
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "service status health uptime", "user_id": "monitoring", "filters": {"state": {"$eq": "active"}}, "limit": 1}'

# CTO verifie l'etat global
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "monitoring services down incidents", "user_id": "monitoring", "filters": {"state": {"$eq": "active"}}, "limit": 3}'
```

---

### 5.8 agent-calendar

**Description** : Recoit les notifications de reservation Cal.com et les sauvegarde dans Mem0.

**Trigger** : Webhook Cal.com (evenement: booking created)

**Agents qui l'utilisent** : Aucun (declenche par Cal.com). Les agents **lisent** le resultat dans Mem0.

**Mem0 user_id ecrit** : `calendar`

#### Payload recu de Cal.com (pas un appel agent)

```json
{
  "triggerEvent": "BOOKING_CREATED",
  "payload": {
    "title": "Consultation 30min",
    "startTime": "2026-03-15T10:00:00Z",
    "endTime": "2026-03-15T10:30:00Z",
    "attendees": [
      {
        "name": "Marie Martin",
        "email": "marie@example.com"
      }
    ],
    "type": "consultation"
  }
}
```

#### Etapes de traitement dans n8n

1. Recevoir le webhook Cal.com (booking created)
2. Extraire les details : nom, email, date/heure, type de booking
3. Sauvegarder dans Mem0 sous `calendar`

#### Sauvegarde Mem0

```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "CALENDAR: Nouveau RDV — Consultation 30min avec Marie Martin (marie@example.com). Date: 2026-03-15 10:00-10:30. Type: consultation.",
    "user_id": "calendar",
    "metadata": {
      "type": "decision",
      "project": "global",
      "confidence": "validated",
      "tags": "calendar,booking,consultation"
    }
  }'
```

#### Sortie / effets de bord

- Booking sauvegarde dans Mem0 sous `calendar`
- Accessible par CEO et CPO dans leur Etape 0

#### Consultation par les agents

```bash
# CEO verifie les prochains RDV
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "prochain rendez-vous booking", "user_id": "calendar", "filters": {"state": {"$eq": "active"}}, "limit": 5}'
```

---

### 5.9 memory-propagation

**Description** : Detecte les decisions et changements d'architecture dans Mem0, puis cree automatiquement des issues Paperclip pour les agents impactes.

**Trigger** : Webhook Mem0 (evenements: `memory.created` ou `memory.state_changed` ou les types `decision` et `architecture`)

**Agents qui l'utilisent** : Aucun (declenche automatiquement par Mem0)

**Mem0 user_id ecrit** : Aucun (cree des issues Paperclip)

#### Payload recu de Mem0

```json
{
  "event": "memory.created",
  "memory_id": "abc-123",
  "user_id": "cto",
  "text": "DECISION: Migrer vers CockroachDB...",
  "metadata": {
    "type": "architecture",
    "project": "api-backend",
    "confidence": "tested",
    "state": "active"
  },
  "timestamp": "2026-03-10T15:00:00Z"
}
```

#### Matrice de propagation

| Auteur de la decision | Agents impactes |
|----------------------|-----------------|
| **CEO** | cto, cpo, cfo |
| **CTO** | lead-backend, lead-frontend, devops, security, qa |
| **CPO** | cto, designer, lead-frontend |
| **CFO** | ceo, cto |
| **Lead Backend** | lead-frontend, qa |
| **Lead Frontend** | designer, qa |
| **DevOps** | lead-backend, lead-frontend, security |
| **Security** | devops, lead-backend, lead-frontend |
| **Growth Lead** | seo, content-writer, data-analyst, sales-automation |
| **Sales Automation** | growth-lead |

#### Etapes de traitement dans n8n

1. Recevoir le webhook Mem0 (memory.created ou memory.state_changed)
2. Verifier que `metadata.type` est `decision` ou `architecture`
3. Identifier l'auteur via `user_id`
4. Consulter la matrice de propagation pour determiner les agents impactes
5. Pour chaque agent impacte, creer une issue Paperclip :

```json
{
  "title": "[AUTO] Architecture modifiee : Migrer vers CockroachDB",
  "body": "Le CTO a pris une decision d'architecture.\n\n## Decision\nMigrer vers CockroachDB...\n\n## Action requise\nLire la memoire CTO (ID: abc-123) et adapter ton travail si necessaire.\n\n## Consulter\nPOST /search/filtered {\"user_id\": \"cto\", \"filters\": {\"type\": {\"$eq\": \"architecture\"}, \"state\": {\"$eq\": \"active\"}}}",
  "assigneeAgentId": "UUID_AGENT_IMPACTE",
  "status": "todo",
  "labels": ["auto-propagation", "architecture"]
}
```

6. Paperclip reveille l'agent assigne (wakeOnAssignment: true)

#### Sortie / effets de bord

- Issues Paperclip creees pour chaque agent impacte
- Agents reveilles automatiquement (propagation en ~30 secondes vs 5-15 min en polling)

---

### 5.10 knowledge-digest

**Description** : Genere un resume hebdomadaire de toutes les memoires, agrege par agent, et cree un doc dans SiYuan.

**Trigger** : Schedule n8n — hebdomadaire (dimanche)

**Agents qui l'utilisent** : Aucun (workflow automatique)

**Mem0 user_id ecrit** : `cto` (avec type `report`)

#### Pas de payload d'entree (schedule automatique)

#### Etapes de traitement dans n8n

1. Declenchement automatique chaque dimanche par le scheduler n8n
2. Appeler `GET http://host.docker.internal:8050/stats` pour les stats globales
3. Pour chaque agent, appeler `/search/filtered` pour les memoires creees cette semaine
4. Agreger : nombre de memoires par agent, types predominants, decisions cles, learnings
5. Creer le digest et le sauvegarder dans Mem0 sous `cto` avec type `report`
6. Creer un doc dans SiYuan (notebook `global`) pour accessibilite globale

#### Sauvegarde Mem0

```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "KNOWLEDGE DIGEST [semaine 2026-03-04 → 2026-03-10]: Total memoires creees: 47. Par agent: CTO 8, Backend 12, Frontend 9, DevOps 5, Security 3, QA 4, Researcher 6. Decisions cles: migration CockroachDB (CTO), nouveau design system (Designer). Learnings: rate limiting sur API (Backend). Incidents: 0. Conflits resolus: 1 (REST vs GraphQL → REST maintenu).",
    "user_id": "cto",
    "metadata": {
      "type": "report",
      "project": "global",
      "confidence": "validated",
      "tags": "digest,weekly,knowledge"
    }
  }'
```

#### Sortie / effets de bord

- Digest sauvegarde dans Mem0 sous `cto`
- Doc digest cree dans SiYuan (notebook `global`)

---

### 5.11 security-alert

**Description** : Recoit les alertes CrowdSec, sauvegarde l'incident dans Mem0 et cree une issue pour l'agent Security.

**Trigger** : Webhook CrowdSec (alerte d'attaque)

**Agents qui l'utilisent** : Aucun (declenche par CrowdSec). L'agent **Security** recoit une issue automatique.

**Mem0 user_id ecrit** : `security-events`

#### Payload recu de CrowdSec

```json
{
  "type": "ban",
  "scope": "ip",
  "value": "203.0.113.42",
  "scenario": "crowdsecurity/http-bad-user-agent",
  "duration": "24h",
  "origin": "CAPI",
  "timestamp": "2026-03-10T14:32:00Z"
}
```

#### Etapes de traitement dans n8n

1. Recevoir le webhook CrowdSec
2. Extraire les details : type d'attaque, IP source, action prise, duree, timestamp
3. Sauvegarder l'alerte dans Mem0 sous `security-events`
4. Creer une issue Paperclip assignee a l'agent Security

#### Sauvegarde Mem0

```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "SECURITY ALERT: Attaque detectee. Type: http-bad-user-agent. Source IP: 203.0.113.42. Action: ban 24h. Origine: CAPI. Timestamp: 2026-03-10T14:32:00Z.",
    "user_id": "security-events",
    "metadata": {
      "type": "incident",
      "project": "global",
      "confidence": "validated",
      "tags": "security,crowdsec,ban,http-bad-user-agent"
    }
  }'
```

#### Issue Paperclip creee

```json
{
  "title": "[SECURITY] Attaque detectee : http-bad-user-agent depuis 203.0.113.42",
  "body": "CrowdSec a detecte et bloque une attaque.\n\n## Details\n- Type: http-bad-user-agent\n- IP: 203.0.113.42\n- Action: ban 24h\n- Timestamp: 2026-03-10T14:32:00Z\n\n## Action requise\nVerifier les logs, evaluer si des mesures supplementaires sont necessaires.\n\n## Consulter\nPOST /search/filtered {\"user_id\": \"security-events\", \"filters\": {\"state\": {\"$eq\": \"active\"}}}",
  "assigneeAgentId": "UUID_SECURITY_AGENT",
  "status": "todo",
  "labels": ["security", "auto-alert"]
}
```

#### Sortie / effets de bord

- Alerte sauvegardee dans Mem0 sous `security-events`
- Issue Paperclip creee et assignee a l'agent Security
- Agent Security reveille automatiquement

---

### 5.12 backup-report

**Description** : Recoit les notifications de fin de backup Duplicati et sauvegarde le status dans Mem0.

**Trigger** : Webhook Duplicati (backup complete)

**Agents qui l'utilisent** : Aucun (declenche par Duplicati). L'agent **DevOps** peut consulter les resultats.

**Mem0 user_id ecrit** : `deployments` (avec type `config`)

#### Payload recu de Duplicati

```json
{
  "EventName": "backup-completed",
  "BackupName": "daily-server-config",
  "Status": "Success",
  "Duration": "00:12:34",
  "SizeOfModifiedFiles": "2.4 GB",
  "Destination": "backblaze-b2://backups/server",
  "Timestamp": "2026-03-10T03:00:00Z"
}
```

#### Etapes de traitement dans n8n

1. Recevoir le webhook Duplicati (backup complete)
2. Extraire : nom du backup, status, duree, taille, destination, timestamp
3. Sauvegarder dans Mem0 sous `deployments` avec type `config`

#### Sauvegarde Mem0

```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "BACKUP: daily-server-config termine. Status: Success. Duree: 12min34s. Taille modifiee: 2.4 GB. Destination: backblaze-b2://backups/server. Timestamp: 2026-03-10T03:00:00Z.",
    "user_id": "deployments",
    "metadata": {
      "type": "config",
      "project": "global",
      "confidence": "validated",
      "tags": "backup,duplicati,success"
    }
  }'
```

#### Sortie / effets de bord

- Status du backup sauvegarde dans Mem0 sous `deployments`

#### Consultation par les agents

```bash
# DevOps verifie les derniers backups
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "backup status duplicati", "user_id": "deployments", "filters": {"type": {"$eq": "config"}, "state": {"$eq": "active"}}, "limit": 5}'
```

---

### 5.13 memory-to-siyuan (auto-publish)

**Description** : Publie automatiquement les memoires importantes dans SiYuan Note pour consultation humaine + mobile, avec routage intelligent par projet et par type de document.

**Trigger** : Webhook Mem0 `memory.created`

**Filtre** : type in {decision, architecture, convention, tech-doc, guideline, prd, user-story, runbook, post-mortem, audit, security, research, finding, design}

**Agents qui l'utilisent** : Aucun (automatique, declenche par Mem0 webhook)

**Extraction du projet** :

```
project_slug = memory.metadata.project (defaut: "global")
```

**Table de routage par type** :

| Type memoire | Notebook SiYuan | Sous-dossier |
|-------------|----------------|-------------|
| decision, architecture | architecture | adrs |
| convention | architecture | conventions |
| tech-doc | engineering | tech-docs |
| guideline | engineering | guidelines |
| prd | produit | prds |
| user-story | produit | user-stories |
| runbook | operations | runbooks |
| post-mortem | operations | post-mortems |
| audit, security | security | audits |
| research, finding | research | pocs |
| design | design-system | components |

**Logique de chemin** :

```
SI project_slug == "global":
  path = "/{subfolder}/{title-slug}"
SINON:
  path = "/projects/{project_slug}/{subfolder}/{title-slug}"
```

**Exemples de chemins resolus** :

| Type | Projet | Chemin final |
|------|--------|-------------|
| decision | global | /adrs/migration-cockroachdb |
| convention | global | /conventions/naming-api |
| prd | mon-saas | /projects/mon-saas/prds/onboarding-v2 |
| runbook | infra-prod | /projects/infra-prod/runbooks/failover-db |
| design | global | /components/button-primary |

#### Etapes de traitement dans n8n

1. Webhook trigger → recoit payload Mem0 `{event, memory_id, user_id, type, text_preview}`
2. HTTP Request → GET Mem0 `/memories/id/{memory_id}` (memoire complete avec metadata)
3. Code node → extraire `project_slug` depuis `memory.metadata.project` (defaut: `"global"`)
4. Code node → consulter la table de routage pour determiner `notebook` et `subfolder` selon le type
5. Code node → construire le path :
   - Si `project_slug == "global"` → `/{subfolder}/{title-slug}`
   - Sinon → `/projects/{project_slug}/{subfolder}/{title-slug}`
6. Code node → formater le contenu en markdown selon le type
7. HTTP Request → POST SiYuan `/api/filetree/createDocWithMd` (creation du document)
8. HTTP Request → POST SiYuan `/api/attr/setBlockAttrs` — attributs :
   - `custom-project` : le project_slug
   - `custom-type` : le type de memoire
   - `custom-status` : statut du document (ex: draft, validated)
   - `custom-agent` : agent source
   - `custom-mem0-id` : identifiant memoire
   - `custom-confidence` : niveau de confiance
9. HTTP Request → POST SiYuan `/api/sql` — rechercher les blocs de conventions globales liees au type
10. HTTP Request → POST SiYuan `/api/block/insertBlock` — ajouter les references de blocs (block refs) des conventions applicables dans le document
11. HTTP Request → POST SiYuan `/api/notification/pushMsg` (notif mobile)
12. Error trigger → log + retry

#### Exemples curl

```bash
# Etape 2 : Recuperer la memoire complete depuis Mem0
curl -X GET "http://host.docker.internal:8050/memories/id/{memory_id}" \
  -H "Content-Type: application/json"

# Etape 7 : Creer le document dans SiYuan (exemple projet specifique)
curl -X POST "http://host.docker.internal:6806/api/filetree/createDocWithMd" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "notebook": "NOTEBOOK_ID_ARCHITECTURE",
    "path": "/projects/mon-saas/adrs/migration-cockroachdb",
    "markdown": "# DECISION: Migration CockroachDB\n\n**Agent** : cto\n**Projet** : mon-saas\n**Confidence** : tested\n**Date** : 2026-03-10\n\n---\n\nContenu complet de la memoire..."
  }'

# Etape 7 bis : Creer le document dans SiYuan (exemple global, sans projet)
curl -X POST "http://host.docker.internal:6806/api/filetree/createDocWithMd" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "notebook": "NOTEBOOK_ID_ARCHITECTURE",
    "path": "/conventions/naming-api",
    "markdown": "# CONVENTION: Naming API REST\n\n**Agent** : cto\n**Confidence** : validated\n**Date** : 2026-03-10\n\n---\n\nContenu complet de la convention..."
  }'

# Etape 8 : Ajouter les attributs custom au bloc (avec projet, type, status, agent)
curl -X POST "http://host.docker.internal:6806/api/attr/setBlockAttrs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "id": "BLOCK_ID_RETOURNE",
    "attrs": {
      "custom-project": "mon-saas",
      "custom-type": "decision",
      "custom-status": "draft",
      "custom-agent": "cto",
      "custom-mem0-id": "abc-123",
      "custom-confidence": "tested"
    }
  }'

# Etape 9 : Rechercher les conventions globales liees (via SQL SiYuan)
curl -X POST "http://host.docker.internal:6806/api/sql" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "stmt": "SELECT blocks.id, blocks.content FROM blocks JOIN attributes ON blocks.id = attributes.block_id WHERE attributes.name = '\''custom-type'\'' AND attributes.value = '\''convention'\'' LIMIT 20"
  }'

# Etape 10 : Inserer les references de blocs des conventions dans le document
curl -X POST "http://host.docker.internal:6806/api/block/insertBlock" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "dataType": "markdown",
    "data": "## Conventions applicables\n\n- ((CONVENTION_BLOCK_ID_1 '\''Naming API REST'\''))\n- ((CONVENTION_BLOCK_ID_2 '\''Format des logs'\''))",
    "previousID": "LAST_BLOCK_ID_DU_DOC",
    "parentID": "DOC_BLOCK_ID"
  }'

# Etape 11 : Notification mobile
curl -X POST "http://host.docker.internal:6806/api/notification/pushMsg" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "msg": "Nouvelle memoire publiee : DECISION: Migration CockroachDB (cto, projet: mon-saas)",
    "timeout": 7000
  }'
```

#### Sortie / effets de bord

- Document cree dans SiYuan dans le bon notebook et sous-dossier selon la table de routage
- Routage par projet : les documents de projet sont classes sous `/projects/{project_slug}/`, les documents globaux directement sous `/{subfolder}/`
- Attributs custom ajoutes pour la tracabilite (project, type, status, agent, mem0-id, confidence)
- References de blocs des conventions globales ajoutees automatiquement au document
- Notification push envoyee sur mobile via SiYuan
- En cas d'erreur, le workflow retry automatiquement

---

### 5.14 siyuan-dashboard-services

**Description** : Rafraichit le dashboard services dans SiYuan avec le status actuel de tous les services.

**Trigger** : Schedule n8n — toutes les 5 minutes

**Agents qui l'utilisent** : Aucun (workflow automatique). Le dashboard est consultable dans SiYuan.

#### Etapes de traitement dans n8n

1. Schedule trigger
2. HTTP Request → POST Mem0 `/search/filtered` `{user_id: "monitoring", filters: {state: active}, limit: 1}`
3. Code node → format en markdown (tableau services avec status, uptime, response time)
4. HTTP Request → POST SiYuan `/api/block/updateBlock` `{id: DASHBOARD_BLOCK_ID, data: markdown, dataType: markdown}`

#### Exemple curl

```bash
# Etape 2 : Lire le dernier snapshot monitoring depuis Mem0
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "service status health uptime",
    "user_id": "monitoring",
    "filters": {"state": {"$eq": "active"}},
    "limit": 1
  }'

# Etape 4 : Mettre a jour le bloc dashboard dans SiYuan
curl -X POST "http://host.docker.internal:6806/api/block/updateBlock" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "id": "DASHBOARD_BLOCK_ID",
    "data": "| Service | Status | Uptime | Response |\n|---------|--------|--------|----------|\n| Gitea | UP | 99.98% | 120ms |\n| Dokploy | UP | 99.99% | 85ms |\n| Twenty CRM | UP | 99.95% | 200ms |",
    "dataType": "markdown"
  }'
```

#### Sortie / effets de bord

- Dashboard services mis a jour dans SiYuan toutes les 5 minutes
- Consultable sur mobile et desktop via SiYuan

---

### 5.15 siyuan-dashboard-analytics

**Description** : Rafraichit le dashboard analytics dans SiYuan avec les dernieres metriques.

**Trigger** : Schedule n8n — toutes les heures

**Agents qui l'utilisent** : Aucun (workflow automatique). Le dashboard est consultable dans SiYuan.

#### Etapes de traitement dans n8n

1. Schedule trigger
2. HTTP Request → POST Mem0 `/search/filtered` `{user_id: "analytics", filters: {state: active}, limit: 1}`
3. Code node → format en markdown (tableau metriques avec pages vues, visiteurs, conversions)
4. HTTP Request → POST SiYuan `/api/block/updateBlock` `{id: ANALYTICS_BLOCK_ID, data: markdown, dataType: markdown}`

#### Exemple curl

```bash
# Etape 2 : Lire le dernier snapshot analytics depuis Mem0
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "analytics visitors conversions pages",
    "user_id": "analytics",
    "filters": {"state": {"$eq": "active"}},
    "limit": 1
  }'

# Etape 4 : Mettre a jour le bloc dashboard analytics dans SiYuan
curl -X POST "http://host.docker.internal:6806/api/block/updateBlock" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "id": "ANALYTICS_BLOCK_ID",
    "data": "| Metrique | Valeur | Tendance |\n|----------|--------|----------|\n| Pages vues (1h) | 1,247 | +15% |\n| Visiteurs uniques | 389 | +8% |\n| Conversions | 12 signups | +20% |",
    "dataType": "markdown"
  }'
```

#### Sortie / effets de bord

- Dashboard analytics mis a jour dans SiYuan toutes les heures
- Meme pattern que 5.14 mais source `analytics` au lieu de `monitoring`

---

### 5.16 siyuan-dashboard-activity

**Description** : Rafraichit le dashboard team-activity dans SiYuan avec l'activite recente des agents.

**Trigger** : Schedule n8n — toutes les 30 minutes

**Agents qui l'utilisent** : Aucun (workflow automatique). Le dashboard est consultable dans SiYuan.

#### Etapes de traitement dans n8n

1. Schedule trigger
2. HTTP Request → GET Mem0 `/stats` (global stats)
3. For each active agent → GET Mem0 `/timeline/{agent}?limit=3`
4. Code node → format timeline en markdown
5. HTTP Request → POST SiYuan `/api/block/updateBlock`

#### Exemple curl

```bash
# Etape 2 : Recuperer les stats globales Mem0
curl -X GET "http://host.docker.internal:8050/stats" \
  -H "Content-Type: application/json"

# Etape 3 : Recuperer la timeline d'un agent
curl -X GET "http://host.docker.internal:8050/timeline/cto?limit=3" \
  -H "Content-Type: application/json"

# Etape 5 : Mettre a jour le bloc dashboard activity dans SiYuan
curl -X POST "http://host.docker.internal:6806/api/block/updateBlock" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "id": "ACTIVITY_BLOCK_ID",
    "data": "## Activite des agents\n\n### CTO\n- 14:00 — DECISION: Migration CockroachDB\n- 13:30 — ARCHITECTURE: Schema API v2\n\n### DevOps\n- 14:05 — DEPLOY: frontend-app success\n- 13:45 — CONFIG: Mise a jour Nginx",
    "dataType": "markdown"
  }'
```

#### Sortie / effets de bord

- Dashboard activite mis a jour dans SiYuan toutes les 30 minutes
- Vue consolidee de l'activite de tous les agents

---

### 5.17 siyuan-lifecycle-sync

**Description** : Synchronise les changements de lifecycle Mem0 vers les docs SiYuan correspondants.

**Trigger** : Webhook Mem0 `memory.state_changed`

**Agents qui l'utilisent** : Aucun (automatique, declenche par Mem0 webhook)

#### Etapes de traitement dans n8n

1. Webhook trigger → recoit `{memory_id, old_state, new_state}`
2. HTTP Request → POST SiYuan `/api/query/sql` `{stmt: "SELECT * FROM blocks WHERE ial LIKE '%custom-mem0-id=MEMORY_ID%'"}`
3. If doc found → POST SiYuan `/api/attr/setBlockAttrs` `{attrs: {custom-status: new_state}}`
4. If `new_state = "deprecated"` → POST SiYuan `/api/block/prependBlock` → add deprecation banner

#### Exemple curl

```bash
# Etape 2 : Rechercher le doc SiYuan correspondant a la memoire
curl -X POST "http://host.docker.internal:6806/api/query/sql" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "stmt": "SELECT * FROM blocks WHERE ial LIKE '\''%custom-mem0-id=abc-123%'\''"
  }'

# Etape 3 : Mettre a jour le status du bloc
curl -X POST "http://host.docker.internal:6806/api/attr/setBlockAttrs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "id": "BLOCK_ID_TROUVE",
    "attrs": {
      "custom-status": "deprecated"
    }
  }'

# Etape 4 : Ajouter une banniere de deprecation
curl -X POST "http://host.docker.internal:6806/api/block/prependBlock" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "parentID": "BLOCK_ID_TROUVE",
    "data": "> **DEPRECIE** — Cette memoire a ete marquee comme obsolete le 2026-03-10. Elle est conservee a titre historique.",
    "dataType": "markdown"
  }'
```

#### Sortie / effets de bord

- Attribut `custom-status` mis a jour dans SiYuan pour refleter le nouvel etat
- Banniere de deprecation ajoutee si la memoire passe en etat `deprecated`
- Les docs SiYuan restent synchronises avec le lifecycle Mem0

---

### 5.18 siyuan-weekly-digest

**Description** : Genere un resume hebdomadaire complet et le publie dans SiYuan.

**Trigger** : Schedule dimanche 20h

**Agents qui l'utilisent** : Aucun (workflow automatique)

#### Etapes de traitement dans n8n

1. HTTP Request → GET Mem0 `/stats` → global stats
2. For each agent → GET `/timeline/{agent}?since=last_week&limit=10`
3. Code node → format markdown resume with sections : decisions, learnings, incidents, stats
4. HTTP Request → POST SiYuan `/api/filetree/createDocWithMd` → notebook `global`, path `/digests/week-{num}`
5. HTTP Request → POST SiYuan `/api/notification/pushMsg` `{msg: "Digest semaine {num} disponible", timeout: 60000}`

#### Exemple curl

```bash
# Etape 1 : Stats globales Mem0
curl -X GET "http://host.docker.internal:8050/stats" \
  -H "Content-Type: application/json"

# Etape 2 : Timeline de chaque agent pour la semaine
curl -X GET "http://host.docker.internal:8050/timeline/cto?since=last_week&limit=10" \
  -H "Content-Type: application/json"

# Etape 4 : Creer le document digest dans SiYuan
curl -X POST "http://host.docker.internal:6806/api/filetree/createDocWithMd" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "notebook": "GLOBAL_NOTEBOOK_ID",
    "path": "/digests/week-10",
    "markdown": "# Digest semaine 10 (2026-03-04 → 2026-03-10)\n\n## Decisions\n- Migration CockroachDB (CTO)\n- Nouveau design system (Designer)\n\n## Learnings\n- Rate limiting sur API (Backend)\n\n## Incidents\n- Aucun\n\n## Stats\n- Total memoires : 47\n- Par agent : CTO 8, Backend 12, Frontend 9, DevOps 5, Security 3, QA 4, Researcher 6"
  }'

# Etape 5 : Notification mobile
curl -X POST "http://host.docker.internal:6806/api/notification/pushMsg" \
  -H "Content-Type: application/json" \
  -H "Authorization: Token $SIYUAN_API_TOKEN" \
  -d '{
    "msg": "Digest semaine 10 disponible",
    "timeout": 60000
  }'
```

#### Sortie / effets de bord

- Document digest cree dans SiYuan (notebook `global`, chemin `/digests/week-{num}`)
- Notification push envoyee sur mobile via SiYuan
- Historique des digests conserve et consultable

---

### 5.19 ai-agent-workflow (feature majeure)

**Description** : Agent IA autonome dans n8n utilisant LangChain + Ollama avec acces a toutes les APIs.

**Trigger** : Paperclip webhook (task assigned to n8n AI agent)

**Agents qui l'utilisent** : Declenche par Paperclip quand une tache est assignee a l'agent n8n AI

#### Architecture

```
Trigger: Paperclip webhook (task assigned)
  → AI Agent node (Ollama qwen3:14b via LangChain)
    Tools disponibles:
      - mem0_search: POST Mem0 /search/filtered
      - mem0_save: POST Mem0 /memories
      - siyuan_search: POST SiYuan /api/query/sql
      - siyuan_create: POST SiYuan /api/filetree/createDocWithMd
      - paperclip_comment: POST Paperclip /issues/:id/comments
      - paperclip_update: PATCH Paperclip /issues/:id
    Context: Mem0 memories loaded as system context
  → Result stored in Mem0 + Paperclip comment + SiYuan doc
```

Ce workflow permet a n8n d'agir comme un agent autonome capable de rechercher dans les bases de connaissances (Mem0, SiYuan), de prendre des decisions basees sur le contexte accumule, de publier les resultats dans SiYuan, et de mettre a jour les taches Paperclip. Contrairement aux autres workflows qui executent une sequence fixe, celui-ci utilise un LLM (Ollama qwen3:14b) via LangChain pour determiner dynamiquement les actions a effectuer.

#### Etapes de traitement dans n8n

1. Webhook → receive task payload from Paperclip
2. HTTP Request → POST Mem0 `/search/filtered` → load relevant memories as context
3. AI Agent node with tools → execute task autonomously
4. HTTP Request → POST Mem0 `/memories` → save results
5. HTTP Request → POST Paperclip `/issues/:id/comments` → report back
6. HTTP Request → PATCH Paperclip `/issues/:id` `{status: "done"}`

#### Exemple curl

```bash
# Etape 2 : Charger le contexte depuis Mem0
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "contexte pertinent pour la tache",
    "user_id": "global",
    "filters": {"state": {"$eq": "active"}},
    "limit": 10
  }'

# Etape 4 : Sauvegarder les resultats dans Mem0
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "AI AGENT RESULT: [resume du resultat de la tache]. Task: PAPER-100. Approche: [description]. Conclusion: [conclusion].",
    "user_id": "n8n-ai-agent",
    "metadata": {
      "type": "finding",
      "project": "global",
      "confidence": "hypothesis",
      "source_task": "PAPER-100",
      "tags": "ai-agent,autonomous,n8n"
    }
  }'

# Etape 5 : Commenter sur la tache Paperclip
curl -X POST "http://host.docker.internal:8060/api/issues/PAPER-100/comments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $PAPERCLIP_API_TOKEN" \
  -d '{
    "body": "Tache completee par n8n AI Agent.\n\n## Resultat\n[Resume du travail effectue]\n\n## Memoire sauvegardee\nID: xyz-456 (user_id: n8n-ai-agent)\n\n## Document SiYuan\nCree dans notebook research."
  }'

# Etape 6 : Mettre a jour le status de la tache Paperclip
curl -X PATCH "http://host.docker.internal:8060/api/issues/PAPER-100" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $PAPERCLIP_API_TOKEN" \
  -d '{
    "status": "done"
  }'
```

#### Sortie / effets de bord

- Tache executee de maniere autonome par le LLM
- Resultats sauvegardes dans Mem0 sous `n8n-ai-agent`
- Commentaire ajoute sur la tache Paperclip avec le resume
- Tache marquee comme terminee dans Paperclip
- Document optionnel cree dans SiYuan si le resultat le justifie

---

### 5.20 agent-email-sequence

**Description** : Execute une sequence d'emails de vente via BillionMail, declenchee par l'agent Sales Automation. Gere le timing entre les etapes et le suivi des metriques.

**Trigger** : Webhook agent (event: `email-sequence`)

**Agents qui l'utilisent** : Sales Automation

**Mem0 user_id ecrit** : Aucun (les metriques sont ecrites par Sales Automation)

#### Payload attendu

```json
{
  "event": "email-sequence",
  "agent": "sales-automation",
  "task_id": "PAPER-200",
  "payload": {
    "contact_email": "prospect@example.com",
    "sequence_id": "nurture-v1",
    "stage": "step1"
  }
}
```

#### Etapes de traitement dans n8n

1. Webhook trigger → recoit le payload de Sales Automation
2. Code node → determiner le template email et le timing selon `sequence_id` et `stage`
3. HTTP Request → POST BillionMail `/api/send` — envoyer l'email au contact
4. Wait node → attendre le delai configure entre les etapes (ex: 3 jours)
5. HTTP Request → GET BillionMail `/api/campaigns/{id}/stats` — verifier open/click
6. If opened → HTTP Request → POST Mem0 `/memories` — sauvegarder le signal sous `crm`
7. If not opened et etape suivante disponible → boucler sur l'etape suivante
8. HTTP Request → POST ntfy — notifier Sales Automation du resultat

#### Exemple curl

```bash
# Etape 3 : Envoyer l'email via BillionMail
curl -X POST "https://mail.home/api/send" \
  -H "Authorization: Bearer $BILLIONMAIL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "prospect@example.com",
    "template_id": "nurture-v1-step1",
    "subject": "Decouvrez comment [proposition de valeur]",
    "variables": {"name": "Marie", "company": "Acme"}
  }'

# Etape 5 : Verifier les stats
curl -s "https://mail.home/api/campaigns/last/stats" \
  -H "Authorization: Bearer $BILLIONMAIL_TOKEN"
```

#### Sortie / effets de bord

- Email envoye via BillionMail au contact
- Signal d'engagement (open/click) sauvegarde dans Mem0 channel `crm`
- Etape suivante de la sequence declenchee automatiquement apres le delai
- Sales Automation notifie du resultat pour ajuster le scoring

---

### 5.21 agent-lead-score

**Description** : Calcule et met a jour le score d'un lead dans Twenty CRM en se basant sur les signaux comportementaux (Umami) et les interactions (BillionMail, Cal.com).

**Trigger** : Webhook agent (event: `lead-score`)

**Agents qui l'utilisent** : Sales Automation

**Mem0 user_id ecrit** : `crm` (mise a jour du score dans le channel CRM)

#### Payload attendu

```json
{
  "event": "lead-score",
  "agent": "sales-automation",
  "task_id": "PAPER-201",
  "payload": {
    "contact_email": "prospect@example.com",
    "score": 85,
    "tier": "hot",
    "signals": [
      "visited pricing page 3x",
      "downloaded whitepaper",
      "opened 5 emails"
    ]
  }
}
```

#### Etapes de traitement dans n8n

1. Webhook trigger → recoit le payload de Sales Automation
2. HTTP Request → GET Twenty CRM `/api/contacts?email={email}` — trouver le contact
3. HTTP Request → PATCH Twenty CRM `/api/contacts/{id}` — mettre a jour le score et le tier
4. HTTP Request → POST Twenty CRM `/api/activities` — logger l'activite de scoring
5. HTTP Request → POST Mem0 `/memories` — sauvegarder le score dans le channel `crm`
6. If tier == "hot" → HTTP Request → POST ntfy — alerter pour action immediate

#### Exemple curl

```bash
# Etape 2 : Trouver le contact dans Twenty CRM
curl -s "https://crm.home/api/contacts?email=prospect@example.com" \
  -H "Authorization: Bearer $TWENTY_TOKEN"

# Etape 3 : Mettre a jour le score
curl -X PATCH "https://crm.home/api/contacts/CONTACT_ID" \
  -H "Authorization: Bearer $TWENTY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customFields": {
      "lead_score": 85,
      "lead_tier": "hot",
      "last_scored": "2026-03-12T10:00:00Z"
    }
  }'

# Etape 4 : Logger l'activite
curl -X POST "https://crm.home/api/activities" \
  -H "Authorization: Bearer $TWENTY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "contact_id": "CONTACT_ID",
    "type": "scoring",
    "note": "Lead score updated: 85 (hot). Signals: visited pricing 3x, downloaded whitepaper, opened 5 emails."
  }'

# Etape 5 : Sauvegarder dans Mem0 channel crm
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "CRM: Lead score update — prospect@example.com score 85 (hot). Signaux: visited pricing 3x, downloaded whitepaper, opened 5 emails. Action: outreach immediat.",
    "user_id": "crm",
    "metadata": {
      "type": "decision",
      "project": "pipeline",
      "confidence": "validated",
      "tags": "lead-score,hot,sales"
    }
  }'
```

#### Sortie / effets de bord

- Score et tier mis a jour dans Twenty CRM
- Activite de scoring loggee dans CRM
- Score sauvegarde dans Mem0 channel `crm` pour consultation par les agents
- Notification ntfy si le lead est "hot" (action immediate requise)

---

## 6. Gestion des erreurs

### Si n8n est injoignable

Quand un agent tente d'appeler `$N8N_WEBHOOK_URL/agent-event` et recoit un timeout ou une erreur reseau :

```
1. L'agent detecte l'erreur (timeout > 10s ou code HTTP 5xx ou erreur reseau)
2. L'agent NE retry PAS immediatement (eviter de surcharger)
3. L'agent continue sa tache en mode degrade (sans l'action n8n)
4. L'agent sauvegarde l'action en attente dans Mem0 :
   POST /memories {
     "text": "N8N PENDING: event=deploy, payload={...}. n8n injoignable a [timestamp].",
     "user_id": "MON_ID",
     "metadata": {"type": "incident", "tags": "n8n-pending,retry-needed"}
   }
5. L'agent commente sur sa tache Paperclip :
   "n8n injoignable. Action [event] mise en attente dans Mem0. Retry au prochain reveil."
6. Au prochain reveil, l'agent cherche ses actions en attente :
   POST /search/filtered {
     "user_id": "MON_ID",
     "filters": {"tags": {"$contains": "n8n-pending"}, "state": {"$eq": "active"}},
     "limit": 5
   }
7. Pour chaque action en attente, retry le curl vers n8n
8. Si succes : deprecier la memoire "pending"
9. Si encore en echec : laisser en attente et reporter
```

### Si Mem0 est injoignable (cote n8n)

Quand n8n tente d'ecrire dans Mem0 et echoue :

```
1. n8n detecte l'erreur sur le POST vers Mem0
2. n8n sauvegarde l'action dans sa base PostgreSQL interne (noeud "Error Trigger")
3. n8n envoie une notification ntfy a Zahid : "Mem0 injoignable depuis n8n"
4. Un workflow de retry s'execute toutes les 5 minutes jusqu'a succes
```

### Codes de retour du webhook n8n

| Code | Signification | Action agent |
|------|--------------|-------------|
| `200` | Succes — action executee | Continuer normalement |
| `401` | Cle d'authentification invalide | Verifier `$N8N_AGENT_KEY` |
| `400` | Payload invalide | Verifier le format JSON et les champs obligatoires |
| `404` | Event type inconnu | Verifier la valeur du champ `event` |
| `500` | Erreur interne n8n | Traiter comme "n8n injoignable" |
| `502/503` | n8n down ou surcharge | Traiter comme "n8n injoignable" |
| timeout | Pas de reponse en 10s | Traiter comme "n8n injoignable" |

---

## Resume des workflows

| # | Workflow | Trigger | Qui declenche | Mem0 user_id | Services utilises |
|---|---------|---------|---------------|-------------|-------------------|
| 1 | agent-deploy | Webhook agent | DevOps, Backend, Frontend | `deployments` | Dokploy, Playwright, ntfy |
| 2 | agent-notify | Webhook agent | Tous | Aucun | ntfy, BillionMail |
| 3 | agent-scrape | Webhook agent | Researcher | `researcher` | Firecrawl, Mem0, SiYuan |
| 4 | agent-git | Webhook agent | Backend, Frontend, DevOps | `git-events` | Gitea |
| 5 | agent-crm-sync | Webhook agent | CPO, CFO | `crm` | Twenty CRM |
| 6 | agent-analytics | Schedule 1h | Automatique | `analytics` | Umami |
| 7 | agent-status | Schedule 5min | Automatique | `monitoring` | Uptime Kuma |
| 8 | agent-calendar | Webhook Cal.com | Cal.com | `calendar` | Cal.com |
| 9 | memory-propagation | Webhook Mem0 | Mem0 | Aucun (issues) | Paperclip |
| 10 | knowledge-digest | Schedule hebdo | Automatique | `cto` | Mem0, SiYuan |
| 11 | security-alert | Webhook CrowdSec | CrowdSec | `security-events` | Paperclip |
| 12 | backup-report | Webhook Duplicati | Duplicati | `deployments` | Duplicati |
| 13 | memory-to-siyuan | Webhook Mem0 | Mem0 | Aucun | Mem0, SiYuan |
| 14 | siyuan-dashboard-services | Schedule 5min | Automatique | Aucun | Mem0, SiYuan |
| 15 | siyuan-dashboard-analytics | Schedule 1h | Automatique | Aucun | Mem0, SiYuan |
| 16 | siyuan-dashboard-activity | Schedule 30min | Automatique | Aucun | Mem0, SiYuan |
| 17 | siyuan-lifecycle-sync | Webhook Mem0 | Mem0 | Aucun | SiYuan |
| 18 | siyuan-weekly-digest | Schedule dimanche 20h | Automatique | Aucun | Mem0, SiYuan |
| 19 | ai-agent-workflow | Webhook Paperclip | Paperclip | `n8n-ai-agent` | Mem0, SiYuan, Paperclip, Ollama |
| 20 | agent-email-sequence | Webhook agent | Sales Automation | Aucun | BillionMail, Mem0, ntfy |
| 21 | agent-lead-score | Webhook agent | Sales Automation | `crm` | Twenty CRM, Mem0, ntfy |
