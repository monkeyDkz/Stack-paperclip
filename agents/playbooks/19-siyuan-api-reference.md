# Reference API : SiYuan Note — Knowledge Base des Agents

> SiYuan est la base de connaissances structuree de la stack Paperclip.
> Les agents y stockent ADR, PRD, specs, rapports de recherche et documentation partagee.
> Ce document est la reference complete pour interagir avec SiYuan via curl.

---

## Convention generale

- **Toutes les requetes sont en POST** avec un body JSON
- **Base URL** : `http://host.docker.internal:6806`
- **Authentification** : header `Authorization: Token paperclip-siyuan-token`
- **Content-Type** : `application/json` (sauf upload de fichiers)

Variables reutilisables dans tous les exemples :

```bash
AUTH="Authorization: Token paperclip-siyuan-token"
BASE="http://host.docker.internal:6806"
```

### Format de reponse

Toutes les reponses suivent le meme schema :

```json
{"code": 0, "msg": "", "data": {...}}
```

- `code = 0` : succes
- `code != 0` : erreur, le champ `msg` contient le detail

---

## 1. Notebooks

Les notebooks sont les conteneurs de premier niveau. Chaque agent dispose de son propre notebook.

### Creer un notebook

```bash
curl -s -X POST "$BASE/api/notebook/createNotebook" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"name": "Projet-X"}'
# Retourne :
# {
#   "code": 0,
#   "msg": "",
#   "data": {
#     "notebook": {
#       "id": "20260310120000-abc1def",
#       "name": "Projet-X",
#       "icon": "",
#       "sort": 0,
#       "closed": false
#     }
#   }
# }
```

### Ouvrir un notebook

```bash
curl -s -X POST "$BASE/api/notebook/openNotebook" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"notebook": "20260310120000-abc1def"}'
```

### Fermer un notebook

```bash
curl -s -X POST "$BASE/api/notebook/closeNotebook" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"notebook": "20260310120000-abc1def"}'
```

### Renommer un notebook

```bash
curl -s -X POST "$BASE/api/notebook/renameNotebook" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"notebook": "20260310120000-abc1def", "name": "nouveau-nom"}'
```

### Supprimer un notebook

```bash
curl -s -X POST "$BASE/api/notebook/removeNotebook" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"notebook": "20260310120000-abc1def"}'
```

### Lister tous les notebooks

```bash
curl -s -X POST "$BASE/api/notebook/lsNotebooks" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{}'
# Retourne :
# {
#   "code": 0,
#   "msg": "",
#   "data": {
#     "notebooks": [
#       {"id": "20260310120000-abc1def", "name": "architecture", "closed": false},
#       {"id": "20260310120001-xyz9876", "name": "produit", "closed": false}
#     ]
#   }
# }
```

### Obtenir la configuration d'un notebook

```bash
curl -s -X POST "$BASE/api/notebook/getNotebookConf" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"notebook": "20260310120000-abc1def"}'
```

### Modifier la configuration d'un notebook

```bash
curl -s -X POST "$BASE/api/notebook/setNotebookConf" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "notebook": "20260310120000-abc1def",
    "conf": {
      "name": "architecture",
      "closed": false,
      "dailyNoteSavePath": "/daily/{{now | date \"2006-01-02\"}}",
      "dailyNoteTemplatePath": ""
    }
  }'
```

---

## 2. Documents

Les documents sont les fichiers Markdown dans un notebook. Chaque document est aussi un bloc de type `d` (document).

### Creer un document avec du Markdown

```bash
curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "notebook": "20260310120000-abc1def",
    "path": "/ADR/001-choix-base-de-donnees",
    "markdown": "# ADR-001 : Choix de la base de donnees\n\n## Contexte\n\nNous avons besoin d'\''une base relationnelle ACID.\n\n## Decision\n\nPostgreSQL 16.\n\n## Consequences\n\nBonne performance, necessite tuning."
  }'
# Retourne :
# {
#   "code": 0,
#   "msg": "",
#   "data": "20260310143000-docid01"
# }
# Note : data contient l'ID du document cree (qui est aussi son block ID racine)
```

