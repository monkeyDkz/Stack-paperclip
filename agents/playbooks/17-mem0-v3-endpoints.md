# Endpoints Mem0 v3 — Webhooks, Links, Timeline, Conflicts

> Ce document couvre les **nouveaux endpoints ajoutes dans Mem0 v3**.
> Les endpoints CRUD, recherche, lifecycle et stats existants sont dans [12-memory-api-reference.md](./12-memory-api-reference.md).

Base URL: `http://host.docker.internal:8050`

---

## 1. Webhooks

Les webhooks permettent a n8n (ou tout autre service) de reagir en temps reel aux evenements memoire.

### Enregistrer un webhook

```bash
curl -X POST "http://host.docker.internal:8050/webhooks/register" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://n8n.home/webhook/memory-event",
    "events": ["memory.created", "memory.updated", "memory.state_changed"],
    "filter_user_ids": ["cto"],
    "filter_types": ["decision"]
  }'
# Retourne :
# {
#   "id": "a1b2c3d4-...",
#   "url": "https://n8n.home/webhook/memory-event",
#   "events": ["memory.created", "memory.updated", "memory.state_changed"]
# }
```

### Lister tous les webhooks enregistres

```bash
curl -s "http://host.docker.internal:8050/webhooks"
# Retourne :
# {
#   "webhooks": [
#     {
#       "id": "a1b2c3d4-...",
#       "url": "https://n8n.home/webhook/memory-event",
#       "events": ["memory.created", "memory.updated", "memory.state_changed"],
#       "filter_user_ids": ["cto"],
#       "filter_types": ["decision"],
#       "created": "2026-03-10"
#     }
#   ]
# }
```

### Supprimer un webhook

```bash
curl -X DELETE "http://host.docker.internal:8050/webhooks/a1b2c3d4-xxxx"
# Retourne :
# {"status": "deleted", "webhook_id": "a1b2c3d4-xxxx"}
```

### Payloads des evenements dispatches

Quand un evenement se produit, Mem0 envoie un POST au(x) webhook(s) enregistres avec le payload correspondant.

#### memory.created

```json
{
  "event": "memory.created",
  "webhook_id": "a1b2c3d4-...",
  "memory_id": "mem-xxxx",
  "user_id": "cto",
  "type": "decision",
  "text_preview": "DECISION: Utiliser PostgreSQL..."
}
```

#### memory.updated

```json
{
  "event": "memory.updated",
  "webhook_id": "a1b2c3d4-...",
  "memory_id": "mem-xxxx",
  "user_id": "cto",
  "updated_fields": ["text", "metadata.confidence"]
}
```

Variante avec creation de lien :

```json
{
  "event": "memory.updated",
  "webhook_id": "a1b2c3d4-...",
  "memory_id": "mem-xxxx",
  "user_id": "cto",
  "link_created": {"target_id": "mem-yyyy", "relation": "supersedes"}
}
```

#### memory.state_changed

```json
{
  "event": "memory.state_changed",
  "webhook_id": "a1b2c3d4-...",
  "memory_id": "mem-xxxx",
  "old_state": "active",
  "new_state": "deprecated",
  "user_id": "cto",
  "type": "decision"
}
```

---

## 2. Links (relations entre memoires)

Les links permettent de creer un graphe de relations entre memoires : remplacement, dependance, contradiction, etc.

### Creer un lien

```bash
curl -X POST "http://host.docker.internal:8050/memories/mem-xxxx/link" \
  -H "Content-Type: application/json" \
  -d '{
    "target_id": "mem-yyyy",
    "relation": "supersedes"
  }'
# Retourne :
# {
#   "status": "linked",
#   "memory_id": "mem-xxxx",
#   "link": {
#     "target_id": "mem-yyyy",
#     "relation": "supersedes",
#     "created": "2026-03-10"
#   }
# }
```

### Consulter le graphe d'une memoire

```bash
curl -s "http://host.docker.internal:8050/memories/mem-xxxx/graph"
# Retourne :
# {
#   "memory_id": "mem-xxxx",
#   "links": [
#     {"target_id": "mem-yyyy", "relation": "supersedes", "direction": "outgoing", "created": "2026-03-10"},
#     {"target_id": "mem-zzzz", "relation": "depends_on", "direction": "incoming", "created": "2026-03-09"}
#   ],
#   "total": 2
# }
```

