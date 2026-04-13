# Ordre de deploiement des agents

## Pre-requis

1. Ollama installe avec les modeles necessaires
2. Paperclip running (docker compose up)
3. LiteLLM configure avec les modeles

## Phase 1 : Le fondateur

### 1. CEO
- **Creer manuellement** dans l'UI Paperclip
- C'est le seul agent cree a la main
- Tous les autres seront recrutes par le CEO ou le CTO
- **Permissions** : `canCreateAgents: true`
- **Premiere tache** : "Recrute un CTO pour gerer la stack technique"

## Phase 2 : La C-suite (recrutee par le CEO)

### 2. CTO
- Recrute par le CEO via l'API
- **Permissions** : `canCreateAgents: true`
- Premiere tache : "Fais un audit technique et propose une architecture"

### 3. CPO
- Recrute par le CEO via l'API
- **Permissions** : `canCreateAgents: false`
- Premiere tache : "Definis les specs produit du projet X"

### 4. CFO
- Recrute par le CEO via l'API
- **Permissions** : `canCreateAgents: false`
- Premiere tache : "Mets en place le suivi des couts"

## Phase 3 : L'equipe technique (recrutee par le CTO)

### 5. Lead Backend
- Recrute par le CTO
- Premiere tache : definie par le CTO selon l'architecture

### 6. Lead Frontend
- Recrute par le CTO
- Premiere tache : definie par le CTO selon l'architecture

### 7. DevOps
- Recrute par le CTO
- Premiere tache : "Dockerise le projet et configure la CI/CD"

## Phase 4 : Support (recrutes par le CTO selon les besoins)

### 8. QA Engineer
- Recrute quand le premier code est livre
- Premiere tache : "Ecris les tests pour la feature X"

### 9. Security Engineer
- Recrute avant la mise en prod
- Premiere tache : "Audite le code et l'infra"

### 10. Designer
- Recrute par le CPO ou CTO selon le besoin
- Premiere tache : "Cree les specs d'interface pour la feature X"

### 11. Researcher
- Recrute a la demande quand il faut evaluer une techno
- Premiere tache : "Compare les options pour le besoin X"

## Workflow type pour un nouveau projet

```
CEO recoit la demande
  │
  ├── CEO cree le CTO (si pas deja fait)
  ├── CEO cree le CPO (si pas deja fait)
  │
  ├── CEO assigne au CPO : "Specifier le projet"
  │     └── CPO livre les specs produit
  │
  ├── CEO assigne au CTO : "Architecturer et executer le projet"
  │     │
  │     ├── CTO definit l'architecture
  │     ├── CTO recrute Lead Backend + Lead Frontend + DevOps
  │     ├── CTO decompose en taches techniques
  │     ├── CTO assigne les taches aux devs
  │     │     ├── Lead Backend implemente le backend
  │     │     ├── Lead Frontend implemente le frontend
  │     │     └── DevOps configure l'infra
  │     │
  │     ├── CTO recrute QA quand le code est pret
  │     │     └── QA ecrit et execute les tests
  │     │
  │     ├── CTO recrute Security avant la prod
  │     │     └── Security audite le code
  │     │
  │     └── CTO reporte au CEO
  │
  └── CEO assigne au CFO : "Suivre les couts du projet"
        └── CFO monitore et rapporte
```

## Commande pour demarrer tout

Une fois le CEO configure dans l'UI :

1. Creer une issue dans Paperclip : **"Recrute ton equipe C-level : CTO, CPO, CFO"**
2. Assigner au CEO
3. Le CEO va recruter les 3 agents
4. Creer une issue : **"Nouveau projet : [description du projet]"**
5. Assigner au CEO
6. Le CEO va orchestrer toute la chaine
