# Workflows de gestion des connaissances

Ce document definit les workflows pour le partage, la propagation, la resolution de conflits et la maintenance de la knowledge base.

---

## Workflow 1 : Onboarding d'un nouvel agent

Quand le CEO ou le CTO recrute un nouvel agent, le `promptTemplate` de l'agent recrute DOIT inclure un bloc d'onboarding.

### Template d'onboarding a injecter

```
## ONBOARDING — Premiere chose a faire au premier reveil

1. Charger les conventions de l'entreprise :
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "conventions standards regles", "user_id": "cto", "filters": {"type": {"$eq": "convention"}, "state": {"$eq": "active"}}, "limit": 10}'

2. Charger l'architecture du projet :
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "architecture stack", "user_id": "cto", "filters": {"project": {"$eq": "NOM_PROJET"}, "state": {"$eq": "active"}}, "limit": 10}'

3. Charger les memoires de ton predecesseur (si remplacement) :
curl -s "http://host.docker.internal:8050/memories/NOM_ANCIEN_AGENT"

4. Sauvegarder ton arrivee :
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{"text": "Agent [nom] operationnel. Role: [role]. Premiere tache: [description]", "user_id": "[nom]", "metadata": {"type": "context", "project": "global", "confidence": "validated"}}'
```

### Responsabilite du recruteur

Le CEO/CTO qui recrute doit :
1. Remplacer `NOM_PROJET` par le vrai nom du projet
2. Remplacer `NOM_ANCIEN_AGENT` si c'est un remplacement
3. Inclure les URLs de TOUS les services memoire dans le prompt
4. Specifier quels agents le nouveau doit lire (selon la matrice de permissions)

---

## Workflow 2 : Propagation de decisions

Quand un agent (generalement le CTO) prend une decision qui impacte d'autres agents.

> **Note** : Ce workflow est desormais automatise via n8n — WF13 (memory-to-siyuan) et WF9 (memory-propagation).
> La procedure manuelle ci-dessous reste documentee comme reference, mais n8n gere automatiquement la propagation des decisions et leur publication dans SiYuan.

### Procedure

```
Etape 1 : Sauvegarder la nouvelle decision
  POST /memories
  {
    "text": "DECISION: [titre]\nCONTEXT: ...\nCHOICE: ...",
    "user_id": "cto",
    "metadata": {
      "type": "architecture",
      "project": "projet-x",
      "confidence": "tested",
      "supersedes": "OLD_MEMORY_ID"
    }
  }

Etape 2 : Deprecier l'ancienne decision
  PATCH /memories/OLD_MEMORY_ID/state
  {"state": "deprecated"}

Etape 3 : Notifier les agents impactes
  Pour chaque agent concerne, creer une issue Paperclip :
  POST $PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/issues
  {
    "title": "Architecture modifiee : [resume du changement]",
    "body": "## Changement\n[description]\n\n## Action requise\nLire la nouvelle decision CTO dans Mem0.\nAdapter ton implementation si necessaire.\n\n## Memoire CTO a consulter\nPOST /search/filtered {user_id: 'cto', filters: {type: {$eq: 'architecture'}, project: {$eq: 'projet-x'}, state: {$eq: 'active'}}}",
    "assigneeAgentId": "UUID_AGENT_IMPACTE",
    "status": "todo"
  }
```

### Quand propager

| Declencheur | Agents a notifier |
|-------------|------------------|
| Changement de stack/framework | Lead Backend, Lead Frontend, DevOps |
| Changement de conventions de code | Lead Backend, Lead Frontend, QA |
| Changement d'API contract | Lead Backend, Lead Frontend |
| Changement d'infra/deploiement | DevOps, Security |
| Changement de design system | Designer, Lead Frontend |
| Changement de specs produit | CTO, Designer, Lead Backend, Lead Frontend |

---

## Workflow 3 : Resolution de conflits

Quand deux agents ont des positions contradictoires.

### Detection du conflit

Un conflit existe quand :
- Deux memoires actives se contredisent
- Un agent commente une issue en desaccord avec un autre
- Une implementation diverge d'une decision enregistree

### Procedure d'escalation

```
Niveau 1 : Discussion entre les agents concernes
  → Les deux agents sauvent leur position avec confidence: "hypothesis"
  → Les deux commentent sur la meme issue Paperclip avec leurs arguments

Niveau 2 : Arbitrage par le CTO (conflits techniques)
  → CTO lit les deux memoires :
    POST /search/multi {query: "[sujet du conflit]", user_ids: ["agent-a", "agent-b"]}
  → CTO recherche des references dans SiYuan (recherche SQL) et Mem0
  → CTO prend la decision finale

Niveau 3 : Arbitrage par le CEO (conflits strategiques ou inter-C-level)
  → CEO lit les positions de tous les C-level concernes
  → CEO tranche

Resolution :
  1. L'arbitre cree la decision finale :
     POST /memories {metadata: {supersedes: "BOTH_MEMORY_IDS", confidence: "validated"}}
  2. L'arbitre deprecie les deux memoires conflictuelles :
     PATCH /memories/MEMORY_A/state {"state": "deprecated"}
     PATCH /memories/MEMORY_B/state {"state": "deprecated"}
  3. L'arbitre cree une issue pour l'agent "perdant" :
     "Adapter ton travail suite a la decision [resume]"
```

