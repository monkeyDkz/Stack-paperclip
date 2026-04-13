# Protocole Memoire — Standard obligatoire pour tous les agents

Ce document definit les regles que CHAQUE agent doit suivre pour lire et ecrire dans Mem0.

## 1. Schema metadata obligatoire

Chaque appel `POST /memories` DOIT inclure ces champs dans `metadata` :

| Champ | Obligatoire | Valeurs | Description |
|-------|:-----------:|---------|-------------|
| `type` | Oui | voir ci-dessous | Categorie de la memoire |
| `project` | Oui | nom du projet ou `"global"` | Scope de la memoire |
| `state` | Auto | `active` (defaut), `deprecated`, `archived` | Lifecycle (injecte auto par le serveur) |
| `created` | Auto | `YYYY-MM-DD` | Date de creation (injecte auto par le serveur) |
| `confidence` | Oui | `hypothesis`, `tested`, `validated` | Niveau de fiabilite |

### Champs optionnels recommandes

| Champ | Valeurs | Description |
|-------|---------|-------------|
| `source_task` | UUID Paperclip | L'issue qui a genere cette memoire |
| `supersedes` | memory ID | Memoire que celle-ci remplace |
| `depends_on` | memory ID | Memoire dont celle-ci depend |
| `reviewed_by` | nom-agent | Agent qui a valide cette memoire |
| `expires` | `YYYY-MM-DD` ou vide | Date d'expiration (pour infos temporaires) |
| `tags` | `tag1,tag2,tag3` | Tags libres separes par virgules |

### Types de memoire valides

| Type | Utilise par | Description |
|------|-----------|-------------|
| `decision` | Tous | Decision technique ou business |
| `learning` | Tous | Apprentissage d'une erreur ou succes |
| `bug` | Backend, Frontend, QA | Bug rencontre et sa resolution |
| `architecture` | CTO | Decision d'architecture (ADR) |
| `convention` | CTO | Convention de code ou process |
| `prd` | CPO | Specification produit |
| `research` | Researcher | Resultat de recherche |
| `incident` | DevOps | Incident et sa resolution |
| `vulnerability` | Security | Vulnerabilite trouvee |
| `config` | DevOps | Configuration d'infrastructure |
| `pattern` | Backend, Frontend | Pattern de code reutilisable |
| `component` | Designer, Frontend | Composant UI defini |
| `tokens` | Designer | Design tokens (couleurs, typo, spacing) |
| `wireframe` | Designer | Wireframe de page |
| `metrics` | QA, CFO | Metriques (coverage, couts) |
| `report` | CFO | Rapport financier |

### Exemple complet

```bash
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "DECISION: Utiliser PostgreSQL pour le projet X\nCONTEXT: Besoin de transactions ACID et de relations complexes\nCHOICE: PostgreSQL 16\nALTERNATIVES: MongoDB rejete car besoin de joins complexes\nCONSEQUENCES: Bonne scalabilite verticale, besoin de tuning pour gros volumes\nSTATUS: active\nLINKED_TASK: ea0bc1a8-xxxx",
    "user_id": "cto",
    "metadata": {
      "type": "architecture",
      "project": "projet-x",
      "confidence": "tested",
      "source_task": "ea0bc1a8-xxxx",
      "tags": "database,postgresql,architecture"
    }
  }'
```

---

## 2. Lifecycle des memoires

```
[creation] ──→ active ──→ deprecated ──→ archived ──→ [deletion]
                              ↑
                   (quand une nouvelle decision
                    avec "supersedes" est creee)
```

### Regles de transition

| De | Vers | Qui peut faire | Quand |
|----|------|---------------|-------|
| (new) | `active` | Tout agent | Par defaut a la creation |
| `active` | `deprecated` | Auteur, CTO, CEO | Quand remplacee par une nouvelle decision |
| `deprecated` | `archived` | CTO, CEO | Lors des reviews periodiques |
| `archived` | (supprime) | CEO uniquement | Nettoyage exceptionnel |

### Comment deprecier une memoire

```bash
# 1. Creer la nouvelle decision avec supersedes
curl -X POST "http://host.docker.internal:8050/memories" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "DECISION: Migrer vers CockroachDB...",
    "user_id": "cto",
    "metadata": {
      "type": "architecture",
      "project": "projet-x",
      "confidence": "hypothesis",
      "supersedes": "OLD_MEMORY_ID"
    }
  }'

# 2. Deprecier l'ancienne
curl -X PATCH "http://host.docker.internal:8050/memories/OLD_MEMORY_ID/state" \
  -H "Content-Type: application/json" \
  -d '{"state": "deprecated"}'
```

---

## 3. Format Decision Record

Pour toute memoire de `type: "decision"` ou `type: "architecture"`, le champ `text` DOIT suivre ce format :

