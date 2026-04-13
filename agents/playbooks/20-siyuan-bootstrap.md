# Bootstrap SiYuan — Knowledge Base des Agents

> Ce document decrit le processus de bootstrap de SiYuan : creation des notebooks, dashboards, daily notes, templates et query embeds.
> Le script `bootstrap.sh` initialise la structure complete de la knowledge base au premier demarrage de la stack.

---

## Pre-requis

- SiYuan en cours d'execution sur `http://host.docker.internal:6806`
- `python3` disponible dans le PATH
- Token d'authentification configure : `paperclip-siyuan-token`

## Lancement

```bash
bash mac/siyuan/bootstrap.sh
```

---

## 1. Notebooks crees

Le bootstrap cree 5 notebooks, chacun dedie a un domaine fonctionnel de l'organisation :

| Notebook | Contenu | Agents responsables |
|----------|---------|---------------------|
| `architecture` | ADR, conventions techniques, patterns, decisions infra | CTO, Lead Backend |
| `produit` | PRD, specs fonctionnelles, user stories, metriques produit | CPO, Lead Frontend |
| `design-system` | Tokens, composants, guidelines UI, audits accessibilite | Designer |
| `research` | Rapports de veille, analyses concurrentielles, benchmarks | Researcher |
| `global` | Dashboards, documents partages, onboarding, rapports transverses | Tous |

### Script de creation

```bash
AUTH="Authorization: Token paperclip-siyuan-token"
BASE="http://host.docker.internal:6806"

for NB in architecture produit design-system research global; do
  echo "Creation du notebook : $NB"
  curl -s -X POST "$BASE/api/notebook/createNotebook" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$NB\"}"
done
```

### Verification post-creation

```bash
curl -s -X POST "$BASE/api/notebook/lsNotebooks" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.data.notebooks[] | {id, name, closed}'
```

---

## 2. Dashboards

Trois dashboards sont crees dans le notebook `global` pour fournir une vue transversale de l'activite :

### 2.1 Dashboard Services

Vue de l'etat de tous les services de la stack (ports, statuts, dependances).

```bash
GLOBAL_NB="<global_notebook_id>"

curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"$GLOBAL_NB\",
    \"path\": \"/dashboards/services\",
    \"markdown\": \"# Dashboard Services\n\n## Etat des services\n\n| Service | Port | Statut |\n|---------|------|--------|\n| Paperclip | 8060 | - |\n| Mem0 | 8050 | - |\n| SiYuan | 6806 | - |\n| Ollama | 11434 | - |\n| Chroma | 8000 | - |\n| n8n | 5678 | - |\n| LobeChat | 3210 | - |\n\n> Mis a jour par les agents a chaque heartbeat.\"
  }"
```

### 2.2 Dashboard Analytics

Metriques cles : tokens consommes, taches completees, memoires creees.

```bash
curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"$GLOBAL_NB\",
    \"path\": \"/dashboards/analytics\",
    \"markdown\": \"# Dashboard Analytics\n\n## Metriques hebdomadaires\n\n| Metrique | Valeur | Tendance |\n|----------|--------|----------|\n| Taches completees | - | - |\n| Tokens consommes | - | - |\n| Memoires creees | - | - |\n| ADR publies | - | - |\"
  }"
```

### 2.3 Dashboard Team Activity

Activite recente par agent : dernier heartbeat, taches en cours, documents produits.

```bash
curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"$GLOBAL_NB\",
    \"path\": \"/dashboards/team-activity\",
    \"markdown\": \"# Dashboard Team Activity\n\n## Activite par agent\n\n| Agent | Dernier heartbeat | Tache en cours | Documents recents |\n|-------|-------------------|----------------|-------------------|\n| CEO | - | - | - |\n| CTO | - | - | - |\n| CPO | - | - | - |\"
  }"
```

---

## 3. Daily Notes

La configuration des daily notes permet a chaque notebook de generer automatiquement des notes journalieres.

### Format de date Go