### Regle d'or

**L'agent le plus haut dans la hierarchie gagne en cas de conflit non resolu.**
CEO > CTO/CPO/CFO > Leads > QA/Security/Designer/Researcher

---

## Workflow 4 : Review periodique des connaissances

Tache mensuelle (ou par fin de projet) assignee au CTO.

### Procedure

```
Etape 1 : Collecter les stats
  GET http://host.docker.internal:8050/stats

Etape 2 : Identifier les memoires a risque
  # Memoires hypothesis jamais promues (> 30 jours)
  POST /search/filtered {
    query: "decisions non validees",
    filters: {"confidence": {"$eq": "hypothesis"}, "state": {"$eq": "active"}}
  }

Etape 3 : Pour chaque memoire a risque
  - Si toujours pertinente et testee → promouvoir a "tested" ou "validated"
  - Si obsolete → deprecier
  - Si remplacee → verifier que supersedes existe, sinon creer

Etape 4 : Archiver les memoires deprecated depuis > 30 jours
  POST /search/filtered {filters: {"state": {"$eq": "deprecated"}}}
  Pour chaque : PATCH /memories/{id}/state {"state": "archived"}

Etape 5 : Creer le Knowledge Digest
  POST /memories {
    text: "KNOWLEDGE DIGEST [date]: X memoires actives, Y deprecated, Z archivees. Themes principaux: [resume]. Decisions cles: [liste]. Points d'attention: [risques]",
    user_id: "cto",
    metadata: {type: "report", project: "global", confidence: "validated"}
  }

Etape 6 : Reporter au CEO
  Commenter la tache avec le resume du digest
```

---

## Workflow 5 : Boucle Task → Memory → Task

### A la completion d'une tache (CHAQUE agent)

Apres avoir fait `PATCH /issues/{id} {status: "done"}`, l'agent DOIT :

```bash
# Sauvegarder les apprentissages lies a la tache
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Task '$PAPERCLIP_TASK_ID' terminee. Apprentissages: [resume de ce qui a ete appris]. Decisions: [decisions prises]. Problemes: [problemes rencontres et solutions]",
    "user_id": "MON_ID",
    "metadata": {
      "type": "learning",
      "project": "nom-projet",
      "confidence": "tested",
      "source_task": "'$PAPERCLIP_TASK_ID'"
    }
  }'

# Reporter les couts de l'execution a Paperclip
curl -X POST "http://host.docker.internal:8060/api/companies/$COMPANY_ID/cost-events" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"agentId": "'$PAPERCLIP_AGENT_ID'", "issueId": "'$PAPERCLIP_TASK_ID'", "provider": "ollama", "model": "MODEL_USED", "inputTokens": N, "outputTokens": N, "costCents": 0}'
```

### A la creation d'une nouvelle tache (CEO, CTO)

Le createur de la tache DOIT chercher les memoires pertinentes et les inclure dans la description :

```bash
# Chercher les memoires liees au sujet de la tache
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "[sujet de la tache]", "filters": {"state": {"$eq": "active"}, "project": {"$eq": "nom-projet"}}, "limit": 5}'
```

Puis inclure dans le body de l'issue :

```
## Contexte memoire
Les memoires suivantes sont pertinentes :
- CTO decision [resume] (confidence: validated)
- Backend pattern [resume] (confidence: tested)
Consulter Mem0 pour les details complets.
```

---

## Workflow 6 : Knowledge Digest du Researcher

Tache hebdomadaire ou bi-mensuelle assignee au Researcher.

### Procedure

```
Etape 1 : Collecter les recherches recentes
  POST /search/filtered {
    user_id: "researcher",
    filters: {"state": {"$eq": "active"}},
    query: "recherches recentes",
    limit: 20
  }

Etape 2 : Synthetiser
  Creer un resume des themes principaux, recommandations, et sujets ouverts

Etape 3 : Sauvegarder le digest
  POST /memories {
    text: "RESEARCH DIGEST [date]: [resume des recherches]. Recommandations actives: [liste]. Sujets a explorer: [liste]. Technologies surveillees: [liste]",
    user_id: "researcher",
    metadata: {type: "report", project: "global", confidence: "validated", tags: "digest,weekly"}
  }

Etape 4 : Creer un doc dans SiYuan pour accessibilite globale
  POST http://host.docker.internal:6806/api/filetree/createDocWithMd {
    notebook: "NOTEBOOK_ID_RESEARCH",
    path: "/digests/research-digest-[date]",
    markdown: "[contenu du digest en markdown]"
  }
  Note : Ce doc est egalement auto-publie via n8n WF18 (siyuan-weekly-digest).
  Une notification push est envoyee aux utilisateurs SiYuan a la publication.
```

