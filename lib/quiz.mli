(** Génération déterministe de quiz sans LLM à partir de textes courts ou de
    documents déjà extraits du corpus. *)

type fact_type =
  | Definition
  | Subject_verb_object
  | Date_event
  | Enumeration

type answer_type =
  | Person
  | Date
  | Concept
  | Text

type annotated_sentence = {
  sentence_id : string;
  doc_id : string;
  text : string;
  tokens : string list;
  lemmas : string list;
  char_start : int;
  char_end : int;
}

type fact = {
  fact_id : string;
  doc_id : string;
  sentence_id : string;
  source_text : string;
  fact_type : fact_type;
  subject : string;
  predicate : string;
  object_ : string;
  answer_type : answer_type;
  confidence : float;
}

type question_type =
  | Cloze
  | Open
  | Multiple_choice

type question = {
  question_id : string;
  fact_id : string;
  question_type : question_type;
  prompt : string;
  correct_answer : string;
  choices : string list;
  support_sentence_id : string;
  support_text : string;
  valid : bool;
}

(** Alias du tokenizer partagé de [Text_process], pour garantir une seule
    normalisation entre recherche, extraction et génération de quiz. *)
val tokenize : string -> string list

(** Alias de la normalisation de token partagée de [Text_process]. *)
val lemmatize_token : string -> string

val segment_sentences : doc_id:string -> string -> annotated_sentence list

val extract_definitions : annotated_sentence list -> fact list
val extract_relations : annotated_sentence list -> fact list
val extract_dates : annotated_sentence list -> fact list
val extract_enumerations : annotated_sentence list -> fact list
val extract_facts : annotated_sentence list -> fact list

val score_fact : fact -> float
val generate_cloze : fact -> question option
val generate_open_question : fact -> question option
val generate_distractors : facts:fact list -> fact -> string list
val generate_mcq : facts:fact list -> fact -> question option
val validate_question : question -> bool
val deduplicate_questions : question list -> question list