SiYuan utilise le format de date Go (reference : `2006-01-02`). Le template de chemin suit cette convention :

```
/daily/{{now | date "2006-01-02"}}
```

Ce qui produit des chemins comme `/daily/2026-03-11`.

### Configuration par notebook

```bash
# Recuperer l'ID du notebook
NB_ID=$(curl -s -X POST "$BASE/api/notebook/lsNotebooks" \
  -H "$AUTH" -H "Content-Type: application/json" -d '{}' \
  | jq -r '.data.notebooks[] | select(.name=="architecture") | .id')

# Configurer le chemin des daily notes
curl -s -X POST "$BASE/api/notebook/setNotebookConf" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"$NB_ID\",
    \"conf\": {
      \"dailyNoteSavePath\": \"/daily/{{now | date \\\"2006-01-02\\\"}}\",
      \"dailyNoteTemplatePath\": \"\"
    }
  }"
```

### Chemin journal par notebook

| Notebook | Chemin daily note |
|----------|-------------------|
| `architecture` | `/daily/2026-03-11` |
| `produit` | `/daily/2026-03-11` |
| `design-system` | `/daily/2026-03-11` |
| `research` | `/daily/2026-03-11` |
| `global` | `/daily/2026-03-11` |

---

## 4. Template ADR

Le bootstrap cree un template ADR (Architecture Decision Record) reutilisable par le CTO et les leads.

### Format

```markdown
# ADR-{NUM} : {Titre}

## Statut
{draft | review | validated | deprecated | superseded}

## Contexte
{Description du probleme ou de la situation qui necessite une decision.}

## Decision
{La decision prise, formulee de maniere claire et concise.}

## Alternatives considerees
1. {Alternative 1} — {raison du rejet}
2. {Alternative 2} — {raison du rejet}

## Consequences
- **Positives** : {impacts positifs}
- **Negatives** : {impacts negatifs ou risques}
- **Neutres** : {impacts neutres ou tradeoffs}

## References
- {Liens vers docs, PRD, issues, ou autres ADR}
```

### Creation du template via API

```bash
# Creer le document template
ARCH_NB="<architecture_notebook_id>"

TEMPLATE_ID=$(curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"$ARCH_NB\",
    \"path\": \"/templates/adr-template\",
    \"markdown\": \"# ADR-{NUM} : {Titre}\n\n## Statut\ndraft\n\n## Contexte\n{Description du probleme.}\n\n## Decision\n{La decision prise.}\n\n## Alternatives considerees\n1. {Alt 1} — {raison}\n2. {Alt 2} — {raison}\n\n## Consequences\n- **Positives** : {impacts}\n- **Negatives** : {risques}\n\n## References\n- {liens}\"
  }" | jq -r '.data')

# Sauvegarder comme template SiYuan
curl -s -X POST "$BASE/api/template/docSaveAsTemplate" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"id\": \"$TEMPLATE_ID\", \"name\": \"adr-template\", \"overwrite\": true}"
```

---

## 5. Query Embeds

Les query embeds permettent d'inserer du contenu dynamique dans les documents SiYuan. Un bloc de type `query_embed` execute une requete SQL et affiche les resultats directement dans le document.

### Syntaxe

Dans un document SiYuan, inserer un bloc query embed avec la syntaxe Kramdown :

```markdown
{{query
SELECT content, hpath FROM blocks WHERE ial LIKE '%custom-type=decision%' AND ial LIKE '%custom-status=active%' ORDER BY updated DESC LIMIT 10
}}
```

### Cas d'usage pour les agents

#### Lister toutes les decisions actives

```sql
SELECT content, hpath FROM blocks
WHERE ial LIKE '%custom-type=decision%'
  AND ial LIKE '%custom-status=active%'
ORDER BY updated DESC LIMIT 10
```

#### Lister les documents recents d'un agent

```sql
SELECT content, hpath, updated FROM blocks
WHERE type = 'd'
  AND ial LIKE '%custom-agent=cto%'
ORDER BY updated DESC LIMIT 10
```