### Types de relations

| Relation | Signification | Exemple |
|----------|--------------|---------|
| `supersedes` | Cette memoire remplace la cible | Nouvelle decision remplace l'ancienne |
| `depends_on` | Cette memoire depend de la cible | Implementation depend d'une decision d'archi |
| `contradicts` | Cette memoire entre en conflit avec la cible | Deux agents ont des visions opposees |
| `implements` | Cette memoire implemente la cible | Code qui implemente une decision d'architecture |
| `refines` | Cette memoire ajoute du detail a la cible | Precision technique sur une convention |

### Exemples concrets

```bash
# Le CTO remplace une ancienne decision par une nouvelle
curl -X POST "http://host.docker.internal:8050/memories/mem-nouvelle-decision/link" \
  -H "Content-Type: application/json" \
  -d '{"target_id": "mem-ancienne-decision", "relation": "supersedes"}'

# Le lead-backend indique que son pattern depend d'une decision CTO
curl -X POST "http://host.docker.internal:8050/memories/mem-pattern-backend/link" \
  -H "Content-Type: application/json" \
  -d '{"target_id": "mem-decision-cto", "relation": "depends_on"}'

# Le lead-backend implemente une decision d'architecture
curl -X POST "http://host.docker.internal:8050/memories/mem-implementation/link" \
  -H "Content-Type: application/json" \
  -d '{"target_id": "mem-archi-decision", "relation": "implements"}'

# Le CTO raffine une convention existante
curl -X POST "http://host.docker.internal:8050/memories/mem-convention-detail/link" \
  -H "Content-Type: application/json" \
  -d '{"target_id": "mem-convention-parent", "relation": "refines"}'

# Signaler un conflit entre deux memoires
curl -X POST "http://host.docker.internal:8050/memories/mem-opinion-a/link" \
  -H "Content-Type: application/json" \
  -d '{"target_id": "mem-opinion-b", "relation": "contradicts"}'
```

---

## 3. Timeline

Recupere l'historique des memoires actives d'un agent, triees par date de creation decroissante.

```bash
curl -s "http://host.docker.internal:8050/timeline/cto?type=decision&since=2026-03-01&limit=20"
# Retourne :
# {
#   "user_id": "cto",
#   "memories": [
#     {"id": "mem-xxxx", "text": "...", "metadata": {...}, "created": "2026-03-10"},
#     {"id": "mem-yyyy", "text": "...", "metadata": {...}, "created": "2026-03-08"}
#   ],
#   "total": 2
# }
```

Parametres :

| Parametre | Obligatoire | Description |
|-----------|:-----------:|-------------|
| `user_id` (path) | Oui | L'agent dont on veut la timeline |
| `type` | Non | Filtrer par type de memoire (`decision`, `architecture`, etc.) |
| `since` | Non | Date minimale au format `YYYY-MM-DD` |
| `limit` | Non | Nombre max de memoires retournees (defaut: 20) |

> **Note :** Seules les memoires avec `state: "active"` sont retournees.

### Exemples

```bash
# Toutes les decisions du CTO depuis le 1er mars
curl -s "http://host.docker.internal:8050/timeline/cto?type=decision&since=2026-03-01&limit=20"

# Les 10 derniers bugs du lead-backend
curl -s "http://host.docker.internal:8050/timeline/lead-backend?type=bug&limit=10"

# Tout l'historique actif du security
curl -s "http://host.docker.internal:8050/timeline/security?limit=50"

# Les incidents devops de la derniere semaine
curl -s "http://host.docker.internal:8050/timeline/devops?type=incident&since=2026-03-03&limit=10"
```

---

## 4. Detection de conflits

Cet endpoint compare les memoires actives de plusieurs agents sur un meme sujet et retourne les paires a examiner.

```bash
curl -s "http://host.docker.internal:8050/conflicts?agents=cto,lead-backend&topic=database&limit=5"
# Retourne :
# {
#   "topic": "database",
#   "agents": ["cto", "lead-backend"],
#   "agent_memories": {
#     "cto": [
#       {"id": "mem-xxxx", "text": "DECISION: PostgreSQL pour tout", "metadata": {...}}
#     ],
#     "lead-backend": [
#       {"id": "mem-yyyy", "text": "Pattern: MongoDB pour les logs", "metadata": {...}}
#     ]
#   },
#   "review_pairs": [
#     {
#       "agent_a": "cto",
#       "memories_a": [{"id": "mem-xxxx", "text": "..."}],
#       "agent_b": "lead-backend",
#       "memories_b": [{"id": "mem-yyyy", "text": "..."}]
#     }
#   ],
#   "total_pairs": 1
# }
```

