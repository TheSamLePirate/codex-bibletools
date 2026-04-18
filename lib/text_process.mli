(** Corpus texte prétraité, chargé pour une seule source logique à la fois. *)
type t

(** Métadonnées minimales d'une source disponible dans le manifeste prétraité. *)
type source_info = {
  id : string;
  label : string;
  document_count : int;
}

(** Résultat d'une recherche textuelle ou sémantique. *)
type search_hit = {
  document_id : string;
  title : string;
  reference : string;
  score : float;
  excerpt : string;
}

(** Score d'un terme saillant pour une source, éventuellement comparé au corpus de référence. *)
type term_score = {
  term : string;
  score : float;
  frequency : int;
  reference_frequency : int option;
}

(** Concept central extrait à partir des cooccurrences d'une source. *)
type concept = {
  term : string;
  score : float;
  neighbours : string list;
}

(** Noeud d'une hiérarchie thématique dérivée du corpus chargé. *)
type theme = {
  title : string;
  keywords : string list;
  document_ids : string list;
  children : theme list;
}

(** Résumé synthétique d'une question, avec passages justificatifs. *)
type summary = {
  short_answer : string;
  long_answer : string;
  passages : (string * string * string) list;
}

(** Chemin du manifeste principal attendu pour le prétraitement. *)
val artifact_path : root:string -> string

(** Commande à exécuter pour régénérer les artefacts de prétraitement. *)
val preprocess_command : string

(** Prétraite les sources disponibles depuis [root] et écrit les artefacts JSON sur disque.
    Retourne [Error _] si l'écriture ou le chargement des sources échoue. *)
val preprocess_and_save : root:string -> (unit, string) result

(** Vérifie la présence du manifeste prétraité sous [root].
    Lève [Failure] si le corpus n'a pas encore été généré. *)
val ensure_preprocessed : root:string -> unit

(** Charge en mémoire la source logique demandée à partir des artefacts prétraités.
    Retourne [Error _] si le manifeste, la source ou les fichiers JSON sont invalides. *)
val load : root:string -> source:string -> (t, string) result

(** Liste les sources effectivement chargées dans [t].
    Dans l'architecture actuelle, la liste contient la source unique demandée à [load]. *)
val sources : t -> source_info list

(** Recherche lexicale BM25 bornée aux vingt meilleurs résultats. *)
val lexical_search : t -> source:string -> query:string -> search_hit list

(** Recherche sémantique légère avec expansion par cooccurrences, bornée aux vingt meilleurs résultats. *)
val semantic_search : t -> source:string -> query:string -> search_hit list

(** Extrait le vocabulaire spécifique de la source par rapport au corpus de référence. *)
val specific_terms : t -> source:string -> term_score list

(** Calcule les concepts centraux d'une source à partir du graphe de cooccurrences. *)
val central_concepts : t -> source:string -> concept list

(** Construit une hiérarchie thématique approximative à partir des documents de la source. *)
val themes : t -> source:string -> theme list

(** Produit une réponse courte, une réponse longue et des passages pertinents pour une question. *)
val summarize : t -> source:string -> question:string -> summary

(** Génère quelques phrases candidates à partir d'un mot d'entrée pour la source chargée. *)
val generate_from_word : t -> source:string -> word:string -> string list
