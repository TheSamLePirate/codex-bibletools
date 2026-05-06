# Génération de quiz et QCM à partir d’un corpus textuel, sans LLM

## Objectif

Construire un système capable de produire automatiquement des quiz et QCM à partir d’une base de textes, sans utiliser de modèle génératif de type LLM.

Le système doit :

- extraire des informations fiables depuis le corpus
- sélectionner les faits pédagogiquement intéressants
- transformer ces faits en questions
- produire des distracteurs plausibles pour les QCM
- valider automatiquement que chaque question est correcte, non ambiguë, et bien supportée par le corpus

Ce document décrit une architecture complète, les étapes, les structures de données, les algorithmes utiles, et les validations à implémenter.

---

## 1. Contraintes et principes

### 1.1 Contraintes de départ

Le système ne doit pas dépendre d’un LLM pour :

- comprendre le corpus
- inventer des questions
- produire la réponse correcte
- produire les mauvaises réponses
- reformuler librement les phrases

Le système doit rester :

- déterministe ou quasi déterministe
- explicable
- vérifiable
- traçable jusqu’au texte source

### 1.2 Conséquence architecturale

Il faut remplacer la génération libre par une chaîne de transformation structurée :

```text
Corpus
-> segmentation
-> analyse linguistique
-> extraction d’unités de connaissance
-> filtrage / scoring
-> génération par gabarits
-> génération de distracteurs
-> validation
-> export
```

L’élément central n’est pas la “génération de langage”, mais la **construction d’une représentation intermédiaire fiable** des informations du corpus.

---

## 2. Types de questions visés

Le système peut générer plusieurs familles de questions sans LLM.

### 2.1 Questions à trous

Exemple :

> La photosynthèse convertit l’énergie lumineuse en énergie ___.

Utilité :
- simple à produire
- très robuste
- bonne base pour un premier système

### 2.2 Questions ouvertes factuelles

Exemple :

- Qui a formulé l’argument dominateur ?
- En quelle année a eu lieu tel événement ?
- Que désigne tel terme ?

Utilité :
- bonne fidélité au corpus
- faibles besoins de reformulation

### 2.3 QCM

Exemple :

- Qui a formulé l’argument dominateur ?
  - Diodore Cronos
  - Chrysippe
  - Épicure
  - Parménide

Utilité :
- format standard
- nécessite une bonne stratégie de distracteurs

### 2.4 Vrai / faux

Exemple :

- OCaml est un langage à typage dynamique. Faux.

Utilité :
- facile à produire à partir d’assertions et de perturbations contrôlées

### 2.5 Association terme / définition

Exemple :
- Associer chaque notion à sa définition

Utilité :
- très adapté aux corpus didactiques

### 2.6 Classement ou remise en ordre

Exemple :
- Remettre des événements dans l’ordre chronologique

Utilité :
- exploite les dates et séquences logiques extraites

---

## 3. Vue d’ensemble du pipeline

Le pipeline recommandé comporte 8 étages.

1. Prétraitement du corpus
2. Analyse linguistique
3. Extraction de candidats “faits”
4. Construction d’une base de connaissances interne
5. Scorage pédagogique des faits
6. Génération des questions par gabarits
7. Génération des distracteurs
8. Validation et export

---

## 4. Prétraitement du corpus

## 4.1 Segmentation documentaire

Le corpus doit être découpé en niveaux :

- document
- section
- sous-section
- paragraphe
- phrase

Chaque unité doit posséder un identifiant stable.

Exemple de structure :

```text
doc_id
section_id
paragraph_id
sentence_id
char_start
char_end
text
```

### 4.2 Nettoyage

Appliquer :

- normalisation Unicode
- suppression ou traitement des balises parasites
- homogénéisation des espaces
- conservation des ponctuations utiles
- gestion des listes à puces et titres

### 4.3 Détection de langue

