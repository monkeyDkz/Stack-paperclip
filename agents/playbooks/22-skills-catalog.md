# 22 - Catalogue des Skills

> Catalogue centralise de toutes les competences du systeme multi-agents Paperclip.
> Chaque skill est identifie, categorise et attribue a un ou plusieurs agents.

---

## Table des matieres

1. [Format d'un skill](#format-dun-skill)
2. [Categories](#categories)
3. [Skills par agent](#skills-par-agent)
   - [CEO](#ceo-5-skills)
   - [CTO](#cto-10-skills)
   - [CPO](#cpo-6-skills)
   - [CFO](#cfo-5-skills)
   - [Lead Backend](#lead-backend-7-skills)
   - [Lead Frontend](#lead-frontend-8-skills)
   - [DevOps](#devops-8-skills)
   - [Security](#security-7-skills)
   - [QA](#qa-8-skills)
   - [Designer](#designer-7-skills)
   - [Researcher](#researcher-7-skills)
   - [Growth Lead](#growth-lead-6-skills)
   - [SEO Specialist](#seo-specialist-7-skills)
   - [Content Writer](#content-writer-6-skills)
   - [Data Analyst](#data-analyst-7-skills)
   - [Sales Automation](#sales-automation-7-skills)
4. [Matrice skills x agents](#matrice-skills-x-agents)
5. [Protocole de discovery](#protocole-de-discovery)
6. [Regles d'evolution des skills](#regles-devolution-des-skills)

---

## Format d'un skill

Chaque skill est documente selon le schema suivant :

| Champ | Description |
|---|---|
| `id` | Identifiant unique du skill (slug) |
| `nom` | Nom lisible du skill |
| `description` | Ce que le skill permet de faire (imperatif) |
| `categorie` | Une parmi : `code`, `architecture`, `produit`, `operations`, `securite`, `design`, `recherche`, `management`, `finance` |
| `agents` | Liste des agents possedant ce skill |
| `outils-requis` | Outils necessaires a l'execution |
| `niveau` | `primaire` (identite fondamentale de l'agent) ou `secondaire` (sur demande) |
| `input` | Donnees attendues en entree |
| `output` | Resultats produits |
| `exemple` | Scenario d'utilisation concret |

---

## Categories

| Categorie | Description | Nombre de skills |
|---|---|---|
| `code` | Developpement, tests, revue de code | 22 |
| `architecture` | Conception systeme, stack, decisions techniques | 6 |
| `produit` | Discovery, specifications, roadmap, feedback | 6 |
| `operations` | CI/CD, infra, monitoring, environnements | 7 |
| `securite` | Audit, dependances, auth, protection des donnees | 8 |
| `design` | UX, wireframes, design system, accessibilite | 8 |
| `recherche` | Veille, benchmarks, documentation, analyse | 7 |
| `management` | Recrutement, arbitrage, reporting, coordination | 7 |
| `finance` | Couts, budgets, ROI, audit financier | 5 |
| `seo` | Keyword research, audits on-page, SERP, technical SEO | 7 |
| `content` | Redaction articles, emails, landing pages, editorial | 6 |
| `analytics` | Funnel analysis, cohortes, anomalies, dashboards business | 7 |
| `sales` | Lead scoring, prospection, sequences, pipeline, win/loss | 7 |
| `growth` | Strategie growth, orchestration, experiences, audit funnel | 6 |

---

## Skills par agent

---

### CEO (5 skills)

#### `recrutement-agents`

| Champ | Valeur |
|---|---|
| **nom** | Recrutement d'agents |
| **description** | Creer des agents via l'API Paperclip, injecter le bloc ONBOARDING dans leur definition |
| **categorie** | `management` |
| **agents** | `ceo` |
| **outils-requis** | `paperclip` |
| **niveau** | `primaire` |
| **input** | Besoin identifie (role, responsabilites, skills attendus) |
| **output** | Agent cree et operationnel avec bloc ONBOARDING injecte |
| **exemple** | Le CEO identifie le besoin d'un agent QA. Il appelle l'API Paperclip pour creer l'agent, lui injecte le bloc ONBOARDING contenant les conventions du projet, les outils disponibles et les protocoles memoire. |

#### `vision-strategique`

| Champ | Valeur |
|---|---|
| **nom** | Vision strategique |
| **description** | Transformer des idees en plans d'execution, decomposer les taches et les assigner |
| **categorie** | `management` |
| **agents** | `ceo` |
| **outils-requis** | `paperclip`, `mem0` |
| **niveau** | `primaire` |
| **input** | Idee, objectif strategique ou demande utilisateur |
| **output** | Plan d'execution decompose en taches assignees aux C-levels |
| **exemple** | L'utilisateur demande "je veux une app de gestion de taches". Le CEO decompose en : discovery produit (CPO), architecture technique (CTO), estimation budgetaire (CFO), et cree un plan d'execution coordonne. |

#### `arbitrage-conflits`

| Champ | Valeur |
|---|---|
| **nom** | Arbitrage de conflits |
| **description** | Resoudre les conflits entre C-levels quand ils ne trouvent pas de consensus |
| **categorie** | `management` |
| **agents** | `ceo` |
| **outils-requis** | `mem0`, `paperclip` |
| **niveau** | `primaire` |
| **input** | Conflit identifie entre deux ou plusieurs agents C-level |
| **output** | Decision d'arbitrage enregistree comme Decision Record dans Mem0 |
| **exemple** | Le CTO veut utiliser Rust pour la performance, le CPO insiste sur TypeScript pour la vitesse de livraison. Le CEO tranche en faveur de TypeScript avec des modules critiques en Rust, et enregistre la decision. |

#### `knowledge-review-strategique`

| Champ | Valeur |
|---|---|
| **nom** | Revue strategique de la connaissance |
| **description** | Verifier les statistiques Mem0, deleguer la revue detaillee au CTO |
| **categorie** | `management` |
| **agents** | `ceo` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Declencheur periodique ou demande manuelle |
| **output** | Rapport de sante de la base de connaissances, delegation au CTO si action requise |
| **exemple** | Le CEO consulte les stats Mem0 (nombre de memories, agents actifs, derniere mise a jour). Il constate que le Researcher n'a pas alimente Chroma depuis 5 jours et demande au CTO d'investiguer. |

#### `memoire-strategique`

| Champ | Valeur |
|---|---|
| **nom** | Memoire strategique |
| **description** | Sauvegarder les decisions majeures comme Decision Records dans Mem0 |
| **categorie** | `management` |
| **agents** | `ceo` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Decision prise (contexte, options evaluees, choix final, justification) |
| **output** | Decision Record stocke dans Mem0 avec metadata (date, agents impactes, statut) |
| **exemple** | Apres avoir tranche pour une architecture microservices, le CEO enregistre le Decision Record : contexte (scalabilite requise), alternatives (monolithe, serverless), decision (microservices Docker), consequences (complexite accrue, meilleur scaling). |

---

### CTO (10 skills)

#### `architecture-systeme`

| Champ | Valeur |
|---|---|
| **nom** | Architecture systeme |
| **description** | Concevoir l'architecture du systeme : composants, flux de donnees, interfaces |
| **categorie** | `architecture` |
| **agents** | `cto` |
| **outils-requis** | `mem0`, `siyuan`, `chroma` |
| **niveau** | `primaire` |
| **input** | Besoins fonctionnels et non-fonctionnels du projet |
| **output** | Document d'architecture (composants, diagrammes, flux de donnees, choix technologiques justifies) |
| **exemple** | Le CPO fournit un PRD pour une plateforme e-commerce. Le CTO conçoit l'architecture : API Gateway, service catalogue, service commandes, service paiement, message queue pour les evenements, et documente le tout dans SiYuan. |

#### `gestion-stack-technique`

| Champ | Valeur |
|---|---|
| **nom** | Gestion du stack technique |
| **description** | Gerer et faire evoluer le stack technique du projet |
| **categorie** | `architecture` |
| **agents** | `cto` |
| **outils-requis** | `mem0`, `siyuan` |
| **niveau** | `primaire` |
| **input** | Stack actuel, contraintes, besoins d'evolution |
| **output** | Stack technique documente et versionne dans SiYuan |
| **exemple** | Le CTO evalue le passage de Express.js a Fastify pour le backend. Il consulte les benchmarks du Researcher, analyse l'impact sur l'equipe, et met a jour le document de stack technique dans SiYuan. |

#### `recrutement-technique`

| Champ | Valeur |
|---|---|
| **nom** | Recrutement technique |
| **description** | Recruter des agents techniques avec onboarding memoire complet |
| **categorie** | `management` |
| **agents** | `cto` |
| **outils-requis** | `paperclip`, `mem0` |
| **niveau** | `primaire` |
| **input** | Besoin technique identifie (role, skills, contexte projet) |
| **output** | Agent technique cree avec memoire initialisee (conventions, stack, patterns) |
| **exemple** | Le CTO recrute un Lead Frontend. Il cree l'agent via Paperclip, injecte le stack technique (React, Tailwind), les conventions de code, les patterns UI existants depuis Mem0 et Chroma. |

#### `code-review-standards`

| Champ | Valeur |
|---|---|
| **nom** | Revue de code et standards |
| **description** | Revoir le code produit et appliquer les standards de qualite |
| **categorie** | `code` |
| **agents** | `cto` |
| **outils-requis** | `mem0`, `chroma` |
| **niveau** | `primaire` |
| **input** | Code soumis pour revue, standards existants |
| **output** | Feedback structure (approbation, demandes de changement, suggestions) |
| **exemple** | Le Lead Backend soumet un nouveau service d'authentification. Le CTO verifie la conformite aux patterns etablis (Repository pattern), la gestion d'erreurs, le nommage, et valide ou demande des modifications. |

#### `knowledge-management`

| Champ | Valeur |
|---|---|
| **nom** | Gestion de la connaissance |
| **description** | Gerer les trois couches de connaissance : Mem0 (memoire), SiYuan (documentation), Chroma (embeddings) |
| **categorie** | `architecture` |
| **agents** | `cto`, `researcher` |
| **outils-requis** | `mem0`, `siyuan`, `chroma` |
| **niveau** | `primaire` |
| **input** | Etat des bases de connaissance, besoins de synchronisation |
| **output** | Bases de connaissance alignees, propres et a jour |
| **exemple** | Le CTO lance une revue hebdomadaire : verifie les memories obsoletes dans Mem0, s'assure que les pages SiYuan sont a jour, et que les embeddings Chroma refletent le code actuel. |

#### `decision-propagation`

| Champ | Valeur |
|---|---|
| **nom** | Propagation des decisions |
| **description** | Remplacer les decisions obsoletes et notifier les agents impactes |
| **categorie** | `architecture` |
| **agents** | `cto` |
| **outils-requis** | `mem0`, `n8n` |
| **niveau** | `primaire` |
| **input** | Nouvelle decision technique qui remplace une decision existante |
| **output** | Ancienne decision marquee comme superseded, agents impactes notifies |
| **exemple** | La decision de passer de REST a GraphQL est prise. Le CTO marque l'ancienne decision REST comme superseded dans Mem0, notifie le Lead Backend, le Lead Frontend et le QA via Paperclip. |

#### `cross-agent-status`

| Champ | Valeur |
|---|---|
| **nom** | Statut multi-agents |
| **description** | Verifier le statut et l'avancement de plusieurs agents simultanement |
| **categorie** | `management` |
| **agents** | `cto` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Liste d'agents ou de taches a verifier |
| **output** | Rapport de statut consolide (avancement, blocages, dependances) |
| **exemple** | Le CTO interroge Mem0 pour obtenir le statut du Lead Backend (API auth en cours), Lead Frontend (en attente de l'API), et DevOps (pipeline CI pret). Il identifie le blocage frontend et repriorise. |

#### `knowledge-review-periodique`

| Champ | Valeur |
|---|---|
| **nom** | Revue periodique de la connaissance |
| **description** | Revoir et archiver la connaissance obsolete periodiquement |
| **categorie** | `operations` |
| **agents** | `cto` |
| **outils-requis** | `mem0`, `siyuan` |
| **niveau** | `secondaire` |
| **input** | Calendrier de revue, seuils d'obsolescence |
| **output** | Memories archivees ou supprimees, documentation a jour |
| **exemple** | Lors de la revue mensuelle, le CTO identifie 15 memories liees a une version obsolete du framework. Il les archive dans SiYuan comme historique et les supprime de Mem0 pour garder la base propre. |

#### `resolution-conflits-techniques`

| Champ | Valeur |
|---|---|
| **nom** | Resolution de conflits techniques |
| **description** | Resoudre les desaccords techniques entre agents |
| **categorie** | `architecture` |
| **agents** | `cto` |
| **outils-requis** | `mem0`, `paperclip` |
| **niveau** | `primaire` |
| **input** | Conflit technique (arguments des deux parties, contexte) |
| **output** | Decision technique tranchee et documentee |
| **exemple** | Le Lead Backend veut PostgreSQL, le DevOps prefere MongoDB pour la simplicite de deploiement. Le CTO analyse les besoins (relations complexes, transactions ACID), tranche pour PostgreSQL et documente la decision. |

#### `reporting-ceo`

| Champ | Valeur |
|---|---|
| **nom** | Reporting au CEO |
| **description** | Produire des rapports d'avancement pour le CEO |
| **categorie** | `management` |
| **agents** | `cto` |
| **outils-requis** | `mem0`, `paperclip` |
| **niveau** | `secondaire` |
| **input** | Demande de rapport du CEO, donnees d'avancement |
| **output** | Rapport structure (avancement global, risques, decisions requises) |
| **exemple** | Le CEO demande un point d'avancement. Le CTO compile les statuts de tous les agents techniques, identifie un risque de retard sur l'API paiement, et envoie un rapport structure avec recommandations. |

---

### CPO (6 skills)

#### `product-discovery`

| Champ | Valeur |
|---|---|
| **nom** | Discovery produit |
| **description** | Identifier les besoins utilisateurs, creer des personas et cartographier les parcours |
| **categorie** | `produit` |
| **agents** | `cpo` |
| **outils-requis** | `mem0`, `siyuan` |
| **niveau** | `primaire` |
| **input** | Idee produit, marche cible, retours utilisateurs |
| **output** | Personas, user journeys, pain points identifies, opportunites |
| **exemple** | Pour une app de gestion de taches, le CPO cree 3 personas (developpeur solo, chef de projet, freelance), cartographie leurs parcours actuels et identifie les friction points principaux. |

#### `specification-produit`

| Champ | Valeur |
|---|---|
| **nom** | Specification produit |
| **description** | Rediger les PRD, user stories et criteres d'acceptation |
| **categorie** | `produit` |
| **agents** | `cpo` |
| **outils-requis** | `mem0`, `siyuan` |
| **niveau** | `primaire` |
| **input** | Resultats du discovery, priorites business |
| **output** | PRD complet, user stories avec criteres d'acceptation |
| **exemple** | Le CPO redige le PRD pour le module "Gestion des taches" : epic, 8 user stories (creer, editer, supprimer, assigner, filtrer, trier, archiver, exporter), chacune avec criteres d'acceptation et maquettes textuelles. |

#### `roadmap-planification`

| Champ | Valeur |
|---|---|
| **nom** | Roadmap et planification |
| **description** | Prioriser avec RICE/MoSCoW, gerer le backlog et planifier les iterations |
| **categorie** | `produit` |
| **agents** | `cpo` |
| **outils-requis** | `mem0`, `paperclip` |
| **niveau** | `primaire` |
| **input** | Liste de features, contraintes techniques, capacite equipe |
| **output** | Roadmap priorisee, backlog ordonne, plan de sprint |
| **exemple** | Le CPO applique le scoring RICE sur 20 features. L'authentification (score 85) et le CRUD taches (score 78) passent en sprint 1, le partage collaboratif (score 45) est reporte au sprint 3. |

#### `coordination-produit`

| Champ | Valeur |
|---|---|
| **nom** | Coordination produit |
| **description** | Transmettre les specs au CTO et les besoins UX au Designer |
| **categorie** | `produit` |
| **agents** | `cpo` |
| **outils-requis** | `paperclip` |
| **niveau** | `primaire` |
| **input** | PRD valide, user stories pretes |
| **output** | Specs transmises au CTO, briefs UX envoyes au Designer |
| **exemple** | Le PRD du module taches est pret. Le CPO envoie les specs techniques au CTO pour estimation et architecture, et le brief UX au Designer pour les wireframes des ecrans principaux. |

#### `analyse-feedback`

| Champ | Valeur |
|---|---|
| **nom** | Analyse de feedback |
| **description** | Analyser les KPIs et les retours pour iterer sur le produit |
| **categorie** | `produit` |
| **agents** | `cpo` |
| **outils-requis** | `mem0`, `n8n` |
| **niveau** | `secondaire` |
| **input** | Metriques d'usage, retours utilisateurs, bugs remontes |
| **output** | Rapport d'analyse, recommandations d'iterations, ajustements backlog |
| **exemple** | Les metriques montrent que 60% des utilisateurs abandonnent a l'ecran de creation de tache. Le CPO analyse, identifie un formulaire trop long, et cree une story pour simplifier en 3 champs essentiels. |

#### `memoire-produit`

| Champ | Valeur |
|---|---|
| **nom** | Memoire produit |
| **description** | Stocker les PRD, user stories et decisions produit dans la base de connaissances |
| **categorie** | `produit` |
| **agents** | `cpo` |
| **outils-requis** | `mem0`, `siyuan` |
| **niveau** | `primaire` |
| **input** | Documents produit finalises (PRD, stories, decisions) |
| **output** | Documents indexes dans Mem0 (recherche rapide) et SiYuan (documentation structuree) |
| **exemple** | Le PRD v2 du module taches est finalise. Le CPO le sauvegarde dans SiYuan sous `/product/prd/taches-v2`, cree une memory Mem0 avec les metadata (version, statut, date) pour retrouver rapidement le document. |

---

### CFO (5 skills)

#### `suivi-couts`

| Champ | Valeur |
|---|---|
| **nom** | Suivi des couts |
| **description** | Suivre les couts en tokens, appels API et budgets par agent |
| **categorie** | `finance` |
| **agents** | `cfo` |
| **outils-requis** | `paperclip`, `mem0` |
| **niveau** | `primaire` |
| **input** | Logs d'utilisation des APIs, tarifs des modeles LLM |
| **output** | Tableau de bord des couts par agent, par outil, par periode |
| **exemple** | Le CFO compile les couts de la semaine : CTO (12k tokens, $0.35), Lead Backend (45k tokens, $1.20), Researcher (80k tokens, $2.10). Il identifie que le Researcher depasse son budget et alerte le CEO. |

#### `budget-planification`

| Champ | Valeur |
|---|---|
| **nom** | Planification budgetaire |
| **description** | Planifier les budgets pour chaque agent et chaque projet |
| **categorie** | `finance` |
| **agents** | `cfo` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Historique de couts, roadmap, projections d'usage |
| **output** | Budget previsionnel par agent et par sprint |
| **exemple** | Pour le sprint 2, le CFO alloue : Lead Backend $5 (API complexe), Lead Frontend $3 (UI standard), QA $2 (tests), DevOps $1 (pipeline). Budget total sprint : $11. |

#### `roi-analyse`

| Champ | Valeur |
|---|---|
| **nom** | Analyse ROI |
| **description** | Analyser le rapport cout/valeur des agents et des features |
| **categorie** | `finance` |
| **agents** | `cfo` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Couts reels, valeur livree (features completees, qualite) |
| **output** | Rapport ROI avec recommandations d'optimisation |
| **exemple** | Le CFO analyse que le Lead Backend a coute $8 pour livrer 3 endpoints critiques (haute valeur), tandis que le Researcher a coute $6 pour une veille sans impact immediat. Il recommande de reduire la frequence de veille. |

#### `audit-financier`

| Champ | Valeur |
|---|---|
| **nom** | Audit financier |
| **description** | Auditer les logs, permissions et detecter les anomalies financieres |
| **categorie** | `finance` |
| **agents** | `cfo` |
| **outils-requis** | `mem0`, `paperclip` |
| **niveau** | `secondaire` |
| **input** | Logs d'appels API, permissions des agents, seuils d'alerte |
| **output** | Rapport d'audit (anomalies, recommandations, alertes) |
| **exemple** | L'audit revele que l'agent Security a fait 200 appels API en 1 heure (normal : 30). Le CFO investigue, decouvre une boucle dans un audit automatise, et alerte le CTO pour correction. |

#### `memoire-financiere`

| Champ | Valeur |
|---|---|
| **nom** | Memoire financiere |
| **description** | Sauvegarder les rapports financiers et les alertes dans la base de connaissances |
| **categorie** | `finance` |
| **agents** | `cfo` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Rapports de couts, budgets, audits, alertes |
| **output** | Historique financier indexe dans Mem0 |
| **exemple** | Le CFO enregistre le rapport mensuel dans Mem0 : cout total $45, budget respecte a 92%, alerte sur le depassement du Researcher, tendance a la baisse des couts backend grace au caching. |

---

### Lead Backend (7 skills)

#### `conception-api`

| Champ | Valeur |
|---|---|
| **nom** | Conception d'API |
| **description** | Concevoir des APIs REST/GraphQL avec pagination, authentification et versioning |
| **categorie** | `code` |
| **agents** | `lead-backend` |
| **outils-requis** | `mem0`, `siyuan`, `chroma` |
| **niveau** | `primaire` |
| **input** | Specs fonctionnelles (PRD, user stories), contraintes techniques |
| **output** | Specification API (endpoints, schemas, auth, pagination, versioning) |
| **exemple** | Le Lead Backend conçoit l'API taches : `POST /api/v1/tasks`, `GET /api/v1/tasks?page=1&limit=20&sort=created_at`, `PATCH /api/v1/tasks/:id`. Auth par JWT Bearer, pagination cursor-based, reponses JSON:API. |

#### `base-de-donnees`

| Champ | Valeur |
|---|---|
| **nom** | Base de donnees |
| **description** | Concevoir les schemas, migrations, seeds et gerer les bases SQL/NoSQL |
| **categorie** | `code` |
| **agents** | `lead-backend` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Modele de donnees requis, relations, contraintes |
| **output** | Schemas, fichiers de migration, seeds de donnees de test |
| **exemple** | Le Lead Backend cree le schema pour les taches : table `tasks` (id, title, description, status, assignee_id, created_at, updated_at), migration avec index sur status et assignee_id, seeds pour 50 taches de test. |

#### `logique-metier`

| Champ | Valeur |
|---|---|
| **nom** | Logique metier |
| **description** | Implementer les services, controllers et patterns (Repository, Service, Factory) |
| **categorie** | `code` |
| **agents** | `lead-backend` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Specs API, schemas DB, regles metier |
| **output** | Code structure : services, controllers, repositories, validators |
| **exemple** | Le Lead Backend implemente le service `TaskService` avec les methodes `create()`, `update()`, `assignTo()`. Il utilise le pattern Repository pour l'acces DB et le pattern Factory pour la creation de taches avec valeurs par defaut. |

#### `integration-backend`

| Champ | Valeur |
|---|---|
| **nom** | Integration backend |
| **description** | Integrer des APIs tierces, webhooks, queues de messages et jobs asynchrones |
| **categorie** | `code` |
| **agents** | `lead-backend` |
| **outils-requis** | `mem0`, `n8n` |
| **niveau** | `primaire` |
| **input** | Documentation API tierce, besoins d'integration |
| **output** | Connecteurs, handlers de webhooks, consumers de queues, jobs planifies |
| **exemple** | Le Lead Backend integre l'API Stripe pour les paiements : cree un service `PaymentService`, configure les webhooks pour `payment_intent.succeeded` et `payment_intent.failed`, et un job cron pour la reconciliation quotidienne. |

#### `testing-backend`

| Champ | Valeur |
|---|---|
| **nom** | Tests backend |
| **description** | Ecrire des tests unitaires et d'integration, mocking, viser 80%+ de couverture |
| **categorie** | `code` |
| **agents** | `lead-backend`, `qa` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Code a tester, specs fonctionnelles, cas limites |
| **output** | Suite de tests (unitaires + integration), rapport de couverture |
| **exemple** | Le Lead Backend ecrit les tests du `TaskService` : 12 tests unitaires (creation valide, validation echec, assignation, transition de statut), 5 tests d'integration (CRUD complet via API, auth, pagination). Couverture : 87%. |

#### `performance-backend`

| Champ | Valeur |
|---|---|
| **nom** | Performance backend |
| **description** | Optimiser les performances : caching Redis, rate limiting, compression |
| **categorie** | `code` |
| **agents** | `lead-backend` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Metriques de performance, goulots d'etranglement identifies |
| **output** | Optimisations implementees (cache, rate limit, compression, requetes optimisees) |
| **exemple** | Le endpoint `GET /tasks` repond en 800ms. Le Lead Backend ajoute un cache Redis (TTL 60s) sur la liste, optimise la requete SQL (index compose), active la compression gzip. Temps de reponse : 120ms. |

#### `memoire-backend`

| Champ | Valeur |
|---|---|
| **nom** | Memoire backend |
| **description** | Sauvegarder les patterns, bugs resolus et solutions dans la base de connaissances et indexer dans Chroma |
| **categorie** | `code` |
| **agents** | `lead-backend` |
| **outils-requis** | `mem0`, `chroma` |
| **niveau** | `primaire` |
| **input** | Pattern decouvert, bug resolu, solution technique |
| **output** | Memory dans Mem0 + embedding dans Chroma pour recherche semantique |
| **exemple** | Le Lead Backend resout un bug de deadlock sur les transactions concurrentes. Il enregistre le pattern "optimistic locking pour les mises a jour concurrentes de taches" dans Mem0 et l'indexe dans Chroma. |

---

### Lead Frontend (8 skills)

#### `architecture-frontend`

| Champ | Valeur |
|---|---|
| **nom** | Architecture frontend |
| **description** | Concevoir l'architecture frontend : framework, routing, state management |
| **categorie** | `code` |
| **agents** | `lead-frontend` |
| **outils-requis** | `mem0`, `chroma` |
| **niveau** | `primaire` |
| **input** | Specs produit, contraintes techniques, choix de framework |
| **output** | Architecture frontend documentee (structure dossiers, routing, state, conventions) |
| **exemple** | Le Lead Frontend conçoit l'architecture React : structure feature-based (`/features/tasks/`, `/features/auth/`), React Router v6, Zustand pour le state global, Tanstack Query pour le cache serveur. |

#### `composants-ui`

| Champ | Valeur |
|---|---|
| **nom** | Composants UI |
| **description** | Creer des composants reutilisables, accessibles, conformes au design system |
| **categorie** | `code` |
| **agents** | `lead-frontend`, `designer` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Specs du design system, maquettes, criteres d'accessibilite |
| **output** | Composants React/Vue/Svelte documentes, accessibles, avec stories Storybook |
| **exemple** | Le Lead Frontend cree le composant `<TaskCard>` : affiche titre, statut, assignee, date. Props typees avec TypeScript, etats (default, hover, loading, error), accessible (role, aria-label), story Storybook. |

#### `integration-api-frontend`

| Champ | Valeur |
|---|---|
| **nom** | Integration API frontend |
| **description** | Integrer les APIs avec Tanstack Query/SWR, gerer le cache client et les websockets |
| **categorie** | `code` |
| **agents** | `lead-frontend` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Specification API, schemas de donnees |
| **output** | Hooks de requetes, gestion du cache, handlers websocket |
| **exemple** | Le Lead Frontend cree `useTasksQuery()` avec Tanstack Query : fetch pagine, invalidation automatique apres mutation, optimistic updates sur le drag-and-drop, websocket pour les mises a jour temps reel. |

#### `styling-frontend`

| Champ | Valeur |
|---|---|
| **nom** | Styling frontend |
| **description** | Implementer le styling avec Tailwind CSS, responsive, dark mode et animations |
| **categorie** | `code` |
| **agents** | `lead-frontend` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Tokens du design system, maquettes, breakpoints |
| **output** | Styles implementes, responsive, dark mode, animations fluides |
| **exemple** | Le Lead Frontend style le `<TaskBoard>` : grid responsive (1 col mobile, 2 tablette, 4 desktop), dark mode via `dark:` prefix Tailwind, animation de drag avec `framer-motion`, transitions douces sur les changements de statut. |

#### `performance-frontend`

| Champ | Valeur |
|---|---|
| **nom** | Performance frontend |
| **description** | Optimiser les performances : lazy loading, Core Web Vitals, SSR/SSG |
| **categorie** | `code` |
| **agents** | `lead-frontend` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Metriques Core Web Vitals, rapport Lighthouse, profiling |
| **output** | Optimisations (code splitting, lazy loading, prefetch, SSR/SSG) |
| **exemple** | Le LCP est a 3.2s (objectif < 2.5s). Le Lead Frontend applique : lazy loading des routes secondaires, preload des fonts critiques, SSR pour la page d'accueil, image optimization avec next/image. LCP final : 1.8s. |

#### `testing-frontend`

| Champ | Valeur |
|---|---|
| **nom** | Tests frontend |
| **description** | Ecrire des tests avec Vitest, testing-library, Playwright et axe-core |
| **categorie** | `code` |
| **agents** | `lead-frontend`, `qa` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Composants et pages a tester, criteres d'acceptation |
| **output** | Tests unitaires (Vitest), tests de composants (testing-library), tests E2E (Playwright), tests a11y (axe-core) |
| **exemple** | Le Lead Frontend teste le `<TaskCard>` : 5 tests unitaires (rendu, props, etats), 3 tests d'interaction (click, hover, drag), 1 test Playwright (workflow complet creation-edition), 1 test axe-core (zero violation). |

#### `accessibilite`

| Champ | Valeur |
|---|---|
| **nom** | Accessibilite |
| **description** | Garantir l'accessibilite : HTML semantique, ARIA, navigation clavier, lecteur d'ecran |
| **categorie** | `design` |
| **agents** | `lead-frontend`, `designer` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Composants UI, criteres WCAG 2.1 AA |
| **output** | Composants accessibles, rapport d'audit a11y |
| **exemple** | Le Lead Frontend audite le `<TaskBoard>` : ajoute `role="list"` sur les colonnes, `aria-grabbed` sur les cartes draggables, focus trap dans les modales, annonces live region pour les mises a jour asynchrones. |

#### `memoire-frontend`

| Champ | Valeur |
|---|---|
| **nom** | Memoire frontend |
| **description** | Sauvegarder les patterns UI et bugs resolus dans la base de connaissances |
| **categorie** | `code` |
| **agents** | `lead-frontend` |
| **outils-requis** | `mem0`, `chroma` |
| **niveau** | `primaire` |
| **input** | Pattern UI decouvert, bug resolu, composant reutilisable |
| **output** | Memory dans Mem0 + embedding dans Chroma |
| **exemple** | Le Lead Frontend documente le pattern "optimistic update avec rollback sur erreur pour le drag-and-drop de taches" dans Mem0 et l'indexe dans Chroma pour que le QA puisse retrouver les cas de test associes. |

---

### DevOps (8 skills)

#### `containerisation`

| Champ | Valeur |
|---|---|
| **nom** | Containerisation |
| **description** | Creer des images Docker multi-stage, optimiser les layers, gerer les registries |
| **categorie** | `operations` |
| **agents** | `devops` |
| **outils-requis** | `mem0`, `n8n` |
| **niveau** | `primaire` |
| **input** | Application a containeriser, contraintes de taille/performance |
| **output** | Dockerfile optimise, image publiee dans le registry |
| **exemple** | Le DevOps cree un Dockerfile multi-stage pour le backend Node.js : stage 1 (build avec devDependencies), stage 2 (production, Alpine, node_modules pruned). Image finale : 180MB au lieu de 1.2GB. |

#### `ci-cd`

| Champ | Valeur |
|---|---|
| **nom** | CI/CD |
| **description** | Configurer les pipelines GitHub Actions : lint, test, build, deploy, rollback |
| **categorie** | `operations` |
| **agents** | `devops` |
| **outils-requis** | `n8n`, `mem0` |
| **niveau** | `primaire` |
| **input** | Stack technique, contraintes de deploiement, environnements cibles |
| **output** | Pipeline CI/CD complet avec stages, caches, rollback automatique |
| **exemple** | Le DevOps configure GitHub Actions : lint (ESLint + Prettier), tests (Vitest + Playwright), build Docker, push registry, deploy staging (auto), deploy prod (manual approval), rollback si healthcheck echoue. |

#### `infrastructure-as-code`

| Champ | Valeur |
|---|---|
| **nom** | Infrastructure as Code |
| **description** | Gerer l'infrastructure avec Docker Compose, provisioning et gestion des environnements |
| **categorie** | `operations` |
| **agents** | `devops` |
| **outils-requis** | `mem0`, `n8n` |
| **niveau** | `primaire` |
| **input** | Architecture cible, services requis, contraintes reseau |
| **output** | Fichiers Docker Compose, scripts de provisioning, configs d'environnement |
| **exemple** | Le DevOps cree le `docker-compose.yml` : backend (3 replicas), PostgreSQL (volume persistant), Redis (cache), Nginx (reverse proxy), Prometheus + Grafana (monitoring). Variables d'env via `.env` par environnement. |

#### `monitoring-logging`

| Champ | Valeur |
|---|---|
| **nom** | Monitoring et logging |
| **description** | Configurer les health checks, logs JSON structures et systeme d'alerting |
| **categorie** | `operations` |
| **agents** | `devops` |
| **outils-requis** | `mem0`, `n8n` |
| **niveau** | `primaire` |
| **input** | Services a monitorer, seuils d'alerte, format de logs souhaite |
| **output** | Health checks, logging structure, dashboards, alertes configurees |
| **exemple** | Le DevOps configure : health check `/health` sur chaque service (DB, Redis, API), logs JSON (timestamp, level, service, requestId, message), alerte n8n si le taux d'erreur 5xx depasse 1% en 5 minutes. |

#### `gestion-environnements`

| Champ | Valeur |
|---|---|
| **nom** | Gestion des environnements |
| **description** | Gerer les environnements dev, staging et production |
| **categorie** | `operations` |
| **agents** | `devops` |
| **outils-requis** | `n8n`, `mem0` |
| **niveau** | `primaire` |
| **input** | Besoins par environnement, contraintes d'isolation |
| **output** | Environnements configures et isoles (dev, staging, prod) |
| **exemple** | Le DevOps configure 3 environnements : dev (hot reload, debug, DB locale), staging (miroir prod, donnees anonymisees, deploy auto sur merge), prod (replicas, backups, SSL, monitoring). |

#### `securite-infra`

| Champ | Valeur |
|---|---|
| **nom** | Securite infrastructure |
| **description** | Gerer les secrets, firewalls, SSL/TLS et sauvegardes |
| **categorie** | `securite` |
| **agents** | `devops`, `security` |
| **outils-requis** | `mem0`, `n8n` |
| **niveau** | `primaire` |
| **input** | Secrets a gerer, politique de securite, certificats |
| **output** | Secrets chiffres, firewall configure, SSL/TLS actif, backups planifies |
| **exemple** | Le DevOps configure : secrets via Docker secrets (pas de .env en prod), firewall (seuls ports 80/443 exposes), Let's Encrypt pour SSL auto-renew, backup PostgreSQL quotidien chiffre vers S3. |

#### `performance-infra`

| Champ | Valeur |
|---|---|
| **nom** | Performance infrastructure |
| **description** | Optimiser avec reverse proxy, load balancing et CDN |
| **categorie** | `operations` |
| **agents** | `devops` |
| **outils-requis** | `mem0`, `n8n` |
| **niveau** | `secondaire` |
| **input** | Metriques de charge, goulots identifies, SLO/SLA |
| **output** | Configuration optimisee (Nginx, load balancer, CDN, compression) |
| **exemple** | Le DevOps configure Nginx : gzip on, static files cache 1 an, load balancing round-robin sur 3 instances backend, rate limiting 100 req/min par IP, CDN Cloudflare pour les assets statiques. |

#### `memoire-devops`

| Champ | Valeur |
|---|---|
| **nom** | Memoire DevOps |
| **description** | Sauvegarder les configurations, incidents et runbooks dans la base de connaissances |
| **categorie** | `operations` |
| **agents** | `devops` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Configuration deployee, incident resolu, procedure creee |
| **output** | Memory dans Mem0 (configs, incidents, runbooks) |
| **exemple** | Apres un incident de saturation memoire Redis, le DevOps enregistre dans Mem0 : cause (pas de maxmemory configure), resolution (maxmemory 256mb + policy allkeys-lru), runbook (etapes de diagnostic et resolution). |

---

### Security (7 skills)

#### `audit-code`

| Champ | Valeur |
|---|---|
| **nom** | Audit de code |
| **description** | Auditer le code selon l'OWASP Top 10 : injections, secrets hardcodes, vulnerabilites |
| **categorie** | `securite` |
| **agents** | `security` |
| **outils-requis** | `mem0`, `chroma` |
| **niveau** | `primaire` |
| **input** | Code source a auditer, regles OWASP |
| **output** | Rapport d'audit (vulnerabilites, severite, remediations) |
| **exemple** | L'agent Security audite le service d'authentification : detecte une injection SQL dans le endpoint de login (parametres non sanitises), un secret API Stripe hardcode dans le code, et une faille XSS dans le champ commentaire. |

#### `securite-dependances`

| Champ | Valeur |
|---|---|
| **nom** | Securite des dependances |
| **description** | Auditer les dependances : npm audit, CVE, licences incompatibles |
| **categorie** | `securite` |
| **agents** | `security` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Fichiers de dependances (package.json, requirements.txt) |
| **output** | Rapport de vulnerabilites, mises a jour recommandees, alertes licences |
| **exemple** | L'audit revele : 3 CVE critiques dans `lodash@4.17.20` (prototype pollution), 1 CVE haute dans `express@4.17.1`, licence GPL dans une dependance (incompatible avec le projet MIT). Remediations proposees. |

#### `securite-infrastructure`

| Champ | Valeur |
|---|---|
| **nom** | Securite infrastructure |
| **description** | Auditer la securite Docker, reseau et TLS |
| **categorie** | `securite` |
| **agents** | `security`, `devops` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Configuration Docker, reseau, certificats |
| **output** | Rapport de securite infra (failles, remediations, score) |
| **exemple** | L'audit infra revele : containers tournant en root (risque d'escalade), ports PostgreSQL exposes publiquement, certificat TLS expirant dans 5 jours. Remediations : user non-root, network Docker interne, renouvellement auto. |

#### `auth-autorisations`

| Champ | Valeur |
|---|---|
| **nom** | Authentification et autorisations |
| **description** | Concevoir et auditer les mecanismes JWT, OAuth2, RBAC, CSRF |
| **categorie** | `securite` |
| **agents** | `security` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Implementation auth existante, besoins d'autorisation |
| **output** | Specs auth securisees, audit de l'implementation existante |
| **exemple** | L'agent Security audite l'auth : JWT sans expiration (risque de vol de token), pas de refresh token rotation, CSRF non protege sur les formulaires. Il propose : JWT 15min + refresh 7j avec rotation, SameSite cookie, CSRF token. |

#### `protection-donnees`

| Champ | Valeur |
|---|---|
| **nom** | Protection des donnees |
| **description** | Garantir le chiffrement, la gestion des PII et les sauvegardes securisees |
| **categorie** | `securite` |
| **agents** | `security` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Modele de donnees, flux de donnees, reglementation applicable |
| **output** | Politique de protection des donnees, chiffrement, anonymisation |
| **exemple** | L'agent Security identifie des PII (email, nom, adresse) stockees en clair. Il recommande : chiffrement AES-256 pour les PII au repos, TLS 1.3 en transit, anonymisation pour l'environnement staging, droit a l'effacement implemente. |

#### `reporting-securite`

| Champ | Valeur |
|---|---|
| **nom** | Reporting securite |
| **description** | Produire des rapports de securite classes par severite avec plan de remediation |
| **categorie** | `securite` |
| **agents** | `security` |
| **outils-requis** | `mem0`, `siyuan` |
| **niveau** | `secondaire` |
| **input** | Resultats d'audits, vulnerabilites detectees |
| **output** | Rapport structure (classification CVSS, priorites, plan de remediation) |
| **exemple** | Rapport mensuel : 2 critiques (injection SQL, secret expose), 5 hautes (dependances obsoletes), 12 moyennes (headers manquants). Plan : critiques a corriger sous 24h, hautes sous 1 semaine, moyennes au prochain sprint. |

#### `memoire-securite`

| Champ | Valeur |
|---|---|
| **nom** | Memoire securite |
| **description** | Sauvegarder les vulnerabilites, patterns de securite et audits dans la base de connaissances |
| **categorie** | `securite` |
| **agents** | `security` |
| **outils-requis** | `mem0`, `chroma` |
| **niveau** | `primaire` |
| **input** | Vulnerabilite resolue, pattern de securite, rapport d'audit |
| **output** | Memory dans Mem0 + embedding dans Chroma pour recherche semantique |
| **exemple** | Apres correction de l'injection SQL, l'agent Security enregistre le pattern "prepared statements obligatoires pour toutes les requetes SQL" dans Mem0, avec le code corrige indexe dans Chroma. |

---

### QA (8 skills)

#### `test-planning`

| Champ | Valeur |
|---|---|
| **nom** | Planification de tests |
| **description** | Definir les scenarios de test, les cas limites et prioriser l'effort de test |
| **categorie** | `code` |
| **agents** | `qa` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Specs fonctionnelles, criteres d'acceptation, risques identifies |
| **output** | Plan de test (scenarios, cas limites, priorites, estimation effort) |
| **exemple** | Le QA planifie les tests du module taches : 15 scenarios nominaux, 8 cas limites (titre vide, titre 500 chars, assignation a un user supprime, creation concurrente), priorite P1 pour le CRUD, P2 pour le drag-and-drop. |

#### `tests-unitaires`

| Champ | Valeur |
|---|---|
| **nom** | Tests unitaires |
| **description** | Ecrire des tests unitaires avec Vitest, Jest ou Pytest, mocking et couverture |
| **categorie** | `code` |
| **agents** | `qa`, `lead-backend`, `lead-frontend` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Code a tester, specs, cas limites identifies |
| **output** | Suite de tests unitaires, rapport de couverture |
| **exemple** | Le QA ecrit 25 tests unitaires pour le `TaskService` : tests des validations (titre requis, longueur max), transitions de statut (todo->in_progress->done, pas de retour arriere), mocking du repository et du cache Redis. |

#### `tests-integration`

| Champ | Valeur |
|---|---|
| **nom** | Tests d'integration |
| **description** | Tester les workflows complets et les endpoints |
| **categorie** | `code` |
| **agents** | `qa` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Specification API, workflows a tester |
| **output** | Suite de tests d'integration, resultats |
| **exemple** | Le QA teste le workflow complet : creation d'un user, login, creation d'une tache, assignation, changement de statut, verification en base. Chaque test utilise une DB de test isolee, nettoyee apres execution. |

#### `tests-e2e`

| Champ | Valeur |
|---|---|
| **nom** | Tests end-to-end |
| **description** | Ecrire des tests E2E avec Playwright ou Cypress |
| **categorie** | `code` |
| **agents** | `qa` |
| **outils-requis** | `mem0`, `n8n` |
| **niveau** | `primaire` |
| **input** | Parcours utilisateur a tester, environnement de test |
| **output** | Suite de tests E2E, captures d'ecran, traces |
| **exemple** | Le QA ecrit un test Playwright : ouvrir l'app, se connecter, creer une tache "Deploy v2", la drag-drop vers "En cours", verifier la notification, se deconnecter. Test execute sur Chrome, Firefox et Safari. |

#### `code-review-qualite`

| Champ | Valeur |
|---|---|
| **nom** | Revue de code qualite |
| **description** | Revoir le code pour la lisibilite, la gestion d'erreurs et le respect des standards |
| **categorie** | `code` |
| **agents** | `qa`, `cto` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Code soumis pour revue |
| **output** | Feedback (lisibilite, erreurs, conformite standards, suggestions) |
| **exemple** | Le QA releve : fonction `handleStuff()` mal nommee (devrait etre `updateTaskStatus()`), catch vide qui avale les erreurs, constantes magiques (remplacer `3` par `MAX_RETRY_ATTEMPTS`), absence de JSDoc sur les fonctions publiques. |

#### `regression-testing`

| Champ | Valeur |
|---|---|
| **nom** | Tests de regression |
| **description** | Ecrire et maintenir des tests de regression pour prevenir les regressions |
| **categorie** | `code` |
| **agents** | `qa` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Bug corrige, code modifie |
| **output** | Test de regression specifique au bug, ajoute a la suite CI |
| **exemple** | Le bug "les taches disparaissent apres changement de filtre" est corrige. Le QA ajoute un test de regression : appliquer le filtre "En cours", revenir a "Toutes", verifier que toutes les taches sont presentes. Ce test tourne a chaque CI. |

#### `reporting-qualite`

| Champ | Valeur |
|---|---|
| **nom** | Reporting qualite |
| **description** | Produire des rapports de couverture, bugs et tendances qualite |
| **categorie** | `code` |
| **agents** | `qa` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Resultats de tests, metriques, historique |
| **output** | Rapport qualite (couverture, bugs ouverts/fermes, tendances) |
| **exemple** | Rapport sprint 3 : couverture 84% (+3%), 12 bugs trouves (3 critiques, 5 majeurs, 4 mineurs), 10 corriges, tendance a la baisse des bugs de regression grace aux tests automatises. |

#### `memoire-qa`

| Champ | Valeur |
|---|---|
| **nom** | Memoire QA |
| **description** | Sauvegarder les bugs, regressions et cas limites dans la base de connaissances |
| **categorie** | `code` |
| **agents** | `qa` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Bug documente, regression identifiee, cas limite decouvert |
| **output** | Memory dans Mem0 pour reference future |
| **exemple** | Le QA enregistre dans Mem0 : "Bug : le drag-and-drop echoue silencieusement si le websocket est deconnecte. Cause : pas de fallback HTTP. Resolution : mutation optimiste + sync au reconnect. Regression test ajoute." |

---

### Designer (7 skills)

#### `ux-research`

| Champ | Valeur |
|---|---|
| **nom** | Recherche UX |
| **description** | Creer des personas, cartographier les parcours utilisateurs et identifier les pain points |
| **categorie** | `design` |
| **agents** | `designer` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Brief produit, donnees utilisateurs, retours |
| **output** | Personas, user journey maps, pain points, opportunites |
| **exemple** | Le Designer cree le persona "Marie, chef de projet, 35 ans" : utilise 3 outils differents, frustree par la dispersion, veut une vue unifiee. Journey map : decouverte -> inscription -> premier projet -> invite equipe -> usage quotidien. Pain point : onboarding trop long. |

#### `wireframing-textuel`

| Champ | Valeur |
|---|---|
| **nom** | Wireframing textuel |
| **description** | Creer des wireframes en ASCII art et descriptions structurees |
| **categorie** | `design` |
| **agents** | `designer` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Specs ecran, composants requis, flux utilisateur |
| **output** | Wireframes ASCII, descriptions structurees des ecrans |
| **exemple** | Le Designer cree le wireframe du tableau de taches en ASCII : header (logo, search, avatar), sidebar (navigation, filtres), zone principale (colonnes Kanban : Todo, In Progress, Done), chaque colonne avec des cartes empilees. |

#### `design-system`

| Champ | Valeur |
|---|---|
| **nom** | Design system |
| **description** | Definir les tokens CSS, typographie, espacements et composants du design system |
| **categorie** | `design` |
| **agents** | `designer` |
| **outils-requis** | `mem0`, `siyuan` |
| **niveau** | `primaire` |
| **input** | Identite visuelle, besoins du produit |
| **output** | Design tokens (couleurs, typo, spacing), composants documentes |
| **exemple** | Le Designer definit : palette (primary-500 #3B82F6, gray-900 #111827), typo (Inter, tailles 12/14/16/20/24/32), spacing (4/8/12/16/24/32/48px), radius (4/8/12px), shadows (sm/md/lg). Documente dans SiYuan. |

#### `specifications-interface`

| Champ | Valeur |
|---|---|
| **nom** | Specifications d'interface |
| **description** | Specifier les ecrans, composants, etats et interactions |
| **categorie** | `design` |
| **agents** | `designer` |
| **outils-requis** | `mem0`, `siyuan` |
| **niveau** | `primaire` |
| **input** | Wireframes valides, design system, specs fonctionnelles |
| **output** | Specs detaillees par ecran (composants, etats, interactions, responsive) |
| **exemple** | Spec de la TaskCard : etats (default, hover avec shadow-md, active avec border-primary, loading avec skeleton, error avec border-red), interactions (click ouvre le detail, long press active le drag, swipe gauche archive sur mobile). |

#### `accessibilite-design`

| Champ | Valeur |
|---|---|
| **nom** | Accessibilite design |
| **description** | Garantir les contrastes, les roles ARIA, la navigation clavier et la conformite WCAG 2.1 AA |
| **categorie** | `design` |
| **agents** | `designer`, `lead-frontend` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Design system, composants, criteres WCAG |
| **output** | Audit a11y du design, corrections, guidelines |
| **exemple** | Le Designer audite la palette : le gris texte (#9CA3AF) sur fond blanc a un ratio de 2.9:1 (insuffisant WCAG AA 4.5:1). Il corrige vers #6B7280 (ratio 5.2:1) et met a jour le design system. |

#### `review-design`

| Champ | Valeur |
|---|---|
| **nom** | Revue de design |
| **description** | Verifier la conformite au design system, la coherence et fournir du feedback |
| **categorie** | `design` |
| **agents** | `designer` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Implementation UI a revoir, design system de reference |
| **output** | Feedback (conformite, incoherences, suggestions) |
| **exemple** | Le Designer revoit l'implementation du Lead Frontend : le bouton primaire utilise `rounded-lg` au lieu de `rounded-md` (token du design system), l'espacement entre les cartes est 16px au lieu de 12px. 2 corrections demandees. |

#### `memoire-design`

| Champ | Valeur |
|---|---|
| **nom** | Memoire design |
| **description** | Sauvegarder les decisions de design, tokens et composants dans la base de connaissances |
| **categorie** | `design` |
| **agents** | `designer` |
| **outils-requis** | `mem0`, `siyuan` |
| **niveau** | `primaire` |
| **input** | Decision de design, mise a jour token, nouveau composant |
| **output** | Documentation dans SiYuan + memory dans Mem0 |
| **exemple** | Le Designer documente la decision de passer de 4 a 3 colonnes sur tablette pour le Kanban board. Il met a jour le document responsive dans SiYuan et cree une memory Mem0 pour tracer la decision et sa justification. |

---

### Researcher (7 skills)

#### `veille-technologique`

| Champ | Valeur |
|---|---|
| **nom** | Veille technologique |
| **description** | Evaluer les technologies emergentes, tendances et maturite |
| **categorie** | `recherche` |
| **agents** | `researcher` |
| **outils-requis** | `mem0`, `n8n`, `chroma` |
| **niveau** | `primaire` |
| **input** | Domaine de veille, stack actuel, besoins identifies |
| **output** | Rapport de veille (technologies evaluees, maturite, recommandations) |
| **exemple** | Le Researcher evalue Bun comme alternative a Node.js : performance (2x plus rapide sur les benchmarks), maturite (v1.0, ecosysteme en croissance), risques (compatibilite npm partielle). Recommandation : adopter pour les outils internes, attendre pour la production. |

#### `recherche-solutions`

| Champ | Valeur |
|---|---|
| **nom** | Recherche de solutions |
| **description** | Trouver des patterns, architectures et realiser des POC |
| **categorie** | `recherche` |
| **agents** | `researcher` |
| **outils-requis** | `mem0`, `siyuan`, `chroma` |
| **niveau** | `primaire` |
| **input** | Probleme technique a resoudre, contraintes |
| **output** | Solutions evaluees, POC, recommandation argumentee |
| **exemple** | Le CTO demande une solution pour le temps reel. Le Researcher evalue : WebSockets (bidirectionnel, complexe), SSE (unidirectionnel, simple), polling long (fallback). POC WebSocket avec Socket.io : latence 15ms, reconnection auto. Recommandation : Socket.io avec fallback SSE. |

#### `analyse-libraries`

| Champ | Valeur |
|---|---|
| **nom** | Analyse de librairies |
| **description** | Evaluer les librairies : performance, communaute, securite, maintenance |
| **categorie** | `recherche` |
| **agents** | `researcher` |
| **outils-requis** | `mem0`, `chroma` |
| **niveau** | `primaire` |
| **input** | Besoin fonctionnel, librairies candidates |
| **output** | Comparatif structure (criteres, scores, recommandation) |
| **exemple** | Comparatif ORM Node.js : Prisma (typage fort, migrations auto, communaute large, perf moyenne), Drizzle (leger, performant, API SQL-like, communaute plus petite), TypeORM (mature, patterns ActiveRecord/DataMapper, maintenance ralentie). Recommandation : Prisma pour la DX, Drizzle pour la performance. |

#### `documentation-technique`

| Champ | Valeur |
|---|---|
| **nom** | Documentation technique |
| **description** | Rediger des guides, tutoriels et exemples de code |
| **categorie** | `recherche` |
| **agents** | `researcher` |
| **outils-requis** | `mem0`, `siyuan` |
| **niveau** | `secondaire` |
| **input** | Sujet a documenter, public cible |
| **output** | Documentation structuree dans SiYuan (guide, tutoriel, exemples) |
| **exemple** | Le Researcher redige le guide d'integration de Mem0 : concepts (memories, agents, metadata), API (CRUD, search), patterns d'usage (save decisions, search context, cleanup), exemples de code pour chaque operation. |

#### `benchmarking`

| Champ | Valeur |
|---|---|
| **nom** | Benchmarking |
| **description** | Realiser des comparatifs de performance entre solutions |
| **categorie** | `recherche` |
| **agents** | `researcher` |
| **outils-requis** | `mem0`, `chroma` |
| **niveau** | `secondaire` |
| **input** | Solutions a comparer, criteres de performance, conditions de test |
| **output** | Rapport de benchmark (metriques, graphiques textuels, analyse) |
| **exemple** | Benchmark API frameworks : Express (12k req/s, 45ms p99), Fastify (28k req/s, 22ms p99), Hono (35k req/s, 18ms p99). Conditions : 100 connexions concurrentes, reponse JSON 1KB, machine 4 CPU. Recommandation : Fastify (bon equilibre performance/ecosysteme). |

#### `competitive-analysis`

| Champ | Valeur |
|---|---|
| **nom** | Analyse concurrentielle |
| **description** | Analyser le marche et les solutions concurrentes |
| **categorie** | `recherche` |
| **agents** | `researcher` |
| **outils-requis** | `mem0`, `n8n` |
| **niveau** | `secondaire` |
| **input** | Marche cible, produit a positionner |
| **output** | Analyse concurrentielle (acteurs, forces/faiblesses, positionnement) |
| **exemple** | Analyse du marche des outils de gestion de taches : Trello (simple, visuel, limite pour grands projets), Jira (puissant, complexe, entreprise), Linear (rapide, moderne, startup). Positionnement recommande : simplicite de Trello + puissance de Linear. |

#### `memoire-recherche`

| Champ | Valeur |
|---|---|
| **nom** | Memoire recherche |
| **description** | Alimenter les trois couches de connaissance : Mem0, SiYuan et Chroma |
| **categorie** | `recherche` |
| **agents** | `researcher` |
| **outils-requis** | `mem0`, `siyuan`, `chroma` |
| **niveau** | `primaire` |
| **input** | Resultat de recherche, benchmark, analyse |
| **output** | Memory Mem0 (acces rapide) + page SiYuan (documentation structuree) + embedding Chroma (recherche semantique) |
| **exemple** | Apres le benchmark des API frameworks, le Researcher : enregistre la recommandation Fastify dans Mem0, cree une page detaillee dans SiYuan avec les chiffres et conditions, indexe le rapport dans Chroma pour recherche semantique future. |

---

### Growth Lead (6 skills)

#### `growth-strategy`

| Champ | Valeur |
|---|---|
| **nom** | Strategie growth |
| **description** | Definir et ajuster la strategie d'acquisition, retention et monetisation |
| **categorie** | `growth` |
| **agents** | `growth-lead` |
| **outils-requis** | `mem0`, `paperclip` |
| **niveau** | `primaire` |
| **input** | Objectifs business, metriques actuelles, insights Data Analyst |
| **output** | Plan growth avec channels, budget, timeline, KPIs |
| **exemple** | Le Growth Lead analyse les metriques du Data Analyst (taux de conversion 2%, bounce 60%) et definit une strategie : SEO sur 5 keywords transactionnels, sequence email nurturing, landing page optimisee. Il decompose en taches pour SEO, Content Writer et Sales. |

#### `channel-orchestration`

| Champ | Valeur |
|---|---|
| **nom** | Orchestration de channels |
| **description** | Coordonner SEO, content, email et CRM comme un pipeline unifie |
| **categorie** | `growth` |
| **agents** | `growth-lead` |
| **outils-requis** | `paperclip`, `mem0` |
| **niveau** | `primaire` |
| **input** | Initiative growth approuvee |
| **output** | Pipeline de taches decompose et assigne (SEO→Content→Sales→Data) |
| **exemple** | L'initiative "lancer le blog technique" est decomposee : SEO fait le keyword research (J1-3), Content Writer redige 4 articles (J4-10), Sales prepare une sequence email pour les lecteurs engages (J11-15), Data Analyst mesure le ROI (J20). |

#### `experiment-design`

| Champ | Valeur |
|---|---|
| **nom** | Design d'experiences |
| **description** | Concevoir des A/B tests et experiences growth avec hypotheses mesurables |
| **categorie** | `growth` |
| **agents** | `growth-lead` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Hypothese a tester, metriques de reference |
| **output** | Plan d'experience (variantes, KPIs, duree, taille echantillon) |
| **exemple** | Hypothese : "un CTA plus visible augmentera les signups de 20%". Le Growth Lead definit : variante A (CTA actuel), variante B (CTA rouge en sticky bar), KPI (taux de signup), duree (2 semaines), taille (500 visiteurs/variante). |

#### `growth-audit`

| Champ | Valeur |
|---|---|
| **nom** | Audit growth |
| **description** | Analyser le funnel complet et identifier les bottlenecks de croissance |
| **categorie** | `growth` |
| **agents** | `growth-lead` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Metriques funnel completes (Data Analyst) |
| **output** | Rapport bottlenecks avec recommandations priorisees |
| **exemple** | L'audit revele : trafic OK (5K/mois), mais conversion landing→signup a 1.5% (cible 3%). Le Growth Lead identifie le formulaire trop long comme bottleneck et recommande de passer de 6 a 3 champs. |

#### `cross-agent-workflow`

| Champ | Valeur |
|---|---|
| **nom** | Workflow cross-agent |
| **description** | Decomposer les initiatives growth en taches assignees aux agents specialises |
| **categorie** | `growth` |
| **agents** | `growth-lead` |
| **outils-requis** | `paperclip`, `mem0` |
| **niveau** | `primaire` |
| **input** | Initiative growth a executer |
| **output** | Sous-taches assignees avec dependances, deadlines et KPIs |
| **exemple** | Initiative "campagne Q2 acquisition". Le Growth Lead cree : tache SEO (competitor analysis + 10 briefs), tache Content (10 articles), tache Sales (sequence outbound), tache Data (dashboard ROI). Chaque tache a des criteres d'acceptation et des deadlines. |

#### `memoire-growth`

| Champ | Valeur |
|---|---|
| **nom** | Memoire growth |
| **description** | Sauvegarder les strategies, resultats d'experiences et metriques de croissance |
| **categorie** | `growth` |
| **agents** | `growth-lead` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Strategie, resultat d'experience, metrique de croissance |
| **output** | Memory dans Mem0 pour reference future et prise de decision |
| **exemple** | Le Growth Lead sauvegarde le resultat de l'experience CTA : "le CTA rouge sticky bar a augmente les signups de 35% (vs hypothese 20%). Decision : deployer en production. Impact : +150 signups/mois attendus." |

---

### SEO Specialist (7 skills)

#### `keyword-research`

| Champ | Valeur |
|---|---|
| **nom** | Keyword research |
| **description** | Identifier les keywords a fort potentiel avec volume, difficulte et intent |
| **categorie** | `seo` |
| **agents** | `seo` |
| **outils-requis** | `mem0`, `n8n` (Firecrawl) |
| **niveau** | `primaire` |
| **input** | Niche, theme ou objectif business |
| **output** | Liste keywords avec volume, difficulte, intent et clusters thematiques |
| **exemple** | Pour le theme "gestion de projet IA", le SEO identifie : "outil gestion projet ia" (1.2K/mois, diff 35, transactionnel), "automatiser gestion projet" (800/mois, diff 28, informationnel), et 15 keywords secondaires groupes en 4 clusters. |

#### `onpage-seo-audit`

| Champ | Valeur |
|---|---|
| **nom** | Audit SEO on-page |
| **description** | Auditer les titres, meta, structure Hn, maillage interne et schema markup |
| **categorie** | `seo` |
| **agents** | `seo` |
| **outils-requis** | `mem0`, `n8n` (Firecrawl) |
| **niveau** | `primaire` |
| **input** | URL ou page a auditer |
| **output** | Rapport audit avec score, issues et actions priorisees |
| **exemple** | Audit de la page /pricing : title trop long (72 chars, max 60), meta description absente, H1 manquant, pas de schema Product, 3 liens internes (minimum 5 recommande). Score : 45/100. Plan d'action en 4 points. |

#### `serp-monitoring`

| Champ | Valeur |
|---|---|
| **nom** | SERP monitoring |
| **description** | Suivre les positions dans les resultats de recherche et detecter les variations |
| **categorie** | `seo` |
| **agents** | `seo` |
| **outils-requis** | `mem0`, `n8n` (Firecrawl) |
| **niveau** | `primaire` |
| **input** | Keywords a suivre |
| **output** | Rapport positions avec variations et alertes |
| **exemple** | Suivi hebdomadaire : "gestion projet ia" passe de #8 a #5 (+3), "automatiser taches" de #12 a #15 (-3, alerte). Le SEO notifie le Growth Lead de la perte et recommande de renforcer le contenu avec des backlinks internes. |

#### `competitor-seo-analysis`

| Champ | Valeur |
|---|---|
| **nom** | Analyse SEO concurrentielle |
| **description** | Analyser les strategies SEO des concurrents (keywords, structure, contenu) |
| **categorie** | `seo` |
| **agents** | `seo` |
| **outils-requis** | `mem0`, `n8n` (Firecrawl) |
| **niveau** | `secondaire` |
| **input** | URL(s) concurrent(s) a analyser |
| **output** | Analyse comparative (keywords, structure, gaps, opportunites) |
| **exemple** | Analyse du concurrent X : 120 pages indexees (vs nos 30), fort sur "gestion de projet agile" (nous absents), faible sur "automatisation" (notre force). Opportunite : creer 10 pages sur les keywords ou X est absent. |

#### `technical-seo`

| Champ | Valeur |
|---|---|
| **nom** | SEO technique |
| **description** | Auditer la performance, crawlability, indexation et Core Web Vitals |
| **categorie** | `seo` |
| **agents** | `seo` |
| **outils-requis** | `mem0`, `n8n` (Firecrawl, Umami) |
| **niveau** | `secondaire` |
| **input** | Site ou page a auditer techniquement |
| **output** | Rapport technique avec metriques et actions correctives |
| **exemple** | Audit technique : LCP 3.8s (cible <2.5s), CLS 0.15 (cible <0.1), 12 pages orphelines non linkees, sitemap.xml absent, robots.txt bloque /api/. Actions : optimiser images, ajouter sitemap, corriger robots.txt. |

#### `content-brief-generation`

| Champ | Valeur |
|---|---|
| **nom** | Generation de content briefs |
| **description** | Produire des briefs SEO complets pour le Content Writer |
| **categorie** | `seo` |
| **agents** | `seo` |
| **outils-requis** | `mem0`, `n8n` (Firecrawl) |
| **niveau** | `primaire` |
| **input** | Keyword cible, intent, objectif |
| **output** | Brief complet (structure Hn, keywords secondaires, longueur, angle, concurrents) |
| **exemple** | Brief pour "automatiser gestion projet" : H1 "Guide complet : automatiser sa gestion de projet en 2026", H2 sections (pourquoi, outils, etapes, ROI), 2000 mots, 8 keywords secondaires, angle pratique avec exemples, top 3 concurrents analyses. |

#### `memoire-seo`

| Champ | Valeur |
|---|---|
| **nom** | Memoire SEO |
| **description** | Sauvegarder les keywords, audits, rankings et briefs dans la base de connaissances |
| **categorie** | `seo` |
| **agents** | `seo` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Resultat de keyword research, audit ou monitoring |
| **output** | Memory dans Mem0 pour reference future |
| **exemple** | Apres le keyword research Q2, le SEO sauvegarde la liste de 25 keywords avec leurs metriques, les clusters identifies et les priorites recommandees dans Mem0 pour que le Content Writer et le Growth Lead puissent les consulter. |

---

### Content Writer (6 skills)

#### `blog-article-writing`

| Champ | Valeur |
|---|---|
| **nom** | Redaction d'articles blog |
| **description** | Rediger des articles SEO-optimises a partir des briefs SEO |
| **categorie** | `content` |
| **agents** | `content-writer` |
| **outils-requis** | `mem0`, `n8n` (Firecrawl, Gitea) |
| **niveau** | `primaire` |
| **input** | Brief SEO du SEO Specialist |
| **output** | Article markdown SEO-optimise pousse dans Gitea |
| **exemple** | A partir du brief "automatiser gestion projet", le Content Writer redige un article de 2200 mots, integre les 8 keywords secondaires naturellement, structure en H2/H3 conforme au brief, ajoute 3 exemples concrets et un CTA vers la page pricing. |

#### `email-copywriting`

| Champ | Valeur |
|---|---|
| **nom** | Email copywriting |
| **description** | Rediger des emails marketing, nurturing et onboarding |
| **categorie** | `content` |
| **agents** | `content-writer` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Objectif campagne, segment cible, etape du funnel |
| **output** | Email avec subject line, preheader, body et CTA |
| **exemple** | Email nurturing step 3 : subject "3 erreurs qui tuent votre productivite", preheader "et comment les eviter en 5 min", body avec storytelling + 3 tips concrets, CTA "Decouvrir notre solution" vers la landing page. |

#### `landing-page-copy`

| Champ | Valeur |
|---|---|
| **nom** | Copy landing page |
| **description** | Rediger les textes de landing pages a forte conversion |
| **categorie** | `content` |
| **agents** | `content-writer` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Offre, proposition de valeur, audience cible |
| **output** | Copy complete (headline, sub-headline, features, CTA, FAQ, temoignages) |
| **exemple** | Landing page pour l'offre Pro : headline "Automatisez votre gestion de projet en 5 minutes", sub "Rejoignez 500+ equipes qui gagnent 10h/semaine", 4 features avec icones, CTA "Essai gratuit 14 jours", FAQ 5 questions. |

#### `content-repurposing`

| Champ | Valeur |
|---|---|
| **nom** | Repurposing de contenu |
| **description** | Adapter un contenu existant pour differents formats et canaux |
| **categorie** | `content` |
| **agents** | `content-writer` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Article ou contenu source a adapter |
| **output** | Variantes adaptees (thread LinkedIn, newsletter, tweets, infographie textuelle) |
| **exemple** | L'article "Guide automatisation gestion de projet" est repurpose en : 1 thread LinkedIn (8 posts), 1 newsletter (version condensee 500 mots), 5 tweets avec les stats cles, 1 email pour la sequence nurturing. |

#### `editorial-calendar`

| Champ | Valeur |
|---|---|
| **nom** | Calendrier editorial |
| **description** | Planifier et suivre le calendrier de publication |
| **categorie** | `content` |
| **agents** | `content-writer` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Strategie growth, briefs disponibles, capacite de production |
| **output** | Planning de publication avec deadlines, statuts et responsables |
| **exemple** | Calendrier mars : semaine 1 — article "automatisation" (draft J3, review J5, publish J7), semaine 2 — 3 emails sequence nurturing, semaine 3 — landing page offre Pro, semaine 4 — repurposing des contenus du mois. |

#### `memoire-content`

| Champ | Valeur |
|---|---|
| **nom** | Memoire contenu |
| **description** | Sauvegarder les articles, templates et performances dans la base de connaissances |
| **categorie** | `content` |
| **agents** | `content-writer` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Article redige, email, landing page ou learning redactionnel |
| **output** | Memory dans Mem0 pour reference future |
| **exemple** | Apres publication de l'article "automatisation", le Content Writer sauvegarde : titre, keyword, longueur, repo path, et un mois plus tard met a jour la memory avec les performances (2.5K vues, 3.2% CTR, 45 signups attribues). |

---

### Data Analyst (7 skills)

#### `funnel-analysis`

| Champ | Valeur |
|---|---|
| **nom** | Analyse de funnel |
| **description** | Analyser chaque etape du funnel acquisition→conversion→retention |
| **categorie** | `analytics` |
| **agents** | `data-analyst` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Periode d'analyse, metriques sources (Umami, CRM, BillionMail) |
| **output** | Rapport funnel avec taux de conversion par etape et bottlenecks |
| **exemple** | Funnel mars : visiteurs 5.2K → inscrits 156 (3%) → actifs 89 (57%) → payants 12 (13.5%). Bottleneck : actifs→payants (13.5% vs cible 20%). Cause probable : onboarding trop complexe. Recommandation : simplifier les 3 premieres etapes. |

#### `cross-service-correlation`

| Champ | Valeur |
|---|---|
| **nom** | Correlation cross-services |
| **description** | Correler les donnees Umami + Twenty CRM + BillionMail + Cal.com pour trouver des patterns |
| **categorie** | `analytics` |
| **agents** | `data-analyst` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Question business ou initiative growth a analyser |
| **output** | Analyse correlee multi-sources avec conclusions actionables |
| **exemple** | Correlation : les leads qui visitent la page pricing 3+ fois (Umami) ET ouvrent 2+ emails (BillionMail) ont un taux de conversion 4x superieur. Les meetings Cal.com avec ces leads convertissent a 65% vs 25% pour les autres. Recommandation : prioriser ces leads dans le scoring. |

#### `cohort-analysis`

| Champ | Valeur |
|---|---|
| **nom** | Analyse de cohortes |
| **description** | Segmenter les utilisateurs par comportement et periode |
| **categorie** | `analytics` |
| **agents** | `data-analyst` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Critere de segmentation, periode d'analyse |
| **output** | Segments identifies avec taille, comportements et retention |
| **exemple** | Cohorte "inscrits fevrier" : 120 inscrits, retention J7 65%, retention J30 40%, retention J60 28%. Comparaison avec cohorte janvier : +5% sur J30. Cause : nouveau flow d'onboarding deploye en fevrier. |

#### `anomaly-detection`

| Champ | Valeur |
|---|---|
| **nom** | Detection d'anomalies |
| **description** | Detecter les variations anormales dans les metriques business |
| **categorie** | `analytics` |
| **agents** | `data-analyst` |
| **outils-requis** | `mem0`, `n8n` (ntfy) |
| **niveau** | `primaire` |
| **input** | Metriques courantes vs baselines stockees dans Mem0 |
| **output** | Alertes anomalies avec contexte, impact et cause probable |
| **exemple** | Anomalie detectee : trafic organique -35% sur les 24h (vs baseline 200 visiteurs/jour). Correle avec : aucun incident serveur (monitoring OK), pas de changement de contenu. Cause probable : update algorithme Google. Alerte envoyee au Growth Lead via ntfy. |

#### `weekly-business-dashboard`

| Champ | Valeur |
|---|---|
| **nom** | Dashboard business hebdomadaire |
| **description** | Generer un rapport hebdomadaire consolide de toutes les sources business |
| **categorie** | `analytics` |
| **agents** | `data-analyst` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Automatique (schedule hebdomadaire) |
| **output** | Dashboard consolide (Umami + CRM + BillionMail + Cal.com) |
| **exemple** | Dashboard semaine 10 : Trafic 5.2K (+8%), Leads 23 (+15%), Deals en cours 8 (valeur $12K), Emails envoyes 450 (open 32%, click 8%), Meetings 6 (conversion 50%). Tendance globale : croissance soutenue. Alerte : taux de click emails en baisse. |

#### `roi-attribution`

| Champ | Valeur |
|---|---|
| **nom** | Attribution ROI |
| **description** | Mesurer le retour sur investissement de chaque action growth |
| **categorie** | `analytics` |
| **agents** | `data-analyst` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Initiative growth + metriques avant/apres |
| **output** | Rapport ROI avec cout, impact mesure et recommandation |
| **exemple** | ROI campagne "blog technique" : cout (5 articles * 2h agent = 10h), impact (1.2K visiteurs organiques, 45 leads, 5 deals clos pour $3.5K), ROI = 350%. Recommandation : doubler la cadence de publication. |

#### `memoire-analytics`

| Champ | Valeur |
|---|---|
| **nom** | Memoire analytics |
| **description** | Sauvegarder les rapports, baselines et insights business |
| **categorie** | `analytics` |
| **agents** | `data-analyst` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Rapport, baseline, anomalie ou insight |
| **output** | Memory dans Mem0 pour reference et comparaison future |
| **exemple** | Le Data Analyst sauvegarde la baseline hebdomadaire : visiteurs 5.2K, leads 23, pipeline $12K, emails open 32%. Cette baseline sera utilisee la semaine suivante pour detecter les anomalies et mesurer les tendances. |

---

### Sales Automation (7 skills)

#### `lead-scoring`

| Champ | Valeur |
|---|---|
| **nom** | Lead scoring |
| **description** | Evaluer et prioriser les leads selon les signaux comportementaux et demographiques |
| **categorie** | `sales` |
| **agents** | `sales-automation` |
| **outils-requis** | `mem0`, `n8n` (Twenty CRM, Umami) |
| **niveau** | `primaire` |
| **input** | Donnees lead (source, comportement web, interactions email, profil) |
| **output** | Score sur 100 + tier (hot/warm/cold) + next action recommandee |
| **exemple** | Lead "Marie Martin" : visite pricing 3x (+20), telecharge whitepaper (+15), ouvre 5 emails (+10), entreprise >50 personnes (+15), secteur SaaS (+10). Score : 70/100, tier warm. Next action : envoyer email personnalise avec demo. |

#### `outbound-prospecting`

| Champ | Valeur |
|---|---|
| **nom** | Prospection outbound |
| **description** | Identifier et qualifier les prospects via scraping et CRM |
| **categorie** | `sales` |
| **agents** | `sales-automation` |
| **outils-requis** | `mem0`, `n8n` (Firecrawl, Twenty CRM) |
| **niveau** | `primaire` |
| **input** | ICP (Ideal Customer Profile), marche cible |
| **output** | Liste prospects qualifies avec approach strategy |
| **exemple** | ICP : SaaS B2B, 20-200 employes, France. Le Sales scrape 3 directories via Firecrawl, identifie 25 prospects, les qualifie (10 hot, 8 warm, 7 cold), les ajoute dans Twenty CRM et prepare l'approach personnalisee pour les 10 hot. |

#### `email-sequences`

| Champ | Valeur |
|---|---|
| **nom** | Sequences email |
| **description** | Concevoir et optimiser les sequences d'emails de nurturing et outreach |
| **categorie** | `sales` |
| **agents** | `sales-automation` |
| **outils-requis** | `mem0`, `n8n` (BillionMail) |
| **niveau** | `primaire` |
| **input** | Objectif, segment cible, etape du pipeline |
| **output** | Sequence email avec timing, sujets, templates et metriques |
| **exemple** | Sequence "nurture warm leads" en 5 etapes : J0 intro personnalisee, J3 case study, J7 invitation webinar, J14 offre speciale, J21 derniere chance. Metriques cibles : open >30%, reply >10%, conversion >5%. |

#### `pipeline-management`

| Champ | Valeur |
|---|---|
| **nom** | Gestion du pipeline |
| **description** | Gerer et optimiser le pipeline de vente dans Twenty CRM |
| **categorie** | `sales` |
| **agents** | `sales-automation` |
| **outils-requis** | `mem0`, `n8n` (Twenty CRM) |
| **niveau** | `primaire` |
| **input** | Etat actuel du CRM, objectifs de vente |
| **output** | Pipeline mis a jour avec forecast et actions prioritaires |
| **exemple** | Pipeline Q1 : 15 deals en cours (valeur $45K), 5 en negociation ($20K, close prevu mars), 3 bloques (relancer avec nouvelle offre). Forecast : $25K closes ce mois (confiance 70%). Actions : relancer les 3 bloques, accelerer les 5 en nego. |

#### `meeting-to-deal`

| Champ | Valeur |
|---|---|
| **nom** | Meeting to deal |
| **description** | Convertir les meetings Cal.com en deals CRM avec follow-up |
| **categorie** | `sales` |
| **agents** | `sales-automation` |
| **outils-requis** | `mem0`, `n8n` (Cal.com, Twenty CRM) |
| **niveau** | `primaire` |
| **input** | Booking Cal.com avec details du prospect |
| **output** | Deal cree dans CRM + follow-up planifie |
| **exemple** | Meeting "Demo 30min" avec Marie Martin (marie@acme.com). Le Sales cree le deal dans Twenty CRM (stage: qualification, valeur estimee: $2K/mois), planifie un follow-up a J+2 avec proposition commerciale, et met a jour le scoring. |

#### `win-loss-analysis`

| Champ | Valeur |
|---|---|
| **nom** | Analyse win/loss |
| **description** | Analyser les deals gagnes et perdus pour ameliorer le processus commercial |
| **categorie** | `sales` |
| **agents** | `sales-automation` |
| **outils-requis** | `mem0` |
| **niveau** | `secondaire` |
| **input** | Deal clos (gagne ou perdu) avec historique des interactions |
| **output** | Analyse facteurs cles + recommandations d'amelioration |
| **exemple** | Analyse Q1 : 8 deals gagnes (facteurs : demo personnalisee, suivi rapide, offre sur mesure), 5 perdus (facteurs : prix trop eleve 3x, concurrent 2x). Recommandation : creer une offre decouverte a prix reduit, accelerer le suivi post-demo a <24h. |

#### `memoire-sales`

| Champ | Valeur |
|---|---|
| **nom** | Memoire sales |
| **description** | Sauvegarder les scoring models, sequences, deals et analyses dans la base de connaissances |
| **categorie** | `sales` |
| **agents** | `sales-automation` |
| **outils-requis** | `mem0` |
| **niveau** | `primaire` |
| **input** | Lead score, sequence, deal ou analyse win/loss |
| **output** | Memory dans Mem0 pour reference et optimisation continue |
| **exemple** | Le Sales sauvegarde l'analyse win/loss Q1 avec les facteurs de succes et d'echec, les metriques de conversion par etape du pipeline, et les recommandations d'ajustement du scoring model. Le Growth Lead consultera ces insights pour la strategie Q2. |

---

## Matrice skills x agents

### Categorie : `code` (22 skills)

| Skill | ceo | cto | cpo | cfo | lead-backend | lead-frontend | devops | security | qa | designer | researcher |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `code-review-standards` | | X | | | | | | | | | |
| `conception-api` | | | | | X | | | | | | |
| `base-de-donnees` | | | | | X | | | | | | |
| `logique-metier` | | | | | X | | | | | | |
| `integration-backend` | | | | | X | | | | | | |
| `testing-backend` | | | | | X | | | | X | | |
| `performance-backend` | | | | | X | | | | | | |
| `memoire-backend` | | | | | X | | | | | | |
| `architecture-frontend` | | | | | | X | | | | | |
| `composants-ui` | | | | | | X | | | | X | |
| `integration-api-frontend` | | | | | | X | | | | | |
| `styling-frontend` | | | | | | X | | | | | |
| `performance-frontend` | | | | | | X | | | | | |
| `testing-frontend` | | | | | | X | | | X | | |
| `memoire-frontend` | | | | | | X | | | | | |
| `test-planning` | | | | | | | | | X | | |
| `tests-unitaires` | | | | | X | X | | | X | | |
| `tests-integration` | | | | | | | | | X | | |
| `tests-e2e` | | | | | | | | | X | | |
| `code-review-qualite` | | X | | | | | | | X | | |
| `regression-testing` | | | | | | | | | X | | |
| `reporting-qualite` | | | | | | | | | X | | |
| `memoire-qa` | | | | | | | | | X | | |

### Categorie : `architecture` (6 skills)

| Skill | ceo | cto | cpo | cfo | lead-backend | lead-frontend | devops | security | qa | designer | researcher |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `architecture-systeme` | | X | | | | | | | | | |
| `gestion-stack-technique` | | X | | | | | | | | | |
| `knowledge-management` | | X | | | | | | | | | X |
| `decision-propagation` | | X | | | | | | | | | |
| `resolution-conflits-techniques` | | X | | | | | | | | | |

### Categorie : `produit` (6 skills)

| Skill | ceo | cto | cpo | cfo | lead-backend | lead-frontend | devops | security | qa | designer | researcher |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `product-discovery` | | | X | | | | | | | | |
| `specification-produit` | | | X | | | | | | | | |
| `roadmap-planification` | | | X | | | | | | | | |
| `coordination-produit` | | | X | | | | | | | | |
| `analyse-feedback` | | | X | | | | | | | | |
| `memoire-produit` | | | X | | | | | | | | |

### Categorie : `operations` (7 skills)

| Skill | ceo | cto | cpo | cfo | lead-backend | lead-frontend | devops | security | qa | designer | researcher |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `knowledge-review-periodique` | | X | | | | | | | | | |
| `containerisation` | | | | | | | X | | | | |
| `ci-cd` | | | | | | | X | | | | |
| `infrastructure-as-code` | | | | | | | X | | | | |
| `monitoring-logging` | | | | | | | X | | | | |
| `gestion-environnements` | | | | | | | X | | | | |
| `performance-infra` | | | | | | | X | | | | |
| `memoire-devops` | | | | | | | X | | | | |

### Categorie : `securite` (8 skills)

| Skill | ceo | cto | cpo | cfo | lead-backend | lead-frontend | devops | security | qa | designer | researcher |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `securite-infra` | | | | | | | X | X | | | |
| `audit-code` | | | | | | | | X | | | |
| `securite-dependances` | | | | | | | | X | | | |
| `securite-infrastructure` | | | | | | | X | X | | | |
| `auth-autorisations` | | | | | | | | X | | | |
| `protection-donnees` | | | | | | | | X | | | |
| `reporting-securite` | | | | | | | | X | | | |
| `memoire-securite` | | | | | | | | X | | | |

### Categorie : `design` (8 skills)

| Skill | ceo | cto | cpo | cfo | lead-backend | lead-frontend | devops | security | qa | designer | researcher |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `accessibilite` | | | | | | X | | | | X | |
| `ux-research` | | | | | | | | | | X | |
| `wireframing-textuel` | | | | | | | | | | X | |
| `design-system` | | | | | | | | | | X | |
| `specifications-interface` | | | | | | | | | | X | |
| `accessibilite-design` | | | | | | X | | | | X | |
| `review-design` | | | | | | | | | | X | |
| `memoire-design` | | | | | | | | | | X | |

### Categorie : `recherche` (7 skills)

| Skill | ceo | cto | cpo | cfo | lead-backend | lead-frontend | devops | security | qa | designer | researcher |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `veille-technologique` | | | | | | | | | | | X |
| `recherche-solutions` | | | | | | | | | | | X |
| `analyse-libraries` | | | | | | | | | | | X |
| `documentation-technique` | | | | | | | | | | | X |
| `benchmarking` | | | | | | | | | | | X |
| `competitive-analysis` | | | | | | | | | | | X |
| `memoire-recherche` | | | | | | | | | | | X |

### Categorie : `management` (7 skills)

| Skill | ceo | cto | cpo | cfo | lead-backend | lead-frontend | devops | security | qa | designer | researcher |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `recrutement-agents` | X | | | | | | | | | | |
| `vision-strategique` | X | | | | | | | | | | |
| `arbitrage-conflits` | X | | | | | | | | | | |
| `knowledge-review-strategique` | X | | | | | | | | | | |
| `memoire-strategique` | X | | | | | | | | | | |
| `recrutement-technique` | | X | | | | | | | | | |
| `cross-agent-status` | | X | | | | | | | | | |
| `reporting-ceo` | | X | | | | | | | | | |

### Categorie : `finance` (5 skills)

| Skill | ceo | cto | cpo | cfo | lead-backend | lead-frontend | devops | security | qa | designer | researcher |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `suivi-couts` | | | | X | | | | | | | |
| `budget-planification` | | | | X | | | | | | | |
| `roi-analyse` | | | | X | | | | | | | |
| `audit-financier` | | | | X | | | | | | | |
| `memoire-financiere` | | | | X | | | | | | | |

### Categorie : `growth` (6 skills)

| Skill | growth-lead | seo | content-writer | data-analyst | sales-automation |
|---|---|---|---|---|---|
| `growth-strategy` | X | | | | |
| `channel-orchestration` | X | | | | |
| `experiment-design` | X | | | | |
| `growth-audit` | X | | | | |
| `cross-agent-workflow` | X | | | | |
| `memoire-growth` | X | | | | |

### Categorie : `seo` (7 skills)

| Skill | growth-lead | seo | content-writer | data-analyst | sales-automation |
|---|---|---|---|---|---|
| `keyword-research` | | X | | | |
| `onpage-seo-audit` | | X | | | |
| `serp-monitoring` | | X | | | |
| `competitor-seo-analysis` | | X | | | |
| `technical-seo` | | X | | | |
| `content-brief-generation` | | X | | | |
| `memoire-seo` | | X | | | |

### Categorie : `content` (6 skills)

| Skill | growth-lead | seo | content-writer | data-analyst | sales-automation |
|---|---|---|---|---|---|
| `blog-article-writing` | | | X | | |
| `email-copywriting` | | | X | | |
| `landing-page-copy` | | | X | | |
| `content-repurposing` | | | X | | |
| `editorial-calendar` | | | X | | |
| `memoire-content` | | | X | | |

### Categorie : `analytics` (7 skills)

| Skill | growth-lead | seo | content-writer | data-analyst | sales-automation |
|---|---|---|---|---|---|
| `funnel-analysis` | | | | X | |
| `cross-service-correlation` | | | | X | |
| `cohort-analysis` | | | | X | |
| `anomaly-detection` | | | | X | |
| `weekly-business-dashboard` | | | | X | |
| `roi-attribution` | | | | X | |
| `memoire-analytics` | | | | X | |

### Categorie : `sales` (7 skills)

| Skill | growth-lead | seo | content-writer | data-analyst | sales-automation |
|---|---|---|---|---|---|
| `lead-scoring` | | | | | X |
| `outbound-prospecting` | | | | | X |
| `email-sequences` | | | | | X |
| `pipeline-management` | | | | | X |
| `meeting-to-deal` | | | | | X |
| `win-loss-analysis` | | | | | X |
| `memoire-sales` | | | | | X |

---

## Protocole de discovery

### Trouver "qui sait faire X" via SiYuan

Pour rechercher quel agent possede un skill donne, utiliser la requete SQL SiYuan :

```sql
SELECT * FROM blocks WHERE content LIKE '%skill-id%' AND hpath LIKE '%skills-catalog%'
```

Exemples concrets :

```sql
-- Trouver qui sait faire du testing
SELECT * FROM blocks WHERE content LIKE '%testing%' AND hpath LIKE '%skills-catalog%'

-- Trouver qui gere l'accessibilite
SELECT * FROM blocks WHERE content LIKE '%accessibilite%' AND hpath LIKE '%skills-catalog%'

-- Trouver tous les skills d'un agent specifique
SELECT * FROM blocks WHERE content LIKE '%lead-backend%' AND hpath LIKE '%skills-catalog%'
```

### Trouver les memories liees a un skill via Mem0

```json
{
  "method": "POST",
  "url": "/v1/memories/search/",
  "body": {
    "query": "skill:conception-api patterns et decisions",
    "agent_id": "lead-backend",
    "limit": 10
  }
}
```

Pour une recherche transversale (tous les agents) :

```json
{
  "method": "POST",
  "url": "/v1/memories/search/",
  "body": {
    "query": "conception-api",
    "limit": 20
  }
}
```

### Trouver des exemples de code lies a un skill via Chroma

```json
{
  "method": "POST",
  "url": "/api/v1/collections/{collection_id}/query",
  "body": {
    "query_texts": ["pattern repository pour conception API REST"],
    "n_results": 5,
    "where": {
      "agent": "lead-backend"
    }
  }
}
```

---

## Regles d'evolution des skills

### Ajouter un nouveau skill

1. **Identifier le besoin** : un agent a besoin d'une competence non cataloguee
2. **Definir le skill** selon le format standard (id, nom, description, categorie, agents, outils-requis, niveau, input, output, exemple)
3. **Mettre a jour ce catalogue** : ajouter le skill dans la section de l'agent concerne et dans la matrice
4. **Mettre a jour la definition de l'agent** : ajouter le skill dans le fichier de l'agent (ex: `01-ceo.md`)
5. **Valider** : le CTO valide la coherence avec l'architecture globale

### Deprecier un skill

1. **Marquer comme deprecie** : ajouter le prefixe `[DEPRECIE]` au nom du skill dans le catalogue
2. **Indiquer le remplacement** : si un nouveau skill le remplace, ajouter une note `remplace-par: nouveau-skill-id`
3. **Periode de transition** : le skill reste disponible pendant 2 sprints apres depreciation
4. **Suppression** : retirer le skill du catalogue et de la definition de l'agent apres la periode de transition
5. **Archiver** : deplacer la documentation du skill dans la section archives de SiYuan

### Transferer un skill entre agents

1. **Justifier le transfert** : documenter pourquoi le skill change d'agent
2. **Evaluer les outils** : verifier que l'agent destinataire a acces aux outils requis
3. **Mettre a jour le catalogue** : modifier la liste `agents` du skill
4. **Mettre a jour les definitions des agents** : retirer du source, ajouter au destinataire
5. **Transferer la memoire** : copier les memories Mem0 liees au skill vers le nouvel agent
6. **Notifier** : informer les agents qui interagissent avec ce skill via Paperclip

### Niveaux de skill

| Niveau | Definition | Implication |
|---|---|---|
| `primaire` | Competence fondamentale qui definit l'identite de l'agent | L'agent execute ce skill de maniere proactive, sans qu'on le lui demande explicitement |
| `secondaire` | Competence que l'agent peut exercer sur demande | L'agent n'execute ce skill que lorsqu'il est explicitement sollicite ou que le contexte l'exige |

**Regles de transition** :
- Un skill `secondaire` peut etre promu `primaire` si l'agent l'utilise frequemment (plus de 50% des sessions)
- Un skill `primaire` peut etre retrograde `secondaire` si un autre agent le fait mieux (decision CTO)
- Chaque agent doit avoir au minimum 3 skills `primaire` pour justifier son existence

---

## Statistiques globales

| Metrique | Valeur |
|---|---|
| **Nombre total de skills** | 111 |
| **Nombre d'agents** | 16 |
| **Moyenne de skills par agent** | 6.9 |
| **Agent le plus polyvalent** | CTO (10 skills) |
| **Categorie la plus fournie** | `code` (22 skills) |
| **Skills partages (multi-agents)** | 8 |
| **Skills primaires** | 82 |
| **Skills secondaires** | 29 |
| **Nouvelles categories (growth)** | `seo` (7), `content` (6), `analytics` (7), `sales` (7), `growth` (6) |