```
DECISION: [titre court, max 80 caracteres]
CONTEXT: [1-2 phrases : pourquoi cette decision etait necessaire]
CHOICE: [ce qui a ete decide, avec details techniques]
ALTERNATIVES: [ce qui a ete rejete et pourquoi, 1 ligne par alternative]
CONSEQUENCES: [impact attendu, risques identifies]
STATUS: active|deprecated
LINKED_TASK: [paperclip issue id ou "none"]
```

### Pourquoi ce format
- Texte structure lisible par des LLMs locaux (pas de JSON a parser)
- Chaque section est cherchable via Mem0 search
- Le STATUS dans le texte est un backup du champ metadata.state
- Compatible avec des modeles 14B qui ne gerent pas le JSON complexe

---

## 4. Niveaux de confiance et promotion

### Les 3 niveaux

| Niveau | Signification | Quand l'utiliser |
|--------|--------------|-----------------|
| `hypothesis` | Analyse initiale, pas testee en production | Researcher propose une techno, CTO fait un choix initial |
| `tested` | Implemente et verifie par un agent | Backend a implemente et les tests passent |
| `validated` | Confirme par un second agent independant | QA a teste, Security a audite, CTO a review |

### Qui peut promouvoir

| Promotion | Qui peut faire | Comment |
|-----------|---------------|---------|
| → `hypothesis` | Tout agent | Defaut a la creation pour les decisions |
| → `tested` | L'agent qui a implemente | Apres implementation et tests verts |
| → `validated` | QA, Security, ou CTO | Apres review/audit/test independant |

### Comment promouvoir

```bash
# QA valide un pattern du backend
curl -X PUT "http://host.docker.internal:8050/memories/MEMORY_ID" \
  -H "Content-Type: application/json" \
  -d '{"metadata": {"confidence": "validated", "reviewed_by": "qa"}}'
```

---

## 5. Matrice de permissions cross-agent

Convention sur qui lit les memoires de qui (soft, pas de controle serveur) :

```
                          LECTEURS
                CEO CTO CPO CFO BK  FR  DO  SE  QA  DE  RE
ECRIVAINS  CEO  rw  r   r   r   -   -   -   -   -   -   -
           CTO  r   rw  r   -   r   r   r   r   r   -   r
           CPO  r   r   rw  -   -   -   -   -   -   r   -
           CFO  r   -   -   rw  -   -   -   -   -   -   -
           BK   -   r   -   -   rw  r   -   r   r   -   -
           FR   -   r   -   -   r   rw  -   -   r   r   -
           DO   -   r   -   -   -   -   rw  r   -   -   -
           SE   -   r   -   -   r   r   r   rw  -   -   -
           QA   -   r   -   -   r   r   -   -   rw  -   -
           DE   -   -   r   -   -   r   -   -   -   rw  -
           RE   -   r   -   -   -   -   -   -   -   -   rw
```

`r` = lire, `rw` = lire et ecrire (son propre namespace), `-` = pas de lecture necessaire

### En pratique dans les prompts

Chaque agent a dans son "Etape 0" les requetes vers les agents qu'il doit lire :

```bash
# Exemple pour Lead Frontend : lit CTO, Backend, Designer
curl -X POST "http://host.docker.internal:8050/search/multi" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "conventions architecture endpoints composants",
    "user_ids": ["cto", "lead-backend", "designer"],
    "limit_per_user": 3
  }'
```

---

## 6. Deduplication

### Cote serveur (optionnel)

Ajouter `"deduplicate": true` au `POST /memories` :
- Le serveur cherche une memoire similaire (cosine > 0.92) du meme user_id
- Si trouvee : retourne `{"status": "duplicate", "existing_memory_id": "xxx"}`
- Si pas trouvee : cree normalement

### Cote agent (recommande)

Avant de sauvegarder, l'agent DEVRAIT chercher si une memoire similaire existe :

```bash
# Chercher avant de sauvegarder
curl -X POST "http://host.docker.internal:8050/search" \
  -H "Content-Type: application/json" \
  -d '{"query": "le contenu a sauvegarder", "user_id": "MON_ID", "limit": 1}'
# Si le resultat est tres similaire -> ne pas re-sauvegarder
```

---

## 7. Procedure standard pour chaque agent

### Au reveil (Etape 0 — OBLIGATOIRE)

```
1. Charger ses propres memoires actives :
   POST /search/filtered {user_id: "self", filters: {state: {$eq: "active"}}, limit: 10}

2. Charger les conventions du CTO :
   POST /search/filtered {user_id: "cto", filters: {type: {$eq: "convention"}, state: {$eq: "active"}}, limit: 5}

3. Charger le contexte cross-agent (selon la matrice) :
   POST /search/multi {query: "contexte pertinent", user_ids: [...], limit_per_user: 3}
```

### A la sauvegarde (Etape finale — OBLIGATOIRE)