#### Lister les ADR en review

```sql
SELECT content, hpath FROM blocks
WHERE type = 'd'
  AND hpath LIKE '%ADR%'
  AND ial LIKE '%custom-status=review%'
ORDER BY updated DESC
```

#### Lister les findings de recherche par projet

```sql
SELECT content, hpath FROM blocks
WHERE ial LIKE '%custom-type=finding%'
  AND ial LIKE '%custom-project=projet-x%'
ORDER BY updated DESC LIMIT 20
```

### Creation d'un query embed via API

```bash
curl -s -X POST "$BASE/api/block/appendBlock" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d "{
    \"dataType\": \"markdown\",
    \"data\": \"{{query\nSELECT content, hpath FROM blocks WHERE ial LIKE '%custom-type=decision%' AND ial LIKE '%custom-status=active%' ORDER BY updated DESC LIMIT 10\n}}\",
    \"parentID\": \"$DOC_ID\"
  }"
```

---

## 6. Templates de documents

Le bootstrap cree les templates suivants, en plus du template ADR :

### 6.1 PRD (Product Requirements Document)

```bash
curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"$PRODUIT_NB\",
    \"path\": \"/templates/prd-template\",
    \"markdown\": \"# PRD : {Titre}\n\n## Resume\n{Description courte de la fonctionnalite.}\n\n## Probleme\n{Quel probleme utilisateur est resolu ?}\n\n## Solution proposee\n{Description de la solution.}\n\n## User Stories\n- En tant que {role}, je veux {action} afin de {benefice}\n\n## Criteres d'acceptation\n- [ ] {Critere 1}\n- [ ] {Critere 2}\n\n## Metriques de succes\n| Metrique | Objectif | Mesure |\n|----------|----------|--------|\n| {nom} | {cible} | {comment} |\n\n## Dependencies\n- {service ou equipe}\n\n## Timeline\n| Phase | Date | Livrable |\n|-------|------|----------|\n| {phase} | {date} | {livrable} |\"
  }"
```

### 6.2 Security Audit Report

```bash
curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"$ARCH_NB\",
    \"path\": \"/templates/security-audit-template\",
    \"markdown\": \"# Audit Securite : {Perimetre}\n\n## Date\n{YYYY-MM-DD}\n\n## Perimetre\n{Services et composants audites.}\n\n## Resultats\n\n### Vulnerabilites critiques\n| ID | Description | Severite | Statut | Remediation |\n|----|-------------|----------|--------|-------------|\n| {id} | {desc} | critical | open | {action} |\n\n### Vulnerabilites hautes\n| ID | Description | Severite | Statut | Remediation |\n|----|-------------|----------|--------|-------------|\n| {id} | {desc} | high | open | {action} |\n\n## Recommandations\n1. {Recommandation prioritaire}\n2. {Recommandation secondaire}\n\n## Prochaine revue\n{Date prevue}\"
  }"
```

### 6.3 Sprint Report

```bash
curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"$GLOBAL_NB\",
    \"path\": \"/templates/sprint-report-template\",
    \"markdown\": \"# Sprint Report — Semaine {NUM}\n\n## Resume\n{Bilan general du sprint.}\n\n## Objectifs atteints\n- [x] {Objectif 1}\n- [x] {Objectif 2}\n- [ ] {Objectif non atteint}\n\n## Metriques\n| Metrique | Valeur | Objectif | Delta |\n|----------|--------|----------|-------|\n| Taches completees | {N} | {N} | {+/-} |\n| Tokens consommes | {N} | {N} | {+/-} |\n| Bugs resolus | {N} | {N} | {+/-} |\n\n## Blocages rencontres\n- {Blocage et resolution}\n\n## Objectifs sprint suivant\n1. {Objectif}\n2. {Objectif}\"
  }"
```

### 6.4 Incident Post-mortem

