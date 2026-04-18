type stored_document = {
  id : string;
  title : string;
  reference : string;
  text : string;
  tokens : string list;
  counts : (string * int) list;
}

type stored_source = {
  id : string;
  label : string;
  documents : stored_document list;
}

type legacy_corpus = {
  sources : stored_source list;
  reference : stored_document list;
}

type source_info = {
  id : string;
  label : string;
  document_count : int;
}

type manifest = { sources : source_info list }

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

type analyzed_document = {
  stored : stored_document;
  count_map : (string, int) Hashtbl.t;
  length : int;
  tokens : string list;
}

type analyzed_source = {
  info : source_info;
  docs : analyzed_document list;
  df : (string, int) Hashtbl.t;
  total_tokens : int;
  average_length : float;
  collocations : (string, (string * int) list) Hashtbl.t;
  mutable specific_terms_cache : term_score list option;
  mutable central_concepts_cache : concept list option;
  mutable themes_cache : theme list option;
}

type t = {
  source : analyzed_source;
  reference_tf : (string, int) Hashtbl.t;
  reference_total_tokens : int;
}

type reference_stats = {
  total_tokens : int;
  frequencies : (string * int) list;
}

let ( let* ) result f = match result with Ok value -> f value | Error _ as error -> error

let preprocess_command = "dune exec processSources"

let artifact_path ~root = Filename.concat root "datas/textprocess_manifest.json"

let artifact_dir ~root = Filename.concat root "datas/textprocess_corpus"

let reference_artifact_path ~root = Filename.concat (artifact_dir ~root) "reference.json"

let reference_stats_artifact_path ~root = Filename.concat (artifact_dir ~root) "reference_stats.json"

let sanitize_source_id source_id =
  source_id
  |> String.to_seq
  |> Seq.map (function
       | ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_') as char -> char
       | _ -> '_')
  |> String.of_seq

let source_artifact_path ~root ~source_id =
  Filename.concat (artifact_dir ~root) (sanitize_source_id source_id ^ ".json")

let stopwords =
  [
    "a"; "au"; "aux"; "avec"; "ce"; "ces"; "dans"; "de"; "des"; "du"; "elle"; "en"; "et"; "eux"; "il"; "je";
    "la"; "le"; "les"; "leur"; "lui"; "ma"; "mais"; "me"; "meme"; "mes"; "moi"; "mon"; "ne"; "nos"; "notre";
    "nous"; "on"; "ou"; "par"; "pas"; "pour"; "qu"; "que"; "qui"; "sa"; "se"; "ses"; "son"; "sur"; "ta"; "te";
    "tes"; "toi"; "ton"; "tu"; "un"; "une"; "vos"; "votre"; "vous"; "c"; "d"; "l"; "y"; "est"; "sont"; "etre";
    "avait"; "ont"; "plus"; "comme"; "sans"; "donc"; "or"; "ni"; "car"; "cet"; "cette"; "ces"; "leurs"; "leurs";
    "ainsi"; "si"; "ou"; "où"; "fait"; "faites"; "été"; "etre"; "été"; "être";
  ]
  |> List.fold_left (fun set word -> Hashtbl.replace set word (); set) (Hashtbl.create 128)

let starts_with ~prefix text =
  let prefix_len = String.length prefix in
  String.length text >= prefix_len && String.sub text 0 prefix_len = prefix

let sentence_split_regexp = Str.regexp "[.!?;\n\r]+"
let token_regexp = Str.regexp "[A-Za-zÀ-ÿ0-9']+"

let normalize_spaces text = Str.global_replace (Str.regexp "[ \t]+") " " text |> String.trim

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

let normalize_token token =
  let token = String.lowercase_ascii token in
  let token_len = String.length token in
  if token_len > 5 && starts_with ~prefix:"l'" token then String.sub token 2 (token_len - 2)
  else if token_len > 5 && String.ends_with ~suffix:"es" token then String.sub token 0 (token_len - 2)
  else if token_len > 4 && String.ends_with ~suffix:"s" token then String.sub token 0 (token_len - 1)
  else if token_len > 5 && String.ends_with ~suffix:"ent" token then String.sub token 0 (token_len - 3)
  else token

let tokenize text =
  let rec loop start acc =
    try
      let _ = Str.search_forward token_regexp text start in
      let token = Str.matched_string text |> normalize_token in
      let next = Str.match_end () in
      if token = "" || Hashtbl.mem stopwords token then loop next acc else loop next (token :: acc)
    with Not_found -> List.rev acc
  in
  loop 0 []

let split_sentences text =
  Str.split sentence_split_regexp text |> List.map normalize_spaces |> List.filter (fun item -> item <> "")

let split_paragraphs text =
  Str.split (Str.regexp "\n[ \t]*\n+") text |> List.map normalize_spaces |> List.filter (fun item -> item <> "")