Si plusieurs langues sont possibles, identifier la langue par document ou section.  
La chaîne de traitement linguistique dépendra de ce choix.

---

## 5. Analyse linguistique

Le système a besoin d’annotations structurées.

### 5.1 Tokenisation

Découper les phrases en tokens.

Utilité :
- base de toutes les étapes ultérieures

### 5.2 Lemmatisation

Ramener les mots à leur lemme.

Utilité :
- comparer des formes différentes
- calculer des statistiques de fréquence plus propres
- regrouper des candidats similaires

### 5.3 Étiquetage morpho-syntaxique (POS tagging)

Attribuer une catégorie à chaque token :

- nom
- verbe
- adjectif
- déterminant
- nombre
- etc.

Utilité :
- choisir quoi masquer dans une question à trous
- reconnaître des patrons de définition ou de relation

### 5.4 Reconnaissance d’entités nommées (NER)

Identifier les entités :

- personne
- lieu
- date
- organisation
- œuvre
- quantité
- événement selon les outils disponibles

Utilité :
- produire des réponses typées
- générer des distracteurs du bon type

### 5.5 Analyse de dépendances

Construire des relations syntaxiques dans la phrase :

- sujet
- verbe
- objet
- compléments
- modifieurs

Utilité :
- extraire des triplets relationnels
- repérer des structures de définition
- reformuler localement sans génération libre

### 5.6 Coréférence (optionnel mais utile)

Résoudre des pronoms et expressions anaphoriques :

- il
- elle
- ce dernier
- cette théorie

Utilité :
- éviter de générer une question depuis une phrase incompréhensible seule

---

## 6. Représentation intermédiaire : la base de faits

Le cœur du système est une base de faits ou d’unités de connaissance extraites.

### 6.1 Structure minimale d’un fait

```text
fact_id
doc_id
sentence_id
source_text
fact_type
subject
predicate
object
answer_type
confidence
support_span
```

### 6.2 Types de faits à extraire

Prévoir au moins :

- `definition`
- `attribute`
- `subject_verb_object`
- `date_event`
- `location_event`
- `author_work`
- `part_of`
- `cause_effect`
- `comparison`
- `enumeration`
- `classification`

### 6.3 Exemples

Phrase :
> Diodore Cronos a formulé l’argument dominateur.

Fait :
```text
fact_type = subject_verb_object
subject = Diodore Cronos
predicate = formuler
object = argument dominateur
answer_type = person
```

Phrase :
> La photosynthèse est le processus par lequel les plantes convertissent l’énergie lumineuse en énergie chimique.

Fait :
```text
fact_type = definition
subject = photosynthèse
predicate = être
object = processus par lequel les plantes convertissent l’énergie lumineuse en énergie chimique
answer_type = concept_definition
```

---

## 7. Extraction des faits

Plusieurs approches doivent être combinées.

## 7.1 Extraction par patrons linguistiques

Mettre en place des règles sur des structures fréquentes.

### 7.1.1 Patrons de définition

Repérer :

- `X est Y`
- `X désigne Y`
- `On appelle X Y`
- `X correspond à Y`
- `X se définit comme Y`

Algorithme :
1. détecter une phrase contenant un verbe copule ou assimilé
2. vérifier que le sujet nominal est stable
3. récupérer le complément définitoire
4. produire un fait `definition`

### 7.1.2 Patrons d’attribution

Repérer :

- `X a écrit Y`
- `X a inventé Y`
- `X a formulé Y`
- `Y a été formulé par X`

Algorithme :
1. détecter le verbe relationnel
2. extraire sujet / objet ou agent passif
3. normaliser la relation
4. produire un fait relationnel

### 7.1.3 Patrons date / lieu

Repérer :

- `en 1789`
- `à Paris`
- `le 14 juillet 1789`
- `pendant ...`

Algorithme :
1. détecter les entités temporelles ou spatiales
2. relier l’expression à l’événement principal de la phrase
3. produire un fait `date_event` ou `location_event`