### Renommer un document

```bash
curl -s -X POST "$BASE/api/filetree/renameDoc" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "notebook": "20260310120000-abc1def",
    "path": "/ADR/001-choix-base-de-donnees",
    "title": "ADR-001 : PostgreSQL 16"
  }'
```

### Supprimer un document

```bash
curl -s -X POST "$BASE/api/filetree/removeDoc" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "notebook": "20260310120000-abc1def",
    "path": "/ADR/001-choix-base-de-donnees"
  }'
```

### Deplacer des documents

```bash
curl -s -X POST "$BASE/api/filetree/moveDocs" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "fromPaths": ["/20260310143000-docid01.sy"],
    "toNotebook": "20260310120001-xyz9876",
    "toPath": "/"
  }'
```

### Obtenir un document complet

```bash
curl -s -X POST "$BASE/api/filetree/getDoc" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"id": "20260310143000-docid01"}'
# Retourne le document complet avec tous ses blocs enfants.
# Le champ data contient : id, rootID, name, content, etc.
```

### Rechercher des documents

```bash
curl -s -X POST "$BASE/api/filetree/searchDocs" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"k": "PostgreSQL"}'
# Retourne :
# {
#   "code": 0,
#   "msg": "",
#   "data": [
#     {
#       "box": "20260310120000-abc1def",
#       "boxIcon": "",
#       "hPath": "/ADR/001-choix-base-de-donnees",
#       "path": "/20260310143000-docid01.sy"
#     }
#   ]
# }
```

### Lister les documents d'un chemin

```bash
curl -s -X POST "$BASE/api/filetree/listDocsByPath" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"notebook": "20260310120000-abc1def", "path": "/"}'
# Retourne la liste des documents et sous-dossiers a la racine du notebook.
```

### Obtenir le chemin lisible d'un bloc

```bash
curl -s -X POST "$BASE/api/filetree/getHPathByID" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"id": "20260310143000-docid01"}'
# Retourne :
# {"code": 0, "msg": "", "data": "/ADR/001-choix-base-de-donnees"}
```

---

## 3. Blocs — LE PLUS IMPORTANT POUR LES AGENTS

SiYuan est un editeur base sur des blocs. Chaque paragraphe, titre, liste, bloc de code, etc. est un bloc avec un ID unique. Les agents manipulent principalement des blocs.

### Inserer un bloc apres un autre

```bash
curl -s -X POST "$BASE/api/block/insertBlock" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "dataType": "markdown",
    "data": "## Nouvelle section\n\nContenu ajoute par l'\''agent CTO.",
    "previousID": "20260310143000-block01"
  }'
# Retourne :
# {
#   "code": 0,
#   "msg": "",
#   "data": [
#     {
#       "doOperations": [
#         {"action": "insert", "id": "20260310150000-newblk1", ...}
#       ]
#     }
#   ]
# }
```

### Ajouter un bloc au debut d'un document (prepend)

```bash
curl -s -X POST "$BASE/api/block/prependBlock" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "dataType": "markdown",
    "data": "> Mis a jour par agent CTO le 2026-03-11",
    "parentID": "20260310143000-docid01"
  }'
```

### Ajouter un bloc a la fin d'un document (append)

```bash
curl -s -X POST "$BASE/api/block/appendBlock" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "dataType": "markdown",
    "data": "## Notes supplementaires\n\n- Point 1\n- Point 2\n- Point 3",
    "parentID": "20260310143000-docid01"
  }'
```

### Mettre a jour un bloc existant

```bash
curl -s -X POST "$BASE/api/block/updateBlock" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "dataType": "markdown",
    "data": "Contenu mis a jour avec les nouvelles informations.",
    "id": "20260310143000-block01"
  }'
```

