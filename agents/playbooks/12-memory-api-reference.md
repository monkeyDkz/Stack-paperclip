# Reference API : Couches Memoire et Knowledge (v3.1)

> Tous les agents doivent suivre le [Protocole Memoire](./13-memory-protocol.md) et les [Knowledge Workflows](./14-knowledge-workflows.md).

---

## 1. MEM0 — Memoire persistante (port 8050)

Base URL: `http://host.docker.internal:8050`

Mem0 v3.1 apporte des ameliorations majeures :
- **Webhooks persistants** : sauvegardes sur disque, survivent aux redemarrages du container
- **Links persistants** : relations entre memoires sauvegardees sur disque
- **Webhook retry avec backoff** : 3 tentatives avec backoff exponentiel (1s, 2s, 4s) en cas d'echec d'envoi
- **Graph memory (Kuzu)** : extraction automatique de relations entre entites via un graph DB embedded (Kuzu)

### Schema metadata obligatoire

Chaque `POST /memories` DOIT inclure dans metadata :
```json
{
  "type": "decision|learning|bug|architecture|convention|...",
  "project": "nom-projet ou global",
  "confidence": "hypothesis|tested|validated"
}
```
Le serveur injecte automatiquement `state: "active"` et `created: YYYY-MM-DD` si absents.

Voir [13-memory-protocol.md](./13-memory-protocol.md) pour la liste complete des types et regles.

---

### Endpoints CRUD

#### Sauvegarder une memoire
```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "DECISION: Utiliser PostgreSQL\nCONTEXT: Besoin ACID\nCHOICE: PostgreSQL 16\nALTERNATIVES: MongoDB rejete\nCONSEQUENCES: Bonne perf, besoin tuning\nSTATUS: active\nLINKED_TASK: ea0bc1a8",
    "user_id": "cto",
    "metadata": {
      "type": "architecture",
      "project": "projet-x",
      "confidence": "tested",
      "source_task": "ea0bc1a8"
    }
  }'
```

#### Sauvegarder avec deduplication
```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Pattern: utiliser zod pour la validation",
    "user_id": "lead-backend",
    "deduplicate": true,
    "metadata": {"type": "pattern", "project": "projet-x", "confidence": "tested"}
  }'
# Si doublon detecte (cosine > 0.92) : retourne {"status": "duplicate", "existing_memory_id": "xxx"}
```

#### Sauvegarder en bulk
```bash
curl -X POST "http://host.docker.internal:8050/memories/bulk" \
  -H "Content-Type: application/json" \
  -d '{
    "memories": [
      {"text": "Convention 1: ...", "user_id": "cto", "metadata": {"type": "convention", "project": "global", "confidence": "validated"}},
      {"text": "Convention 2: ...", "user_id": "cto", "metadata": {"type": "convention", "project": "global", "confidence": "validated"}}
    ]
  }'
```

#### Lire une memoire par ID
```bash
curl -s "http://host.docker.internal:8050/memories/id/MEMORY_ID"
```

#### Lire toutes les memoires d'un agent
```bash
curl -s "http://host.docker.internal:8050/memories/AGENT_NAME"
```

#### Mettre a jour une memoire
```bash
curl -X PUT "http://host.docker.internal:8050/memories/MEMORY_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Nouveau texte mis a jour",
    "metadata": {"confidence": "validated", "reviewed_by": "qa"}
  }'
```

#### Supprimer une memoire
```bash
curl -X DELETE "http://host.docker.internal:8050/memories/MEMORY_ID"
```

#### Supprimer toutes les memoires d'un agent
```bash
curl -X DELETE "http://host.docker.internal:8050/users/AGENT_NAME/memories"
```

---

### Endpoints de recherche

#### Recherche basique (retrocompatible)
```bash
curl -X POST "http://host.docker.internal:8050/search" \
  -H "Content-Type: application/json" \
  -d '{"query": "quelle BDD pour le projet X", "user_id": "cto", "limit": 5}'
```

#### Recherche avec filtres metadata
```bash
# Filtrer par type ET state
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "architecture decisions",
    "user_id": "cto",
    "limit": 10,
    "filters": {
      "$and": [
        {"type": {"$eq": "architecture"}},
        {"state": {"$eq": "active"}}
      ]
    }
  }'

# Filtrer par projet
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "patterns conventions",
    "user_id": "cto",
    "filters": {"project": {"$eq": "projet-x"}},
    "limit": 5
  }'

# Filtrer par confiance
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "decisions non validees",
    "filters": {"confidence": {"$eq": "hypothesis"}, "state": {"$eq": "active"}},
    "limit": 10
  }'
```

