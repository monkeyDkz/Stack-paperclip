# Bilan & Plan d'amélioration — Paperclip Multi-Agents
> Dernière mise à jour : 23 mars 2026

---

## CE QUI FONCTIONNE VRAIMENT ✅

### Infrastructure
- **Ollama** : stable, 7 modèles installés, API fiable, pas de crash
- **Mem0** : lecture/écriture OK depuis le container Docker, search rapide
- **SiYuan** : cookie auth fonctionne, création de docs OK depuis le container
- **Paperclip** : API stable (wake, issues, agents, runs), UI fonctionnelle
- **Docker** : bind mounts, networking host.docker.internal, tout connecté

### Agents
- **CEO avec qwen3:14b** : 10 tool calls réussis, délégation correcte avec ANNUAIRE
- **Tool calling** : Mem0 search, Issues fetch, Issue creation, PATCH status — tout fonctionne
- **ANNUAIRE** : le CEO utilise les bons UUIDs pour assigner (Designer ✓, testé)
- **Orchestrateur** : `agent-orchestrator.sh` gère le séquentiel (status, queue, wake, reset)
- **Prompts standardisés** : 16 templates avec structure canonique identique

### OpenCode
- **81 skills** installés (Paperclip, Mem0, SiYuan, DevOps, OK Skills, Open Skills)
- **Config séparée** : agents (sans plugins) vs terminal perso (avec plugins)
- **Adapter opencode_local** : fonctionne, sessions, env vars Paperclip injectées

---

## CE QUI NE FONCTIONNE PAS ❌

### Performance
- **Temps de run** : ~6-10 min par agent avec qwen3:14b → cascade CEO→CTO→Dev = 30+ min
- **Thinking time** : le modèle passe 3-5 min à "réfléchir" avant le premier tool call
- **Pas de parallélisme** : OLLAMA_MAX_LOADED_MODELS=2 + 48GB = séquentiel obligatoire