## 7.2 Extraction par dépendances syntaxiques

Pour les phrases moins stéréotypées, utiliser l’arbre de dépendances.

Approche :
1. repérer le verbe principal
2. récupérer le sujet grammatical
3. récupérer l’objet direct ou complément principal
4. normaliser les formes
5. produire un triplet `(sujet, prédicat, objet)`

Cette méthode sert de base générique pour fabriquer :
- questions ouvertes
- questions à trous
- QCM relationnels

## 7.3 Extraction par cooccurrences et titres

Pour les corpus mal structurés syntaxiquement, exploiter aussi :

- titres / sous-titres
- listes
- tableaux
- termes répétés dans la même section

Utilité :
- identifier les notions saillantes même quand l’extraction syntaxique est faible

## 7.4 Extraction depuis les listes et énumérations

Si une phrase ou une section contient une énumération :

> Les trois états sont : solide, liquide, gazeux.

Produire :
- un fait `enumeration`
- éventuellement plusieurs questions :
  - Quels sont les trois états ?
  - Lequel des éléments suivants n’est pas un des trois états ?

---

## 8. Mesures statistiques pour choisir les bons candidats

Tous les faits extraits ne doivent pas devenir des questions.

Il faut scorer les candidats.

## 8.1 Fréquence de terme

Calculer les fréquences de mots ou lemmes :

- par document
- par section
- sur l’ensemble du corpus

Utilité :
- éviter de choisir des termes trop rares et accidentels
- éviter aussi les mots trop fréquents et triviaux

## 8.2 Spécificité lexicale

Comparer le corpus cible à un corpus de référence si disponible.

Mesures possibles :

- TF-IDF
- log-likelihood ratio
- chi carré
- weirdness index
- ratio de fréquence corpus cible / corpus de référence

Utilité :
- trouver les notions caractéristiques du corpus
- sélectionner les concepts plus susceptibles d’être pédagogiquement importants

## 8.3 Centralité dans un graphe lexical

Construire un graphe de cooccurrence :
- nœuds = termes ou concepts
- arêtes = cooccurrence dans fenêtre, phrase ou paragraphe

Mesures utiles :
- degree
- PageRank
- betweenness
- TextRank

Utilité :
- identifier les concepts centraux
- mieux pondérer les candidats de quiz

## 8.4 Position dans le document

Donner un bonus aux informations présentes dans :
- titres
- débuts de section
- phrases introductives
- phrases conclusives
- légendes ou résumés

Souvent, les faits importants y sont surreprésentés.

## 8.5 Clarté syntaxique

Noter plus haut les phrases :
- courtes à moyennes
- contenant un verbe principal clair
- avec peu d’anaphores
- avec peu d’incises

Noter plus bas les phrases :
- longues et enchâssées
- ambiguës
- dépendantes du contexte immédiat

---

## 9. Scoring pédagogique d’un fait

Chaque fait reçoit un score global.

### 9.1 Critères recommandés

- importance du concept
- spécificité au corpus
- clarté de la source
- univocité de la réponse
- longueur acceptable de la réponse
- réutilisabilité pédagogique
- non-redondance avec d’autres questions déjà générées

### 9.2 Formule possible

```text
score_fact =
    w1 * concept_centrality
  + w2 * lexical_specificity
  + w3 * sentence_clarity
  + w4 * answer_uniqueness
  + w5 * structural_confidence
  - w6 * redundancy_penalty
```

Les poids doivent être paramétrables.

### 9.3 Déduplication

Deux faits peuvent conduire à la même question.  
Prévoir :

- normalisation des lemmes
- comparaison par similarité de chaîne
- comparaison sur triplets normalisés
- clustering des faits proches

Conserver une seule version, la plus claire.

---

## 10. Génération des questions par gabarits

Sans LLM, la génération doit reposer sur des gabarits déterministes.

