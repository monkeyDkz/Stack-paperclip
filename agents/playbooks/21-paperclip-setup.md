# Paperclip — Setup avance et fonctionnalites

> Paperclip est l'orchestrateur unique des 11 agents de la stack.
> Ce document couvre les fonctionnalites avancees : goals, projets, approvals, cost tracking, sessions, config revisions et atomic checkout.

---

## Variables reutilisables

```bash
PAPERCLIP_URL="http://host.docker.internal:8060"
AGENT_API_KEY="<agent-api-key>"
COMPANY_ID="<company-id>"
```

---

## 1. Goals et Projects

Paperclip organise le travail en une hierarchie : Company Goal > Team Goals > Projects > Issues (taches).

### Structure

```
Company Goal: "Construire un produit SaaS rentable"
├── Team Goal (CTO): "Architecture scalable et maintenable"
│   ├── Project: "Backend API"
│   └── Project: "Infrastructure"
├── Team Goal (CPO): "Product-market fit"
│   └── Project: "MVP Feature Set"
└── Team Goal (CFO): "Runway > 18 mois"
    └── Project: "Cost Optimization"
```

### Creer un Company Goal

```bash
curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY_ID/goals" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Construire un produit SaaS rentable",
    "description": "Objectif principal de la societe pour les 12 prochains mois.",
    "level": "company"
  }'
```

### Creer un Team Goal

```bash
curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY_ID/goals" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Architecture scalable et maintenable",
    "description": "Garantir que l architecture supporte 10x la charge actuelle.",
    "level": "team",
    "parentGoalId": "<company-goal-id>",
    "ownerAgentId": "<cto-agent-id>"
  }'
```

### Creer un Project

```bash
curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY_ID/projects" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Backend API",
    "description": "API REST principale du produit.",
    "goalId": "<team-goal-id>",
    "leadAgentId": "<lead-backend-agent-id>"
  }'
```

### Lister les Goals

```bash
curl -s "$PAPERCLIP_URL/api/companies/$COMPANY_ID/goals" \
  -H "Authorization: Bearer $AGENT_API_KEY"
```

### Lister les Projects

```bash
curl -s "$PAPERCLIP_URL/api/companies/$COMPANY_ID/projects" \
  -H "Authorization: Bearer $AGENT_API_KEY"
```

---

## 2. Approval Workflows

Les decisions critiques passent par un systeme d'approbation avant execution.

### Types d'approvals

| Type | Soumis par | Approuve par | Declencheur |
|------|-----------|-------------|-------------|
| Strategie CEO | CEO | Board | Decision strategique majeure |
| Hiring agent | CEO/CTO | Approval flow | Creation d'un nouvel agent |
| Architecture critique | CTO | CEO + CPO | Changement d'architecture majeur |
| Production deploy | DevOps | CTO | Deploiement en production |
| Budget depassement | CFO | CEO | Depense hors budget |

### Soumettre une demande d'approval

```bash
curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY_ID/approvals" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "architecture",
    "title": "Migration vers PostgreSQL 16",
    "description": "Remplacement de SQLite par PostgreSQL pour le service principal.",
    "submittedByAgentId": "<cto-agent-id>",
    "approverAgentIds": ["<ceo-agent-id>", "<cpo-agent-id>"],
    "relatedIssueId": "<issue-id>",
    "metadata": {
      "impact": "high",
      "reversible": false,
      "estimatedCost": "2 jours de dev"
    }
  }'
```

### Lister les approvals en attente

```bash
curl -s "$PAPERCLIP_URL/api/companies/$COMPANY_ID/approvals?status=pending" \
  -H "Authorization: Bearer $AGENT_API_KEY"
```

### Approuver ou rejeter

```bash
# Approuver
curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY_ID/approvals/<approval-id>/approve" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "agentId": "<ceo-agent-id>",
    "comment": "Approuve. Planifier pour le sprint suivant."
  }'

# Rejeter
curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY_ID/approvals/<approval-id>/reject" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "agentId": "<ceo-agent-id>",
    "comment": "Rejete. SQLite suffit pour la charge actuelle."
  }'
```

---

## 3. Cost Tracking

Chaque appel LLM est trace pour suivre la consommation de tokens et les couts associes.

### Enregistrer un evenement de cout

