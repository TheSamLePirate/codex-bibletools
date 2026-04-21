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

let contains_substring text needle =
  let text_len = String.length text in
  let needle_len = String.length needle in
  let rec loop index =
    if needle_len = 0 then true
    else if index + needle_len > text_len then false
    else if String.sub text index needle_len = needle then true
    else loop (index + 1)
  in
  loop 0

let strip_trailing_punctuation text =
  String.trim text |> Str.replace_first (Str.regexp "[ .;:!?]+$") "" |> String.trim

let starts_with_uppercase text =
  String.length text > 0
  &&
  match text.[0] with
  | 'A' .. 'Z' | '\192' .. '\222' -> true
  | _ -> false

let tokenize = Text_process.tokenize

let lemmatize_token = Text_process.normalize_token

let make_sentence ~doc_id ~index ~char_start ~char_end text =
  let text = Text_process.normalize_spaces text in
  let tokens = tokenize text in
  {
    sentence_id = Printf.sprintf "%s:s%d" doc_id index;
    doc_id;
    text;
    tokens;
    lemmas = List.map lemmatize_token tokens;
    char_start;
    char_end;
  }

let segment_sentences ~doc_id text =
  let find_sentence_start ~from sentence =
    try Str.search_forward (Str.regexp_string sentence) text from
    with Not_found -> from
  in
  Text_process.split_sentences text
  |> List.fold_left
       (fun (index, search_from, sentences) sentence_text ->
         let char_start = find_sentence_start ~from:search_from sentence_text in
         let char_end = char_start + String.length sentence_text in
         let sentence = make_sentence ~doc_id ~index ~char_start ~char_end sentence_text in
         (index + 1, char_end, sentence :: sentences))
       (1, 0, [])
  |> fun (_, _, sentences) -> List.rev sentences

let answer_type_of_text text =
  if Str.string_match (Str.regexp ".*[0-9][0-9][0-9][0-9].*") text 0 then Date
  else if starts_with_uppercase text && List.length (tokenize text) <= 4 then Person
  else if List.length (tokenize text) <= 4 then Concept
  else Text

let fact_id (sentence : annotated_sentence) suffix = sentence.sentence_id ^ ":" ^ suffix

let make_fact (sentence : annotated_sentence) suffix fact_type subject predicate object_ confidence =
  let subject = strip_trailing_punctuation subject in
  let object_ = strip_trailing_punctuation object_ in
  {
    fact_id = fact_id sentence suffix;
    doc_id = sentence.doc_id;
    sentence_id = sentence.sentence_id;
    source_text = sentence.text;
    fact_type;
    subject;
    predicate;
    object_;
    answer_type = answer_type_of_text (if fact_type = Date_event then object_ else subject);
    confidence;
  }

let match_first patterns text =
  List.find_map
    (fun (regexp, build) ->
      if Str.string_match regexp text 0 then Some (build ()) else None)
    patterns

let extract_definitions sentences =
  sentences
  |> List.filter_map (fun sentence ->
         let text = strip_trailing_punctuation sentence.text in
         match_first
           [
             ( Str.regexp "^\\(.+\\) est \\(.+\\)$",
               fun () -> make_fact sentence "def" Definition (Str.matched_group 1 text) "être" (Str.matched_group 2 text) 0.85 );
             ( Str.regexp "^\\(.+\\) désigne \\(.+\\)$",
               fun () -> make_fact sentence "def" Definition (Str.matched_group 1 text) "désigner" (Str.matched_group 2 text) 0.9 );
             ( Str.regexp "^\\(.+\\) correspond à \\(.+\\)$",
               fun () -> make_fact sentence "def" Definition (Str.matched_group 1 text) "correspondre" (Str.matched_group 2 text) 0.82 );
             ( Str.regexp "^\\(.+\\) se définit comme \\(.+\\)$",
               fun () -> make_fact sentence "def" Definition (Str.matched_group 1 text) "définir" (Str.matched_group 2 text) 0.9 );
           ]
           text)

let normalize_relation_predicate = function
  | "écrit" | "ecrit" -> "écrire"
  | "inventé" | "invente" -> "inventer"
  | "formulé" | "formule" -> "formuler"
  | value -> value

let extract_relations sentences =
  sentences
  |> List.filter_map (fun sentence ->
         let text = strip_trailing_punctuation sentence.text in
         match_first
           [
             ( Str.regexp "^\\(.+\\) a \\(écrit\\|ecrit\\|inventé\\|invente\\|formulé\\|formule\\) \\(.+\\)$",
               fun () ->
                 let predicate = normalize_relation_predicate (Str.matched_group 2 text) in
                 make_fact sentence "rel" Subject_verb_object (Str.matched_group 1 text) predicate (Str.matched_group 3 text) 0.82 );
             ( Str.regexp "^\\(.+\\) a été \\(écrit\\|ecrit\\|inventé\\|invente\\|formulé\\|formule\\) par \\(.+\\)$",
               fun () ->
                 let predicate = normalize_relation_predicate (Str.matched_group 2 text) in
                 make_fact sentence "rel" Subject_verb_object (Str.matched_group 3 text) predicate (Str.matched_group 1 text) 0.78 );
           ]
           text)

let extract_dates sentences =
  let date_regexp = Str.regexp "\\(en\\|le\\) +\\([0-9][0-9]?[ /a-zA-ZÀ-ÿ]*[0-9][0-9][0-9][0-9]\\|[0-9][0-9][0-9][0-9]\\)" in
  sentences
  |> List.filter_map (fun sentence ->
         try
           ignore (Str.search_forward date_regexp sentence.text 0);
           let date = Str.matched_group 2 sentence.text |> strip_trailing_punctuation in
           let event =
             Str.global_replace date_regexp "" sentence.text |> strip_trailing_punctuation |> Text_process.normalize_spaces
           in
           if event = "" then None else Some (make_fact sentence "date" Date_event event "avoir lieu" date 0.72)
         with Not_found -> None)