```bash
curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"$ARCH_NB\",
    \"path\": \"/templates/incident-postmortem-template\",
    \"markdown\": \"# Post-mortem : {Titre de l'incident}\n\n## Resume\n| Champ | Valeur |\n|-------|--------|\n| Date | {YYYY-MM-DD HH:MM} |\n| Duree | {duree totale} |\n| Severite | {P0/P1/P2} |\n| Services impactes | {liste} |\n| Impact utilisateur | {description} |\n\n## Timeline\n| Heure | Evenement |\n|-------|----------|\n| {HH:MM} | {detection} |\n| {HH:MM} | {diagnostic} |\n| {HH:MM} | {resolution} |\n\n## Cause racine\n{Description detaillee de la cause.}\n\n## Resolution\n{Actions prises pour resoudre l'incident.}\n\n## Actions preventives\n| Action | Responsable | Deadline | Statut |\n|--------|-------------|----------|--------|\n| {action} | {agent} | {date} | todo |\n\n## Lecons apprises\n- {Learning 1}\n- {Learning 2}\"
  }"
```

---

## 7. Notifications push strategiques

Les agents utilisent l'API de notification SiYuan pour alerter sur les evenements importants. Les notifications apparaissent dans l'interface SiYuan.

### Endpoint

```bash
curl -X POST "http://host.docker.internal:6806/api/notification/pushMsg" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"msg": "Message content", "timeout": 0}'
```

- `timeout: 0` : notification persistante (doit etre fermee manuellement)
- `timeout: N` : disparait apres N millisecondes

### Table des notifications

| Source | Notification | Timeout |
|--------|-------------|---------|
| Decision critique | "CTO: {titre}" | 0 (persistant) |
| Deploy reussi | "Deploy {service} v{version}" | 30000 |
| Deploy echoue | "DEPLOY FAIL: {service}" | 0 |
| Bug critique | "Bug P0: {titre}" | 0 |
| Security alert | "ALERT: {description}" | 0 |
| Approval needed | "Approval en attente: {titre}" | 0 |
| Weekly digest | "Digest semaine {num} disponible" | 60000 |

### Exemples

```bash
# Decision critique (persistant)
curl -s -X POST "$BASE/api/notification/pushMsg" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"msg": "CTO: Migration PostgreSQL 16 validee", "timeout": 0}'

# Deploy reussi (30 secondes)
curl -s -X POST "$BASE/api/notification/pushMsg" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"msg": "Deploy backend-api v2.3.1", "timeout": 30000}'

# Deploy echoue (persistant)
curl -s -X POST "$BASE/api/notification/pushErrMsg" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"msg": "DEPLOY FAIL: backend-api", "timeout": 0}'

# Bug critique (persistant)
curl -s -X POST "$BASE/api/notification/pushErrMsg" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"msg": "Bug P0: Perte de donnees sur endpoint /users", "timeout": 0}'

# Security alert (persistant)
curl -s -X POST "$BASE/api/notification/pushErrMsg" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"msg": "ALERT: Tentative brute force detectee sur /api/auth", "timeout": 0}'
```

---

## 8. Tags et Bookmarks via attributs custom

Les agents utilisent des attributs custom pour organiser les blocs avec des tags, bookmarks et pins. Ces attributs sont interrogeables via SQL.

### Convention d'attributs

| Attribut | Usage | Valeurs |
|----------|-------|---------|
| `custom-tag` | Categoriser un bloc | Texte libre (ex: `performance`, `urgent`, `v2`) |
| `custom-bookmarked` | Marquer un bloc important | `true` |
| `custom-pinned` | Epingler un bloc en haut du dashboard | `true` |

### Definir les attributs

```bash
curl -s -X POST "$BASE/api/attr/setBlockAttrs" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "20260310143000-block01",
    "attrs": {
      "custom-tag": "performance",
      "custom-bookmarked": "true",
      "custom-pinned": "true"
    }
  }'
```

### Requetes SQL pour retrouver les blocs tagges