```bash
curl -X POST "$PAPERCLIP_URL/api/companies/$COMPANY_ID/cost-events" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "agentId": "<agent-id>",
    "issueId": "<issue-id>",
    "provider": "ollama",
    "model": "qwen3:32b",
    "inputTokens": 1500,
    "outputTokens": 800,
    "costCents": 0
  }'
```

> Avec Ollama en local, `costCents` est toujours `0`. Le tracking sert a mesurer la consommation de tokens pour optimiser les prompts et les modeles.

### Consulter les couts par agent

```bash
curl -s "$PAPERCLIP_URL/api/companies/$COMPANY_ID/cost-events?agentId=<agent-id>&from=2026-03-01&to=2026-03-31" \
  -H "Authorization: Bearer $AGENT_API_KEY"
```

### Consulter les couts par projet

```bash
curl -s "$PAPERCLIP_URL/api/companies/$COMPANY_ID/cost-events?projectId=<project-id>" \
  -H "Authorization: Bearer $AGENT_API_KEY"
```

### Resume des couts

```bash
curl -s "$PAPERCLIP_URL/api/companies/$COMPANY_ID/cost-summary" \
  -H "Authorization: Bearer $AGENT_API_KEY"
# Retourne les totaux par agent, par modele et par periode.
```

---

## 4. Task Sessions

Les task sessions maintiennent un contexte persistant entre les heartbeats d'un agent sur une meme tache. Cela evite a l'agent de recharger tout le contexte a chaque reveil.

### Fonctionnement

1. L'agent checkout une tache
2. Paperclip cree ou reprend une session pour cette tache
3. A chaque heartbeat, l'agent peut lire et ecrire dans la session
4. La session est fermee quand la tache passe en `done`

### Lire la session courante

```bash
curl -s "$PAPERCLIP_URL/api/issues/<issue-id>/session" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID"
# Retourne :
# {
#   "sessionId": "...",
#   "issueId": "...",
#   "agentId": "...",
#   "context": { ... },
#   "createdAt": "...",
#   "updatedAt": "..."
# }
```

### Mettre a jour le contexte de session

```bash
curl -s -X PATCH "$PAPERCLIP_URL/api/issues/<issue-id>/session" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "context": {
      "step": 3,
      "filesModified": ["src/api/routes.ts", "src/models/user.ts"],
      "testsStatus": "pending",
      "notes": "Refactoring en cours, reste le controller users."
    }
  }'
```

### Fermer une session

```bash
curl -s -X DELETE "$PAPERCLIP_URL/api/issues/<issue-id>/session" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID"
```

---

## 5. Config Revisions et Rollback

Chaque modification de la configuration d'un agent est versionee. En cas de regression, un rollback est possible.

### Lister les revisions de config d'un agent

```bash
curl -s "$PAPERCLIP_URL/api/agents/<agent-id>/config-revisions" \
  -H "Authorization: Bearer $AGENT_API_KEY"
# Retourne :
# [
#   {
#     "revisionId": "rev-003",
#     "createdAt": "2026-03-11T10:00:00Z",
#     "changedBy": "<ceo-agent-id>",
#     "diff": { "heartbeat.intervalSec": {"old": 600, "new": 300} }
#   },
#   {
#     "revisionId": "rev-002",
#     "createdAt": "2026-03-10T14:00:00Z",
#     "changedBy": "<cto-agent-id>",
#     "diff": { "model": {"old": "qwen3:14b", "new": "qwen3:32b"} }
#   }
# ]
```

### Rollback vers une revision

```bash
curl -s -X POST "$PAPERCLIP_URL/api/agents/<agent-id>/config-revisions/rev-002/rollback" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Regression de performance avec le modele 32b, retour au 14b."
  }'
```

---

## 6. Atomic Checkout

Le mecanisme d'atomic checkout empeche deux agents (ou deux runs du meme agent) de travailler simultanement sur la meme tache.

### Fonctionnement

1. L'agent appelle `POST /api/issues/{id}/checkout` avec son `X-Paperclip-Run-Id`
2. Si la tache est libre, le checkout reussit (code 200)
3. Si la tache est deja checkoutee par un autre run, le checkout echoue (code 409 Conflict)
4. Le checkout est libere quand la tache passe en `done` ou apres un timeout configurable