let count_tokens tokens =
  let table = Hashtbl.create 64 in
  List.iter
    (fun token ->
      let previous = Option.value (Hashtbl.find_opt table token) ~default:0 in
      Hashtbl.replace table token (previous + 1))
    tokens;
  table

let counts_to_list counts =
  counts |> Hashtbl.to_seq |> List.of_seq |> List.sort (fun (a, _) (b, _) -> String.compare a b)

let json_of_document (document : stored_document) =
  `Assoc
    [
      ("id", `String document.id);
      ("title", `String document.title);
      ("reference", `String document.reference);
      ("text", `String document.text);
      ("tokens", `List (List.map (fun token -> `String token) document.tokens));
      ("counts", `List (List.map (fun (term, count) -> `List [ `String term; `Int count ]) document.counts));
    ]

let document_of_json json =
  let open Yojson.Safe.Util in
  let text = json |> member "text" |> to_string in
  let tokens =
    match json |> member "tokens" with
    | `List values -> List.map to_string values
    | _ -> tokenize text
  in
  let counts =
    match json |> member "counts" with
    | `List values ->
        values
        |> List.map (fun item ->
               match item with
               | `List [ `String term; `Int count ] -> (term, count)
               | `List [ `String term; `Intlit count ] -> (term, int_of_string count)
               | _ -> failwith "Format de counts invalide")
    | _ -> count_tokens tokens |> counts_to_list
  in
  {
    id = json |> member "id" |> to_string;
    title = json |> member "title" |> to_string;
    reference = json |> member "reference" |> to_string;
    text;
    tokens;
    counts;
  }

let json_of_source_info (source : source_info) =
  `Assoc
    [
      ("id", `String source.id);
      ("label", `String source.label);
      ("document_count", `Int source.document_count);
    ]

let source_info_of_json json =
  let open Yojson.Safe.Util in
  {
    id = json |> member "id" |> to_string;
    label = json |> member "label" |> to_string;
    document_count = json |> member "document_count" |> to_int;
  }

let source_of_json json =
  let open Yojson.Safe.Util in
  {
    id = json |> member "id" |> to_string;
    label = json |> member "label" |> to_string;
    documents = json |> member "documents" |> to_list |> List.map document_of_json;
  }

let legacy_corpus_of_json json =
  let open Yojson.Safe.Util in
  {
    sources = json |> member "sources" |> to_list |> List.map source_of_json;
    reference = json |> member "reference" |> to_list |> List.map document_of_json;
  }

let build_document ~id ~title ~reference text =
  let normalized_text = normalize_spaces text in
  let tokens = tokenize normalized_text in
  let counts = count_tokens tokens |> counts_to_list in
  { id; title; reference; text = normalized_text; tokens; counts }

let analyze_documents documents =
  let df = Hashtbl.create 512 in
  let total_tokens = ref 0 in
  let docs =
    List.map
      (fun (document : stored_document) ->
        let count_map = Hashtbl.create (List.length document.counts + 8) in
        List.iter
          (fun (term, count) ->
            Hashtbl.replace count_map term count;
            Hashtbl.replace df term (Option.value (Hashtbl.find_opt df term) ~default:0 + 1))
          document.counts;
        total_tokens := !total_tokens + List.length document.tokens;
        { stored = document; count_map; length = List.length document.tokens; tokens = document.tokens })
      documents
  in
  let collocations = Hashtbl.create 256 in
  List.iter
    (fun (document : analyzed_document) ->
      let rec loop = function
        | a :: (b :: _ as rest) ->
            let previous = Option.value (Hashtbl.find_opt collocations a) ~default:[] in
            let count = Option.value (List.assoc_opt b previous) ~default:0 + 1 in
            let filtered = List.remove_assoc b previous in
            Hashtbl.replace collocations a ((b, count) :: filtered);
            loop rest
        | _ -> ()
      in
      loop document.tokens)
    docs;
  let average_length =
    if docs = [] then 0.0 else float_of_int !total_tokens /. float_of_int (List.length docs)
  in
  (docs, df, !total_tokens, average_length, collocations)

let excerpt_from_text text query_tokens =
  let sentences = split_sentences text in
  let lower_query = List.map String.lowercase_ascii query_tokens in
  let matches sentence =
    let lower = String.lowercase_ascii sentence in
    List.exists (fun token -> token <> "" && contains_substring lower token) lower_query
  in
  match List.find_opt matches sentences with
  | Some sentence -> sentence
  | None -> (match sentences with first :: _ -> first | [] -> text)

let term_idf df document_count term =
  let frequency = Option.value (Hashtbl.find_opt df term) ~default:0 in
  log ((float_of_int (document_count + 1)) /. float_of_int (frequency + 1)) +. 1.0

let bm25_score analyzed_source query_terms (document : analyzed_document) =
  let k1 = 1.5 in
  let b = 0.75 in
  let document_count = List.length analyzed_source.docs in
  let doc_len = float_of_int (max 1 document.length) in
  let avg_len = if analyzed_source.average_length <= 0.0 then 1.0 else analyzed_source.average_length in
  List.fold_left
    (fun acc term ->
      let tf = float_of_int (Option.value (Hashtbl.find_opt document.count_map term) ~default:0) in
      if tf <= 0.0 then acc
      else
        let idf = term_idf analyzed_source.df document_count term in
        let numerator = tf *. (k1 +. 1.0) in
        let denominator = tf +. k1 *. (1.0 -. b +. b *. (doc_len /. avg_len)) in
        acc +. (idf *. numerator /. denominator))
    0.0 query_terms

let cosine_score query_count_map count_map =
  let dot =
    Hashtbl.fold
      (fun term value_a acc ->
        acc +. (float_of_int value_a *. float_of_int (Option.value (Hashtbl.find_opt count_map term) ~default:0)))
      query_count_map 0.0
  in
  let norm table =
    sqrt (Hashtbl.fold (fun _term value acc -> acc +. float_of_int (value * value)) table 0.0)
  in
  let denominator = norm query_count_map *. norm count_map in
  if denominator = 0.0 then 0.0 else dot /. denominator

let query_counts text = tokenize text |> count_tokens

let semantic_expansion analyzed_source query_terms =
  query_terms
  |> List.concat_map (fun term ->
         let neighbours = Option.value (Hashtbl.find_opt analyzed_source.collocations term) ~default:[] in
         term :: (neighbours |> List.sort (fun (_, a) (_, b) -> compare b a) |> List.map fst |> List.filteri (fun index _ -> index < 3)))
  |> List.sort_uniq String.compare

let group_term_frequencies documents =
  let frequencies = Hashtbl.create 512 in
  List.iter
    (fun (document : analyzed_document) ->
      Hashtbl.iter
        (fun term count ->
          Hashtbl.replace frequencies term (Option.value (Hashtbl.find_opt frequencies term) ~default:0 + count))
        document.count_map)
    documents;
  frequencies

let reference_term_frequency reference_tf term = Option.value (Hashtbl.find_opt reference_tf term) ~default:0

let log_ratio ~target_count ~target_total ~reference_count ~reference_total =
  let target = (float_of_int (target_count + 1)) /. float_of_int (target_total + 1) in
  let reference = (float_of_int (reference_count + 1)) /. float_of_int (reference_total + 1) in
  log (target /. reference) /. log 2.0

let specific_terms_internal corpus (analyzed_source : analyzed_source) : term_score list =
  let target_freq = group_term_frequencies analyzed_source.docs in
  let doc_count = max 1 (List.length analyzed_source.docs) in
  let terms : term_score list =
    target_freq |> Hashtbl.to_seq |> List.of_seq
    |> List.map (fun (term, frequency) ->
           let df = Option.value (Hashtbl.find_opt analyzed_source.df term) ~default:1 in
           let idf = term_idf analyzed_source.df doc_count term in
           let specificity =
             if corpus.reference_total_tokens = 0 then float_of_int frequency *. idf
             else
               log_ratio ~target_count:frequency ~target_total:analyzed_source.total_tokens
                 ~reference_count:(reference_term_frequency corpus.reference_tf term)
                 ~reference_total:corpus.reference_total_tokens
           in
           {
             term;
             score = specificity +. (float_of_int df *. 0.01);
             frequency;
             reference_frequency =
               if corpus.reference_total_tokens = 0 then None else Some (reference_term_frequency corpus.reference_tf term);
           })
  in
  terms |> List.sort (fun (a : term_score) (b : term_score) -> Float.compare b.score a.score) |> List.filteri (fun index _ -> index < 30)

let central_concepts_internal (analyzed_source : analyzed_source) : concept list =
  let weights = Hashtbl.create 512 in
  let add_edge source target =
    let neighbours =
      match Hashtbl.find_opt weights source with
      | Some table -> table
      | None ->
          let table = Hashtbl.create 8 in
          Hashtbl.replace weights source table;
          table
    in
    Hashtbl.replace neighbours target (Option.value (Hashtbl.find_opt neighbours target) ~default:0 + 1)
  in
  List.iter
    (fun (document : analyzed_document) ->
      let rec windows = function
        | a :: b :: c :: rest ->
            let pairs = [ (a, b); (a, c); (b, c) ] in
            List.iter
              (fun (left, right) ->
                add_edge left right;
                add_edge right left)
              pairs;
            windows (b :: c :: rest)
        | _ -> ()
      in
      windows document.tokens)
    analyzed_source.docs;
  let concepts : concept list =
    weights |> Hashtbl.to_seq |> List.of_seq
    |> List.map (fun (term, neighbours) ->
           let sorted = neighbours |> Hashtbl.to_seq |> List.of_seq |> List.sort (fun (_, a) (_, b) -> compare b a) in
           {
             term;
             score = float_of_int (List.fold_left (fun acc (_item, count) -> acc + count) 0 sorted);
             neighbours = sorted |> List.map fst |> List.filteri (fun index _ -> index < 5);
           })
  in
  concepts |> List.sort (fun (a : concept) (b : concept) -> Float.compare b.score a.score) |> List.filteri (fun index _ -> index < 20)

let theme_title keywords index =
  match keywords with
  | first :: second :: _ -> Printf.sprintf "Thème %d: %s / %s" index first second
  | [ first ] -> Printf.sprintf "Thème %d: %s" index first
  | [] -> Printf.sprintf "Thème %d" index

let dominant_keywords (documents : analyzed_document list) =
  let frequencies = Hashtbl.create 128 in
  List.iter
    (fun (document : analyzed_document) ->
      Hashtbl.iter
        (fun term count ->
          Hashtbl.replace frequencies term (Option.value (Hashtbl.find_opt frequencies term) ~default:0 + count))
        document.count_map)
    documents;
  frequencies |> Hashtbl.to_seq |> List.of_seq |> List.sort (fun (_, a) (_, b) -> compare b a) |> List.map fst
  |> List.filteri (fun index _ -> index < 5)

let primary_keyword (document : analyzed_document) =
  Hashtbl.fold
    (fun term count best ->
      match best with
      | None -> Some (term, count)
      | Some (_best_term, best_count) when count > best_count -> Some (term, count)
      | Some current -> Some current)
    document.count_map None
  |> Option.map fst

let rec build_themes (analyzed_source : analyzed_source) (documents : analyzed_document list) depth =
  if documents = [] then []
  else if depth >= 2 || List.length documents <= 3 then
    [
      {
        title = theme_title (dominant_keywords documents) 1;
        keywords = dominant_keywords documents;
        document_ids = List.map (fun (document : analyzed_document) -> document.stored.id) documents;
        children = [];
      };
    ]
  else
    let sorted =
      documents
      |> List.map (fun (document : analyzed_document) ->
             (match primary_keyword document with Some key -> key | None -> document.stored.id), document)
      |> List.sort (fun (left, _) (right, _) -> String.compare left right)
    in
    let grouped =
      List.fold_left
        (fun acc (key, document) ->
          match acc with
          | (current_key, docs) :: rest when String.equal current_key key -> (current_key, document :: docs) :: rest
          | _ -> (key, [ document ]) :: acc)
        [] sorted
      |> List.rev
    in
    grouped
    |> List.mapi (fun index ((_, docs) : string * analyzed_document list) ->
           let docs : analyzed_document list = List.rev docs in
           let keywords = dominant_keywords docs in
           {
             title = theme_title keywords (index + 1);
             keywords;
             document_ids = List.map (fun (document : analyzed_document) -> document.stored.id) docs;
             children = build_themes analyzed_source docs (depth + 1);
           })

let summarize_internal (analyzed_source : analyzed_source) question =
  let lexical : search_hit list =
    let query_terms = tokenize question in
    List.fold_left
      (fun acc (document : analyzed_document) ->
        let score = bm25_score analyzed_source query_terms document in
        if score <= 0.0 then acc
        else
          {
            document_id = document.stored.id;
            title = document.stored.title;
            reference = document.stored.reference;
            score;
            excerpt = excerpt_from_text document.stored.text query_terms;
          }
          :: acc)
      [] analyzed_source.docs
    |> List.rev
    |> List.sort (fun (a : search_hit) (b : search_hit) -> Float.compare b.score a.score)
    |> List.filteri (fun index _ -> index < 20)
  in
  let query_vector = query_counts question in
  let semantic : search_hit list =
    List.fold_left
      (fun acc (document : analyzed_document) ->
        let score = cosine_score query_vector document.count_map in
        if score <= 0.0 then acc
        else
          {
            document_id = document.stored.id;
            title = document.stored.title;
            reference = document.stored.reference;
            score;
            excerpt = excerpt_from_text document.stored.text (tokenize question);
          }
          :: acc)
      [] analyzed_source.docs
    |> List.rev
    |> List.sort (fun (a : search_hit) (b : search_hit) -> Float.compare b.score a.score)
  in
  let combined : search_hit list =
    (lexical @ semantic)
    |> List.sort (fun (a : search_hit) (b : search_hit) -> Float.compare b.score a.score)
    |> List.fold_left
         (fun acc (hit : search_hit) ->
           if List.exists (fun (existing : search_hit) -> String.equal existing.document_id hit.document_id) acc then acc else acc @ [ hit ])
         []
    |> List.filteri (fun index _ -> index < 5)
  in
  let short_answer =
    combined |> List.filter_map (fun (hit : search_hit) -> if hit.excerpt = "" then None else Some hit.excerpt) |> List.filteri (fun index _ -> index < 2)
    |> String.concat " "
  in
  let long_answer =
    combined |> List.map (fun (hit : search_hit) -> Printf.sprintf "%s (%s): %s" hit.title hit.reference hit.excerpt) |> String.concat "\n\n"
  in
  {
    short_answer;
    long_answer;
    passages = combined |> List.map (fun (hit : search_hit) -> (hit.reference, hit.title, hit.excerpt));
  }

let take_random_items count items =
  let indexed = Array.of_list items in
  let length = Array.length indexed in
  for index = length - 1 downto 1 do
    let swap_index = Random.int (index + 1) in
    let current = indexed.(index) in
    indexed.(index) <- indexed.(swap_index);
    indexed.(swap_index) <- current
  done;
  let rec loop index acc =
    if index >= min count length then List.rev acc else loop (index + 1) (indexed.(index) :: acc)
  in
  loop 0 []

let random_choice items =
  match items with
  | [] -> None
  | _ -> Some (List.nth items (Random.int (List.length items)))

let build_generated_phrase analyzed_source token =
  let rec extend seen current remaining acc =
    if remaining <= 0 then List.rev acc
    else
      let neighbours =
        Option.value (Hashtbl.find_opt analyzed_source.collocations current) ~default:[]
        |> List.sort (fun (_, a) (_, b) -> compare b a)
        |> List.map fst
        |> List.filter (fun candidate -> not (List.mem candidate seen))
      in
      match random_choice (take_random_items 3 neighbours) with
      | None -> List.rev acc
      | Some next -> extend (next :: seen) next (remaining - 1) (next :: acc)
  in
  let phrase_tokens = token :: extend [ token ] token 5 [] in
  phrase_tokens
  |> List.map (fun item -> if item = "" then item else String.lowercase_ascii item)
  |> String.concat " "
  |> String.capitalize_ascii
  |> fun phrase -> phrase ^ "."

let collect_distinct_phrases ~count ~attempts ~is_valid build =
  let rec loop attempts_left acc =
    if List.length acc >= count || attempts_left <= 0 then List.rev acc
    else
      let phrase = build () |> String.trim in
      if (not (is_valid phrase)) || List.mem phrase acc then loop (attempts_left - 1) acc else loop (attempts_left - 1) (phrase :: acc)
  in
  loop attempts []

let generate_internal (analyzed_source : analyzed_source) word =
  let token = normalize_token word in
  let trivial_phrase = String.capitalize_ascii token ^ "." in
  let is_valid phrase = phrase <> "" && not (String.equal phrase trivial_phrase) in
  let synthetic =
    collect_distinct_phrases ~count:2 ~attempts:16 ~is_valid (fun () -> build_generated_phrase analyzed_source token)
  in
  if List.length synthetic >= 2 then synthetic
  else
    let fallback_candidates =
      analyzed_source.docs
      |> List.filter_map (fun document ->
             if List.mem token document.tokens then Some (String.capitalize_ascii (String.concat " " (take_random_items 4 document.tokens)) ^ ".") else None)
      |> List.filter is_valid |> List.sort_uniq String.compare
    in
    let missing = max 0 (2 - List.length synthetic) in
    let fallback =
      fallback_candidates |> List.filter (fun phrase -> not (List.mem phrase synthetic)) |> take_random_items missing
    in
    match synthetic @ fallback with
    | [] -> [ String.capitalize_ascii word ^ "." ]
    | values -> values

let source_depth_hint source_id =
  match source_id with
  | "Bible" -> Some 2
  | "Coran" -> Some 1
  | _ -> None

let log_preprocess message = prerr_endline ("[processSources] " ^ message)

let write_json channel json = Yojson.Safe.to_channel channel json

let write_json_field channel name json =
  output_string channel "\"";
  output_string channel name;
  output_string channel "\":";
  write_json channel json

let write_document channel (document : stored_document) = write_json channel (json_of_document document)

let preprocess_hugo_iter ~root ~emit =
  let path = Filename.concat root "datas/Hugo.txt" in
  let text = Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all in
  let count = ref 0 in
  text |> split_paragraphs
  |> List.filteri (fun index paragraph -> String.length paragraph > 120 && index mod 3 = 0)
  |> List.iteri (fun index paragraph ->
         incr count;
         emit
           (build_document ~id:(Printf.sprintf "Hugo:%d" (index + 1)) ~title:(Printf.sprintf "Hugo %d" (index + 1))
              ~reference:(Printf.sprintf "Hugo:%d" (index + 1)) paragraph);
         if !count mod 100 = 0 then log_preprocess (Printf.sprintf "Corpus de référence: %d extraits écrits..." !count));
  !count

let rec iter_source_documents ~root ~names ~bible_translation ~source_id path depth ~emit =
  let current_reference =
    if path = [] then Error "empty"
    else Sources.compile_reference ~root ~names ~bible_translation ~source:source_id ~path
  in
  let current_rendered =
    match current_reference with
    | Ok reference -> Sources.render_reference ~root ~names ~bible_translation ~reference
    | Error _ -> Error "not-renderable"
  in
  let should_take_current =
    match source_depth_hint source_id, path, current_rendered with
    | Some expected_depth, _, Ok rendered when List.length path = expected_depth && String.trim rendered.body <> "" ->
        Some rendered
    | _, _, _ -> None
  in
  match should_take_current with
  | Some rendered ->
      let id = source_id ^ ":" ^ rendered.reference in
      emit (build_document ~id ~title:rendered.title ~reference:rendered.reference rendered.body);
      Ok ()
  | None ->
      if depth > 6 then Ok ()
      else
        match Sources.selector_count ~root ~names ~bible_translation ~source:source_id ~path with
        | Ok (Some count) ->
            let rec loop index =
              if index > count then Ok ()
              else
                let* () =
                  iter_source_documents ~root ~names ~bible_translation ~source_id (path @ [ string_of_int index ]) (depth + 1) ~emit
                in
                loop (index + 1)
            in
            loop 1
        | _ -> (
            match Sources.selector_options ~root ~names ~bible_translation ~source:source_id ~path with
            | Ok options when options <> [] ->
                List.fold_left
                  (fun result (option : Sources.selector_option) ->
                    let* () = result in
                    iter_source_documents ~root ~names ~bible_translation ~source_id (path @ [ option.value ]) (depth + 1) ~emit)
                  (Ok ()) options
            | _ -> (
                match current_rendered with
                | Ok rendered when String.trim rendered.body <> "" ->
                    let id = source_id ^ ":" ^ rendered.reference in
                    emit (build_document ~id ~title:rendered.title ~reference:rendered.reference rendered.body);
                    Ok ()
                | _ -> Ok ()))

let ensure_directory path =
  if Sys.file_exists path then
    if Sys.is_directory path then Ok () else Error (path ^ " existe mais n'est pas un dossier.")
  else (
    Unix.mkdir path 0o755;
    Ok ())

let json_of_reference_stats stats =
  `Assoc
    [
      ("total_tokens", `Int stats.total_tokens);
      ("frequencies", `List (List.map (fun (term, count) -> `List [ `String term; `Int count ]) stats.frequencies));
    ]

let reference_stats_of_json json =
  let open Yojson.Safe.Util in
  let frequencies =
    json |> member "frequencies" |> to_list
    |> List.map (fun item ->
           match item with
           | `List [ `String term; `Int count ] -> (term, count)
           | `List [ `String term; `Intlit count ] -> (term, int_of_string count)
           | _ -> failwith "Format de reference_stats invalide")
  in
  { total_tokens = json |> member "total_tokens" |> to_int; frequencies }

let write_reference_stats ~root stats =
  let path = reference_stats_artifact_path ~root in
  let temp_path = path ^ ".tmp" in
  try
    Yojson.Safe.to_file temp_path (json_of_reference_stats stats);
    Sys.rename temp_path path;
    Ok ()
  with
  | Sys_error message ->
      if Sys.file_exists temp_path then Sys.remove temp_path;
      Error message
  | error ->
      if Sys.file_exists temp_path then Sys.remove temp_path;
      raise error

let reference_stats_to_tables stats =
  let table = Hashtbl.create (List.length stats.frequencies + 8) in
  List.iter (fun (term, count) -> Hashtbl.replace table term count) stats.frequencies;
  (table, stats.total_tokens)

let write_reference_artifact ~root =
  let path = reference_artifact_path ~root in
  let temp_path = path ^ ".tmp" in
  let frequencies = Hashtbl.create 512 in
  let total_tokens = ref 0 in
  try
    ignore
      (Stdlib.Out_channel.with_open_bin temp_path (fun channel ->
           output_string channel "{\"documents\":[";
           let first_reference = ref true in
           log_preprocess "Corpus de référence: démarrage...";
           let reference_count =
             preprocess_hugo_iter ~root ~emit:(fun document ->
                 total_tokens := !total_tokens + List.length document.tokens;
                 List.iter
                   (fun (term, count) ->
                     Hashtbl.replace frequencies term (Option.value (Hashtbl.find_opt frequencies term) ~default:0 + count))
                   document.counts;
                 if !first_reference then first_reference := false else output_char channel ',';
                 write_document channel document)
           in
           output_string channel "]}";
           log_preprocess (Printf.sprintf "Corpus de référence: terminé avec %d extraits." reference_count);
           reference_count));
    Sys.rename temp_path path;
    let stats = { total_tokens = !total_tokens; frequencies = counts_to_list frequencies } in
    let* () = write_reference_stats ~root stats in
    Ok ()
  with
  | Sys_error message ->
      if Sys.file_exists temp_path then Sys.remove temp_path;
      Error message
  | error ->
      if Sys.file_exists temp_path then Sys.remove temp_path;
      raise error

let write_source_artifact ~root ~names ~index ~total (source : Sources.source_descriptor) =
  log_preprocess (Printf.sprintf "Source %d/%d: %s (%s), démarrage..." index total source.label source.id);
  let path = source_artifact_path ~root ~source_id:source.id in
  let temp_path = path ^ ".tmp" in
  let first_document = ref true in
  let document_count = ref 0 in
  try
    let* () =
      Stdlib.Out_channel.with_open_bin temp_path (fun channel ->
          output_char channel '{';
          write_json_field channel "id" (`String source.id);
          output_char channel ',';
          write_json_field channel "label" (`String source.label);
          output_string channel ",\"documents\":[";
          let emit document =
            incr document_count;
            if !first_document then first_document := false else output_char channel ',';
            write_document channel document;
            if !document_count mod 100 = 0 then
              log_preprocess
                (Printf.sprintf "Source %d/%d: %s (%s), %d documents écrits..." index total source.label source.id !document_count)
          in
          let* () =
            iter_source_documents ~root ~names ~bible_translation:"bible_aelf" ~source_id:source.id [] 0 ~emit
          in
          output_string channel "]}";
          Ok ())
    in
    Sys.rename temp_path path;
    log_preprocess (Printf.sprintf "Source %d/%d: %s (%s), terminé avec %d documents." index total source.label source.id !document_count);
    Ok { id = source.id; label = source.label; document_count = !document_count }
  with
  | Sys_error message ->
      if Sys.file_exists temp_path then Sys.remove temp_path;
      Error message
  | error ->
      if Sys.file_exists temp_path then Sys.remove temp_path;
      raise error

let write_manifest ~root manifest =
  let path = artifact_path ~root in
  let temp_path = path ^ ".tmp" in
  try
    Yojson.Safe.to_file temp_path (`Assoc [ ("sources", `List (List.map json_of_source_info manifest.sources)) ]);
    Sys.rename temp_path path;
    Ok ()
  with
  | Sys_error message ->
      if Sys.file_exists temp_path then Sys.remove temp_path;
      Error message
  | error ->
      if Sys.file_exists temp_path then Sys.remove temp_path;
      raise error

let preprocess_and_save ~root =
  let* names = Book_names.load ~root in
  let sources = Sources.list_sources ~root in
  let total_sources = List.length sources in
  let* () = ensure_directory (artifact_dir ~root) in
  try
    log_preprocess (Printf.sprintf "Prétraitement démarré. %d corpus à parcourir." total_sources);
    let* source_infos =
      sources
      |> List.mapi (fun index source -> (index + 1, source))
      |> List.fold_left
           (fun result (index, source) ->
             let* acc = result in
             let* source_info = write_source_artifact ~root ~names ~index ~total:total_sources source in
             Ok (source_info :: acc))
           (Ok [])
    in
    let* () = write_reference_artifact ~root in
    let manifest = { sources = List.rev source_infos } in
    let* () = write_manifest ~root manifest in
    log_preprocess ("Prétraitement terminé. Manifeste écrit dans " ^ artifact_path ~root);
    Ok ()
  with Sys_error message -> Error message

let ensure_preprocessed ~root =
  let path = artifact_path ~root in
  if not (Sys.file_exists path) then (
    prerr_endline ("Prétraitement manquant. Lance d'abord : " ^ preprocess_command);
    failwith ("Prétraitement introuvable: " ^ path))

let manifest_of_json json =
  let open Yojson.Safe.Util in
  { sources = json |> member "sources" |> to_list |> List.map source_info_of_json }

let load_reference_stats ~root =
  let path = reference_stats_artifact_path ~root in
  if Sys.file_exists path then Yojson.Safe.from_file path |> reference_stats_of_json |> reference_stats_to_tables
  else
    let json = Yojson.Safe.from_file (reference_artifact_path ~root) in
    let open Yojson.Safe.Util in
    let docs, _df, total_tokens, _average_length, _collocations =
      json |> member "documents" |> to_list |> List.map document_of_json |> analyze_documents
    in
    (group_term_frequencies docs, total_tokens)

let load ~root ~source =
  try
    let manifest_json = Yojson.Safe.from_file (artifact_path ~root) in
    let open Yojson.Safe.Util in
    let uses_legacy_format =
      match manifest_json |> member "reference" with
      | `Null -> false
      | _ -> true
    in
    if uses_legacy_format then
      let legacy = legacy_corpus_of_json manifest_json in
      let source_entry =
        List.find_opt (fun (entry : stored_source) -> String.equal entry.id source) legacy.sources
      in
      match source_entry with
      | None -> Error ("Source inconnue: " ^ source)
      | Some source_entry ->
          let docs, df, total_tokens, average_length, collocations = analyze_documents source_entry.documents in
          let reference_docs, _reference_df, reference_total_tokens, _average_length, _collocations = analyze_documents legacy.reference in
          let reference_tf = group_term_frequencies reference_docs in
          Ok
            {
              source =
                {
                  info = { id = source_entry.id; label = source_entry.label; document_count = List.length source_entry.documents };
                  docs;
                  df;
                  total_tokens;
                  average_length;
                  collocations;
                  specific_terms_cache = None;
                  central_concepts_cache = None;
                  themes_cache = None;
                };
              reference_tf;
              reference_total_tokens;
            }
    else
      let manifest = manifest_of_json manifest_json in
      match List.find_opt (fun (entry : source_info) -> String.equal entry.id source) manifest.sources with
      | None -> Error ("Source inconnue: " ^ source)
      | Some source_info ->
          let source_json = Yojson.Safe.from_file (source_artifact_path ~root ~source_id:source) in
          let source_stored = source_of_json source_json in
          let docs, df, total_tokens, average_length, collocations = analyze_documents source_stored.documents in
          let reference_tf, reference_total_tokens = load_reference_stats ~root in
          Ok
            {
              source =
                {
                  info = source_info;
                  docs;
                  df;
                  total_tokens;
                  average_length;
                  collocations;
                  specific_terms_cache = None;
                  central_concepts_cache = None;
                  themes_cache = None;
                };
              reference_tf;
              reference_total_tokens;
            }
  with Sys_error message | Yojson.Json_error message -> Error message

let lookup_source corpus source =
  if String.equal corpus.source.info.id source then corpus.source else invalid_arg ("Source inconnue: " ^ source)

let sources corpus = [ corpus.source.info ]

let lexical_search corpus ~source ~query =
  let analyzed_source = lookup_source corpus source in
  let query_terms = tokenize query in
  let hits : search_hit list =
    List.fold_left
      (fun acc (document : analyzed_document) ->
        let score = bm25_score analyzed_source query_terms document in
        if score <= 0.0 then acc
        else
          {
            document_id = document.stored.id;
            title = document.stored.title;
            reference = document.stored.reference;
            score;
            excerpt = excerpt_from_text document.stored.text query_terms;
          }
          :: acc)
      [] analyzed_source.docs
    |> List.rev
  in
  hits |> List.sort (fun (a : search_hit) (b : search_hit) -> Float.compare b.score a.score) |> List.filteri (fun index _ -> index < 20)

let semantic_search corpus ~source ~query =
  let analyzed_source = lookup_source corpus source in
  let expanded = semantic_expansion analyzed_source (tokenize query) in
  let query_vector = count_tokens expanded in
  let hits : search_hit list =
    List.fold_left
      (fun acc (document : analyzed_document) ->
        let score = cosine_score query_vector document.count_map in
        if score <= 0.0 then acc
        else
          {
            document_id = document.stored.id;
            title = document.stored.title;
            reference = document.stored.reference;
            score;
            excerpt = excerpt_from_text document.stored.text expanded;
          }
          :: acc)
      [] analyzed_source.docs
    |> List.rev
  in
  hits |> List.sort (fun (a : search_hit) (b : search_hit) -> Float.compare b.score a.score) |> List.filteri (fun index _ -> index < 20)

let specific_terms corpus ~source =
  let analyzed_source = lookup_source corpus source in
  match analyzed_source.specific_terms_cache with
  | Some terms -> terms
  | None ->
      let terms = specific_terms_internal corpus analyzed_source in
      analyzed_source.specific_terms_cache <- Some terms;
      terms

let central_concepts corpus ~source =
  let analyzed_source = lookup_source corpus source in
  match analyzed_source.central_concepts_cache with
  | Some concepts -> concepts
  | None ->
      let concepts = central_concepts_internal analyzed_source in
      analyzed_source.central_concepts_cache <- Some concepts;
      concepts

let themes corpus ~source =
  let analyzed_source = lookup_source corpus source in
  match analyzed_source.themes_cache with
  | Some themes -> themes
  | None ->
      let computed = build_themes analyzed_source analyzed_source.docs 0 in
      analyzed_source.themes_cache <- Some computed;
      computed

let summarize corpus ~source ~question =
  let analyzed_source = lookup_source corpus source in
  summarize_internal analyzed_source question

let generate_from_word corpus ~source ~word =
  let analyzed_source = lookup_source corpus source in
  generate_internal analyzed_source word