#### Trouver tous les blocs bookmarkes

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT b.id, b.content, b.hpath FROM blocks b JOIN attributes a ON b.id = a.block_id WHERE a.name = '\''custom-bookmarked'\'' AND a.value = '\''true'\'' ORDER BY b.updated DESC"}'
```

#### Trouver les blocs epingles

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT b.id, b.content, b.hpath FROM blocks b JOIN attributes a ON b.id = a.block_id WHERE a.name = '\''custom-pinned'\'' AND a.value = '\''true'\'' ORDER BY b.updated DESC"}'
```

#### Trouver les blocs par tag

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT b.id, b.content, b.hpath FROM blocks b JOIN attributes a ON b.id = a.block_id WHERE a.name = '\''custom-tag'\'' AND a.value = '\''performance'\'' ORDER BY b.updated DESC LIMIT 20"}'
```

#### Trouver les blocs avec plusieurs attributs (tag + agent)

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT b.id, b.content, b.hpath FROM blocks b WHERE b.ial LIKE '\''%custom-tag=urgent%'\'' AND b.ial LIKE '\''%custom-agent=cto%'\'' ORDER BY b.updated DESC LIMIT 10"}'
```

---

## Verification post-bootstrap

Apres execution du script, verifier que tout est en place :

```bash
# 1. Lister les notebooks
curl -s -X POST "$BASE/api/notebook/lsNotebooks" \
  -H "$AUTH" -H "Content-Type: application/json" -d '{}' \
  | jq '.data.notebooks[] | {id, name}'

# 2. Verifier les dashboards dans global
GLOBAL_NB=$(curl -s -X POST "$BASE/api/notebook/lsNotebooks" \
  -H "$AUTH" -H "Content-Type: application/json" -d '{}' \
  | jq -r '.data.notebooks[] | select(.name=="global") | .id')

curl -s -X POST "$BASE/api/filetree/listDocsByPath" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"notebook\": \"$GLOBAL_NB\", \"path\": \"/dashboards\"}"

# 3. Verifier la configuration daily notes
curl -s -X POST "$BASE/api/notebook/getNotebookConf" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"notebook\": \"$GLOBAL_NB\"}" | jq '.data.conf.dailyNoteSavePath'

# 4. Verifier les templates
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT id, hpath FROM blocks WHERE type = '\''d'\'' AND hpath LIKE '\''%template%'\'' ORDER BY hpath"}'
```

---

## Gestion Multi-Projets

Lorsque la stack gere plusieurs projets en parallele, il faut structurer SiYuan pour isoler le contenu par projet tout en conservant une base de conventions globale partagee.

### Convention de paths

Le contenu global (conventions, templates, dashboards) reste a la racine de chaque notebook. Le contenu specifique a un projet est place sous `/projects/{slug}/` :

```
notebook: architecture
├── /conventions/           ← global, partage par tous les projets
├── /templates/             ← global
├── /projects/
│   ├── /projet-alpha/
│   │   ├── /adr/
│   │   ├── /specs/
│   │   └── /daily/
│   └── /projet-beta/
│       ├── /adr/
│       └── /specs/
└── /daily/                 ← daily notes globales

notebook: global
├── /dashboards/
├── /projects/
│   ├── /registry           ← registre de tous les projets
│   └── /projet-alpha/
│       └── /overview
└── /daily/
```

Le `{slug}` est le nom normalise du projet : minuscules, tirets, pas d'accents (ex: `mon-projet-saas`).

### Script bootstrap-project.sh

Le script `bootstrap-project.sh` initialise la structure d'un nouveau projet dans tous les notebooks :

```bash
bash mac/siyuan/bootstrap-project.sh <project-slug>
```

Ce qu'il cree :

| Notebook | Dossier cree | Contenu initial |
|----------|-------------|-----------------|
| `architecture` | `/projects/{slug}/` | Dossiers `adr/`, `specs/`, `infra/` |
| `produit` | `/projects/{slug}/` | Dossiers `prd/`, `stories/`, `metrics/` |
| `design-system` | `/projects/{slug}/` | Dossiers `tokens/`, `composants/`, `audits/` |
| `research` | `/projects/{slug}/` | Dossiers `veille/`, `benchmarks/` |
| `global` | `/projects/{slug}/` | Document `overview` avec metadonnees du projet |