#### Recherche cross-agent (multi user_ids)
```bash
# CTO verifie les blockers de toute l'equipe en un appel
curl -X POST "http://host.docker.internal:8050/search/multi" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "problemes blockers bugs critiques",
    "user_ids": ["lead-backend", "lead-frontend", "devops", "security", "qa"],
    "limit_per_user": 3
  }'
# Retourne : {"lead-backend": [...], "lead-frontend": [...], ...}
```

---

### Endpoints de lifecycle

#### Changer l'etat d'une memoire
```bash
# Deprecier une memoire remplacee
curl -X PATCH "http://host.docker.internal:8050/memories/MEMORY_ID/state" \
  -H "Content-Type: application/json" \
  -d '{"state": "deprecated"}'

# Archiver
curl -X PATCH "http://host.docker.internal:8050/memories/MEMORY_ID/state" \
  -H "Content-Type: application/json" \
  -d '{"state": "archived"}'
```

Etats valides : `draft`, `active`, `deprecated`, `archived`

---

### Endpoints de stats

#### Stats d'un agent
```bash
curl -s "http://host.docker.internal:8050/stats/cto"
# Retourne :
# {
#   "user_id": "cto",
#   "total": 42,
#   "by_type": {"architecture": 10, "convention": 15, "decision": 17},
#   "by_state": {"active": 35, "deprecated": 5, "archived": 2},
#   "by_confidence": {"validated": 20, "tested": 15, "hypothesis": 7},
#   "last_created": "2026-03-10"
# }
```

#### Stats globales
```bash
curl -s "http://host.docker.internal:8050/stats"
# Retourne :
# {
#   "total_memories": 234,
#   "per_agent": {"cto": 42, "lead-backend": 38, ...},
#   "agents_tracked": 11
# }
```

---

### Health checks

#### Basique
```bash
curl -s "http://host.docker.internal:8050/health"
```

#### Deep (verifie Chroma + Ollama)
```bash
curl -s "http://host.docker.internal:8050/health/deep"
# Retourne :
# {"status": "ok|degraded", "checks": {"mem0": "ok", "chroma": "ok", "ollama": "ok"}}
```

---

## 2. SIYUAN NOTE — Knowledge base structuree (port 6806)

Base URL: `http://host.docker.internal:6806`
Auth: `Authorization: Token paperclip-siyuan-token`

### Notebooks
```bash
# Lister les notebooks
curl -s -X POST "http://host.docker.internal:6806/api/notebook/lsNotebooks" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{}'

# Creer un notebook
curl -X POST "http://host.docker.internal:6806/api/notebook/createNotebook" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"name": "Projet X"}'
```

### Documents
```bash
# Creer un document avec Markdown
curl -X POST "http://host.docker.internal:6806/api/filetree/createDocWithMd" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{
    "notebook": "NOTEBOOK_ID",
    "path": "/architecture/adr-001",
    "markdown": "# ADR 001\n\n## Contexte\n..."
  }'

# Rechercher des documents
curl -X POST "http://host.docker.internal:6806/api/filetree/searchDocs" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"k": "authentication best practices"}'

# Lire un document
curl -X POST "http://host.docker.internal:6806/api/filetree/getDoc" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOC_ID"}'
```

### Blocs (edition granulaire)
```bash
# Ajouter un bloc a un document
curl -X POST "http://host.docker.internal:6806/api/block/appendBlock" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{
    "data": "## Nouvelle section\n\nContenu du bloc...",
    "dataType": "markdown",
    "parentID": "PARENT_BLOCK_ID"
  }'

# Mettre a jour un bloc
curl -X POST "http://host.docker.internal:6806/api/block/updateBlock" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "BLOCK_ID",
    "data": "Contenu mis a jour",
    "dataType": "markdown"
  }'

# Lire les blocs enfants
curl -X POST "http://host.docker.internal:6806/api/block/getChildBlocks" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"id": "PARENT_BLOCK_ID"}'
```

