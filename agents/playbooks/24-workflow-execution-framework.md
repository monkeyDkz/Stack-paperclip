# Framework d'execution de workflows

> Reference complementaire : [16-n8n-agent-workflows.md](./16-n8n-agent-workflows.md), [14-knowledge-workflows.md](./14-knowledge-workflows.md), [23-agent-communication-protocol.md](./23-agent-communication-protocol.md)

---

## 1. Patterns d'orchestration

### Pattern 1 : Sequentiel

```
A → B → C → D
```

**Usage** : pipeline lineaire (PRD → architecture → code → test → deploy)

- Chaque etape attend la fin de la precedente
- Resultat transmis via Paperclip issue child
- Rollback : revenir a l'etape precedente

**Quand l'utiliser** : flux simples ou chaque etape depend strictement de la sortie precedente. Ideal pour les processus bien definis avec peu d'incertitude.

---

### Pattern 2 : Fan-out / Fan-in

```
      ┌→ B ─┐
A ────┤→ C ─├──→ E
      └→ D ─┘
```

**Usage** : parallelisation (CTO decompose, 3 devs executent, QA valide)

- Coordinateur cree N taches enfant
- Chaque tache independante
- Sync point : coordinateur attend toutes les completions
- Gestion partielle : si 1 echoue, les autres continuent (configurable)

**Quand l'utiliser** : quand plusieurs sous-taches peuvent etre executees simultanement sans dependance entre elles. Reduit significativement la duree totale du workflow.

---

### Pattern 3 : Pipeline continu

```
Code → Review → Test → Deploy → Monitor
  ↑                                  │
  └──────── Feedback ────────────────┘
```

**Usage** : CI/CD, amelioration continue

- Boucle de feedback
- Chaque etape peut rejeter vers une etape precedente
- Le rejet inclut un commentaire expliquant la raison et les corrections attendues

**Quand l'utiliser** : processus iteratifs ou la qualite s'ameliore par boucles successives. Particulierement adapte au design et au deploiement continu.

---

### Pattern 4 : Superviseur

```
CEO ──→ CTO ──→ Lead Backend
   │        └──→ Lead Frontend
   └──→ CPO ──→ Designer
```

**Usage** : delegation hierarchique avec supervision

- Le superviseur delegue mais garde la visibilite
- Reporting periodique vers le superviseur
- Escalade si bloqueur

**Quand l'utiliser** : projets complexes necessitant une coordination multi-equipe avec un point de decision central.

---

## 2. Workflows concrets

### WF-FEAT : Feature Delivery

```
CPO(PRD) → CTO(architecture+decomposition) → [Lead Backend(code) + Lead Frontend(code)] → QA(test) → Security(audit si requis) → DevOps(deploy)
```

**Pattern** : Sequentiel + Fan-out/Fan-in
**Coordinateur** : CTO
**Duree estimee** : 5-10 heartbeat cycles CTO

**Etapes detaillees** :

1. **CPO** cree PRD dans Mem0 (`type: prd`), publie dans SiYuan (`notebook: produit`)
2. **CTO** lit PRD, cree ADR si decision architecturale, decompose en taches
3. **Backend + Frontend** executent en parallele, sauvent patterns dans Mem0
4. **QA** valide (promeut memories a `confidence: validated`)
5. **Security** audit si critere : auth, data, infra
6. **DevOps** deploy via n8n (`agent-deploy`)

**Criteres de succes** :
- PRD approuve par CEO
- Tous les tests passent
- Audit security OK (si applicable)
- Deploiement reussi

---

### WF-BUG : Bug Resolution

```
QA(report) → CTO(triage+assign) → Backend/Frontend(fix) → QA(verify) → DevOps(hotfix deploy)
```

**Pattern** : Sequentiel
**Coordinateur** : CTO
**Duree estimee** : 2-4 heartbeat cycles

**Etapes detaillees** :

1. **QA** cree bug report dans Mem0 (`type: bug`, `confidence: tested`)
2. **CTO** triage : severity, assign to backend or frontend
3. **Dev** fix, cree regression test
4. **QA** verifie fix + regression
5. **DevOps** deploy hotfix