Le script ajoute egalement une entree dans le registre global (`global/projects/registry`).

### Custom Attributes

Les attributs custom permettent de filtrer et categoriser les blocs par projet, type, et contexte :

| Attribut | Description | Valeurs possibles |
|----------|-------------|-------------------|
| `custom-project` | Projet auquel appartient le bloc | Slug du projet (ex: `projet-alpha`) |
| `custom-type` | Type de document | `decision`, `finding`, `prd`, `spec`, `story`, `audit`, `incident`, `report` |
| `custom-status` | Etat du document | `draft`, `review`, `active`, `done`, `deprecated`, `superseded` |
| `custom-agent` | Agent responsable | `ceo`, `cto`, `cpo`, `lead-backend`, `lead-frontend`, `designer`, `researcher` |
| `custom-tag` | Categorisation libre | Texte libre (ex: `performance`, `urgent`, `v2`, `security`) |
| `custom-bookmarked` | Marquer un bloc important | `true` |
| `custom-pinned` | Epingler un bloc en haut d'un dashboard | `true` |

Chaque document cree par un agent dans un contexte projet **doit** au minimum porter `custom-project` et `custom-type` :

```bash
curl -s -X POST "$BASE/api/attr/setBlockAttrs" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "id": "<block-id>",
    "attrs": {
      "custom-project": "projet-alpha",
      "custom-type": "decision",
      "custom-status": "draft",
      "custom-agent": "cto"
    }
  }'
```

### Block References & Graph

Les documents projet **doivent** inclure des references de blocs vers les conventions globales. Cela alimente le graphe SiYuan et cree des backlinks navigables.

**Syntaxe de reference** : `((block-id "texte ancre"))` insere un lien cliquable vers le bloc cible.

**Convention** :

- Chaque ADR projet doit referencer le template ADR global et les conventions de nommage
- Chaque PRD projet doit referencer les guidelines produit globales
- Chaque spec technique doit referencer les patterns d'architecture valides

**Exemple dans un ADR projet** :

```markdown
# ADR-003 : Choix du cache distribue

## Contexte
Ce choix s'inscrit dans le cadre des ((20260310-conv-patterns "conventions de patterns architecture"))
et respecte les ((20260310-conv-securite "guidelines securite")) etablies.
```

**Backlinks** : SiYuan genere automatiquement un panneau de backlinks sur chaque bloc reference. Cela permet de voir, depuis une convention globale, tous les documents projet qui la referencent. Le graphe visualise ces connexions et aide a evaluer l'impact d'une modification de convention.

### Block Embeds

Utiliser les embeds de blocs `{{block-id}}` pour inclure le contenu d'un bloc global directement dans un document projet. Contrairement aux references (qui sont des liens), les embeds affichent le contenu inline.

**Quand utiliser un embed vs une reference** :

| Situation | Utiliser |
|-----------|---------|
| Rappeler une convention dans un doc projet | `{{block-id}}` (embed) |
| Creer un lien navigable vers un doc global | `((block-id))` (reference) |
| Dashboard qui agrege du contenu | `{{block-id}}` (embed) |
| Tracer une dependance dans le graphe | `((block-id))` (reference) |

**Syntaxe Kramdown dans un document** :

```markdown
## Rappel des conventions applicables

{{select * from blocks where id = '20260310-conv-api'}}
```

Via l'API, inserer un embed dans un document existant :

```bash
curl -s -X POST "$BASE/api/block/appendBlock" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"dataType\": \"markdown\",
    \"data\": \"{{select * from blocks where id = '20260310-conv-api'}}\",
    \"parentID\": \"$DOC_ID\"
  }"
```

### SQL Queries

Requetes cles pour la gestion multi-projets.