Parametres :

| Parametre | Obligatoire | Description |
|-----------|:-----------:|-------------|
| `agents` | Oui | Liste d'agents separes par virgules |
| `topic` | Oui | Sujet a rechercher dans les memoires |
| `limit` | Non | Nombre max de memoires par agent (defaut: 5) |

### Exemples

```bash
# Verifier les conflits entre CTO et lead-backend sur la BDD
curl -s "http://host.docker.internal:8050/conflicts?agents=cto,lead-backend&topic=database&limit=5"

# Verifier les conflits entre tous les devs sur l'authentification
curl -s "http://host.docker.internal:8050/conflicts?agents=cto,lead-backend,lead-frontend,security&topic=authentication&limit=5"

# Le CEO verifie l'alignement des agents sur la strategie produit
curl -s "http://host.docker.internal:8050/conflicts?agents=ceo,cpo,cto&topic=roadmap+priorities&limit=10"
```

---

## 5. User IDs systeme (convention n8n)

n8n alimente Mem0 sous des `user_id` virtuels que tous les agents peuvent lire. Ces IDs representent des flux de donnees automatises depuis les services du stack.

| user_id | Source | Frequence | Contenu |
|---------|--------|-----------|---------|
| `monitoring` | Uptime Kuma | Toutes les 5 min | Status des services (up/down/degraded) |
| `analytics` | Umami | Toutes les 1h | Stats web (visites, pages, referrers) |
| `calendar` | Cal.com | Temps reel (webhook) | Reservations, rendez-vous |
| `crm` | Twenty CRM | Temps reel (webhook) | Contacts, deals, pipeline |
| `security-events` | CrowdSec | Temps reel (webhook) | Alertes attaques, IPs bannies |
| `deployments` | n8n | Temps reel (webhook) | Resultats de deploiement et backups |
| `git-events` | Gitea | Temps reel (webhook) | Commits, PRs, issues |

### Lire les memoires systeme

```bash
# Verifier le status des services
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "service status",
    "user_id": "monitoring",
    "filters": {"state": {"$eq": "active"}},
    "limit": 10
  }'

# Derniers evenements de securite
curl -s "http://host.docker.internal:8050/timeline/security-events?limit=10"

# Derniers deploiements
curl -s "http://host.docker.internal:8050/timeline/deployments?limit=5"

# Stats web recentes
curl -s "http://host.docker.internal:8050/timeline/analytics?since=2026-03-09&limit=5"

# Derniers commits/PRs
curl -s "http://host.docker.internal:8050/timeline/git-events?limit=10"
```

> **Convention importante :** Les agents **lisent** ces user_ids systeme mais **n'ecrivent jamais** dessus. n8n est le seul writer. Un agent qui a besoin de stocker une analyse basee sur ces donnees doit ecrire sous son propre user_id avec une reference au user_id systeme source.

### Exemple : un agent exploite des donnees systeme

```bash
# Le security analyse les evenements CrowdSec et stocke sa conclusion sous son propre user_id
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "ANALYSE: Pic d attaques brute-force SSH detecte entre 02h et 04h. Source: security-events. Recommandation: renforcer fail2ban et ajouter geo-blocking.",
    "user_id": "security",
    "metadata": {
      "type": "vulnerability",
      "project": "global",
      "confidence": "tested",
      "source_user_id": "security-events"
    }
  }'
```

---

## Resume des nouveaux endpoints v3

| Methode | Endpoint | Description |
|---------|----------|-------------|
| `POST` | `/webhooks/register` | Enregistrer un webhook |
| `GET` | `/webhooks` | Lister les webhooks |
| `DELETE` | `/webhooks/{webhook_id}` | Supprimer un webhook |
| `POST` | `/memories/{memory_id}/link` | Creer un lien entre memoires |
| `GET` | `/memories/{memory_id}/graph` | Voir le graphe d'une memoire |
| `GET` | `/timeline/{user_id}` | Timeline des memoires actives |
| `GET` | `/conflicts` | Detecter les conflits inter-agents |
