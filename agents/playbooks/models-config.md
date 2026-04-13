# Configuration des modeles — MacBook Pro M5 Pro 48GB

## Modeles a installer sur Ollama

```bash
# T1 — Strategie & Raisonnement (CEO, CTO, Growth Lead)
ollama pull qwen3:32b             # ~20GB RAM

# T2 — Code (Lead Backend, Lead Frontend, DevOps)
ollama pull qwen3-coder:30b       # ~19GB RAM — MoE, 256K contexte, agentic coding
ollama pull devstral:24b          # ~14GB RAM — Alternative, SWE-Bench 46.8%

# T3 — Execution (CPO, CFO, QA, Security, Designer, Researcher, SEO, Content Writer, Data Analyst, Sales)
ollama pull qwen3:14b             # ~9GB RAM

# Fallback ultra-leger
ollama pull qwen3:8b              # ~5GB RAM

# Embeddings (Mem0, Chroma)
ollama pull nomic-embed-text      # ~0.3GB RAM
```

## Allocation des modeles par agent

### T1 — Strategie & Raisonnement (`qwen3:32b`, ~20GB)

| Agent | Justification |
|-------|---------------|
| **CEO** | Raisonnement complexe, delegation, decisions strategiques, tool calling |
| **CTO** | Architecture, decisions techniques, decomposition de taches, tool calling |
| **Growth Lead** | Coordination equipe growth (4 agents), strategie acquisition, tool calling |

Pourquoi `qwen3:32b` :
- Meilleur raisonnement open-source a cette taille (surpasse Qwen2.5, DeepSeek-R1 en tool calling)
- Tool calling natif (indispensable pour la delegation via Paperclip)
- 100+ langues (francais natif)
- Suffisamment gros pour comprendre des contextes complexes multi-agents

### T2 — Code (`qwen3-coder:30b` / `devstral:24b`)

| Agent | Modele principal | Modele alternatif | Justification |
|-------|-----------------|-------------------|---------------|
| **Lead Backend** | `qwen3-coder:30b` | `devstral:24b` | Code backend haute qualite, agentic coding |
| **Lead Frontend** | `qwen3-coder:30b` | `devstral:24b` | Code frontend, composants React/Vue |
| **DevOps** | `qwen3-coder:30b` | `devstral:24b` | Dockerfiles, CI/CD, scripts infra |

Pourquoi `qwen3-coder:30b` (principal) :
- Le plus recent (2025), optimise SWE-Bench
- Architecture MoE : 30B params totaux mais seulement 3.3B actifs → rapide
- 256K contexte natif (extensible 1M) → peut lire des codebases entieres
- Concu specifiquement pour l'agentic coding (exploration + multi-file edit)

Pourquoi `devstral:24b` (alternatif) :
- SWE-Bench 46.8% (bat Claude 3.5 Haiku)
- Plus leger (~14GB vs ~19GB) → permet dual-loading avec T1 ou T3
- 128K contexte
- Licence Apache 2.0
- Ideal pour les taches code plus courtes ou quand la RAM est tendue

### T3 — Execution (`qwen3:14b`, ~9GB)

| Agent | Justification |
|-------|---------------|
| **CPO** | Specs produit, PRD, priorisation |
| **CFO** | Analyse de couts, rapports financiers |
| **Security** | Audit de code, analyse de vulnerabilites |
| **QA** | Tests, review de code, rapports de bugs |
| **Designer** | Specs textuelles, wireframes ASCII |
| **Researcher** | Recherche, veille, comparaisons, documentation |
| **SEO Specialist** | Analyse SEO, mots-cles, recommandations |
| **Content Writer** | Redaction articles, copy, contenu marketing |
| **Data Analyst** | Analyse de donnees, rapports, metriques |
| **Sales Automation** | Pipeline commercial, sequences email, CRM |

Pourquoi `qwen3:14b` :
- Meme famille que T1 (coherence des outputs)
- Tool calling natif
- Multilingue (francais)
- Leger (~9GB) → peut coexister avec T1 (20+9=29GB) ou T2 (19+9=28GB)
- Suffisant pour les taches structurees qui ne necessitent pas de raisonnement profond

## Gestion memoire Ollama

### Configuration recommandee

```bash
# Dans ~/.zshrc ou launchd d'Ollama
export OLLAMA_MAX_LOADED_MODELS=2
export OLLAMA_KEEP_ALIVE=10m       # Garde le modele en RAM 10 min apres derniere requete
```

### Combos de chargement possibles

| Combo | Slot 1 | Slot 2 | RAM totale | Reste pour OS | Usage |
|-------|--------|--------|------------|---------------|-------|
| **A** | qwen3:32b (20GB) | qwen3:14b (9GB) | 29GB | 19GB | CEO/CTO delegue a un agent T3 |
| **B** | qwen3-coder:30b (19GB) | qwen3:14b (9GB) | 28GB | 20GB | Dev code + QA review en parallele |
| **C** | devstral:24b (14GB) | qwen3:14b (9GB) | 23GB | 25GB | Code leger + execution (max confort) |
| **D** | qwen3:32b (20GB) | qwen3-coder:30b (19GB) | 39GB | 9GB | CEO decide + dev code (tendu, possible) |
| **E** | qwen3:32b (20GB) | devstral:24b (14GB) | 34GB | 14GB | CEO decide + dev code (confortable) |

### Sequencement typique d'un workflow

```
1. CEO demarre (qwen3:32b charge en Slot 1)
   → Delegue tache au CTO

2. CTO travaille (meme modele, pas de swap)
   → Decompose en sous-taches pour Lead Backend + QA

3. Lead Backend demarre (qwen3-coder:30b charge en Slot 2, swap qwen3:14b si present)
   → Temps de swap : ~10-30s
   → Code la feature

4. QA review (qwen3:14b charge en Slot 2, swap qwen3-coder:30b)
   → Temps de swap : ~10-30s
   → Teste et valide

5. DevOps deploy (qwen3-coder:30b recharge en Slot 2)
   → Deploy via n8n webhook
```

## Modeles exclus et pourquoi

| Modele | Raison d'exclusion |
|--------|-------------------|
| DeepSeek-R1:32b | Pas de tool calling fiable, chain-of-thought trop lent pour un orchestrateur |
| Llama 3.3:70b | Rentre (43GB) mais bloque toute la RAM, impossible de dual-load |
| Llama 4 Scout (16x17b) | 67GB, ne rentre pas en 48GB |
| Gemma3:27b | Pas de tool calling → inutilisable pour les agents Paperclip |
| Phi-4:14b | Tool calling limite, surpasse par qwen3:14b |
| Codestral:22b | Contexte 32K trop court, surpasse par devstral et qwen3-coder |
| Qwen2.5-Coder:32b | Surpasse par qwen3-coder:30b (plus recent, MoE, 256K contexte) |
| Qwen2.5:32b | Surpasse par qwen3:32b sur tous les benchmarks |
