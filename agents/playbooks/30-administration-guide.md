# Guide d'administration des agents — Reference complete

> Ce document est la reference unique pour administrer les 16 agents Paperclip sur MacBook Pro M5 Pro 48GB.
> Il couvre : scheduling, priorites, gestion des modeles Ollama, regles de fonctionnement, monitoring et troubleshooting.

---

## Table des matieres

1. [Vue d'ensemble du systeme](#1-vue-densemble-du-systeme)
2. [Les 16 agents — Fiche complete](#2-les-16-agents--fiche-complete)
3. [Gestion des modeles Ollama](#3-gestion-des-modeles-ollama)
4. [Scheduling et heartbeats](#4-scheduling-et-heartbeats)
5. [Priorites et preemption](#5-priorites-et-preemption)
6. [Regles de fonctionnement](#6-regles-de-fonctionnement)
7. [Workflows de reference](#7-workflows-de-reference)
8. [Gouvernance et approvals](#8-gouvernance-et-approvals)
9. [Monitoring et observabilite](#9-monitoring-et-observabilite)
10. [Troubleshooting](#10-troubleshooting)
11. [Operations courantes](#11-operations-courantes)
12. [Checklist de demarrage](#12-checklist-de-demarrage)

---

## 1. Vue d'ensemble du systeme

### Architecture runtime

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MacBook Pro M5 Pro                          │
│                       48GB RAM unifiee · SSD 1To                    │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                     OLLAMA (:11434)                          │    │
│  │                                                              │    │
│  │  OLLAMA_MAX_LOADED_MODELS=2                                  │    │
│  │  OLLAMA_KEEP_ALIVE=10m                                       │    │
│  │                                                              │    │
│  │  Slot 1 ──── qwen3:32b (20GB)     ← CEO, CTO, Growth Lead  │    │
│  │          ou  qwen3-coder:30b (19GB) ← Lead BK, FR, DevOps   │    │
│  │                                                              │    │
│  │  Slot 2 ──── qwen3:14b (9GB)      ← 10 agents T3           │    │
│  │          ou  devstral:24b (14GB)   ← Code alternatif        │    │
│  │          ou  qwen3:8b (5GB)       ← Fallback / Mem0         │    │
│  │                                                              │    │
│  │  Permanent ── nomic-embed-text (0.3GB) ← Embeddings         │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                      │
│  ┌───────────────────────────▼─────────────────────────────────┐    │
│  │                    LiteLLM (:4000)                           │    │
│  │              Proxy API → route vers Ollama                   │    │
│  └───────────────────────────┬─────────────────────────────────┘    │
│                              │                                      │
│  ┌───────────────────────────▼─────────────────────────────────┐    │
│  │                   PAPERCLIP (:8060)                          │    │
│  │           Orchestrateur — source de verite agents            │    │
│  │                                                              │    │
│  │  16 agents · heartbeats · issues · sessions · approvals     │    │
│  │  goals · projects · cost tracking · config revisions        │    │
│  └──────┬──────────────┬──────────────┬────────────────────────┘    │
│         │              │              │                              │
│  ┌──────▼──────┐ ┌─────▼─────┐ ┌─────▼─────┐                      │
│  │ MEM0 (:8050)│ │SIYUAN     │ │CHROMA     │                      │
│  │ Memoire     │ │(:6806)    │ │(:8000)    │                      │
│  │ agents      │ │Knowledge  │ │Vector DB  │                      │
│  │ + Kuzu graph│ │base       │ │(backend   │                      │
│  └─────────────┘ └───────────┘ │ de Mem0)  │                      │
│                                └───────────┘                      │
│                                                                     │
│                    ┌────────────────────┐                            │
│                    │  LOBECHAT (:3210)  │                            │
│                    │  Chat IA humain    │                            │
│                    └────────────────────┘                            │
└─────────────────────────────────────────────────────────────────────┘
                              │
                     NetBird VPN / LAN
                              │
                              ▼
                    Serveur HP OMEN (n8n, Gitea, Dokploy, CRM, ...)
```

### Flux d'execution d'un agent

```
Paperclip heartbeat (timer)
  │
  ├── 1. REVEIL : Paperclip reveille l'agent
  │
  ├── 2. MODELE : LiteLLM route vers Ollama
  │     └── Ollama charge le modele si pas en RAM (~10-30s swap)
  │
  ├── 3. CONTEXTE : Agent charge ses memoires (Mem0 + SiYuan)
  │     └── Mem0 utilise nomic-embed-text (toujours charge)
  │
  ├── 4. TACHE : Agent checkout une issue Paperclip
  │
  ├── 5. EXECUTION : Agent travaille (code, analyse, delegation, ...)
  │
  ├── 6. SAUVEGARDE : Agent sauve learnings dans Mem0
  │
  ├── 7. REPORTING : Agent reporte couts + resultat dans Paperclip
  │
  ├── 8. NOTIFICATION : Agent envoie events via n8n webhook
  │
  └── 9. SOMMEIL : Agent dort jusqu'au prochain heartbeat
```

---

## 2. Les 16 agents — Fiche complete

### Organigramme hierarchique

```
CEO (qwen3:32b · HB 600s)
│
├── CTO (qwen3:32b · HB 600s)
│   ├── Lead Backend (qwen3-coder:30b · HB 900s)
│   ├── Lead Frontend (qwen3-coder:30b · HB 900s)
│   ├── DevOps (qwen3-coder:30b · HB 1800s)
│   ├── Security (qwen3:14b · HB 1800s)
│   ├── QA (qwen3:14b · HB 900s)
│   └── Researcher (qwen3:14b · HB 3600s)
│
├── CPO (qwen3:14b · HB 900s)
│   ├── Designer (qwen3:14b · HB 1800s)
│   └── Growth Lead (qwen3:32b · HB 900s)
│       ├── SEO Specialist (qwen3:14b · HB 1800s)
│       ├── Content Writer (qwen3:14b · HB 1800s)
│       ├── Data Analyst (qwen3:14b · HB 1800s)
│       └── Sales Automation (qwen3:14b · HB 1800s)
│
└── CFO (qwen3:14b · HB 1800s)
```

### Tableau de reference complet

| # | Agent | Modele | Tier | RAM | Heartbeat | Context mode | Permissions | Reporte a |
|---|-------|--------|------|-----|-----------|-------------|-------------|-----------|
| 1 | **CEO** | qwen3:32b | T1 | 20GB | 600s (10min) | full | canCreateAgents | - |
| 2 | **CTO** | qwen3:32b | T1 | 20GB | 600s (10min) | full | canCreateAgents | CEO |
| 3 | **CPO** | qwen3:14b | T3 | 9GB | 900s (15min) | full | - | CEO |
| 4 | **CFO** | qwen3:14b | T3 | 9GB | 1800s (30min) | incremental | - | CEO |
| 5 | **Lead Backend** | qwen3-coder:30b | T2 | 19GB | 900s (15min) | session | - | CTO |
| 6 | **Lead Frontend** | qwen3-coder:30b | T2 | 19GB | 900s (15min) | session | - | CTO |
| 7 | **DevOps** | qwen3-coder:30b | T2 | 19GB | 1800s (30min) | session | - | CTO |
| 8 | **Security** | qwen3:14b | T3 | 9GB | 1800s (30min) | incremental | - | CTO |
| 9 | **QA** | qwen3:14b | T3 | 9GB | 900s (15min) | session | - | CTO |
| 10 | **Designer** | qwen3:14b | T3 | 9GB | 1800s (30min) | incremental | - | CPO |
| 11 | **Researcher** | qwen3:14b | T3 | 9GB | 3600s (60min) | incremental | - | CTO |
| 12 | **Growth Lead** | qwen3:32b | T1 | 20GB | 900s (15min) | full | - | CPO |
| 13 | **SEO Specialist** | qwen3:14b | T3 | 9GB | 1800s (30min) | incremental | - | Growth Lead |
| 14 | **Content Writer** | qwen3:14b | T3 | 9GB | 1800s (30min) | incremental | - | Growth Lead |
| 15 | **Data Analyst** | qwen3:14b | T3 | 9GB | 1800s (30min) | incremental | - | Growth Lead |
| 16 | **Sales Automation** | qwen3:14b | T3 | 9GB | 1800s (30min) | incremental | - | Growth Lead |

### Justification des heartbeats

| Frequence | Agents | Raisonnement |
|-----------|--------|-------------|
| **600s (10min)** | CEO, CTO | Doivent reagir vite aux escalades, delegations, et decisions. Sont les pivots de tout le systeme |
| **900s (15min)** | CPO, Lead Backend, Lead Frontend, QA, Growth Lead | Executeurs principaux — besoin de reactivite sur les taches en cours |
| **1800s (30min)** | CFO, DevOps, Security, Designer, SEO, Content Writer, Data Analyst, Sales | Taches moins frequentes ou de surveillance. Pas besoin de reactivite immediate |
| **3600s (60min)** | Researcher | Recherche long format, pas de besoin de reactivite. Les resultats sont consommes par d'autres agents |

**Tous les agents ont `wakeOnDemand: true` et `wakeOnAssignment: true`** — ils peuvent etre reveilles immediatement par une assignation de tache, meme entre deux heartbeats.

---

## 3. Gestion des modeles Ollama

### Configuration systeme

```bash
# ~/.zshrc
export OLLAMA_MAX_LOADED_MODELS=2    # Max 2 modeles en RAM simultanes
export OLLAMA_KEEP_ALIVE=10m         # Garde le modele 10min apres la derniere requete
```

### Les 3 tiers de modeles

```
┌─────────────────────────────────────────────────────────┐
│                    MODELES INSTALLES                      │
│                                                          │
│  T1 — STRATEGIE (raisonnement + tool calling)           │
│  ┌─────────────────────────────────────────────────┐    │
│  │ qwen3:32b         20GB   CEO, CTO, Growth Lead  │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  T2 — CODE (agentic coding + gros contexte)             │
│  ┌─────────────────────────────────────────────────┐    │
│  │ qwen3-coder:30b   19GB   Lead BK, FR, DevOps    │    │
│  │ devstral:24b      14GB   Alternative plus legere │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  T3 — EXECUTION (taches structurees)                    │
│  ┌─────────────────────────────────────────────────┐    │
│  │ qwen3:14b          9GB   10 agents               │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  FALLBACK                                                │
│  ┌─────────────────────────────────────────────────┐    │
│  │ qwen3:8b           5GB   Mem0 LLM, fallback      │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  EMBEDDINGS (toujours charge)                            │
│  ┌─────────────────────────────────────────────────┐    │
│  │ nomic-embed-text  0.3GB  Mem0, Chroma             │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### Combos de chargement RAM

Ollama garde max 2 modeles en RAM. Voici les combos possibles et quand ils se produisent :

| Combo | Slot 1 | Slot 2 | RAM totale | Reste OS | Quand |
|-------|--------|--------|------------|----------|-------|
| **A** | qwen3:32b (20GB) | qwen3:14b (9GB) | 29GB | 19GB | CEO/CTO delegue → agent T3 execute. **Le plus frequent** |
| **B** | qwen3-coder:30b (19GB) | qwen3:14b (9GB) | 28GB | 20GB | Dev code + QA review en parallele |
| **C** | devstral:24b (14GB) | qwen3:14b (9GB) | 23GB | 25GB | Code leger + execution (max confort) |
| **D** | qwen3:32b (20GB) | qwen3-coder:30b (19GB) | 39GB | 9GB | CEO decide + dev code (tendu mais possible) |
| **E** | qwen3:32b (20GB) | devstral:24b (14GB) | 34GB | 14GB | CEO decide + dev code (confortable) |
| **F** | qwen3:14b (9GB) | qwen3:14b (9GB) | 9GB | 39GB | 2 agents T3 en "parallele" (meme modele = pas de swap) |
| **G** | qwen3:32b (20GB) | qwen3:8b (5GB) | 25GB | 23GB | CEO + Mem0 traitement interne |

### Matrice de swap entre agents

Quand un agent prend la main apres un autre, un swap de modele est-il necessaire ?

```
                    Agent SUIVANT
                    CEO  CTO  CPO  CFO  BK   FR   DO   SE   QA   DE   RE   GL   SEO  CW   DA   SA
Agent     CEO       -    -    S    S    S    S    S    S    S    S    S    -    S    S    S    S
PRECEDENT CTO       -    -    S    S    S    S    S    S    S    S    S    -    S    S    S    S
          CPO       S    S    -    -    S    S    S    -    -    -    -    S    -    -    -    -
          CFO       S    S    -    -    S    S    S    -    -    -    -    S    -    -    -    -
          BK        S    S    S    S    -    -    -    S    S    S    S    S    S    S    S    S
          FR        S    S    S    S    -    -    -    S    S    S    S    S    S    S    S    S
          DO        S    S    S    S    -    -    -    S    S    S    S    S    S    S    S    S
          SE        S    S    -    -    S    S    S    -    -    -    -    S    -    -    -    -
          QA        S    S    -    -    S    S    S    -    -    -    -    S    -    -    -    -
          GL        -    -    S    S    S    S    S    S    S    S    S    -    S    S    S    S

-  = Pas de swap (meme modele)     S = Swap necessaire (~10-30s)
GL = Growth Lead   BK = Backend    FR = Frontend    DO = DevOps
SE = Security      DE = Designer   RE = Researcher  CW = Content Writer
DA = Data Analyst  SA = Sales Auto
```

**Optimisation cle** : les 10 agents T3 (CPO, CFO, Security, QA, Designer, Researcher, SEO, Content Writer, Data Analyst, Sales) partagent `qwen3:14b` — **aucun swap entre eux**. C'est le plus gros gain de performance.

### Sequence de swap typique — Workflow Feature

```
Temps  Agent          Modele charge      Swap?   Duree swap
─────  ─────          ──────────────     ─────   ──────────
t=0    CEO            qwen3:32b          Non     -
t=1    CTO            qwen3:32b          Non     0s (meme modele)
t=2    CPO (PRD)      qwen3:14b          Oui     ~15s
t=3    CTO (archi)    qwen3:32b          Oui     ~25s
t=4    Lead Backend   qwen3-coder:30b    Oui     ~25s
t=5    Lead Frontend  qwen3-coder:30b    Non     0s (meme modele)
t=6    QA             qwen3:14b          Oui     ~15s
t=7    Security       qwen3:14b          Non     0s (meme modele)
t=8    DevOps         qwen3-coder:30b    Oui     ~25s
t=9    CTO (review)   qwen3:32b          Oui     ~25s

Total swaps : 6 sur 10 transitions
Temps perdu en swaps : ~2 minutes sur un workflow de 30+ minutes
```

---

## 4. Scheduling et heartbeats

### Fonctionnement du heartbeat Paperclip

```
┌──────────────────────────────────────────────────────────────┐
│                    CYCLE DE VIE D'UN AGENT                    │
│                                                               │
│  ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌─────────┐ │
│  │  DORT   │───→│ REVEILLE │───→│ TRAVAILLE│───→│ REPORTE │ │
│  │         │    │          │    │          │    │         │ │
│  │ Attend  │    │ Charge   │    │ Execute  │    │ Sauve   │ │
│  │ HB ou   │    │ contexte │    │ tache    │    │ memoire │ │
│  │ wake    │    │ Mem0     │    │ Paperclip│    │ + cout  │ │
│  └────▲────┘    └──────────┘    └──────────┘    └────┬────┘ │
│       │                                              │      │
│       └──────────────────────────────────────────────┘      │
│                                                               │
│  Declencheurs de reveil :                                     │
│    • Timer heartbeat (intervalSec)                            │
│    • wakeOnAssignment (nouvelle tache assignee)               │
│    • wakeOnDemand (appel explicite API)                       │
└──────────────────────────────────────────────────────────────┘
```

### Planification temporelle — qui se reveille quand

Exemple sur une fenetre de 60 minutes (t=0 a t=60min) :

```
Minute: 0    5    10   15   20   25   30   35   40   45   50   55   60
        │    │    │    │    │    │    │    │    │    │    │    │    │
CEO     █─────────█─────────█─────────█─────────█─────────█─────────█  (10min)
CTO     █─────────█─────────█─────────█─────────█─────────█─────────█  (10min)
CPO     █──────────────█──────────────█──────────────█──────────────█  (15min)
LdBK    █──────────────█──────────────█──────────────█──────────────█  (15min)
LdFR    █──────────────█──────────────█──────────────█──────────────█  (15min)
QA      █──────────────█──────────────█──────────────█──────────────█  (15min)
GrwLd   █──────────────█──────────────█──────────────█──────────────█  (15min)
CFO     █─────────────────────────────█─────────────────────────────█  (30min)
DevOps  █─────────────────────────────█─────────────────────────────█  (30min)
Sec     █─────────────────────────────█─────────────────────────────█  (30min)
Design  █─────────────────────────────█─────────────────────────────█  (30min)
SEO     █─────────────────────────────█─────────────────────────────█  (30min)
CntWr   █─────────────────────────────█─────────────────────────────█  (30min)
DatAn   █─────────────────────────────█─────────────────────────────█  (30min)
Sales   █─────────────────────────────█─────────────────────────────█  (30min)
Rsrch   █─────────────────────────────────────────────────────────  █  (60min)
```

### Probleme de contention — comment Paperclip gere les reveils simultanes

**Quand plusieurs agents se reveillent en meme temps**, Paperclip les traite **sequentiellement** (un seul appel LLM a la fois via LiteLLM → Ollama). L'ordre est determine par :

1. **Priorite du tier** : T1 (CEO, CTO, Growth Lead) avant T2 (Leads, DevOps) avant T3 (les 10 autres)
2. **Anciennete de la tache** : tache la plus ancienne en attente passe en premier
3. **Urgence** : taches marquees `priority: urgent` passent devant tout

**En pratique** : Paperclip ne reveille jamais les 16 agents en meme temps. Les heartbeats sont desynchronises naturellement (chaque agent demarre a un moment different). Le cas le plus frequent est 1-3 agents actifs simultanement.

### File d'attente implicite

```
Exemple : t=0, CEO et CPO se reveillent en meme temps

  File : [CEO (T1, prio haute), CPO (T3, prio normale)]

  1. CEO passe en premier → Ollama charge qwen3:32b
     CEO travaille (~30-120s)
     CEO dort

  2. CPO passe ensuite → Ollama swap vers qwen3:14b (~15s)
     CPO travaille (~30-90s)
     CPO dort

Temps total : ~3-5 minutes pour traiter les 2 agents
```

---

## 5. Priorites et preemption

### Niveaux de priorite des taches

| Priorite | Label | Preemption | Exemples |
|----------|-------|-----------|----------|
| **P0 — Critique** | `urgent` | Oui — interrompt les taches en cours | Incident securite, service down, fuite de donnees |
| **P1 — Haute** | `high` | Oui — passe devant la file | Bug bloquant en prod, deadline client |
| **P2 — Normale** | `normal` | Non — ordre FIFO | Feature, refactoring, documentation |
| **P3 — Basse** | `low` | Non — traite quand la file est vide | Tech debt, optimisation, recherche exploratoire |

### Regles de preemption

```
Tache en cours (P2 normale)
  │
  ▼
Nouvelle tache P0 (critique) assignee
  │
  ├── Agent recoit wakeOnAssignment
  ├── Agent suspend la tache en cours (sauve contexte dans session)
  ├── Agent checkout la tache P0
  ├── Agent execute la tache P0
  ├── Agent ferme la tache P0
  └── Agent reprend la tache suspendue (restaure session)
```

### Escalade automatique par timeout

```
TACHE SIMPLE (typo, config, test unitaire)
  │
  [HB 1] En cours ? → Continue
  [HB 2] En cours ? → Continue (ALERTE si toujours en cours)
  [HB 3] TIMEOUT → Escalade au superieur
  │
TACHE COMPLEXE (feature, refactoring, audit)
  │
  [HB 1-4] En cours ? → Continue
  [HB 5] TIMEOUT → Escalade au superieur
  │
TOUTE TACHE
  │
  [> 24h sans activite] → Notification CEO automatique via n8n
```

### Chemins d'escalade

```
TECHNIQUE :     Dev → Lead → CTO → CEO
PRODUIT :       Designer → CPO → CEO
GROWTH :        SEO/CW/DA/SA → Growth Lead → CPO → CEO
SECURITE :      N'importe qui → Security → CTO → CEO  (BYPASS hierarchie)
FINANCE :       N'importe qui → CFO → CEO
```

---

## 6. Regles de fonctionnement

### 6.1 Regle d'or — Sequencement des agents

**Les agents ne tournent PAS en parallele.** Ils sont traites sequentiellement par Paperclip, un a la fois. Le "parallelisme" vient de :
- Des heartbeats desynchronises
- Du wakeOnAssignment qui permet des reveils ad-hoc
- De la persistance de contexte via les sessions Paperclip

### 6.2 Canaux de communication — Quel canal pour quel usage

```
L'information concerne...

├── Une TACHE a realiser ?
│   └── → Paperclip Issue
│       ✓ "Implementer le endpoint /api/users"
│       ✗ PAS dans Mem0, PAS dans SiYuan
│
├── Un SAVOIR a retenir ?
│   ├── Court et factuel (decision, learning, convention) ?
│   │   └── → Mem0 memory
│   │       ✓ "DECISION: Utiliser PostgreSQL pour le projet X"
│   │       ✗ PAS dans Paperclip issues
│   │
│   └── Long et structure (spec, rapport, guide) ?
│       └── → SiYuan document (auto-publie via n8n)
│           ✓ PRD complet, rapport d'audit, architecture decision record
│           ✗ PAS dans Mem0 (trop long, pollue la recherche)
│
└── Un EVENEMENT a signaler ?
    └── → n8n webhook
        ✓ "Deploy termine", "Alerte securite", "Nouveau lead CRM"
        ✗ PAS dans Mem0, PAS dans Paperclip
```

### 6.3 Protocole memoire obligatoire

**Chaque agent, a CHAQUE reveil, DOIT :**

```bash
# Etape 0 — Charger le contexte (AVANT de travailler)

# a. Mes memoires actives
POST mem0:8050/search/filtered
  {user_id: "self", filters: {state: {$eq: "active"}}, limit: 10}

# b. Conventions CTO
POST mem0:8050/search/filtered
  {user_id: "cto", filters: {type: {$eq: "convention"}, state: {$eq: "active"}}, limit: 5}

# c. Contexte cross-agent (selon matrice de visibilite)
POST mem0:8050/search/multi
  {query: "contexte pertinent", user_ids: [...], limit_per_user: 3}

# d. Channels systeme (selon matrice)
POST mem0:8050/search/filtered
  {user_id: "monitoring", filters: {state: {$eq: "active"}}, limit: 5}
```

**Chaque agent, a CHAQUE fin de tache, DOIT :**

```bash
# 1. Verifier la deduplication
POST mem0:8050/search {query: "contenu a sauver", user_id: "self", limit: 1}

# 2. Sauvegarder le learning avec metadata obligatoires
POST mem0:8050/memories
  {text: "LEARNING: ...", user_id: "self", metadata: {
    type: "learning",         # OBLIGATOIRE
    project: "nom-projet",    # OBLIGATOIRE
    confidence: "tested",     # OBLIGATOIRE
    source_task: "issue-uuid" # RECOMMANDE
  }}

# 3. Reporter les couts
POST paperclip:8060/api/companies/$CID/cost-events
  {agentId: "...", issueId: "...", model: "qwen3:32b", inputTokens: N, outputTokens: N}
```

### 6.4 Matrice de visibilite Mem0

Qui lit les memoires de qui :

```
                 Lit les memoires de :
                 CEO CTO CPO CFO BK  FR  DO  SE  QA  DE  RE  GL  SEO CW  DA  SA  mon anl crm cal dep git sec
CEO               .   x   x   x   .   .   .   .   .   .   .   .   .   .   .   .   x   x   x   .   .   .   .
CTO              x    .   x   .   x   x   x   x   x   .   x   .   .   .   .   .   x   .   .   .   x   x   .
CPO              x   x    .   .   .   .   .   .   .   x   .   x   .   .   .   .   .   x   x   x   .   .   .
CFO              x    .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   x   x   .   .   .   .
Lead Backend      .   x   .   .   .   x   .   x   x   .   .   .   .   .   .   .   x   .   .   .   .   x   .
Lead Frontend     .   x   .   .   x   .   .   .   x   x   .   .   .   .   .   .   x   .   .   .   .   x   .
DevOps            .   x   .   .   .   .   .   x   .   .   .   .   .   .   .   .   x   .   .   .   x   x   x
Security          .   x   .   .   x   x   x   .   .   .   x   .   .   .   .   .   x   .   .   .   .   .   x
QA                .   x   .   .   x   x   .   .   .   .   .   .   .   .   .   .   x   .   .   .   .   .   .
Designer          .   .   x   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .
Researcher        .   x   .   .   .   .   .   .   .   .   .   .   .   .   .   .   x   .   .   .   .   .   .
Growth Lead       .   .   x   .   .   .   .   .   .   .   .   .   x   x   x   x   .   x   x   x   .   .   .
SEO Specialist    .   .   .   .   .   .   .   .   .   .   .   x   .   .   x   .   .   x   .   .   .   .   .
Content Writer    .   .   .   .   .   .   .   .   .   .   .   x   x   .   .   .   .   .   .   .   .   .   .
Data Analyst      .   .   .   .   .   .   .   .   .   .   .   x   .   .   .   .   .   x   x   x   .   .   .
Sales Automation  .   .   .   .   .   .   .   .   .   .   .   x   .   .   x   .   .   x   x   x   .   .   .

Legende colonnes systeme : mon=monitoring anl=analytics crm=crm cal=calendar dep=deployments git=git-events sec=security-events
```

### 6.5 Anti-patterns interdits

| # | Anti-pattern | Pourquoi c'est interdit | Correct |
|---|-------------|------------------------|---------|
| 1 | **Appels directs agent-a-agent** | Pas de tracabilite, pas de priorisation | Toujours passer par une Paperclip issue |
| 2 | **Pollution memoire** | Degrade la qualite des recherches Mem0 pour tous | Ne sauvegarder que decisions finales, learnings confirmes |
| 3 | **Echecs silencieux** | Le meme echec sera repete | Toujours sauvegarder un learning type `bug` expliquant l'echec |
| 4 | **Escalade prematuree** | Surcharge les C-level | Tenter au moins une solution avant d'escalader |
| 5 | **Duplication de taches** | 2 agents travaillent sur le meme probleme | Chercher dans Mem0 + Paperclip avant de creer |
| 6 | **Ecrire dans les channels systeme** | Convention : seul n8n ecrit | Agents en lecture seule sur monitoring, analytics, crm, etc. |

### 6.6 Format Decision Record (obligatoire pour type decision/architecture)

```
DECISION: [titre court, max 80 caracteres]
CONTEXT: [1-2 phrases : pourquoi cette decision etait necessaire]
CHOICE: [ce qui a ete decide, avec details techniques]
ALTERNATIVES: [ce qui a ete rejete et pourquoi]
CONSEQUENCES: [impact attendu, risques identifies]
STATUS: active|deprecated
LINKED_TASK: [paperclip issue id ou "none"]
```

---

## 7. Workflows de reference

### Vue d'ensemble

| ID | Nom | Pattern | Coordinateur | Agents impliques | Duree | Modeles charges |
|----|-----|---------|-------------|-----------------|-------|-----------------|
| WF-FEAT | Feature Delivery | Sequentiel + Fan-out | CTO | CPO, CTO, BK, FR, QA, Sec, DO | 5-10 HB | T1 → T3 → T2 → T3 → T2 |
| WF-BUG | Bug Resolution | Sequentiel | CTO | QA, CTO, BK/FR, QA, DO | 2-4 HB | T3 → T1 → T2 → T3 → T2 |
| WF-SEC | Security Audit | Fan-out/Fan-in | Security | Sec, CTO, BK, FR, DO | 3-6 HB | T3 → T1 → T2 → T3 |
| WF-RESEARCH | Tech Research | Sequentiel | CEO | CEO, Researcher, CTO | 2-4 HB | T1 → T3 → T1 |
| WF-COST | Cost Review | Sequentiel | CFO | CFO, CEO, CTO | 1-2 HB | T3 → T1 |
| WF-DESIGN | Design Iteration | Pipeline feedback | CPO | CPO, Designer, FR, QA | 4-8 HB | T3 (tout le long) |
| WF-GROWTH | Growth Campaign | Superviseur | Growth Lead | GL, SEO, CW, DA, SA | 3-6 HB | T1 → T3 (tout le long) |

### WF-FEAT detaille — Feature Delivery (le plus complexe)

```
Phase 1 — SPECIFICATION
  CPO recoit la demande du CEO
  CPO (qwen3:14b) cree le PRD dans Mem0
  CPO publie dans SiYuan (auto via n8n)
  [Swap T3→T1 si CEO/CTO prend la suite]

Phase 2 — ARCHITECTURE
  CTO (qwen3:32b) lit le PRD
  CTO cree l'ADR (Architecture Decision Record)
  CTO decompose en sous-taches
  CTO assigne Lead Backend + Lead Frontend + DevOps
  [Pas de swap — CTO reste sur qwen3:32b]

Phase 3 — IMPLEMENTATION (Fan-out)
  Lead Backend (qwen3-coder:30b) code le backend
    [Swap T1→T2 : ~25s]
  Lead Frontend (qwen3-coder:30b) code le frontend
    [Pas de swap — meme modele]
  (Sequentiel car Ollama traite un agent a la fois)

Phase 4 — VALIDATION
  QA (qwen3:14b) teste
    [Swap T2→T3 : ~15s]
  Security (qwen3:14b) audite si requis
    [Pas de swap — meme modele]

Phase 5 — DEPLOIEMENT
  DevOps (qwen3-coder:30b) deploy via n8n
    [Swap T3→T2 : ~25s]

Phase 6 — REVIEW
  CTO (qwen3:32b) valide le tout
    [Swap T2→T1 : ~25s]
  CTO reporte au CEO

Total swaps : ~6 | Temps perdu : ~2 minutes
```

### WF-GROWTH detaille — Growth Campaign (nouveau)

```
Phase 1 — STRATEGIE
  Growth Lead (qwen3:32b) definit la campagne
  Growth Lead decompose en taches pour SEO, Content, Data, Sales
  [Swap si CEO/CTO etait sur T1 avant — sinon pas de swap]

Phase 2 — ANALYSE (Fan-out)
  Data Analyst (qwen3:14b) analyse les donnees actuelles
    [Swap T1→T3 : ~15s]
  SEO Specialist (qwen3:14b) audit SEO
    [Pas de swap — meme modele]
  (Sequentiel, mais pas de swap entre eux)

Phase 3 — EXECUTION
  Content Writer (qwen3:14b) cree le contenu
    [Pas de swap — meme modele]
  SEO Specialist (qwen3:14b) optimise le contenu
    [Pas de swap — meme modele]

Phase 4 — ACTIVATION
  Sales Automation (qwen3:14b) configure les sequences email
    [Pas de swap — meme modele]
  Sales envoie via n8n → BillionMail

Phase 5 — REPORTING
  Data Analyst (qwen3:14b) mesure les resultats
    [Pas de swap — meme modele]
  Growth Lead (qwen3:32b) review et reporte au CPO
    [Swap T3→T1 : ~25s]

Total swaps : ~2 | Temps perdu : ~40s
Tres efficace car les 4 agents executeurs partagent le meme modele T3
```

---

## 8. Gouvernance et approvals

### Qui peut faire quoi

| Action | CEO | CTO | CPO | CFO | Leads | Autres |
|--------|:---:|:---:|:---:|:---:|:-----:|:------:|
| Creer un agent | x | x | - | - | - | - |
| Supprimer un agent | x | - | - | - | - | - |
| Modifier un heartbeat | x | x | - | - | - | - |
| Changer un modele | x | x | - | - | - | - |
| Rollback config | x | x | - | - | - | - |
| Approuver un deploy prod | x | x | - | - | - | - |
| Approuver un budget | x | - | - | x | - | - |
| Deprecier une memoire | x | x | - | - | Auteur | Auteur |
| Archiver une memoire | x | x | - | - | - | - |
| Supprimer une memoire | x | - | - | - | - | - |

### Types d'approbation requis

| Declencheur | Soumis par | Approuve par | SLA |
|-------------|-----------|-------------|-----|
| Changement d'architecture majeur | CTO | CEO + CPO | 1 HB CEO |
| Deploy en production | DevOps | CTO | 1 HB CTO |
| Depassement budget | CFO | CEO | 1 HB CEO |
| Creation d'un nouvel agent | CEO/CTO | CEO | Immediat |
| Decision strategique majeure | CEO | Board (toi) | Manuel |

### Systeme d'approval Paperclip

```bash
# Soumettre une demande
POST paperclip:8060/api/companies/$CID/approvals
{
  "type": "architecture",
  "title": "Migration vers PostgreSQL 16",
  "submittedByAgentId": "<cto-id>",
  "approverAgentIds": ["<ceo-id>"],
  "metadata": {"impact": "high", "reversible": false}
}

# Approuver
POST paperclip:8060/api/companies/$CID/approvals/<id>/approve
{"agentId": "<ceo-id>", "comment": "Approuve."}

# Rejeter
POST paperclip:8060/api/companies/$CID/approvals/<id>/reject
{"agentId": "<ceo-id>", "comment": "Non, rester sur SQLite."}
```

---

## 9. Monitoring et observabilite

### Points de controle

| Quoi | Comment verifier | Frequence |
|------|-----------------|-----------|
| Ollama tourne | `curl http://localhost:11434/api/tags` | Continu (Uptime Kuma) |
| Modeles charges | `ollama ps` | Ad hoc |
| Paperclip tourne | `curl http://localhost:8060/health` | Continu (Uptime Kuma) |
| Mem0 tourne | `curl http://localhost:8050/health` | Continu (Uptime Kuma) |
| Chroma tourne | `curl http://localhost:8000/api/v2/heartbeat` | Continu (Uptime Kuma) |
| SiYuan tourne | `curl http://localhost:6806/api/system/version` | Continu (Uptime Kuma) |
| LiteLLM tourne | `curl http://localhost:4000/health` | Continu (Uptime Kuma) |
| Agents actifs | `curl paperclip:8060/api/companies/$CID/agents` | Ad hoc |
| Taches en cours | `curl paperclip:8060/api/companies/$CID/issues?status=in_progress` | Ad hoc |
| Stats memoire | `curl mem0:8050/stats` | Hebdo (CTO review) |
| Couts cumules | `curl paperclip:8060/api/companies/$CID/cost-summary` | Mensuel (CFO) |
| RAM Ollama | `ollama ps` (montre la RAM par modele) | Ad hoc |

### Dashboard SiYuan (mis a jour par n8n)

3 dashboards auto-rafraichis dans le notebook `global` de SiYuan :

| Dashboard | Frequence | Contenu |
|-----------|-----------|---------|
| `services` | 5 min | Status, uptime, response time de chaque service |
| `analytics` | 1h | Pages vues, visiteurs, conversions Umami |
| `team-activity` | 30 min | Activite recente par agent, taches completees |

### Alertes automatiques (via n8n → ntfy)

| Evenement | Workflow n8n | Notification |
|-----------|-------------|-------------|
| Service down | `agent-status` → `agent-notify` | Push ntfy immediat |
| Tache en timeout | `task-timeout` webhook | Push ntfy + escalade |
| Deploy echoue | `agent-deploy` | Push ntfy + rollback auto |
| Attaque detectee | `security-alert` | Push ntfy immediat |
| Backup echoue | `backup-report` | Push ntfy |
| > 24h sans activite agent | Paperclip interne | Push ntfy au CEO |

### Commandes de diagnostic rapide

```bash
# Quels modeles sont charges en RAM ?
ollama ps

# Quelle RAM totale utilisee par Ollama ?
ollama ps | awk 'NR>1 {sum+=$4} END {print sum" GB"}'

# Etat de tous les containers Docker (Mac)
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | sort

# Logs d'un agent specifique
docker logs paperclip --since 30m 2>&1 | grep "agent-name"

# Combien de memoires dans Mem0 ?
curl -s http://localhost:8050/stats | jq .

# Taches en cours
curl -s "http://localhost:8060/api/companies/$CID/issues?status=in_progress" | jq '.data[] | {title, assignee, created}'

# Taches bloquees
curl -s "http://localhost:8060/api/companies/$CID/issues?status=blocked" | jq '.data[] | {title, assignee, created}'

# Couts cumules par agent
curl -s "http://localhost:8060/api/companies/$CID/cost-summary" | jq '.data.byAgent'
```

---

## 10. Troubleshooting

### Probleme : Ollama swap trop souvent (lenteur)

**Symptome** : les agents mettent longtemps a repondre, `ollama ps` montre des modeles qui se chargent/dechargent en boucle.

**Cause** : trop d'agents de tiers differents se reveillent en meme temps.

**Solutions** :
1. Augmenter `OLLAMA_KEEP_ALIVE` a `30m` pour garder les modeles plus longtemps
2. Decaler les heartbeats pour grouper les agents du meme tier :
   - Tous les T3 aux minutes 0, 30
   - Tous les T2 aux minutes 10, 40
   - Tous les T1 aux minutes 20, 50
3. Passer certains agents T2 sur `devstral:24b` (14GB) au lieu de `qwen3-coder:30b` (19GB) pour permettre le combo T1+T2 en RAM

### Probleme : Un agent ne se reveille pas

**Symptome** : pas d'activite sur un agent, ses taches restent en `todo`.

**Diagnostic** :
```bash
# Verifier la config de l'agent
curl -s "http://localhost:8060/api/agents/<agent-id>" | jq '.data.runtimeConfig.heartbeat'

# Verifier les logs Paperclip
docker logs paperclip --since 1h 2>&1 | grep "<agent-name>"

# Forcer un reveil
curl -X POST "http://localhost:8060/api/agents/<agent-id>/wake" \
  -H "Authorization: Bearer $AGENT_API_KEY"
```

### Probleme : Mem0 ne repond pas

**Symptome** : agents en mode degrade, pas de contexte charge.

**Diagnostic** :
```bash
# Verifier Mem0
curl http://localhost:8050/health

# Verifier Chroma (dependance)
curl http://localhost:8000/api/v2/heartbeat

# Verifier Ollama embeddings (dependance)
curl http://localhost:11434/api/tags | jq '.models[] | select(.name | contains("nomic"))'

# Redemarrer Mem0
cd stack-configs-16g/mac/mem0 && docker compose restart
```

**Fallback** : les agents continuent sans memoire et sauvegardent localement. Au prochain reveil avec Mem0 fonctionnel, ils re-uploadent.

### Probleme : RAM saturee (Mac ralentit)

**Symptome** : macOS swap sur SSD, tout ralentit.

**Diagnostic** :
```bash
ollama ps                    # RAM par modele
docker stats --no-stream     # RAM par container
```

**Solutions** :
1. Tuer le modele le plus gros : `ollama stop qwen3:32b`
2. Reduire a `OLLAMA_MAX_LOADED_MODELS=1`
3. Basculer des agents T2 vers `devstral:24b` (14GB vs 19GB)
4. Basculer des agents T3 vers `qwen3:8b` (5GB vs 9GB) temporairement

### Probleme : Boucle d'escalade infinie

**Symptome** : agents qui s'escaladent mutuellement sans resoudre.

**Cause** : circuit breaker non declenche.

**Solution** : Paperclip a un circuit breaker a 3 echecs du meme type → pause workflow + alerte CEO. Si ca ne suffit pas :
```bash
# Forcer la cloture d'une tache bloquee
curl -X PATCH "http://localhost:8060/api/issues/<issue-id>" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"status": "cancelled", "comment": "Fermeture manuelle — boucle escalade"}'
```

### Probleme : Memories dupliquees dans Mem0

**Diagnostic** :
```bash
# Lancer la dedup
curl -X POST "http://localhost:8050/dedup" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "<agent-id>", "threshold": 0.92}'
```

**Prevention** : s'assurer que chaque agent fait une recherche avant de sauvegarder (voir regles section 6.3).

---

## 11. Operations courantes

### Ajouter un nouvel agent

1. Definir le role dans un fichier `agents-playbook/XX-nom.md`
2. Choisir le modele (T1/T2/T3) selon la complexite des taches
3. Definir le heartbeat selon la reactivite requise
4. Definir la visibilite Mem0 (qui il lit, qui le lit)
5. Creer l'agent via Paperclip (CEO ou CTO avec `canCreateAgents: true`)
6. L'agent s'auto-onboard via le template d'onboarding dans son prompt

### Changer le modele d'un agent

```bash
# Via Paperclip config revision (tracable + rollback possible)
curl -X PATCH "http://localhost:8060/api/agents/<agent-id>" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen3:14b"}'

# Verifier que le modele est installe
ollama list | grep "qwen3:14b"
```

### Modifier un heartbeat

```bash
curl -X PATCH "http://localhost:8060/api/agents/<agent-id>" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"runtimeConfig": {"heartbeat": {"intervalSec": 600}}}'
```

### Desactiver temporairement un agent

```bash
curl -X PATCH "http://localhost:8060/api/agents/<agent-id>" \
  -H "Authorization: Bearer $AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"runtimeConfig": {"heartbeat": {"enabled": false}}}'
```

### Forcer un reveil immediat

```bash
curl -X POST "http://localhost:8060/api/agents/<agent-id>/wake" \
  -H "Authorization: Bearer $AGENT_API_KEY"
```

### Review mensuelle des memoires (tache CTO)

```bash
# 1. Stats globales
curl -s http://localhost:8050/stats

# 2. Memoires hypothesis jamais promues (> 30 jours)
curl -X POST http://localhost:8050/search/filtered \
  -d '{"query": "decisions", "filters": {"confidence": {"$eq": "hypothesis"}, "state": {"$eq": "active"}}, "limit": 50}'

# 3. Archiver les deprecated de plus de 30 jours
curl -X POST http://localhost:8050/search/filtered \
  -d '{"query": "", "filters": {"state": {"$eq": "deprecated"}}, "limit": 100}'
# Pour chaque : PATCH /memories/{id}/state {"state": "archived"}

# 4. Dedup par agent
for agent in ceo cto cpo cfo lead-backend lead-frontend devops security qa designer researcher growth-lead seo content-writer data-analyst sales-automation; do
  echo "--- Dedup $agent ---"
  curl -X POST http://localhost:8050/dedup -d "{\"user_id\": \"$agent\", \"threshold\": 0.92}"
done
```

### Backup de la stack Mac

Les volumes Docker contiennent toutes les donnees persistantes :

```bash
# Lister les volumes
docker volume ls | grep -E "paperclip|mem0|chroma|siyuan|lobechat"

# Backup manuel
for vol in paperclip_data paperclip_db_data chroma_data mem0_data siyuan_data; do
  docker run --rm -v ${vol}:/data -v $(pwd)/backups:/backup alpine \
    tar czf /backup/${vol}_$(date +%Y%m%d).tar.gz -C /data .
done
```

---

## 12. Checklist de demarrage

### Premier demarrage (setup complet)

```
□ 1. Installer les prerequis
    □ Docker Desktop installe et demarre
    □ Homebrew installe

□ 2. Lancer le setup
    □ chmod +x setup-mac.sh && ./setup-mac.sh
    □ Verifier que les 6 modeles Ollama sont telecharges
    □ Verifier OLLAMA_MAX_LOADED_MODELS=2 dans ~/.zshrc

□ 3. Verifier les services
    □ Ollama     : curl http://localhost:11434/api/tags
    □ Chroma     : curl http://localhost:8000/api/v2/heartbeat
    □ Mem0       : curl http://localhost:8050/health
    □ SiYuan     : curl http://localhost:6806/api/system/version
    □ LiteLLM    : curl http://localhost:4000/health
    □ Paperclip  : curl http://localhost:8060/health
    □ LobeChat   : ouvrir http://localhost:3210

□ 4. Configurer Paperclip
    □ Creer le .env (copier .env.example, remplir les secrets)
    □ Creer la Company dans Paperclip
    □ Creer le Company Goal
    □ Creer le CEO manuellement (seul agent cree a la main)
    □ Assigner au CEO : "Recrute ton equipe C-level : CTO, CPO, CFO"
    □ Le CEO recrute automatiquement les 3 C-level
    □ Le CTO recrute les leads (Backend, Frontend, DevOps)
    □ Les autres agents sont recrutes a la demande

□ 5. Configurer n8n (serveur)
    □ Creer les 21 workflows n8n
    □ Configurer les webhooks Mem0 → n8n
    □ Tester agent-notify (envoyer une notif test via ntfy)

□ 6. Premier projet
    □ Creer une issue : "Nouveau projet : [description]"
    □ Assigner au CEO
    □ Observer le workflow se derouler
```

### Redemarrage apres arret

```
□ 1. Demarrer Docker Desktop
□ 2. Demarrer Ollama : ollama serve (ou via launchd)
□ 3. Verifier OLLAMA_MAX_LOADED_MODELS=2 : echo $OLLAMA_MAX_LOADED_MODELS
□ 4. Demarrer les stacks : cd stack-configs-16g/mac && for d in chroma mem0 lobechat siyuan paperclip; do (cd $d && docker compose up -d); done
□ 5. Verifier : docker ps --format "table {{.Names}}\t{{.Status}}" | sort
□ 6. Les agents reprennent automatiquement via leurs heartbeats
```

### Verification quotidienne (2 minutes)

```
□ ollama ps                           → modeles charges OK
□ docker ps | wc -l                   → tous les containers up
□ curl -s localhost:8050/health        → Mem0 OK
□ curl -s localhost:8060/health        → Paperclip OK
□ Ouvrir SiYuan → dashboard services  → tout vert
```

---

## Annexe A — Recapitulatif des ports Mac

| Port | Service | Healthcheck |
|------|---------|-------------|
| 3210 | LobeChat | `curl localhost:3210` |
| 4000 | LiteLLM | `curl localhost:4000/health` |
| 6806 | SiYuan Note | `curl localhost:6806/api/system/version` |
| 8000 | Chroma | `curl localhost:8000/api/v2/heartbeat` |
| 8050 | Mem0 | `curl localhost:8050/health` |
| 8060 | Paperclip | `curl localhost:8060/health` |
| 11434 | Ollama | `curl localhost:11434/api/tags` |

## Annexe B — Variables d'environnement

| Variable | Ou | Valeur |
|----------|---|--------|
| `OLLAMA_MAX_LOADED_MODELS` | `~/.zshrc` | `2` |
| `OLLAMA_KEEP_ALIVE` | `~/.zshrc` | `10m` |
| `POSTGRES_PASSWORD` | `paperclip/.env` | Secret |
| `BETTER_AUTH_SECRET` | `paperclip/.env` | Secret |
| `N8N_AGENT_KEY` | `paperclip/.env` | Partage avec n8n serveur |
| `SIYUAN_TOKEN` | `paperclip/.env` | Token API SiYuan |

## Annexe C — References croisees

| Document | Contenu |
|----------|---------|
| [00-stack-overview.md](./00-stack-overview.md) | Architecture, ports, interactions, organigramme |
| [13-memory-protocol.md](./13-memory-protocol.md) | Schema metadata, lifecycle, format Decision Record |
| [14-knowledge-workflows.md](./14-knowledge-workflows.md) | Onboarding, propagation, conflits, review, fallbacks |
| [16-n8n-agent-workflows.md](./16-n8n-agent-workflows.md) | Les 21 workflows n8n |
| [21-paperclip-setup.md](./21-paperclip-setup.md) | Goals, projects, approvals, cost tracking, sessions |
| [22-skills-catalog.md](./22-skills-catalog.md) | Skills de chaque agent |
| [23-agent-communication-protocol.md](./23-agent-communication-protocol.md) | Canaux, visibilite, delegation, escalade, SLAs |
| [24-workflow-execution-framework.md](./24-workflow-execution-framework.md) | Patterns d'orchestration, gestion d'etat, echecs |
| [models-config.md](./models-config.md) | Allocation modeles, combos RAM, modeles exclus |
| [deployment-order.md](./deployment-order.md) | Ordre de deploiement des agents |