### Fiabilité du tool calling
- **Boucles** : qwen3:8b boucle sur les erreurs (retry infini au lieu de s'adapter)
- **Hallucination d'UUIDs** : qwen3:8b invente des UUIDs au lieu de lire l'ANNUAIRE
- **qwen3:32b** : comprend bien mais 92 min/run = inutilisable
- **Inconsistance** : même modèle, même prompt → résultats variables d'un run à l'autre

### Plugins OpenCode
- **Inutilisables dans Docker** : snip pas installé, cc-safety-net bloque les curls
- **Config partagée** : bind mount = impossible d'avoir plugins pour agents ET terminal
- ✅ Résolu : config séparée `opencode-personal/`

### Workflows
- **Pas de SiYuan** : les agents n'écrivent pas encore dans SiYuan de manière fiable (jamais testé end-to-end)
- **projectId manquant** : le CEO n'inclut pas toujours le projectId dans les issues
- **Issues dupliquées** : le CEO crée des doublons quand il tourne plusieurs fois
- **Sessions stale** : un run "terminé" reste en status "running" → bloque les suivants

---

## CE QUI EST PARTIELLEMENT FONCTIONNEL ⚠️

| Composant | Marche | Ne marche pas |
|-----------|--------|--------------|
| CEO delegation | Crée les bonnes issues | Parfois duplique, pas toujours le projectId |
| Mem0 write | user_id correct ("ceo") | Pas de metadata riche (project, confidence) |
| SiYuan integration | Login cookie OK | Agents n'écrivent pas encore de docs |
| Orchestrateur | wake, status, queue OK | Pas de cleanup auto, pas de logger |
| Post-run logger | Script créé | Jamais testé en production |
| Config perso | Fichier créé | Alias zsh pas encore ajouté |

---

## PLAN D'AMÉLIORATION

### Sprint 1 : Stabiliser (cette semaine)

- [ ] **Tester le deploy complet** : `./deploy-agents.sh` puis `./agent-orchestrator.sh wake ceo`
- [ ] **Valider SiYuan end-to-end** : CEO crée un Decision Record dans SiYuan
- [ ] **Valider le logger** : après un run, vérifier Mem0 (run-log) + SiYuan (/runs/)
- [ ] **Ajouter l'alias `oc`** dans ~/.zshrc pour la config perso avec plugins
- [ ] **Nettoyer les issues** : supprimer les doublons, garder STA-1 + sous-tâches propres
- [ ] **Tester un cycle complet** : CEO → CTO → un exécutant (3 agents séquentiels)

### Sprint 2 : Robustesse (semaine prochaine)

- [ ] **Anti-duplication** : ajouter une règle dans le prompt CEO "vérifier si l'issue existe avant de créer"
- [ ] **Auto-cleanup orchestrateur** : reset agents bloqués en "running" > 30 min
- [ ] **Monitoring dashboard** : JSON state file + script de visualisation
- [ ] **Heartbeats auto** : activer pour le CEO (toutes les 30 min) une fois stable
- [ ] **Tester devstral:24b** : pour les agents coding, comparer la qualité du code

### Sprint 3 : Scale (dans 2 semaines)

- [ ] **Workflow complet site-agence** : CEO → CTO (archi) → CPO (specs) → Lead Frontend (code) → QA (test) → DevOps (deploy)
- [ ] **n8n integration** : webhook de notification quand un agent finit (ntfy push)
- [ ] **Chroma embeddings** : indexer les docs SiYuan pour recherche sémantique
- [ ] **Évaluer OpenClaw hybrid** : C-levels sur cloud (rapide, fiable) + exécutants sur Ollama local

### Sprint 4 : Optimisation (dans 1 mois)

- [ ] **Benchmarks** : mesurer tool calling success rate par modèle
- [ ] **Prompt optimization** : A/B test des prompts (plus court vs plus détaillé)
- [ ] **Budget tracking** : CFO agent qui analyse les coûts réels (tokens, temps)
- [ ] **Multi-projet** : supporter plusieurs projets simultanés (pas juste site-agence)

---

## MÉTRIQUES À SUIVRE

| Métrique | Cible | Actuel |
|----------|-------|--------|
| Tool calling success rate | > 90% | ~70% (estimé) |
| Temps moyen par run | < 5 min | ~8 min |
| Cascade CEO→Dev (3 agents) | < 20 min | ~30 min |
| Issues correctement assignées | 100% | ~80% |
| SiYuan docs créés par run | 1+ | 0 (pas encore actif) |
| Mem0 memories par run | 1+ | ~0.5 |
| Uptime orchestrateur | 24/7 | manuel uniquement |

---

## ARCHITECTURE ACTUELLE

```
┌─────────────────────────────────────────────┐
│                    Mac M5 48GB               │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Ollama   │  │  Mem0     │  │  SiYuan   │  │
│  │ qwen3:14b │  │ :8050    │  │  :6806   │  │
│  │  :11434   │  └──────────┘  └──────────┘  │
│  └──────────┘                                │
│       ↕                                      │
│  ┌──────────────────────────────────────┐   │
│  │         Paperclip (Docker)            │   │
│  │  ┌──────┐  ┌──────┐  ┌──────┐       │   │
│  │  │ CEO  │→│ CTO  │→│ Lead │       │   │
│  │  │      │  │      │  │ Back │       │   │
│  │  └──────┘  └──────┘  └──────┘       │   │
│  │  ... 16 agents séquentiels ...       │   │
│  │  OpenCode CLI + adapter local        │   │
│  └──────────────────────────────────────┘   │
│       ↕                                      │
│  ┌──────────────────────────────────────┐   │
│  │      Orchestrateur (host bash)        │   │
│  │  agent-orchestrator.sh                │   │
│  │  post-run-logger.py                   │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  Serveur HP OMEN (via NetBird) :             │
│  Gitea, n8n, Twenty CRM, Cal.com,           │
│  Umami, BillionMail, Firecrawl, ntfy        │
└─────────────────────────────────────────────┘
```

---

## DÉCISIONS TECHNIQUES PRISES

1. **qwen3:14b pour tous** — compromis vitesse/intelligence, 0 swap VRAM
2. **ANNUAIRE scopé** — seulement 5 délégateurs, évite la délégation circulaire
3. **Pas de plugins dans Docker** — config séparée terminal vs agents
4. **Orchestrateur séquentiel** — 1 agent à la fois, priorité CEO > CTO > ...
5. **Logger post-run** — script Python, pas de LLM, Mem0 + SiYuan automatique
6. **SiYuan cookie auth** — loginAuth + cookie, pas Token header
7. **wakeOnAssignment = false** — pas de cascade automatique, l'orchestrateur gère