### Recherche SQL
```bash
# Recherche SQL sur les blocs
curl -X POST "http://host.docker.internal:6806/api/query/sql" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT * FROM blocks WHERE content LIKE '\''%authentication%'\'' ORDER BY updated DESC LIMIT 10"}'

# Requetes utiles :
# - Blocs modifies recemment : SELECT * FROM blocks WHERE updated > '20260301' ORDER BY updated DESC LIMIT 20
# - Blocs par type : SELECT * FROM blocks WHERE type = 'h' AND content LIKE '%ADR%'
# - Documents d'un notebook : SELECT * FROM blocks WHERE box = 'NOTEBOOK_ID' AND type = 'd'
```

### Attributs custom
```bash
# Lire les attributs d'un bloc
curl -X POST "http://host.docker.internal:6806/api/attr/getBlockAttrs" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"id": "BLOCK_ID"}'

# Definir des attributs custom sur un bloc
curl -X POST "http://host.docker.internal:6806/api/attr/setBlockAttrs" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "BLOCK_ID",
    "attrs": {
      "custom-agent": "cto",
      "custom-type": "architecture",
      "custom-confidence": "validated",
      "custom-project": "projet-x"
    }
  }'
```

---

## 3. CHROMA — Base vectorielle directe (port 8000)

Base URL: `http://host.docker.internal:8000`

### Lister les collections
```bash
curl -s "http://host.docker.internal:8000/api/v1/collections"
```

### Collections recommandees
| Collection | Contenu | Alimente par |
|-----------|---------|-------------|
| `mem0` | Memoires agents (auto via Mem0) | Tous les agents |
| `architecture-decisions` | ADR complets | CTO |
| `coding-conventions` | Standards de code | CTO |
| `research-reports` | Rapports de recherche | Researcher |
| `project-{name}-docs` | Doc d'un projet | Devs, CTO |
| `security-audits` | Resultats d'audit | Security |

---

## 4. OLLAMA — Embeddings (port 11434)

```bash
curl -X POST "http://host.docker.internal:11434/api/embeddings" \
  -d '{"model": "nomic-embed-text", "prompt": "Le texte a vectoriser"}'
```

---

## 5. Strategie de requetage multi-couche

```
BESOIN                              → COUCHE A UTILISER
─────────────────────────────────── → ──────────────────
Decision/convention d'un agent     → Mem0 /search/filtered
Blockers de toute l'equipe         → Mem0 /search/multi
Quoi de neuf depuis dernier reveil → Mem0 /timeline/{user_id}?since=...
Contradictions entre agents        → Mem0 /conflicts?agents=...&topic=...
Graph relations entre decisions    → Mem0 /memories/{id}/graph + Kuzu auto-relations
Documentation technique, notes     → SiYuan /api/query/sql + /api/filetree/searchDocs
Pattern de code similaire          → Chroma /query + Mem0
Embedding custom                    → Ollama /api/embeddings
Deployer, notifier, scraper        → n8n /agent-event
Status services, analytics, CRM    → Mem0 /search/filtered {user_id: "monitoring|analytics|crm"}

FALLBACK si Mem0 down :
  → Continuer sans memoire, sauvegarder en local, re-upload au prochain reveil
FALLBACK si SiYuan down :
  → Chercher dans Mem0, sauvegarder en local, re-upload au prochain reveil
FALLBACK si n8n down :
  → Continuer sans actions serveur, sauvegarder l'intention dans Mem0, reessayer au prochain reveil
```

---

## 6. Matrice : Quel agent utilise quoi

| Agent | Mem0 | SiYuan | Chroma | n8n events |
|-------|:----:|:------:|:------:|:----------:|
| CEO | rw (decisions, strategie) | - | - | notify |
| CTO | rw (architecture, conventions) | rw (best practices, ADR) | rw (ADR, conventions) | notify, git |
| CPO | rw (specs, decisions produit) | rw (PRD, specs) | - | notify, crm-sync |
| CFO | rw (rapports, alertes) | - | - | notify, crm-sync |
| Lead Backend | rw (patterns, bugs) | r (docs techniques) | r (codebase) | notify, git, deploy |
| Lead Frontend | rw (patterns, bugs) | r (docs techniques) | r (codebase) | notify, git, deploy |
| DevOps | rw (configs, incidents) | r (docs infra) | - | **notify, deploy, git** |
| Security | rw (vulns, audits) | r (CVE, OWASP) | rw (scan results) | notify |
| QA | rw (bugs, coverage) | - | - | notify |
| Designer | rw (tokens, composants) | rw (specs, inspirations) | - | notify |
| Researcher | rw (findings) | rw (rapports, articles) | rw (research index) | notify, scrape |

