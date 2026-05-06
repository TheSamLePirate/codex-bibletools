# Nouvelle fenêtre de traitement sur le texte.
Le projet doit executer un autre binaire codé dans `bin/textTools.ml`
on doit avoir une fenêtre GTK qui permet de sélectionner une source, et d'effectuer un certain nombre d'opérations.

Le projet peut avoir besoin de prétraitement, le binaire codé dans `bin/processSources.ml` effectue ces prétraitements.

Si le prétraitement n'a pas été effectué alors bin/textTools doit planter avec un failwith explicite après avoir affiché la ligne de commande permettant de lancer le prétraitement.

On a un corpus de texte de référence dans `datas/Hugo.txt`
Pour les autres textes, on doit utiliser les mêmes librairies déjà présentes dans le dossier lib.

## OBJECTIVE

Construire un système complet basé sur corpus permettant :

- recherche (lexicale + sémantique)
- extraction de vocabulaire spécifique
- détection de concepts centraux
- structuration hiérarchique par thèmes
- résumé (par question et multi-documents)
- génération de phrases à partir d’un mot

Le système doit fonctionner :

- avec uniquement un corpus spécifique
- avec un corpus de référence optionnel

---

## GLOBAL ARCHITECTURE

Pipeline principal :

1. Ingestion
2. Prétraitement linguistique
3. Statistiques lexicales
4. Indexation (recherche)
5. Structuration thématique
6. Résumé / QA
7. Génération

Tous les modules partagent des structures communes.

---

## DATA MODEL

### Document

- id
- source
- texte brut
- paragraphes
- phrases
- tokens
- lemmes
- POS
- longueur
- vecteur lexical (TF-IDF)
- vecteur sémantique
- thèmes

### Terme

- fréquence totale
- fréquence par document
- DF
- IDF
- score de spécificité
- dispersion
- collocations
- voisins sémantiques

### Passage

- document_id
- position
- texte
- score lexical
- score sémantique
- thèmes
- termes spécifiques

### Thème

- mots dominants
- documents
- sous-thèmes
- score
- résumé

---

## PREPROCESSING

### Required

- tokenisation
- normalisation (lowercase, unicode)
- suppression ponctuation (configurable)
- stopwords
- lemmatisation (fortement recommandé)

### Optional

- POS tagging
- extraction groupes nominaux

---

## LEXICAL STATISTICS

### Always compute

- TF (term frequency)
- DF (document frequency)
- IDF
- TF-IDF
- longueur documents
- dispersion (entropie ou variance)

### If reference corpus exists

- fréquence référence
- log-likelihood
- log-ratio
- keyness

### Collocations

- bigrammes / trigrammes
- scoring :
  - PMI
  - log-likelihood
  - Dice

---

## SEARCH ENGINE

### Index

- index inversé (lemmes + formes)
- index n-grammes
- index passages

### Baseline scoring

BM25

### Advanced scoring

Score = α * BM25  
      + β * score_sémantique  
      + γ * score_spécificité  
      + δ * score_thématique  

### Features

- recherche mot
- recherche expression
- recherche par passage
- highlighting
- expansion de requête

### Optional

- embeddings documents
- embeddings passages
- index vectoriel
- reranking

---

## SPECIFIC TERM EXTRACTION

### Pipeline

1. filtrage fréquence minimale
2. filtrage POS
3. scoring :
   - TF-IDF (sans référence)
   - keyness (avec référence)
4. tri

### Output

- mots spécifiques globaux
- mots spécifiques par document
- mots spécifiques par thème
- collocations spécifiques

---

## CENTRAL CONCEPTS

### Build graph

- nodes = mots / expressions
- edges = cooccurrences

### Compute

- degré
- PageRank
- centralité

### Output

- concepts pivots
- concepts secondaires
- clusters lexicaux

---

## THEMATIC HIERARCHY

### Representation

- documents → vecteurs (TF-IDF ou embeddings)

### Algorithms

- clustering hiérarchique (priorité)
- k-means (fallback)
- NMF (topics interprétables)

### Pipeline

1. clustering global
2. sous-clustering récursif
3. extraction mots caractéristiques

### Output

- arbre de thèmes
- thème → sous-thèmes
- documents associés

---

## QUESTION-BASED SUMMARIZATION

### Pipeline

1. analyser requête
2. récupérer passages :
   - BM25
   - similarité sémantique
3. scorer passages
4. déduplication (MMR)
5. sélection
6. résumé

### Output

- réponse courte
- réponse longue
- passages sources

---

## MULTI-DOCUMENT SUMMARIZATION

### Pipeline

1. sélectionner documents
2. segmenter en passages
3. scoring
4. suppression redondance
5. agrégation

### Algorithms

- TextRank
- centroid-based
- MMR

### Output

- résumé global
- résumé structuré
- plan thématique

---

## RANDOM GENERATION FROM WORD

### Mode 1 — Markov

- n-gram (2 ou 3)
- génération conditionnée par mot

### Mode 2 — Corpus-driven

1. trouver phrases contenant le mot
2. extraire patterns
3. recombiner

### Mode 3 — Guided

1. récupérer voisins (cooccurrence / embeddings)
2. générer phrase avec contraintes

### Constraints

- mot obligatoire
- longueur
- thème

---

## REFERENCE CORPUS USAGE

### If present

Used for:

- keyness
- détection jargon
- amélioration scoring

### If absent

Fallback:

- TF-IDF
- dispersion
- clustering

System must work without reference.

---

## COMPUTATION LAYERS

### Offline

- TF / IDF
- collocations
- embeddings
- clustering
- graphes

### Semi-offline

- mise à jour index
- recalcul thèmes

### Online

- recherche
- résumé
- génération

---

## DEVELOPMENT ORDER

### Phase 1

- ingestion
- preprocessing
- TF / IDF
- BM25

### Phase 2

- mots spécifiques
- collocations

### Phase 3

- recherche avancée

### Phase 4

- concepts centraux (graphe)

### Phase 5

- clustering + hiérarchie

### Phase 6

- résumé (question + multi-doc)

### Phase 7

- génération

---

## CONSTRAINTS FOR AGENT

- éviter dépendances lourdes inutiles
- préférer implémentations simples d’abord
- modulariser chaque brique
- exposer API interne claire
- séparer offline / online
- privilégier interprétabilité des scores

---

## MINIMAL VIABLE SYSTEM

- preprocessing
- TF-IDF
- BM25
- extraction mots spécifiques
- clustering simple
- résumé extractif
- génération Markov

---