### Supprimer un bloc

```bash
curl -s -X POST "$BASE/api/block/deleteBlock" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"id": "20260310143000-block01"}'
```

### Deplacer un bloc

```bash
# Deplacer apres un bloc cible (previousID)
curl -s -X POST "$BASE/api/block/moveBlock" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "20260310143000-block01",
    "previousID": "20260310143000-target01"
  }'

# Deplacer comme premier enfant d'un parent (parentID)
curl -s -X POST "$BASE/api/block/moveBlock" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "20260310143000-block01",
    "parentID": "20260310143000-docid01"
  }'
```

### Plier un bloc

```bash
curl -s -X POST "$BASE/api/block/foldBlock" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"id": "20260310143000-block01"}'
```

### Deplier un bloc

```bash
curl -s -X POST "$BASE/api/block/unfoldBlock" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"id": "20260310143000-block01"}'
```

### Obtenir le contenu Kramdown d'un bloc

```bash
curl -s -X POST "$BASE/api/block/getBlockKramdown" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"id": "20260310143000-block01"}'
# Retourne :
# {
#   "code": 0,
#   "msg": "",
#   "data": {
#     "id": "20260310143000-block01",
#     "kramdown": "Contenu du bloc en format Kramdown avec {: id=\"...\" updated=\"...\"}"
#   }
# }
```

### Obtenir les blocs enfants

```bash
curl -s -X POST "$BASE/api/block/getChildBlocks" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"id": "20260310143000-docid01"}'
# Retourne :
# {
#   "code": 0,
#   "msg": "",
#   "data": [
#     {"id": "20260310143001-child01", "type": "h", "subType": "h1"},
#     {"id": "20260310143001-child02", "type": "p", "subType": ""},
#     {"id": "20260310143001-child03", "type": "h", "subType": "h2"}
#   ]
# }
```

### Transferer les references d'un bloc vers un autre

```bash
curl -s -X POST "$BASE/api/block/transferBlockRef" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "fromID": "20260310143000-oldblk1",
    "toID": "20260310143000-newblk1"
  }'
# Toutes les references pointant vers fromID seront mises a jour vers toID.
```

---

## 4. Requetes SQL — CRITIQUE POUR LA RECHERCHE

L'API SQL est l'outil le plus puissant pour les agents. Elle permet de chercher dans toute la base de connaissances.

