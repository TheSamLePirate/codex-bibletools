type t

type source_info = {
  id : string;
  label : string;
  document_count : int;
}

type search_hit = {
  document_id : string;
  title : string;
  reference : string;
  score : float;
  excerpt : string;
}

type term_score = {
  term : string;
  score : float;
  frequency : int;
  reference_frequency : int option;
}

type concept = {
  term : string;
  score : float;
  neighbours : string list;
}

type theme = {
  title : string;
  keywords : string list;
  document_ids : string list;
  children : theme list;
}

type summary = {
  short_answer : string;
  long_answer : string;
  passages : (string * string * string) list;
}

val artifact_path : root:string -> string
val preprocess_command : string
val preprocess_and_save : root:string -> (unit, string) result
val ensure_preprocessed : root:string -> unit
val load : root:string -> source:string -> (t, string) result
val sources : t -> source_info list
val lexical_search : t -> source:string -> query:string -> search_hit list
val semantic_search : t -> source:string -> query:string -> search_hit list
val specific_terms : t -> source:string -> term_score list
val central_concepts : t -> source:string -> concept list
val themes : t -> source:string -> theme list
val summarize : t -> source:string -> question:string -> summary
val generate_from_word : t -> source:string -> word:string -> string list