```
1. Verifier la deduplication (search avant save)
2. Inclure TOUS les champs metadata obligatoires
3. Utiliser le format Decision Record pour les decisions
4. Ajouter source_task si la memoire vient d'une issue Paperclip
5. Ajouter supersedes si la memoire remplace une ancienne
```

---

## 8. Relations entre memoires (v3)

Les memoires peuvent etre liees entre elles via `POST /memories/{id}/link` :

| Relation | Signification | Exemple |
|----------|--------------|---------|
| `supersedes` | Remplace une ancienne memoire | Nouvelle decision → ancienne decision |
| `depends_on` | Depend d'une autre memoire | Implementation → decision d'architecture |
| `contradicts` | En conflit avec une autre | Position Backend vs position Frontend |
| `implements` | Implemente une decision | Code pattern → architecture decision |
| `refines` | Ajoute du detail | Spec detaillee → wireframe initial |

## 9. Webhook Events (v3)

Mem0 dispatch des webhooks sur les mutations :

| Event | Quand | Payload |
|-------|-------|---------|
| `memory.created` | Nouvelle memoire ajoutee | memory_id, user_id, type, text_preview |
| `memory.updated` | Memoire modifiee | memory_id, user_id, updated_fields |
| `memory.state_changed` | Transition de lifecycle | memory_id, old_state, new_state, user_id, type |

Enregistrer un webhook : `POST /webhooks/register`
n8n utilise ces webhooks pour le workflow `memory-propagation` (detection auto de decisions et notification des agents impactes).

## 10. System User IDs (v3)

n8n alimente Mem0 sous des user_ids virtuels. Convention :
- Les agents peuvent **LIRE** ces channels mais **NE DOIVENT PAS ecrire** directement
- Seul n8n ecrit dans ces channels

| user_id | Source | Contenu | Frequence |
|---------|--------|---------|-----------|
| `monitoring` | Uptime Kuma | Status services, uptimes, incidents | 5 min |
| `analytics` | Umami | Pages vues, visitors, top pages | 1h |
| `calendar` | Cal.com | RDV, bookings | Temps reel |
| `crm` | Twenty CRM | Contacts, deals, pipeline | Temps reel |
| `security-events` | CrowdSec | Attaques, IPs bloquees | Temps reel |
| `deployments` | Dokploy + Duplicati | Deploys, backups | Temps reel |
| `git-events` | Gitea | Commits, PRs, issues | Temps reel |

---

## 11. Conventions SiYuan Note

SiYuan Note (port 6806) est la base de connaissances structuree de l'equipe. Chaque agent peut y creer des documents via l'API SiYuan.

### Organisation des notebooks

Un notebook par domaine :

| Notebook | Contenu | Agents principaux |
|----------|---------|-------------------|
| `architecture` | ADR, decisions techniques, schemas | CTO, DevOps |
| `produit` | Specs, PRD, user stories | CPO, Designer |
| `design-system` | Composants, tokens, wireframes | Designer, Frontend |
| `research` | Veille techno, benchmarks, digests | Researcher |
| `global` | Rapports, digests hebdo, transversal | Tous |

### Attributs personnalises obligatoires

Chaque bloc cree par un agent DOIT porter ces attributs personnalises (`custom-*`) :

| Attribut | Obligatoire | Valeurs | Description |
|----------|:-----------:|---------|-------------|
| `custom-agent` | Oui | user_id Mem0 de l'agent | Auteur du bloc |
| `custom-type` | Oui | `decision`, `learning`, `research`, `report`, `convention`, etc. | Categorie (memes types que Mem0) |
| `custom-project` | Oui | nom du projet ou `global` | Scope |
| `custom-status` | Non | `draft`, `active`, `deprecated` | Lifecycle du document |
| `custom-confidence` | Non | `hypothesis`, `tested`, `validated` | Niveau de fiabilite |

### Types de blocs pour contenu structure

- **Document** : un doc SiYuan = une unite de connaissance (decision, digest, spec)
- **Heading** : sections dans le document
- **Liste** : alternatives, consequences, etapes
- **Code block** : exemples curl, snippets, configurations
- **Blockquote** : contexte, citations, references

### Exemple d'appel API SiYuan

```bash
# Creer un document dans le notebook "research"
curl -X POST "http://host.docker.internal:6806/api/filetree/createDocWithMd" \
  -H "Content-Type: application/json" \
  -d '{
    "notebook": "NOTEBOOK_ID_RESEARCH",
    "path": "/digests/research-digest-2026-03-10",
    "markdown": "# Research Digest 2026-03-10\n\n## Themes principaux\n- ...\n\n## Recommandations\n- ..."
  }'

# Ajouter les attributs personnalises au bloc
curl -X POST "http://host.docker.internal:6806/api/attr/setBlockAttrs" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "BLOCK_ID",
    "attrs": {
      "custom-agent": "researcher",
      "custom-type": "report",
      "custom-project": "global",
      "custom-status": "active",
      "custom-confidence": "validated"
    }
  }'
```