### Endpoint

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT * FROM blocks WHERE content LIKE '\''%terme%'\'' AND type='\''p'\'' LIMIT 10"}'
```

### Tables principales

#### Table `blocks`

| Colonne     | Type   | Description                                    |
|-------------|--------|------------------------------------------------|
| `id`        | TEXT   | ID unique du bloc                              |
| `parent_id` | TEXT   | ID du bloc parent                              |
| `root_id`   | TEXT   | ID du document racine (bloc de type `d`)       |
| `box`       | TEXT   | ID du notebook                                 |
| `content`   | TEXT   | Contenu texte du bloc (sans formatage)         |
| `markdown`  | TEXT   | Contenu Markdown du bloc                       |
| `type`      | TEXT   | Type de bloc (voir reference ci-dessous)       |
| `subtype`   | TEXT   | Sous-type (h1-h6, o/u pour listes, etc.)      |
| `created`   | TEXT   | Date de creation (format 20260311143000)        |
| `updated`   | TEXT   | Date de derniere modification                  |
| `hash`      | TEXT   | Hash du contenu                                |
| `path`      | TEXT   | Chemin du document dans le notebook            |
| `hpath`     | TEXT   | Chemin lisible du document                     |
| `name`      | TEXT   | Nom du bloc (si defini)                        |
| `tag`       | TEXT   | Tags du bloc                                   |
| `ial`       | TEXT   | Inline Attribute List (attributs du bloc)      |

#### Table `attributes`

| Colonne    | Type   | Description                            |
|------------|--------|----------------------------------------|
| `id`       | TEXT   | ID de l'attribut                       |
| `name`     | TEXT   | Nom de l'attribut (ex: `custom-agent`) |
| `value`    | TEXT   | Valeur de l'attribut                   |
| `block_id` | TEXT   | ID du bloc associe                     |
| `root_id`  | TEXT   | ID du document racine                  |
| `type`     | TEXT   | Type de bloc associe                   |
| `box`      | TEXT   | ID du notebook                         |

### Types de blocs

| Code | Type            | Description                     |
|------|-----------------|---------------------------------|
| `d`  | document        | Document (bloc racine)          |
| `h`  | heading         | Titre (h1-h6 via subtype)      |
| `p`  | paragraph       | Paragraphe                      |
| `c`  | code            | Bloc de code                    |
| `t`  | table           | Tableau                         |
| `l`  | list            | Liste (conteneur)               |
| `i`  | list-item       | Element de liste                |
| `b`  | blockquote      | Citation                        |
| `s`  | super-block     | Super bloc (conteneur layout)   |
| `html` | html          | Bloc HTML                       |
| `m`  | math            | Bloc mathematique               |
| `video` | video        | Video                           |
| `audio` | audio        | Audio                           |
| `widget` | widget      | Widget                          |
| `iframe` | iframe      | Iframe                          |
| `query_embed` | query_embed | Requete SQL embarquee     |
| `tb` | thematic-break  | Separateur horizontal           |

### Exemples SQL pour agents

#### Recherche par contenu

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT id, root_id, content, type, hpath FROM blocks WHERE content LIKE '\''%PostgreSQL%'\'' AND type IN ('\''p'\'', '\''h'\'', '\''c'\'') LIMIT 20"}'
```

#### Recherche par attribut custom

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT b.id, b.content, b.hpath, a.value FROM blocks b JOIN attributes a ON b.id = a.block_id WHERE a.name = '\''custom-agent'\'' AND a.value = '\''cto'\'' LIMIT 20"}'
```

#### Recherche par type de bloc

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT id, content, hpath FROM blocks WHERE type = '\''d'\'' AND box = '\''20260310120000-abc1def'\'' ORDER BY updated DESC LIMIT 10"}'
# Liste les 10 documents les plus recemment modifies du notebook architecture.
```

#### Recherche cross-notebook

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT b.id, b.content, b.hpath, b.box FROM blocks b WHERE b.content LIKE '\''%API%'\'' AND b.type = '\''h'\'' ORDER BY b.updated DESC LIMIT 20"}'
# Recherche dans tous les notebooks les titres contenant "API".
```

#### Blocs recemment modifies

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT id, content, type, hpath, updated FROM blocks WHERE updated > '\''20260311000000'\'' AND type IN ('\''p'\'', '\''h'\'') ORDER BY updated DESC LIMIT 30"}'
# Tous les blocs modifies aujourd'\''hui.
```

#### Trouver les decisions d'architecture (par attribut)

```bash
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT b.id, b.content, b.hpath FROM blocks b JOIN attributes a ON b.id = a.block_id WHERE a.name = '\''custom-type'\'' AND a.value = '\''decision'\'' ORDER BY b.updated DESC LIMIT 10"}'
```

---

## 5. Attributs — Metadonnees custom sur les blocs

Les attributs permettent de taguer les blocs avec des metadonnees structurees. C'est le mecanisme principal pour que les agents organisent et retrouvent l'information.

### Obtenir les attributs d'un bloc

```bash
curl -s -X POST "$BASE/api/attr/getBlockAttrs" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"id": "20260310143000-block01"}'
# Retourne :
# {
#   "code": 0,
#   "msg": "",
#   "data": {
#     "id": "20260310143000-block01",
#     "updated": "20260311150000",
#     "custom-agent": "cto",
#     "custom-type": "decision",
#     "custom-project": "projet-x",
#     "custom-status": "validated",
#     "custom-confidence": "tested"
#   }
# }
```