## 10.1 Principe général

À partir d’un fait structuré, produire une ou plusieurs formes de questions.

Chaque `fact_type` possède une famille de gabarits.

## 10.2 Gabarits pour les définitions

Fait :
```text
subject = photosynthèse
object = processus ...
```

Questions possibles :
- Qu’est-ce que la photosynthèse ?
- La photosynthèse désigne :
- Quel terme correspond à la définition suivante : “processus ...” ?

## 10.3 Gabarits pour les relations sujet-verbe-objet

Fait :
```text
subject = Diodore Cronos
predicate = formuler
object = argument dominateur
```

Questions possibles :
- Qui a formulé l’argument dominateur ?
- Qu’a formulé Diodore Cronos ?
- L’argument dominateur a été formulé par qui ?

## 10.4 Gabarits pour les dates

Fait :
```text
event = prise de la Bastille
date = 14 juillet 1789
```

Questions possibles :
- En quelle année a eu lieu la prise de la Bastille ?
- À quelle date a eu lieu la prise de la Bastille ?

## 10.5 Gabarits pour les lieux

Questions possibles :
- Où a eu lieu ...
- Dans quelle ville ...
- Dans quel pays ...

## 10.6 Gabarits pour les énumérations

Exemple :
- Quels sont les trois états de la matière ?
- Lequel des éléments suivants n’appartient pas à la liste ...
- Combien d’éléments comporte ...

## 10.7 Gabarits pour les questions à trous

Algorithme :
1. choisir une phrase source claire
2. sélectionner un segment à masquer
3. remplacer ce segment par un blanc
4. conserver suffisamment de contexte pour que la question reste solvable

Exemple :
> La photosynthèse convertit l’énergie lumineuse en énergie chimique.

Question :
> La photosynthèse convertit l’énergie lumineuse en énergie ___.

---

## 11. Choix du segment à masquer pour les textes à trous

Le choix du trou est un point clé.

## 11.1 Cibles recommandées

Masquer préférentiellement :
- entités nommées
- termes spécifiques au corpus
- concepts centraux
- dates
- nombres importants
- têtes nominales de définitions

## 11.2 Cibles à éviter

Éviter de masquer :
- mots-outils
- termes ambigus sans contexte
- segments trop longs
- segments dépendants d’une anaphore
- adjectifs anecdotiques

## 11.3 Algorithme de sélection

Pour chaque phrase candidate :

1. lister les segments masquables
2. attribuer un score à chaque segment :
   - spécificité lexicale
   - importance conceptuelle
   - typage clair
   - longueur raisonnable
3. choisir le segment au meilleur score
4. vérifier que le reste de la phrase ne révèle pas trop la réponse

---

## 12. Génération des distracteurs pour les QCM

C’est la partie la plus délicate sans LLM.

Le principe est simple : les distracteurs doivent être faux, mais plausibles.

## 12.1 Règle absolue

Les distracteurs doivent être **du même type** que la bonne réponse.

Ne jamais mélanger :
- personne
- date
- lieu
- concept
- œuvre
- organisation

## 12.2 Sources de distracteurs

### 12.2.1 Distracteurs intra-corpus

Prendre d’autres entités du même type présentes :
- dans le même document
- dans la même section
- dans un voisinage thématique proche

Exemple :
bonne réponse = un philosophe  
distracteurs = autres philosophes présents dans le corpus

### 12.2.2 Distracteurs par similarité distributionnelle

Construire des embeddings locaux ou des vecteurs de cooccurrence.

Chercher des éléments proches de la bonne réponse ou du contexte.  
Utilité :
- produire des distracteurs plus plausibles sémantiquement

### 12.2.3 Distracteurs par classe sémantique

Si le système connaît une taxonomie légère :
- villes entre elles
- auteurs entre eux
- langages de programmation entre eux
- écoles philosophiques entre elles