**Criteres de succes** :
- Bug reproduit et confirme
- Fix valide par QA
- Test de regression ajoute
- Hotfix deploye sans regression

---

### WF-SEC : Security Audit

```
Security(scan) → CTO(prioritize) → [Backend(fix) + Frontend(fix) + DevOps(fix)] → Security(verify)
```

**Pattern** : Fan-out/Fan-in
**Coordinateur** : Security
**Duree estimee** : 3-6 heartbeat cycles

**Etapes detaillees** :

1. **Security** scans (code audit + dependency check)
2. **CTO** prioritizes findings (critical first)
3. **Agents** fix in parallel by domain
4. **Security** re-verifies all fixes

**Criteres de succes** :
- Tous les findings critiques resolus
- Aucune nouvelle vulnerabilite introduite
- Rapport d'audit archive dans Mem0

---

### WF-RESEARCH : Tech Research

```
CEO(objective) → Researcher(analysis) → CTO(decision) → CEO(validate)
```

**Pattern** : Sequentiel
**Coordinateur** : CEO
**Duree estimee** : 2-4 heartbeat cycles

**Etapes detaillees** :

1. **CEO** definit l'objectif de recherche
2. **Researcher** utilise Firecrawl + Chroma + web, produit un rapport
3. **CTO** evalue et prend une decision technique (Decision Record)
4. **CEO** valide l'alignement strategique

**Criteres de succes** :
- Rapport de recherche complet avec sources
- Decision Record cree si applicable
- Validation strategique par CEO

---

### WF-COST : Cost Review

```
CFO(analyze) → CEO(decide) → CTO(optimize) → CFO(verify)
```

**Pattern** : Sequentiel
**Coordinateur** : CFO
**Duree estimee** : 1-2 heartbeat cycles

**Etapes detaillees** :

1. **CFO** pull cost data from Paperclip stats
2. **CEO** decide budget adjustments
3. **CTO** implemente optimisations (model downgrades, batch processing)
4. **CFO** verifie impact

**Criteres de succes** :
- Analyse de couts documentee
- Budget ajuste si necessaire
- Optimisations mesurees

---

### WF-DESIGN : Design Iteration

```
CPO(requirements) → Designer(wireframe) → Lead Frontend(implement) → QA(test) → Designer(review)
```

**Pattern** : Pipeline avec feedback
**Coordinateur** : CPO
**Duree estimee** : 4-8 heartbeat cycles

**Etapes detaillees** :

1. **CPO** specs requirements
2. **Designer** creates wireframes + specs dans SiYuan
3. **Frontend** implemente les composants
4. **QA** teste (a11y, visual regression)
5. **Designer** review conformite, boucle si necessaire

**Criteres de succes** :
- Wireframes approuves par CPO
- Implementation conforme aux specs
- Tests a11y et visuels passes
- Designer valide le resultat final

---

## 3. Gestion d'etat

### Identifiant de workflow

Chaque workflow a un ID unique : `WF-{type}-{timestamp}`

Exemples :
- `WF-FEAT-1710200400`
- `WF-BUG-1710201200`
- `WF-SEC-1710202000`

### Stockage dans Mem0

Etat stocke dans Mem0 :

```json
{
  "type": "context",
  "tags": "workflow,WF-FEAT-1710200400",
  "state": "active",
  "metadata": {
    "pattern": "sequentiel+fan-out",
    "coordinator": "cto",
    "phase": 3,
    "started_at": "2026-03-11T10:00:00Z"
  }
}
```

### Transitions d'etat

```
initiated → in_progress → blocked → completed
                       ↘             ↗
                        → failed ────
```

Transitions valides :
- `initiated` → `in_progress` : premiere tache demarre
- `in_progress` → `blocked` : un bloqueur est identifie
- `blocked` → `in_progress` : bloqueur resolu
- `in_progress` → `completed` : toutes les etapes terminees avec succes
- `in_progress` → `failed` : echec irrecuperable
- `failed` → `initiated` : relance manuelle du workflow

### Suivi dans Paperclip

- **Issue parent** : represente le workflow complet
- **Issues enfant** : representent chaque etape
- **Labels** : `workflow`, `WF-{type}`, `phase-{N}`
- Phase tracking : metadata `phase: N` sur chaque memory liee