### Definir les attributs d'un bloc

```bash
curl -s -X POST "$BASE/api/attr/setBlockAttrs" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "20260310143000-block01",
    "attrs": {
      "custom-agent": "cto",
      "custom-type": "decision",
      "custom-project": "projet-x",
      "custom-status": "validated",
      "custom-confidence": "tested"
    }
  }'
```

### Convention de nommage des attributs

> **REGLE** : Tous les attributs personnalises doivent etre prefixes par `custom-`.

Attributs standard pour les agents :

| Attribut              | Valeurs possibles                              | Description                    |
|-----------------------|------------------------------------------------|--------------------------------|
| `custom-agent`        | `cto`, `cpo`, `designer`, `researcher`, etc.   | Agent auteur du bloc           |
| `custom-type`         | `decision`, `convention`, `spec`, `finding`     | Type de contenu                |
| `custom-project`      | `projet-x`, `global`                           | Projet concerne                |
| `custom-status`       | `draft`, `review`, `validated`, `deprecated`   | Statut du contenu              |
| `custom-confidence`   | `hypothesis`, `tested`, `validated`            | Niveau de confiance            |

---

## 6. Assets — Upload de fichiers

### Uploader un fichier

```bash
curl -s -X POST "$BASE/api/asset/upload" \
  -H "$AUTH" \
  -F "assetsDirPath=/assets/" \
  -F "file[]=@/chemin/vers/image.png"
# Retourne :
# {
#   "code": 0,
#   "msg": "",
#   "data": {
#     "succMap": {
#       "image.png": "assets/image-20260311150000-abc123.png"
#     }
#   }
# }
# Utiliser le chemin retourne dans le Markdown : ![image](assets/image-20260311150000-abc123.png)
```

---

## 7. Templates

### Rendre un template

```bash
curl -s -X POST "$BASE/api/template/render" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "20260310143000-tmplid1",
    "path": "/templates/adr-template.md"
  }'
```

### Sauvegarder un document comme template

```bash
curl -s -X POST "$BASE/api/template/docSaveAsTemplate" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "20260310143000-docid01",
    "name": "adr-template",
    "overwrite": true
  }'
```

---

## 8. Export

### Exporter un document en Markdown

```bash
curl -s -X POST "$BASE/api/export/exportMdContent" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"id": "20260310143000-docid01"}'
# Retourne :
# {
#   "code": 0,
#   "msg": "",
#   "data": {
#     "hPath": "/ADR/001-choix-base-de-donnees",
#     "content": "# ADR-001 : Choix de la base de donnees\n\n## Contexte\n..."
#   }
# }
```

### Exporter des ressources

```bash
curl -s -X POST "$BASE/api/export/exportResources" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"paths": ["/20260310143000-docid01.sy", "/20260310143000-docid02.sy"]}'
```

---

## 9. Operations sur les fichiers

Acces direct au systeme de fichiers de SiYuan (sous `/data/`).

### Lire un fichier

```bash
curl -s -X POST "$BASE/api/file/getFile" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"path": "/data/20260310120000-abc1def/20260310143000-docid01.sy"}'
```

### Ecrire un fichier

```bash
curl -s -X POST "$BASE/api/file/putFile" \
  -H "$AUTH" \
  -F "path=/data/storage/agent-state.json" \
  -F "file=@/chemin/vers/agent-state.json"
```

### Supprimer un fichier

```bash
curl -s -X POST "$BASE/api/file/removeFile" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"path": "/data/storage/agent-state.json"}'
```

### Renommer un fichier

```bash
curl -s -X POST "$BASE/api/file/renameFile" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "path": "/data/storage/old-name.json",
    "newPath": "/data/storage/new-name.json"
  }'
```

### Lister les fichiers d'un repertoire

```bash
curl -s -X POST "$BASE/api/file/listFiles" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"path": "/data/"}'
```