let split_enumeration_items text =
  text |> Str.split (Str.regexp " *, *\\| +et +") |> List.map strip_trailing_punctuation |> List.filter (( <> ) "")

let extract_enumerations sentences =
  sentences
  |> List.filter_map (fun sentence ->
         let text = strip_trailing_punctuation sentence.text in
         if Str.string_match (Str.regexp "^\\(.+\\) sont *: *\\(.+\\)$") text 0 then
           let subject = Str.matched_group 1 text in
           let items = split_enumeration_items (Str.matched_group 2 text) in
           if List.length items >= 2 then Some (make_fact sentence "enum" Enumeration subject "énumérer" (String.concat ", " items) 0.8)
           else None
         else None)

let extract_facts sentences =
  extract_definitions sentences @ extract_relations sentences @ extract_dates sentences @ extract_enumerations sentences

let score_fact fact =
  let answer_len = String.length fact.object_ in
  let length_score =
    if answer_len = 0 then 0.0 else if answer_len <= 80 then 1.0 else if answer_len <= 140 then 0.6 else 0.2
  in
  let type_score =
    match fact.fact_type with
    | Definition -> 0.9
    | Subject_verb_object -> 0.82
    | Date_event -> 0.78
    | Enumeration -> 0.74
  in
  (fact.confidence *. 0.5) +. (type_score *. 0.3) +. (length_score *. 0.2)

let replace_first_literal ~needle ~replacement text =
  try
    let start = Str.search_forward (Str.regexp_string needle) text 0 in
    String.sub text 0 start ^ replacement ^ String.sub text (start + String.length needle) (String.length text - start - String.length needle)
  with Not_found -> text

let validate_question question =
  let support = String.lowercase_ascii question.support_text in
  let answer = String.lowercase_ascii question.correct_answer in
  let answer_supported = answer <> "" && Str.string_match (Str.regexp (".*" ^ Str.quote answer ^ ".*")) support 0 in
  let choices_valid =
    match question.question_type with
    | Multiple_choice ->
        List.length question.choices >= 2
        && List.length (List.sort_uniq String.compare question.choices) = List.length question.choices
        && List.exists (String.equal question.correct_answer) question.choices
    | Cloze | Open -> true
  in
  question.prompt <> "" && answer_supported && choices_valid

let make_question question_type (fact : fact) prompt correct_answer choices =
  let question =
    {
      question_id = fact.fact_id ^ ":q";
      fact_id = fact.fact_id;
      question_type;
      prompt;
      correct_answer;
      choices;
      support_sentence_id = fact.sentence_id;
      support_text = fact.source_text;
      valid = false;
    }
  in
  { question with valid = validate_question question }

let generate_cloze fact =
  let answer =
    match fact.fact_type with
    | Definition | Date_event | Enumeration -> fact.object_
    | Subject_verb_object -> fact.subject
  in
  let prompt = replace_first_literal ~needle:answer ~replacement:"___" fact.source_text in
  if String.equal prompt fact.source_text then None else Some (make_question Cloze fact prompt answer [])

let generate_open_question fact =
  let prompt, answer =
    match fact.fact_type with
    | Definition -> (Printf.sprintf "Qu'est-ce que %s ?" fact.subject, fact.object_)
    | Subject_verb_object when fact.answer_type = Person ->
        (Printf.sprintf "Qui a %s %s ?" fact.predicate fact.object_, fact.subject)
    | Subject_verb_object -> (Printf.sprintf "Qu'a %s %s ?" fact.predicate fact.subject, fact.object_)
    | Date_event -> (Printf.sprintf "Quand %s ?" fact.subject, fact.object_)
    | Enumeration -> (Printf.sprintf "Quels éléments sont associés à %s ?" fact.subject, fact.object_)
  in
  Some (make_question Open fact prompt answer [])

let generate_distractors ~facts (fact : fact) =
  let correct =
    match fact.fact_type with
    | Subject_verb_object when fact.answer_type = Person -> fact.subject
    | _ -> fact.object_
  in
  facts
  |> List.filter_map (fun (candidate : fact) ->
         if candidate.fact_id = fact.fact_id || candidate.answer_type <> fact.answer_type then None
         else
           let answer =
             match candidate.fact_type with
             | Subject_verb_object when candidate.answer_type = Person -> candidate.subject
             | _ -> candidate.object_
           in
           let answer = strip_trailing_punctuation answer in
           if answer = "" || String.equal answer correct || contains_substring (String.lowercase_ascii answer) (String.lowercase_ascii correct) then None
           else Some answer)
  |> List.sort_uniq String.compare
  |> List.filteri (fun index _ -> index < 3)

let generate_mcq ~facts (fact : fact) =
  match generate_open_question fact with
  | None -> None
  | Some open_question ->
      let distractors = generate_distractors ~facts fact in
      if List.length distractors < 2 then None
      else
        let choices = open_question.correct_answer :: distractors |> List.sort String.compare in
        Some (make_question Multiple_choice fact open_question.prompt open_question.correct_answer choices)

let deduplicate_questions questions =
  questions
  |> List.fold_left
       (fun acc question ->
         let key = String.lowercase_ascii (question.prompt ^ "\000" ^ question.correct_answer) in
         if List.exists (fun (existing_key, _question) -> String.equal existing_key key) acc then acc else (key, question) :: acc)
       []
  |> List.rev |> List.map snd