---

## 4. Gestion des echecs

### Retry automatique

1 retry pour les taches simples (API call, deploy). Delai avant retry : 1 heartbeat cycle.

Les taches eligibles au retry automatique :
- Appels API externes (Firecrawl, n8n triggers)
- Deploiements (via agent-deploy)
- Publications SiYuan

### Escalade

Si retry echoue → escalade au superviseur du workflow.

Chaine d'escalade :
1. Agent executant → Coordinateur du workflow
2. Coordinateur → CTO (pour les workflows techniques)
3. CTO → CEO (pour les decisions strategiques)

### Circuit breaker

Si > 3 echecs sur le meme type de tache → pause workflow + alerte CEO.

Le circuit breaker se reinitialise apres :
- Intervention manuelle du CEO
- Expiration d'un delai configurable (defaut : 24h)

### Rollback

Pour les deploys, DevOps peut rollback via n8n (`agent-deploy` avec `action: rollback`).

Conditions de rollback automatique :
- Tests post-deploy echoues
- Monitoring detecte une degradation (si configure)

### Post-mortem

Tout echec de workflow genere une memory :

```json
{
  "type": "incident",
  "tags": "post-mortem,WF-FEAT-1710200400",
  "content": "Analyse root cause: ...",
  "confidence": "tested",
  "metadata": {
    "workflow_id": "WF-FEAT-1710200400",
    "failed_step": 3,
    "root_cause": "...",
    "resolution": "...",
    "preventive_action": "..."
  }
}
```

---

## 5. Templates de workflow

Utiliser ce template pour definir un nouveau workflow :

```markdown
## WF-{ID} : {Nom}

**Pattern** : {sequentiel | fan-out | pipeline | superviseur}
**Declencheur** : {evenement ou commande}
**Coordinateur** : {agent responsable}
**Participants** : {liste d'agents}
**Duree estimee** : {N heartbeat cycles}

### Etapes
1. {Agent}({action}) → output: {livrable}
2. ...

### Criteres de succes
- [ ] ...

### Gestion d'echec
- Si etape N echoue: {action}
```

### Exemple rempli

```markdown
## WF-FEAT-001 : Ajout authentification OAuth

**Pattern** : sequentiel + fan-out
**Declencheur** : CPO cree PRD "OAuth Integration"
**Coordinateur** : CTO
**Participants** : CPO, CTO, Lead Backend, Lead Frontend, QA, Security, DevOps
**Duree estimee** : 8 heartbeat cycles

### Etapes
1. CPO(PRD) → output: PRD dans Mem0 + SiYuan
2. CTO(architecture) → output: ADR + decomposition en 4 taches
3. Lead Backend(API OAuth) → output: endpoints auth
4. Lead Frontend(UI login) → output: composants login/signup
5. QA(tests) → output: rapport de test
6. Security(audit) → output: rapport securite
7. DevOps(deploy) → output: deploy staging puis prod

### Criteres de succes
- [ ] OAuth flow complet (Google + GitHub)
- [ ] Tests unitaires et integration > 80% coverage
- [ ] Audit securite passe sans finding critique
- [ ] Deploy prod stable

### Gestion d'echec
- Si etape 3 ou 4 echoue : CTO reassigne ou decompose davantage
- Si etape 6 echoue (finding critique) : retour etape 3/4 pour fix
- Si etape 7 echoue : rollback automatique via n8n
```

---

## 6. Resume rapide des patterns par workflow

| Workflow    | Pattern                  | Coordinateur | Duree estimee       |
|-------------|--------------------------|--------------|---------------------|
| WF-FEAT     | Sequentiel + Fan-out     | CTO          | 5-10 heartbeat      |
| WF-BUG      | Sequentiel               | CTO          | 2-4 heartbeat       |
| WF-SEC      | Fan-out/Fan-in           | Security     | 3-6 heartbeat       |
| WF-RESEARCH | Sequentiel               | CEO          | 2-4 heartbeat       |
| WF-COST     | Sequentiel               | CFO          | 1-2 heartbeat       |
| WF-DESIGN   | Pipeline avec feedback   | CPO          | 4-8 heartbeat       |