les distracteurs deviennent meilleurs.

### 12.2.4 Distracteurs numériques

Pour dates et nombres :
- valeurs proches
- permutations simples
- années du même chapitre
- valeurs réalistes mais incorrectes

Exemple :
1789 -> 1791, 1779, 1788

## 12.3 Stratégie concrète de ranking des distracteurs

Pour un candidat distracteur `d`, définir :

```text
score_distractor(d) =
    a1 * type_match
  + a2 * thematic_similarity
  + a3 * lexical_similarity
  - a4 * truth_risk
  - a5 * too_obvious_penalty
```

### 12.3.1 truth_risk

Pénalité élevée si le distracteur est potentiellement vrai dans le même contexte.

Exemple :
si plusieurs auteurs ont réellement travaillé sur le même sujet, danger d’ambiguïté.

### 12.3.2 too_obvious_penalty

Pénalité si le distracteur :
- est absurde
- n’appartient pas au même domaine
- a une longueur ou une forme très différente

## 12.4 Vérifications obligatoires

Avant d’accepter un distracteur :

- même type que la réponse
- n’apparaît pas comme correct dans le support
- ne duplique pas un autre distracteur
- ne contient pas la bonne réponse
- ne révèle pas la réponse par genre, nombre, forme unique

---

## 13. Génération de vrai / faux

Approche recommandée :
1. partir d’une assertion vraie extraite
2. appliquer une perturbation contrôlée
3. vérifier que la phrase modifiée est bien fausse selon le corpus

## 13.1 Types de perturbation

- remplacer la date
- remplacer le lieu
- remplacer l’auteur
- remplacer le concept clé
- inverser une relation
- nier une propriété

Exemple :
- vrai : OCaml est un langage à typage statique.
- faux : OCaml est un langage à typage dynamique.

## 13.2 Validation

Il faut vérifier que :
- la version fausse n’est pas vraie ailleurs dans le corpus
- la phrase reste grammaticalement correcte
- la modification n’est pas trop grossière

---

## 14. Validation globale des questions

Aucune question ne doit sortir sans validation.

## 14.1 Validations minimales

Pour chaque question :

- la réponse correcte est trouvable dans le corpus
- la question pointe vers un support explicite
- la formulation n’est pas ambiguë
- il n’existe qu’une seule bonne réponse
- les distracteurs sont plausibles mais faux
- la question reste compréhensible sans le paragraphe entier

## 14.2 Validation par recherche inverse

Pour une question générée :

1. construire une requête depuis la question et la réponse
2. rechercher dans l’index du corpus
3. vérifier que le support principal retrouvé est bien le support source ou un voisin cohérent

Utilité :
- détecter les questions mal alignées avec le corpus

## 14.3 Détection d’ambiguïté

Refuser ou dégrader la note d’une question si :
- plusieurs réponses du même type sont compatibles
- la relation est trop générale
- la phrase dépend de pronoms non résolus
- la définition est trop large

## 14.4 Contrôle de surface

Refuser une question si :
- la bonne réponse est beaucoup plus longue ou plus courte que les distracteurs
- le bon choix a une forme grammaticale unique
- les options ne sont pas homogènes

---

## 15. Indexation et structures de données utiles

Le système gagne à posséder plusieurs index internes.

## 15.1 Index inversé lexical

Associer chaque lemme aux phrases et documents où il apparaît.

Utilité :
- validation
- recherche de supports
- distracteurs intra-corpus

## 15.2 Index d’entités par type

```text
type -> liste d’entités
```

Utilité :
- génération rapide de distracteurs typés

## 15.3 Graphe de concepts

Nœuds :
- concepts
- entités
- événements

Arêtes :
- cooccurrence
- relation extraite
- inclusion thématique

Utilité :
- mesurer la centralité
- équilibrer les quiz
- éviter trop de questions sur le même micro-sujet

## 15.4 Base de faits normalisée