#### Filtrer les documents d'un projet

```sql
SELECT b.id, b.content, b.hpath FROM blocks b
JOIN attributes a ON b.id = a.block_id
WHERE a.name = 'custom-project' AND a.value = 'projet-alpha'
  AND b.type = 'd'
ORDER BY b.updated DESC
```

#### Filtrer par projet ET type

```sql
SELECT b.id, b.content, b.hpath FROM blocks b
WHERE b.ial LIKE '%custom-project=projet-alpha%'
  AND b.ial LIKE '%custom-type=decision%'
  AND b.ial LIKE '%custom-status=active%'
ORDER BY b.updated DESC
```

#### Vue cross-projets : toutes les decisions actives

```sql
SELECT b.id, b.content, b.hpath,
  a.value AS project
FROM blocks b
JOIN attributes a ON b.id = a.block_id
WHERE a.name = 'custom-project'
  AND b.ial LIKE '%custom-type=decision%'
  AND b.ial LIKE '%custom-status=active%'
ORDER BY a.value, b.updated DESC
```

#### Compter les documents par projet et par type

```sql
SELECT
  MAX(CASE WHEN a2.name = 'custom-project' THEN a2.value END) AS project,
  MAX(CASE WHEN a2.name = 'custom-type' THEN a2.value END) AS type,
  COUNT(*) AS total
FROM blocks b
JOIN attributes a2 ON b.id = a2.block_id
WHERE a2.name IN ('custom-project', 'custom-type')
GROUP BY b.id
ORDER BY project, type
```

#### Trouver les blocs bookmarkes d'un projet

```sql
SELECT b.id, b.content, b.hpath FROM blocks b
WHERE b.ial LIKE '%custom-project=projet-alpha%'
  AND b.ial LIKE '%custom-bookmarked=true%'
ORDER BY b.updated DESC
```

### Registre des projets

Le document `global/projects/registry` centralise la liste de tous les projets actifs. Il est mis a jour par `bootstrap-project.sh` et consulte par les agents pour connaitre les projets existants.

**Structure du registre** :

```markdown
# Registre des projets

| Slug | Nom complet | Statut | Date creation | Lead | Description |
|------|-------------|--------|---------------|------|-------------|
| projet-alpha | Projet Alpha | active | 2026-03-01 | cto | Refonte API v2 |
| projet-beta | Projet Beta | active | 2026-03-10 | cpo | App mobile MVP |
```

**Attributs du document registre** :

```bash
curl -s -X POST "$BASE/api/attr/setBlockAttrs" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "id": "<registry-doc-id>",
    "attrs": {
      "custom-type": "registry",
      "custom-pinned": "true"
    }
  }'
```

Les agents interrogent le registre pour valider qu'un slug projet existe avant d'y ecrire :

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT content FROM blocks WHERE ial LIKE '\''%custom-type=registry%'\'' AND type = '\''d'\''"}'
```

### Dashboard all-projects

Le document `global/dashboards/all-projects` fournit une vue agregee de tous les projets via des query embeds.

**Creation** :

```bash
curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"$GLOBAL_NB\",
    \"path\": \"/dashboards/all-projects\",
    \"markdown\": \"# Dashboard All Projects\n\n## Projets actifs\n\n{{query\nSELECT b.content, b.hpath FROM blocks b JOIN attributes a ON b.id = a.block_id WHERE a.name = 'custom-project' AND b.type = 'd' AND b.ial LIKE '%custom-type=report%' GROUP BY a.value ORDER BY b.updated DESC\n}}\n\n## Decisions recentes (tous projets)\n\n{{query\nSELECT b.content, b.hpath FROM blocks b WHERE b.ial LIKE '%custom-type=decision%' AND b.ial LIKE '%custom-status=active%' ORDER BY b.updated DESC LIMIT 20\n}}\n\n## Blocs epingles\n\n{{query\nSELECT b.content, b.hpath FROM blocks b WHERE b.ial LIKE '%custom-pinned=true%' ORDER BY b.updated DESC\n}}\"
  }"