---

## 7. WEBHOOKS — Notifications de mutations (v3)

Base URL: `http://host.docker.internal:8050`

> **v3.1** : Les webhooks sont persistes sur disque (`/app/data/webhooks.json`).
> Ils survivent aux redemarrages du container. Les envois utilisent un retry
> avec backoff exponentiel (3 tentatives : 1s, 2s, 4s).

### Enregistrer un webhook
```bash
curl -X POST "http://host.docker.internal:8050/webhooks/register" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://n8n.home/webhook/memory-event",
    "events": ["memory.created", "memory.state_changed"],
    "filter_user_ids": ["cto", "ceo"],
    "filter_types": ["decision", "architecture"]
  }'
# Retourne : {"id": "uuid", "url": "...", "events": [...]}
```

### Lister les webhooks
```bash
curl -s "http://host.docker.internal:8050/webhooks"
```

### Supprimer un webhook
```bash
curl -X DELETE "http://host.docker.internal:8050/webhooks/WEBHOOK_ID"
```

---

## 8. LINKS — Relations entre memoires (v3)

> **v3.1** : Les links sont persistes sur disque (`/app/data/links.json`).

### Creer un lien
```bash
curl -X POST "http://host.docker.internal:8050/memories/MEMORY_ID/link" \
  -H "Content-Type: application/json" \
  -d '{"target_id": "OLD_MEMORY_ID", "relation": "supersedes"}'
```

Relations valides : `supersedes`, `depends_on`, `contradicts`, `implements`, `refines`

### Voir le graphe
```bash
curl -s "http://host.docker.internal:8050/memories/MEMORY_ID/graph"
# Retourne : {"memory_id": "...", "links": [{target_id, relation, direction, created}], "total": N}
```

---

## 9. TIMELINE — Memoires recentes (v3)

```bash
# Toutes les memoires recentes d'un agent
curl -s "http://host.docker.internal:8050/timeline/cto?limit=10"

# Filtrer par type et date
curl -s "http://host.docker.internal:8050/timeline/cto?type=decision&since=2026-03-01&limit=5"
```

---

## 10. CONFLICTS — Detection de contradictions (v3)

```bash
# Comparer les positions de 2 agents sur un sujet
curl -s "http://host.docker.internal:8050/conflicts?agents=lead-backend,lead-frontend&topic=API+design&limit=5"
# Retourne : {topic, agents, agent_memories: {agent: [memories]}, review_pairs: [...]}
```

---

## 11. n8n — Event Bus infrastructure

Base URL: `$N8N_WEBHOOK_URL/agent-event`

```bash
# Pattern unique pour toutes les actions serveur
curl -X POST "$N8N_WEBHOOK_URL/agent-event" \
  -H "X-N8N-Agent-Key: $N8N_AGENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{"event": "deploy|notify|git|scrape|crm-sync", "agent": "USER_ID", "task_id": "...", "payload": {...}}'
```

Voir [16-n8n-agent-workflows.md](./16-n8n-agent-workflows.md) pour les 19 workflows.
Voir [17-mem0-v3-endpoints.md](./17-mem0-v3-endpoints.md) pour la reference detaillee des nouveaux endpoints.

---

## 12. GRAPH MEMORY — Relations automatiques (v3.1)

Mem0 utilise Kuzu (graph DB embedded) pour extraire automatiquement des relations
entre entites. Le LLM analyse le texte et genere des triplets (entity -> relation -> entity).

### Configuration
Le graph store est configure dans `config.yaml` :
```yaml
graph_store:
  provider: kuzu
  config:
    url: /app/data/kuzu_db
```

### Ce que ca debloque
- Relations automatiques extraites par le LLM
- Queries transitives : "quelles implementations sont impactees par cette decision ?"
- Graphe de dependances entre decisions

### Requete de relations
Les relations extraites sont accessibles via l'endpoint `/memories/{id}/graph` existant,
enrichi par les relations automatiques du graph store.

---

Voir [20-siyuan-bootstrap.md](./20-siyuan-bootstrap.md) pour la configuration et le bootstrap de SiYuan.
Voir [21-paperclip-setup.md](./21-paperclip-setup.md) pour la configuration de Paperclip et la gouvernance.