Stocker les faits sous forme interrogeable, dédupliquée, versionnée.

---

## 16. Équilibrage du quiz final

Une fois les questions générées, il faut assembler un quiz équilibré.

## 16.1 Critères d’équilibrage

- couverture des sections du corpus
- variété des types de questions
- variété des concepts
- répartition des difficultés
- absence de répétition de la même réponse

## 16.2 Difficulté estimée

Une difficulté approximative peut être calculée par :

- rareté du concept
- longueur de la définition
- nombre de distracteurs plausibles
- proximité sémantique entre options
- nécessité d’un contexte plus large

Exemple :

```text
difficulty =
    b1 * answer_rarity
  + b2 * distractor_similarity
  + b3 * context_dependency
  - b4 * direct_definition_bonus
```

## 16.3 Diversité

Utiliser une pénalité de redondance lors de la sélection finale :

- éviter 5 questions sur le même terme
- éviter 5 dates consécutives
- éviter 5 définitions de même forme

---

## 17. Algorithmes recommandés par composant

## 17.1 Prétraitement

- segmentation par règles
- tokenisation
- lemmatisation
- POS tagging
- NER
- parsing de dépendances

## 17.2 Sélection des termes et concepts

- TF-IDF
- chi carré
- log-likelihood ratio
- TextRank
- PageRank sur graphe de cooccurrence

## 17.3 Regroupement et déduplication

- normalisation par lemme
- distance de Levenshtein
- similarité Jaccard sur ensembles de lemmes
- clustering hiérarchique léger si nécessaire

## 17.4 Extraction de relations

- patrons syntaxiques
- dépendances sujet-verbe-objet
- patrons définitoires
- patrons temporels et spatiaux

## 17.5 Distracteurs

- filtrage par type
- plus proches voisins dans l’espace vectoriel local
- sélection intra-section ou intra-thème
- perturbation numérique contrôlée

## 17.6 Validation

- recherche inverse dans index
- vérification d’unicité
- tests de cohérence de type
- pénalités de surface

---

## 18. Ordre d’implémentation recommandé

Ne pas tout faire d’un coup.

## Étape 1 — Système minimal viable

Implémenter :
- segmentation
- tokenisation
- lemmatisation
- extraction de définitions simples
- extraction sujet-verbe-objet simple
- questions à trous
- questions ouvertes simples
- support textuel stocké

Objectif :
- produire des questions correctes mais encore peu variées

## Étape 2 — Ajout des QCM

Implémenter :
- typage des réponses
- index d’entités par type
- distracteurs intra-corpus
- validation des distracteurs
- export QCM

Objectif :
- générer des QCM robustes sur un corpus fermé

## Étape 3 — Amélioration du scoring

Implémenter :
- TF-IDF ou log-likelihood
- centralité de graphe
- déduplication
- score pédagogique global
- équilibrage final

Objectif :
- sélectionner de meilleures questions

## Étape 4 — Enrichissements

Implémenter :
- vrai/faux
- associations
- ordre chronologique
- coréférence
- embeddings locaux ou cooccurrences avancées

Objectif :
- augmenter variété et qualité

---

## 19. Schéma de données recommandé

### 19.1 Phrase annotée

```json
{
  "sentence_id": "s_001",
  "doc_id": "doc_a",
  "text": "Diodore Cronos a formulé l’argument dominateur.",
  "tokens": [...],
  "lemmas": [...],
  "pos": [...],
  "entities": [...],
  "dependencies": [...]
}
```

### 19.2 Fait extrait

```json
{
  "fact_id": "f_001",
  "sentence_id": "s_001",
  "fact_type": "subject_verb_object",
  "subject": "Diodore Cronos",
  "predicate": "formuler",
  "object": "argument dominateur",
  "answer_type": "person",
  "confidence": 0.94,
  "support_span": [0, 46]
}
```

### 19.3 Question générée