### Checkout une tache

```bash
curl -s -X POST "$PAPERCLIP_URL/api/issues/<issue-id>/checkout" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID"
# Succes : 200 OK
# Deja prise : 409 Conflict
```

### Verifier le statut de checkout

```bash
curl -s "$PAPERCLIP_URL/api/issues/<issue-id>/checkout" \
  -H "Authorization: Bearer $AGENT_API_KEY"
# Retourne :
# {
#   "checkedOut": true,
#   "agentId": "<agent-id>",
#   "runId": "<run-id>",
#   "since": "2026-03-11T10:30:00Z"
# }
```

### Liberer un checkout (forcage admin)

```bash
curl -s -X DELETE "$PAPERCLIP_URL/api/issues/<issue-id>/checkout" \
  -H "Authorization: Bearer $AGENT_API_KEY"
```

---

## 7. Configuration des agents

### Adapter types

| Type | Description | Usage |
|------|-------------|-------|
| `claude_local` | Appel direct a Ollama via LiteLLM | Agents principaux (CTO, CPO, etc.) |
| `n8n_webhook` | Declenchement via webhook n8n | Agents avec workflows complexes |
| `api_proxy` | Proxy vers un service externe | Agents connectes a des outils tiers |

### Heartbeat configuration

```json
{
  "heartbeat": {
    "enabled": true,
    "intervalSec": 300,
    "wakeOnDemand": true,
    "wakeOnAssignment": true
  }
}
```

| Parametre | Description | Valeurs typiques |
|-----------|-------------|-----------------|
| `enabled` | Active le heartbeat periodique | `true` |
| `intervalSec` | Intervalle entre deux reveils | 300 (CEO), 600 (CTO), 1800 (SysAdmin) |
| `wakeOnDemand` | Reveil sur appel explicite | `true` |
| `wakeOnAssignment` | Reveil quand une tache est assignee | `true` |

### Context mode

| Mode | Description |
|------|-------------|
| `full` | L'agent recoit tout le contexte a chaque reveil (historique complet) |
| `incremental` | L'agent recoit uniquement les changements depuis le dernier heartbeat |
| `session` | L'agent recoit le contexte de la session active (voir section 4) |

---

## 8. Bootstrap complet — Curl examples

Sequence complete pour initialiser une company avec ses goals, projets et agents.

### Etape 1 : Creer la company

```bash
COMPANY=$(curl -s -X POST "$PAPERCLIP_URL/api/companies" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Startup SaaS",
    "description": "Startup en phase de construction produit."
  }' | jq -r '.data.id')

echo "Company ID: $COMPANY"
```

### Etape 2 : Creer le Company Goal

```bash
COMPANY_GOAL=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/goals" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Construire un produit SaaS rentable",
    "level": "company"
  }' | jq -r '.data.id')

echo "Company Goal ID: $COMPANY_GOAL"
```

### Etape 3 : Creer les Team Goals

```bash
# CTO Goal
CTO_GOAL=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/goals" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"Architecture scalable et maintenable\",
    \"level\": \"team\",
    \"parentGoalId\": \"$COMPANY_GOAL\"
  }" | jq -r '.data.id')

# CPO Goal
CPO_GOAL=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/goals" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"Product-market fit\",
    \"level\": \"team\",
    \"parentGoalId\": \"$COMPANY_GOAL\"
  }" | jq -r '.data.id')

# CFO Goal
CFO_GOAL=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/goals" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"Runway > 18 mois\",
    \"level\": \"team\",
    \"parentGoalId\": \"$COMPANY_GOAL\"
  }" | jq -r '.data.id')

echo "CTO Goal: $CTO_GOAL | CPO Goal: $CPO_GOAL | CFO Goal: $CFO_GOAL"
```

### Etape 4 : Creer les Projects

```bash
# Backend API
PROJ_BACKEND=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/projects" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Backend API\",
    \"goalId\": \"$CTO_GOAL\"
  }" | jq -r '.data.id')

# Infrastructure
PROJ_INFRA=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/projects" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Infrastructure\",
    \"goalId\": \"$CTO_GOAL\"
  }" | jq -r '.data.id')

# MVP Feature Set
PROJ_MVP=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/projects" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"MVP Feature Set\",
    \"goalId\": \"$CPO_GOAL\"
  }" | jq -r '.data.id')

# Cost Optimization
PROJ_COST=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/projects" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Cost Optimization\",
    \"goalId\": \"$CFO_GOAL\"
  }" | jq -r '.data.id')
```