---

## 10. Notifications

Permet aux agents d'envoyer des messages visibles dans l'interface SiYuan.

### Envoyer un message de notification

```bash
curl -s -X POST "$BASE/api/notification/pushMsg" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"msg": "Agent CTO : ADR-001 cree avec succes.", "timeout": 7000}'
# timeout en millisecondes (7000 = 7 secondes)
```

### Envoyer un message d'erreur

```bash
curl -s -X POST "$BASE/api/notification/pushErrMsg" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"msg": "Agent CTO : Erreur lors de la creation du document.", "timeout": 7000}'
```

---

## 11. Systeme

### Obtenir la version

```bash
curl -s -X POST "$BASE/api/system/version" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{}'
# Retourne :
# {"code": 0, "msg": "", "data": "3.1.x"}
```

### Obtenir l'heure courante du serveur

```bash
curl -s -X POST "$BASE/api/system/currentTime" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{}'
# Retourne :
# {"code": 0, "msg": "", "data": 1741700000000}
# Timestamp en millisecondes.
```

### Verifier la progression du demarrage

```bash
curl -s -X POST "$BASE/api/system/bootProgress" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{}'
# Retourne :
# {"code": 0, "msg": "", "data": {"progress": 100, "details": "Finishing boot..."}}
# progress = 100 signifie que SiYuan est pret.
```

---

## 12. Strategie par agent

Chaque agent utilise un sous-ensemble de l'API en fonction de son role.

| Agent          | Notebook         | Actions principales                                              |
|----------------|------------------|------------------------------------------------------------------|
| **CTO**        | `architecture`   | `createDocWithMd` (ADR), `appendBlock` (conventions), SQL search |
| **CPO**        | `produit`        | `createDocWithMd` (PRD), `appendBlock` (specs), SQL search       |
| **Designer**   | `design-system`  | `createDocWithMd` (tokens), `appendBlock` (composants)           |
| **Researcher** | `research`       | `createDocWithMd` (rapports), `appendBlock` (findings), SQL      |
| **Lead Backend** | *(lecture)*    | `searchDocs`, SQL queries, `getDoc`, `exportMdContent`           |
| **Lead Frontend** | *(lecture)*   | `searchDocs`, SQL queries, `getDoc`, `exportMdContent`           |

### Workflow type pour un agent ecrivain (CTO, CPO, Designer, Researcher)

```bash
# 1. Trouver le notebook
NOTEBOOK=$(curl -s -X POST "$BASE/api/notebook/lsNotebooks" \
  -H "$AUTH" -H "Content-Type: application/json" -d '{}' \
  | jq -r '.data.notebooks[] | select(.name=="architecture") | .id')

# 2. Creer un document
DOC_ID=$(curl -s -X POST "$BASE/api/filetree/createDocWithMd" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"notebook\": \"$NOTEBOOK\", \"path\": \"/ADR/002-choix-cache\", \"markdown\": \"# ADR-002 : Strategie de cache\"}" \
  | jq -r '.data')

# 3. Ajouter du contenu
curl -s -X POST "$BASE/api/block/appendBlock" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"dataType\": \"markdown\", \"data\": \"## Decision\n\nRedis pour le cache applicatif.\", \"parentID\": \"$DOC_ID\"}"

# 4. Taguer avec des attributs
curl -s -X POST "$BASE/api/attr/setBlockAttrs" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"id\": \"$DOC_ID\", \"attrs\": {\"custom-agent\": \"cto\", \"custom-type\": \"decision\", \"custom-project\": \"projet-x\", \"custom-status\": \"draft\", \"custom-confidence\": \"hypothesis\"}}"

# 5. Notifier
curl -s -X POST "$BASE/api/notification/pushMsg" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"msg": "Agent CTO : ADR-002 cree — Strategie de cache", "timeout": 5000}'
```

### Workflow type pour un agent lecteur (Lead Backend, Lead Frontend)