```json
{
  "question_id": "q_001",
  "fact_id": "f_001",
  "question_type": "mcq",
  "prompt": "Qui a formulé l’argument dominateur ?",
  "correct_answer": "Diodore Cronos",
  "choices": [
    "Diodore Cronos",
    "Chrysippe",
    "Épicure",
    "Parménide"
  ],
  "support_sentence_id": "s_001",
  "difficulty": 0.42,
  "validation": {
    "unique_answer": true,
    "support_found": true,
    "distractors_checked": true
  }
}
```

---

## 20. Points d’échec classiques

### 20.1 Extraction trop naïve

Effet :
- questions absurdes
- réponses incomplètes
- duplications massives

Correction :
- ajouter des patrons ciblés
- mieux filtrer les phrases

### 20.2 Distracteurs absurdes

Effet :
- QCM trop faciles
- mauvaise qualité perçue

Correction :
- typage fort
- proximité thématique
- validation systématique

### 20.3 Questions ambiguës

Effet :
- plusieurs bonnes réponses possibles

Correction :
- validation d’unicité
- rejet des faits trop généraux
- contrôle contextuel

### 20.4 Questions correctes mais pédagogiquement nulles

Effet :
- quiz ennuyeux
- détails anecdotiques

Correction :
- score pédagogique
- pondération par centralité et spécificité
- équilibrage par thème

---

## 21. Extensions possibles, toujours sans LLM

Le système peut ensuite évoluer vers :

- quiz adaptatifs selon difficulté
- génération de quiz par section ou chapitre
- sélection de questions de révision espacée
- estimation de couverture notionnelle
- suivi des erreurs utilisateur par concept
- génération de variantes de surface à partir de gabarits multiples

Même sans LLM, un système bien conçu peut devenir très solide sur un corpus fermé.

---

## 22. Résumé opérationnel

Le système complet repose sur quatre idées centrales.

### 22.1 Première idée

Ne jamais générer directement depuis le texte brut.  
Toujours passer par une représentation intermédiaire de faits, concepts ou relations.

### 22.2 Deuxième idée

Les meilleures questions viennent des éléments :
- centraux
- spécifiques
- clairs
- univoques

Il faut donc scorer les candidats.

### 22.3 Troisième idée

Les QCM dépendent surtout de la qualité des distracteurs.  
Sans typage et validation stricte, les distracteurs seront médiocres.

### 22.4 Quatrième idée

La validation n’est pas optionnelle.  
Une question non validée ne doit pas sortir.

---

## 23. Pipeline final recommandé

```text
1. Charger le corpus
2. Segmenter documents / sections / paragraphes / phrases
3. Annoter linguistiquement
4. Extraire faits, définitions, relations, dates, lieux, listes
5. Construire index lexicaux, entités typées, graphe de concepts
6. Scorer les faits
7. Générer des questions par gabarits
8. Générer les distracteurs par type et proximité thématique
9. Valider support, unicité et cohérence
10. Dédupliquer
11. Équilibrer le quiz final
12. Exporter en JSON / Markdown / HTML / autre format cible
```

---

## 24. Priorité de développement

Ordre conseillé :

1. questions à trous sur phrases claires
2. questions ouvertes factuelles
3. QCM avec distracteurs typés intra-corpus
4. vrai/faux par perturbation contrôlée
5. scoring avancé
6. équilibrage et difficulté
7. variantes et raffinements

---

## 25. Conclusion

Un générateur de quiz sans LLM est parfaitement faisable.

Le problème n’est pas un problème de génération libre, mais un problème de :

- structuration du corpus
- extraction de faits
- sélection pédagogique
- transformation par gabarits
- génération de distracteurs contrôlés
- validation stricte

Le composant le plus important n’est donc pas un moteur de génération, mais une **chaîne d’analyse textuelle produisant une base de connaissances locale, exploitable et vérifiable**.