```

**Attributs** :

```bash
curl -s -X POST "$BASE/api/attr/setBlockAttrs" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "id": "<all-projects-doc-id>",
    "attrs": {
      "custom-type": "dashboard",
      "custom-pinned": "true",
      "custom-bookmarked": "true"
    }
  }'
```

### Mapping Paperclip → SiYuan

Correspondance entre les concepts Paperclip et leur representation dans SiYuan :

| Concept Paperclip | Representation SiYuan | Details |
|--------------------|-----------------------|---------|
| **Company** | Workspace SiYuan | Un workspace = une instance de la stack complete |
| **Goal** | Document `overview` dans `global/projects/{slug}/` | Decrit les objectifs du projet, consultable par tous les agents |
| **Project** | `custom-project` + arborescence `/projects/{slug}/` | Le slug est partage entre Paperclip et SiYuan |
| **Issue** | Reference par ID de tache Paperclip | Le `custom-tag` porte l'ID Paperclip (ex: `task-42`). Les docs SiYuan referencent la tache source |

**Convention de tracabilite** : quand un agent cree un document SiYuan suite a une tache Paperclip, il ajoute l'attribut `custom-tag` avec l'ID de la tache :

```bash
curl -s -X POST "$BASE/api/attr/setBlockAttrs" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "id": "<doc-id>",
    "attrs": {
      "custom-project": "projet-alpha",
      "custom-tag": "task-42",
      "custom-agent": "cto"
    }
  }'
```

Pour retrouver tous les documents SiYuan lies a une tache Paperclip :

```sql
SELECT b.id, b.content, b.hpath FROM blocks b
WHERE b.ial LIKE '%custom-tag=task-42%'
ORDER BY b.updated DESC
```

### n8n Routing — WF13 memory-to-siyuan

Le workflow n8n **WF13 (memory-to-siyuan)** route automatiquement les memoires Mem0 vers le bon dossier projet dans SiYuan. Le routage repose sur le champ `memory.metadata.project`.

**Logique de routage** :

```
1. WF13 recoit une memoire depuis Mem0
2. Extraire memory.metadata.project → slug du projet
3. Si slug est vide ou absent → ecrire dans le notebook global (racine)
4. Si slug est present :
   a. Verifier que /projects/{slug}/ existe dans le notebook cible
   b. Determiner le notebook cible via memory.metadata.type :
      - type=decision → notebook architecture
      - type=finding  → notebook research
      - type=prd      → notebook produit
      - type=design   → notebook design-system
      - autre         → notebook global
   c. Creer le document dans /projects/{slug}/{sous-dossier}/
5. Appliquer les attributs custom-project, custom-type, custom-agent
```

**Extrait de la logique n8n (noeud Function)** :

```javascript
const memory = $input.item.json;
const project = memory.metadata?.project || '';
const type = memory.metadata?.type || 'note';
const agent = memory.metadata?.agent || 'unknown';

// Mapping type → notebook
const notebookMap = {
  'decision': 'architecture',
  'adr': 'architecture',
  'spec': 'architecture',
  'finding': 'research',
  'benchmark': 'research',
  'prd': 'produit',
  'story': 'produit',
  'design': 'design-system',
  'token': 'design-system'
};

const targetNotebook = notebookMap[type] || 'global';
const basePath = project
  ? `/projects/${project}/${type}`
  : `/${type}`;

return {
  notebook: targetNotebook,
  path: basePath,
  content: memory.content,
  attrs: {
    'custom-project': project,
    'custom-type': type,
    'custom-agent': agent
  }
};
```

**Points importants** :

- Si le dossier projet n'existe pas encore dans le notebook cible, WF13 le cree automatiquement (l'API `createDocWithMd` cree les dossiers intermediaires)
- Les attributs sont appliques dans un second appel API apres la creation du document
- Le workflow log chaque routage dans la daily note du notebook `global` pour tracer l'activite