```bash
# 1. Chercher par SQL
curl -s -X POST "$BASE/api/query/sql" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT id, hpath, content FROM blocks WHERE type='\''d'\'' AND content LIKE '\''%API%'\'' ORDER BY updated DESC LIMIT 5"}'

# 2. Lire le document complet en Markdown
curl -s -X POST "$BASE/api/export/exportMdContent" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"id": "20260310143000-docid01"}'
```

---

## 13. Bootstrap — Notebooks a creer au premier demarrage

Au premier lancement de la stack, les notebooks suivants doivent etre crees :

| Notebook         | Contenu                        | Agent responsable |
|------------------|--------------------------------|-------------------|
| `architecture`   | ADR, conventions, patterns     | CTO               |
| `produit`        | PRD, specs fonctionnelles      | CPO               |
| `design-system`  | Tokens, composants, guidelines | Designer          |
| `research`       | Rapports, veille technologique | Researcher        |
| `global`         | Documents partages, onboarding | Tous              |

### Script de bootstrap

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

### Verification post-bootstrap

```bash
curl -s -X POST "$BASE/api/notebook/lsNotebooks" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.data.notebooks[] | {id, name, closed}'
```

---

## 14. Query Embeds (resultats SQL dynamiques)

SiYuan supporte des blocs `query_embed` qui affichent les resultats d'une requete SQL en temps reel directement dans les documents.

### Exemples de query embeds utiles

```sql
-- Decisions actives (dans un doc dashboard)
SELECT content, hpath FROM blocks
WHERE ial LIKE '%custom-type=decision%' AND ial LIKE '%custom-status=active%'
ORDER BY updated DESC LIMIT 10

-- Documents d'un notebook specifique
SELECT * FROM blocks WHERE box = 'NOTEBOOK_ID' AND type = 'd' ORDER BY updated DESC

-- Blocs modifies aujourd'hui
SELECT content, hpath FROM blocks WHERE updated > strftime('%Y%m%d', 'now') ORDER BY updated DESC

-- Tous les docs bookmarkes
SELECT content, hpath FROM blocks WHERE ial LIKE '%custom-bookmarked=true%'

-- Recherche par agent source
SELECT content, hpath FROM blocks WHERE ial LIKE '%custom-agent=cto%' ORDER BY updated DESC LIMIT 20
```

Les query embeds se rafraichissent automatiquement — pas besoin de n8n pour ca.

---

## 15. Daily Notes

Configuration des daily notes sur un notebook :

```bash
curl -X POST "http://host.docker.internal:6806/api/notebook/setNotebookConf" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{
    "notebook": "NOTEBOOK_ID",
    "conf": {
      "dailyNoteSavePath": "/journal/{{now | date \"2006/01\"}}/{{now | date \"2006-01-02\"}}"
    }
  }'
```

Note: SiYuan utilise le format de date Go (2006 = annee, 01 = mois, 02 = jour).

Creer une daily note :
```bash
curl -X POST "http://host.docker.internal:6806/api/filetree/createDailyNote" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"notebook": "NOTEBOOK_ID"}'
```

---

## 16. Templates (Sprig)

SiYuan supporte les templates Sprig pour generer des documents.

### Sauvegarder un doc comme template
```bash
curl -X POST "http://host.docker.internal:6806/api/template/docSaveAsTemplate" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOC_BLOCK_ID", "name": "adr-template", "overwrite": true}'
```

### Rendre un template Sprig
```bash
curl -X POST "http://host.docker.internal:6806/api/template/renderSprig" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"template": "# ADR-{{.Num}}: {{.Title}}\n\nDate: {{now | date \"2006-01-02\"}}\nAgent: {{.Agent}}"}'
```

### Templates recommandes
| Template | Usage | Cree par |
|----------|-------|---------|
| adr-template | Architecture Decision Record | Bootstrap script |
| prd-template | Product Requirements Document | CPO |
| security-audit | Rapport d'audit securite | Security |
| sprint-report | Rapport de sprint | CTO |
| post-mortem | Incident post-mortem | DevOps |