### Etape 5 : Creer les agents

```bash
# CEO
CEO_ID=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/agents" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ceo",
    "role": "executive",
    "title": "Chief Executive Officer",
    "adapterType": "claude_local",
    "model": "qwen3:32b",
    "permissions": {"canCreateAgents": true},
    "runtimeConfig": {
      "heartbeat": {"enabled": true, "intervalSec": 300, "wakeOnDemand": true, "wakeOnAssignment": true},
      "contextMode": "full"
    }
  }' | jq -r '.data.id')

# CTO
CTO_ID=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/agents" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"cto\",
    \"role\": \"executive\",
    \"title\": \"Chief Technology Officer\",
    \"reportsTo\": \"$CEO_ID\",
    \"adapterType\": \"claude_local\",
    \"model\": \"qwen3:32b\",
    \"permissions\": {\"canCreateAgents\": true},
    \"runtimeConfig\": {
      \"heartbeat\": {\"enabled\": true, \"intervalSec\": 600, \"wakeOnDemand\": true, \"wakeOnAssignment\": true},
      \"contextMode\": \"full\"
    }
  }" | jq -r '.data.id')

# CPO
CPO_ID=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/agents" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"cpo\",
    \"role\": \"executive\",
    \"title\": \"Chief Product Officer\",
    \"reportsTo\": \"$CEO_ID\",
    \"adapterType\": \"claude_local\",
    \"model\": \"qwen3:32b\",
    \"permissions\": {\"canCreateAgents\": false},
    \"runtimeConfig\": {
      \"heartbeat\": {\"enabled\": true, \"intervalSec\": 600, \"wakeOnDemand\": true, \"wakeOnAssignment\": true},
      \"contextMode\": \"full\"
    }
  }" | jq -r '.data.id')

# CFO
CFO_ID=$(curl -s -X POST "$PAPERCLIP_URL/api/companies/$COMPANY/agents" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"cfo\",
    \"role\": \"executive\",
    \"title\": \"Chief Financial Officer\",
    \"reportsTo\": \"$CEO_ID\",
    \"adapterType\": \"claude_local\",
    \"model\": \"qwen3:14b\",
    \"permissions\": {\"canCreateAgents\": false},
    \"runtimeConfig\": {
      \"heartbeat\": {\"enabled\": true, \"intervalSec\": 900, \"wakeOnDemand\": true, \"wakeOnAssignment\": true},
      \"contextMode\": \"incremental\"
    }
  }" | jq -r '.data.id')

echo "CEO: $CEO_ID | CTO: $CTO_ID | CPO: $CPO_ID | CFO: $CFO_ID"
```

### Etape 6 : Associer les agents aux goals

```bash
# CTO est owner du goal architecture
curl -s -X PATCH "$PAPERCLIP_URL/api/companies/$COMPANY/goals/$CTO_GOAL" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"ownerAgentId\": \"$CTO_ID\"}"

# CPO est owner du goal produit
curl -s -X PATCH "$PAPERCLIP_URL/api/companies/$COMPANY/goals/$CPO_GOAL" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"ownerAgentId\": \"$CPO_ID\"}"

# CFO est owner du goal financier
curl -s -X PATCH "$PAPERCLIP_URL/api/companies/$COMPANY/goals/$CFO_GOAL" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"ownerAgentId\": \"$CFO_ID\"}"
```

### Verification post-bootstrap

```bash
# Lister les agents
curl -s "$PAPERCLIP_URL/api/companies/$COMPANY/agents" \
  -H "Authorization: Bearer $AGENT_API_KEY" | jq '.data[] | {id, name, role, title}'

# Lister les goals
curl -s "$PAPERCLIP_URL/api/companies/$COMPANY/goals" \
  -H "Authorization: Bearer $AGENT_API_KEY" | jq '.data[] | {id, title, level, ownerAgentId}'

# Lister les projets
curl -s "$PAPERCLIP_URL/api/companies/$COMPANY/projects" \
  -H "Authorization: Bearer $AGENT_API_KEY" | jq '.data[] | {id, name, goalId}'
```