---

## Workflow 7 : Fallback quand un service memoire est down

### Si Mem0 est indisponible

```
1. L'agent detecte l'erreur (timeout ou 5xx sur /search)
2. L'agent continue sa tache SANS memoire (mode degrade)
3. L'agent sauvegarde ses resultats en local (fichier dans le workspace)
4. L'agent commente sur sa tache Paperclip : "Mem0 indisponible, resultats sauvegardes localement"
5. Au prochain reveil, l'agent verifie /health et re-upload les resultats locaux dans Mem0
```

### Si SiYuan est indisponible

```
1. L'agent utilise Mem0 comme fallback pour la recherche
2. Chercher dans les memoires du Researcher : POST /search {user_id: "researcher", query: "..."}
3. Les documents seront crees dans SiYuan au prochain reveil quand le service est retabli
```

### Si Chroma est indisponible

```
1. Mem0 est aussi impacte (Mem0 utilise Chroma)
2. Appliquer le fallback Mem0 ci-dessus
```

---

## Workflow 8 : Propagation automatique via n8n

Automatise le Workflow 2 grace aux webhooks Mem0 + n8n.

### Declencheur
Mem0 webhook `memory.created` ou `memory.state_changed` filtre sur :
- `type` = `decision` ou `architecture`
- `user_id` = `cto` ou `ceo`

### Etapes
1. n8n recoit le webhook de Mem0
2. n8n lit la memoire pour extraire le contexte
3. n8n determine les agents impactes via la matrice :
   - Decisions CEO → impactent cto, cpo, cfo
   - Decisions CTO → impactent lead-backend, lead-frontend, devops, security, qa
4. Pour chaque agent impacte, n8n cree une issue Paperclip :
   ```
   POST $PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues
   {
     "title": "[AUTO] Decision modifiee: [titre]",
     "body": "Memory ID: [id]. Action: lire et adapter.",
     "assignee": "[agent_user_id]",
     "status": "todo"
   }
   ```
5. Paperclip reveille l'agent (wakeOnAssignment)

### Temps de propagation
~30 secondes (vs 5-15 min avec polling heartbeat)

---

## Workflow 9 : Consommation des channels systeme

### Principe
n8n alimente Mem0 sous des user_ids systeme (monitoring, analytics, etc.).
Les agents lisent ces channels dans leur Etape 0 au reveil.

### Channels et consommateurs

| Channel | Producteur | Consommateurs |
|---------|-----------|---------------|
| monitoring | n8n ← Uptime Kuma | CEO, CTO, DevOps, Security, QA, Researcher |
| analytics | n8n ← Umami | CEO, CPO, CFO |
| calendar | n8n ← Cal.com | CEO, CPO |
| crm | n8n ← Twenty CRM | CEO, CPO, CFO |
| security-events | n8n ← CrowdSec | DevOps, Security |
| deployments | n8n ← Dokploy/Duplicati | CTO, DevOps |
| git-events | n8n ← Gitea | CTO, Backend, Frontend, DevOps |

### Comment lire
```bash
curl -X POST "http://host.docker.internal:8050/search/filtered" \
  -H "Content-Type: application/json" \
  -d '{"query": "[sujet]", "user_id": "[channel]", "filters": {"state": {"$eq": "active"}}, "limit": 5}'
```

---

## Workflow 10 : Auto-publication SiYuan via n8n

Quand un agent sauvegarde une memoire importante (type: decision, architecture, convention, prd, spec, finding) :

```
1. Mem0 envoie un webhook `memory.created` a n8n
2. n8n recoit le webhook et determine le notebook SiYuan cible :
   - architecture/convention → notebook "architecture"
   - prd/spec → notebook "produit"
   - finding/research → notebook "research"
   - decision → notebook "global"
3. n8n formate la memoire en markdown et cree un doc SiYuan
4. n8n ajoute les attributs custom (custom-mem0-id, custom-agent, custom-type, custom-confidence)
5. n8n envoie une notification push SiYuan (visible sur mobile)
```

Ce workflow est entierement automatique — aucune action requise des agents.
L'agent sauvegarde dans Mem0, n8n publie dans SiYuan.

Voir [16-n8n-agent-workflows.md](./16-n8n-agent-workflows.md) WF13 pour les details.

---

## Workflow 11 : Dashboards live dans SiYuan

n8n rafraichit automatiquement 3 dashboards dans SiYuan (notebook "global") :

| Dashboard | Frequence | Source Mem0 | Contenu |
|-----------|-----------|------------|---------|
| services | 5 min | monitoring | Status, uptime, response time |
| analytics | 1h | analytics | Pages vues, visiteurs, conversions |
| team-activity | 30 min | stats + timelines | Activite recente par agent |

Les dashboards sont consultables sur mobile via l'app SiYuan.
Pour les query embeds dynamiques dans les docs, voir [20-siyuan-bootstrap.md](./20-siyuan-bootstrap.md).