---

## 17. Notifications Push

```bash
# Notification persistante (timeout: 0)
curl -X POST "http://host.docker.internal:6806/api/notification/pushMsg" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"msg": "Decision CTO: Migration PostgreSQL validee", "timeout": 0}'

# Notification temporaire (30 secondes)
curl -X POST "http://host.docker.internal:6806/api/notification/pushMsg" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"msg": "Deploy frontend-app v2.3 reussi", "timeout": 30000}'
```

Les notifications sont visibles sur l'app mobile SiYuan.

### Tableau des notifications strategiques

| Source | Message | Timeout |
|--------|---------|---------|
| Decision critique | "CTO: {titre}" | 0 (persistant) |
| Deploy reussi | "Deploy {service} v{version}" | 30000 |
| Deploy echoue | "DEPLOY FAIL: {service}" | 0 |
| Bug critique | "Bug P0: {titre}" | 0 |
| Security alert | "ALERT: {description}" | 0 |
| Approval needed | "Approval en attente: {titre}" | 0 |
| Weekly digest | "Digest semaine {num} disponible" | 60000 |

---

## 18. Conventions d'attributs custom

| Attribut | Valeurs | Usage |
|----------|---------|-------|
| custom-mem0-id | UUID | Lien vers la memoire Mem0 source |
| custom-agent | nom agent | Agent qui a cree le doc |
| custom-type | decision, architecture, etc. | Type de memoire Mem0 |
| custom-confidence | hypothesis, tested, validated | Niveau de confiance |
| custom-project | nom projet | Projet associe |
| custom-status | active, deprecated, archived | Etat du document |
| custom-tag | tags,separes,virgules | Tags pour categorisation |
| custom-bookmarked | true | Document important |
| custom-pinned | true | Document epingle en haut |

### Requetes SQL sur les attributs custom

```bash
# Trouver tous les docs bookmarkes
curl -X POST "http://host.docker.internal:6806/api/query/sql" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT * FROM blocks WHERE ial LIKE '\''%custom-bookmarked=true%'\'' ORDER BY updated DESC"}'

# Trouver les docs d'un agent specifique
curl -X POST "http://host.docker.internal:6806/api/query/sql" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT * FROM blocks WHERE ial LIKE '\''%custom-agent=cto%'\'' AND type = '\''d'\'' ORDER BY updated DESC"}'

# Trouver les docs deprecies
curl -X POST "http://host.docker.internal:6806/api/query/sql" \
  -H "Authorization: Token paperclip-siyuan-token" \
  -H "Content-Type: application/json" \
  -d '{"stmt": "SELECT * FROM blocks WHERE ial LIKE '\''%custom-status=deprecated%'\'' ORDER BY updated DESC"}'
```

---

## Aide-memoire rapide

| Action                        | Endpoint                              | Champ cle       |
|-------------------------------|---------------------------------------|-----------------|
| Lister notebooks              | `/api/notebook/lsNotebooks`           | `{}`             |
| Creer document Markdown       | `/api/filetree/createDocWithMd`       | notebook, path, markdown |
| Ajouter contenu a un doc      | `/api/block/appendBlock`              | parentID, data   |
| Mettre a jour un bloc         | `/api/block/updateBlock`              | id, data         |
| Chercher (SQL)                | `/api/query/sql`                      | stmt             |
| Chercher (simple)             | `/api/filetree/searchDocs`            | k                |
| Lire un doc en Markdown       | `/api/export/exportMdContent`         | id               |
| Taguer un bloc                | `/api/attr/setBlockAttrs`             | id, attrs        |
| Lire les tags d'un bloc       | `/api/attr/getBlockAttrs`             | id               |
| Notifier l'utilisateur        | `/api/notification/pushMsg`           | msg, timeout     |
