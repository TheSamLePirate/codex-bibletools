type combo_state = {
  widget : Gtk_bindings.widget;
  mutable entries : (string * string) list;
}

type operation =
  | Search_lexical
  | Search_semantic
  | Specific_terms
  | Specific_terms_hierarchy
  | Central_concepts
  | Themes
  | Summary
  | Generate
  | Quiz_open
  | Quiz_mcq

type quiz_item = {
  quiz_operation : operation;
  quiz_source : string;
  question : Quiz.question;
  reference : string;
  title : string;
}

type quiz_cache = {
  cache_source : string;
  open_questions : quiz_item list;
  mcq_questions : quiz_item list;
}

type t = {
  root : string;
  names : Book_names.t;
  bible_translation : string;
  corpus : Text_process.t;
  window : Gtk_bindings.widget;
  source_combo : combo_state;
  operation_combo : combo_state;
  query_label : Gtk_bindings.widget;
  query_entry : Gtk_bindings.widget;
  reroll_button : Gtk_bindings.widget;
  new_question_button : Gtk_bindings.widget;
  output_label : Gtk_bindings.widget;
  status_label : Gtk_bindings.widget;
  mutable current_quiz : quiz_item option;
  mutable quiz_cache : quiz_cache option;
}

let compact_text max_chars text =
  if String.length text <= max_chars then text else String.sub text 0 (max_chars - 1) ^ "…"

let fill_combo combo entries =
  combo.entries <- entries;
  Gtk_bindings.combo_box_text_remove_all combo.widget;
  List.iter (fun (_value, label) -> Gtk_bindings.combo_box_text_append_text combo.widget (compact_text 32 label)) entries;
  if entries = [] then Gtk_bindings.combo_box_set_active combo.widget (-1) else Gtk_bindings.combo_box_set_active combo.widget 0

let combo_value combo =
  match Gtk_bindings.combo_box_get_active combo.widget with
  | index when index >= 0 && index < List.length combo.entries -> Some (fst (List.nth combo.entries index))
  | _ -> None

let connect_combo_scroll combo =
  Gtk_bindings.connect_scroll combo.widget (fun direction ->
      let count = List.length combo.entries in
      let current = Gtk_bindings.combo_box_get_active combo.widget in
      match Ui_tools.combo_scroll_target ~current ~count ~direction with
      | Some next -> Gtk_bindings.combo_box_set_active combo.widget next
      | None -> ())

let create_label text =
  let label = Gtk_bindings.label_new text in
  Gtk_bindings.label_set_line_wrap label true;
  label

let pascatho_url_encode text =
  let buffer = Buffer.create (String.length text * 3) in
  String.iter
    (fun char ->
      match char with
      | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '-' | '_' | '.' | '~' -> Buffer.add_char buffer char
      | _ -> Buffer.add_string buffer (Printf.sprintf "%%%02X" (Char.code char)))
    text;
  Buffer.contents buffer

let pascatho_url reference = "pascatho://" ^ pascatho_url_encode reference

let open_uri uri =
  let dev_null = Unix.openfile "/dev/null" [ Unix.O_RDWR ] 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close dev_null)
    (fun () ->
      let argv = [| "xdg-open"; uri |] in
      ignore (Unix.create_process "xdg-open" argv dev_null dev_null dev_null))

let append_markup_escaped buffer = function
  | '&' -> Buffer.add_string buffer "&amp;"
  | '<' -> Buffer.add_string buffer "&lt;"
  | '>' -> Buffer.add_string buffer "&gt;"
  | '"' -> Buffer.add_string buffer "&quot;"
  | '\'' -> Buffer.add_string buffer "&#39;"
  | '\n' -> Buffer.add_string buffer "&#10;"
  | chr -> Buffer.add_char buffer chr

let escape_markup_text text =
  let sanitized = Article_markdown.sanitize_text text in
  let buffer = Buffer.create (String.length sanitized * 2) in
  String.iter (append_markup_escaped buffer) sanitized;
  Buffer.contents buffer

let markup_heading text = "<b>" ^ escape_markup_text text ^ "</b>"

let markup_paragraphs items = String.concat "&#10;&#10;" items

let reference_link_markup reference =
  Printf.sprintf "<a href=\"%s\">%s</a>" (pascatho_url reference) (escape_markup_text reference)

let format_hits title hits =
  let body =
    if hits = [] then escape_markup_text "Aucun résultat."
    else
      hits
      |> List.mapi (fun index (hit : Text_process.search_hit) ->
             Printf.sprintf "%d. %s [%s]&#10;score=%.3f&#10;%s" (index + 1) (escape_markup_text hit.title)
               (reference_link_markup hit.reference) hit.score (escape_markup_text hit.excerpt))
      |> markup_paragraphs
  in
  markup_paragraphs [ markup_heading title; body ]

let rec flatten_themes level themes =
  themes
  |> List.concat_map (fun (theme : Text_process.theme) ->
         let indent = String.make (level * 2) ' ' in
         let current =
           Printf.sprintf "%s- %s\n%s  mots-clés: %s\n%s  docs: %d" indent theme.title indent
             (String.concat ", " theme.keywords) indent (List.length theme.document_ids)
         in
         current :: flatten_themes (level + 1) theme.children)

let operation_of_string = function
  | "search-lexical" -> Search_lexical
  | "search-semantic" -> Search_semantic
  | "specific-terms" -> Specific_terms
  | "specific-terms-hierarchy" -> Specific_terms_hierarchy
  | "central-concepts" -> Central_concepts
  | "themes" -> Themes
  | "summary" -> Summary
  | "generate" -> Generate
  | "quiz-open" -> Quiz_open
  | "quiz-mcq" -> Quiz_mcq
  | _ -> Search_lexical

let operation_requires_query = function
  | Search_lexical | Search_semantic | Summary | Generate -> true
  | Specific_terms | Specific_terms_hierarchy | Central_concepts | Themes | Quiz_open | Quiz_mcq -> false

let operation_supports_reroll = function
  | Generate -> true
  | Search_lexical | Search_semantic | Specific_terms | Specific_terms_hierarchy | Central_concepts | Themes | Summary | Quiz_open | Quiz_mcq -> false

let operation_supports_new_question = function
  | Quiz_open | Quiz_mcq -> true
  | Search_lexical | Search_semantic | Specific_terms | Specific_terms_hierarchy | Central_concepts | Themes | Summary | Generate -> false

let operation_query_label = function
  | Generate -> "Mot"
  | Search_lexical | Search_semantic | Summary -> "Question"
  | Specific_terms | Specific_terms_hierarchy | Central_concepts | Themes | Quiz_open | Quiz_mcq -> "Question"

let operation_label = function
  | Search_lexical -> "Recherche lexicale"
  | Search_semantic -> "Recherche sémantique"
  | Specific_terms -> "Vocabulaire spécifique"
  | Specific_terms_hierarchy -> "Vocabulaire spécifique hiérarchique"
  | Central_concepts -> "Concepts centraux"
  | Themes -> "Hiérarchie thématique"
  | Summary -> "Résumé"
  | Generate -> "Génération depuis un mot"
  | Quiz_open -> "Quizz"
  | Quiz_mcq -> "QCM"

let selected_operation ui = combo_value ui.operation_combo |> Option.map operation_of_string

let set_output ui markup = Gtk_bindings.label_set_markup ui.output_label markup

let set_status ui text = Gtk_bindings.label_set_text ui.status_label text

let log_text_tools message = prerr_endline ("[textTools] " ^ message)

let current_source_descriptor ui source =
  Sources.list_sources ~root:ui.root |> List.find_opt (fun (descriptor : Sources.source_descriptor) -> String.equal descriptor.id source)

let top_hierarchy_entries ui source =
  match Sources.selector_options ~root:ui.root ~names:ui.names ~bible_translation:ui.bible_translation ~source ~path:[] with
  | Ok options -> options
  | Error _ -> []

let render_hierarchical_specific_terms ui ~source ~path ~label =
  match Text_process.specific_terms_for_path ui.corpus ~root:ui.root ~names:ui.names ~bible_translation:ui.bible_translation ~source ~path with
  | Error message -> Error message
  | Ok terms ->
      let body = terms |> List.map (fun (term : Text_process.term_score) -> escape_markup_text term.term) |> String.concat "&#10;" in
      Ok
        (markup_paragraphs
           [
             markup_heading (operation_label Specific_terms_hierarchy);
             markup_heading label;
             if body = "" then escape_markup_text "Aucun résultat." else body;
           ])

let show_hierarchy_specific_terms_dialog ui source =
  let entries = top_hierarchy_entries ui source in
  let descriptor = current_source_descriptor ui source in
  match entries, descriptor with
  | [], _ ->
      set_status ui ("Source: " ^ source ^ " | Aucune hiérarchie disponible.");
      set_output ui (markup_paragraphs [ markup_heading (operation_label Specific_terms_hierarchy); escape_markup_text "Aucune hiérarchie disponible." ])
  | entries, Some descriptor ->
      let dialog = Gtk_bindings.window_new () in
      let root_box = Gtk_bindings.box_new ~vertical:true ~spacing:6 in
      let combo = { widget = Gtk_bindings.combo_box_text_new (); entries = [] } in
      let button = Gtk_bindings.button_new "Afficher" in
      let level_label =
        match descriptor.nomenclature with first :: _ -> String.capitalize_ascii first | [] -> "Niveau"
      in
      Gtk_bindings.window_set_title dialog (operation_label Specific_terms_hierarchy);
      Gtk_bindings.window_set_default_size dialog ~width:420 ~height:120;
      connect_combo_scroll combo;
      fill_combo combo (List.map (fun (option : Sources.selector_option) -> (option.value, option.label)) entries);
      Gtk_bindings.box_pack_start root_box (create_label ("Choisir un " ^ String.lowercase_ascii level_label)) ~expand:false ~fill:false ~padding:0;
      Gtk_bindings.box_pack_start root_box combo.widget ~expand:false ~fill:false ~padding:0;
      Gtk_bindings.box_pack_start root_box button ~expand:false ~fill:false ~padding:0;
      Gtk_bindings.container_add dialog root_box;
      Gtk_bindings.connect_clicked button (fun () ->
          match combo_value combo with
          | None -> set_status ui ("Source: " ^ source ^ " | Sélection hiérarchique incomplète.")
          | Some value ->
              let label =
                entries |> List.find_opt (fun (option : Sources.selector_option) -> String.equal option.value value)
                |> Option.map (fun (option : Sources.selector_option) -> option.label) |> Option.value ~default:value
              in
              (match render_hierarchical_specific_terms ui ~source ~path:[ value ] ~label with
              | Ok markup ->
                  set_output ui markup;
                  set_status ui ("Source: " ^ source ^ " | Opération: " ^ operation_label Specific_terms_hierarchy ^ " | " ^ level_label ^ ": " ^ label)
              | Error message ->
                  set_output ui (markup_paragraphs [ markup_heading (operation_label Specific_terms_hierarchy); escape_markup_text message ]);
                  set_status ui ("Source: " ^ source ^ " | " ^ message));
              Gtk_bindings.widget_hide dialog);
      Gtk_bindings.connect_destroy dialog (fun () -> ());
      Gtk_bindings.widget_show_all dialog;
      Gtk_bindings.window_present dialog
  | _, None ->
      set_status ui ("Source: " ^ source ^ " | Source hiérarchique inconnue.");
      set_output ui (markup_paragraphs [ markup_heading (operation_label Specific_terms_hierarchy); escape_markup_text "Source hiérarchique inconnue." ])
let update_query_visibility ui =
  match selected_operation ui with
  | Some operation ->
      Gtk_bindings.label_set_text ui.query_label (operation_query_label operation);
      if operation_requires_query operation then (
        Gtk_bindings.widget_show ui.query_label;
        Gtk_bindings.widget_show ui.query_entry)
      else (
        Gtk_bindings.widget_hide ui.query_label;
        Gtk_bindings.widget_hide ui.query_entry);
      if operation_supports_reroll operation then Gtk_bindings.widget_show ui.reroll_button else Gtk_bindings.widget_hide ui.reroll_button
      ;
      if operation_supports_new_question operation then Gtk_bindings.widget_show ui.new_question_button else Gtk_bindings.widget_hide ui.new_question_button
  | None ->
      Gtk_bindings.widget_hide ui.query_label;
      Gtk_bindings.widget_hide ui.query_entry;
      Gtk_bindings.widget_hide ui.reroll_button;
      Gtk_bindings.widget_hide ui.new_question_button

let same_quiz_context item source operation =
  String.equal item.quiz_source source && item.quiz_operation = operation

let compute_quiz_cache ui source =
  let documents = Text_process.documents ui.corpus ~source in
  let facts =
    documents
    |> List.concat_map (fun (document : Text_process.document) ->
           Quiz.segment_sentences ~doc_id:document.document_id document.text
           |> Quiz.extract_facts
           |> List.map (fun fact -> (fact, document.reference, document.title)))
  in
  let all_facts = List.map (fun (fact, _reference, _title) -> fact) facts in
  let open_questions =
    facts
    |> List.filter_map (fun (fact, reference, title) ->
           Quiz.generate_open_question fact
           |> Option.map (fun question -> { quiz_operation = Quiz_open; quiz_source = source; question; reference; title }))
  in
  let mcq_questions =
    facts
    |> List.filter_map (fun (fact, reference, title) ->
           Quiz.generate_mcq ~facts:all_facts fact
           |> Option.map (fun question -> { quiz_operation = Quiz_mcq; quiz_source = source; question; reference; title }))
  in
  { cache_source = source; open_questions; mcq_questions }

let quiz_cache ui source =
  match ui.quiz_cache with
  | Some cache when String.equal cache.cache_source source -> cache
  | _ ->
      let cache = compute_quiz_cache ui source in
      ui.quiz_cache <- Some cache;
      cache

let random_item ?current items =
  let candidates =
    match current with
    | None -> items
    | Some current_item ->
        let filtered =
          items
          |> List.filter (fun item ->
                 not
                   (String.equal item.question.question_id current_item.question.question_id
                   && String.equal item.reference current_item.reference))
        in
        if filtered = [] then items else filtered
  in
  match candidates with
  | [] -> None
  | _ -> Some (List.nth candidates (Random.int (List.length candidates)))

let question_choices_markup choices =
  choices
  |> List.mapi (fun index choice ->
         let letter = Char.chr (Char.code 'A' + index) |> String.make 1 in
         Printf.sprintf "%s. %s" letter (escape_markup_text choice))
  |> String.concat "&#10;"

let render_quiz_question item =
  let choices =
    match item.question.question_type with
    | Quiz.Multiple_choice -> "&#10;&#10;" ^ markup_heading "Propositions" ^ "&#10;" ^ question_choices_markup item.question.choices
    | Quiz.Cloze | Quiz.Open -> ""
  in
  markup_paragraphs
    [
      markup_heading (operation_label item.quiz_operation);
      markup_heading "Question" ^ "&#10;" ^ escape_markup_text item.question.prompt ^ choices;
      escape_markup_text "Cliquez sur OK pour afficher la réponse.";
    ]

let render_quiz_answer item =
  markup_paragraphs
    [
      markup_heading (operation_label item.quiz_operation);
      markup_heading "Question" ^ "&#10;" ^ escape_markup_text item.question.prompt;
      (match item.question.question_type with
      | Quiz.Multiple_choice -> markup_heading "Propositions" ^ "&#10;" ^ question_choices_markup item.question.choices
      | Quiz.Cloze | Quiz.Open -> "");
      markup_heading "Réponse" ^ "&#10;" ^ escape_markup_text item.question.correct_answer;
      markup_heading "Vérification"
      ^ "&#10;"
      ^ Printf.sprintf "%s - %s&#10;%s" (reference_link_markup item.reference) (escape_markup_text item.title)
          (escape_markup_text item.question.support_text);
    ]

let new_quiz_question ui source operation =
  let cache = quiz_cache ui source in
  let items =
    match operation with
    | Quiz_open -> cache.open_questions
    | Quiz_mcq -> cache.mcq_questions
    | Search_lexical | Search_semantic | Specific_terms | Specific_terms_hierarchy | Central_concepts | Themes | Summary | Generate -> []
  in
  match random_item ?current:ui.current_quiz items with
  | None ->
      ui.current_quiz <- None;
      set_output ui (markup_paragraphs [ markup_heading (operation_label operation); escape_markup_text "Aucune question disponible pour cette source." ]);
      set_status ui ("Source: " ^ source ^ " | Opération: " ^ operation_label operation ^ " | Aucune question disponible.")
  | Some item ->
      ui.current_quiz <- Some item;
      set_output ui (render_quiz_question item);
      set_status ui ("Source: " ^ source ^ " | Opération: " ^ operation_label operation ^ " | Question prête.")

let reveal_quiz_answer ui source operation =
  match ui.current_quiz with
  | Some item when same_quiz_context item source operation ->
      set_output ui (render_quiz_answer item);
      set_status ui ("Source: " ^ source ^ " | Opération: " ^ operation_label operation ^ " | Réponse affichée.")
  | _ -> new_quiz_question ui source operation

let operation_markup ui source operation query =
  match operation with
  | Search_lexical -> format_hits (operation_label operation) (Text_process.lexical_search ui.corpus ~source ~query)
  | Search_semantic -> format_hits (operation_label operation) (Text_process.semantic_search ui.corpus ~source ~query)
  | Specific_terms_hierarchy -> markup_paragraphs [ markup_heading (operation_label operation); escape_markup_text "Choisissez un niveau hiérarchique." ]
  | Specific_terms ->
      let body =
        Text_process.specific_terms ui.corpus ~source |> List.map (fun (term : Text_process.term_score) -> escape_markup_text term.term)
        |> String.concat "&#10;"
      in
      markup_paragraphs [ markup_heading (operation_label operation); if body = "" then escape_markup_text "Aucun résultat." else body ]
  | Central_concepts ->
      let body =
        Text_process.central_concepts ui.corpus ~source
        |> List.mapi (fun index (concept : Text_process.concept) ->
               let neighbours =
                 if concept.neighbours = [] then "aucun" else escape_markup_text (String.concat ", " concept.neighbours)
               in
               Printf.sprintf "%d. %s&#10;score=%.3f&#10;voisins=%s" (index + 1) (escape_markup_text concept.term) concept.score neighbours)
        |> markup_paragraphs
      in
      markup_paragraphs [ markup_heading (operation_label operation); if body = "" then escape_markup_text "Aucun résultat." else body ]
  | Themes ->
      let text = Text_process.themes ui.corpus ~source |> flatten_themes 0 |> String.concat "\n\n" in
      markup_paragraphs [ markup_heading (operation_label operation); if text = "" then escape_markup_text "Aucun thème." else escape_markup_text text ]
  | Summary ->
      let summary = Text_process.summarize ui.corpus ~source ~question:query in
      let passages =
        if summary.passages = [] then escape_markup_text "Aucun passage."
        else
          summary.passages
          |> List.map (fun (reference, title, excerpt) ->
                 Printf.sprintf "- [%s] %s&#10;%s" (reference_link_markup reference) (escape_markup_text title) (escape_markup_text excerpt))
          |> String.concat "&#10;"
      in
      markup_paragraphs
        [
          markup_heading (operation_label operation);
          markup_heading "Réponse courte" ^ "&#10;" ^ escape_markup_text summary.short_answer;
          markup_heading "Réponse longue" ^ "&#10;" ^ escape_markup_text summary.long_answer;
          markup_heading "Passages" ^ "&#10;" ^ passages;
        ]
  | Generate ->
      let text = Text_process.generate_from_word ui.corpus ~source ~word:query |> String.concat "\n\n" in
      markup_paragraphs [ markup_heading (operation_label operation); if text = "" then escape_markup_text "Aucune génération." else escape_markup_text text ]
  | Quiz_open | Quiz_mcq -> markup_paragraphs [ markup_heading (operation_label operation); escape_markup_text "Cliquez sur OK pour afficher la réponse." ]

let run ui =
  update_query_visibility ui;
  match combo_value ui.source_combo, selected_operation ui with
  | Some source, Some operation ->
      let query = Gtk_bindings.entry_get_text ui.query_entry |> String.trim in
      if operation_requires_query operation && query = "" then (
        set_output ui (markup_paragraphs [ markup_heading (operation_label operation); escape_markup_text "Saisie requise." ]);
        set_status ui ("Source: " ^ source ^ " | Opération: " ^ operation_label operation ^ " | Saisie requise."))
      else (
        let operation_id =
          match combo_value ui.operation_combo with
          | Some value -> value
          | None -> ""
        in
        log_text_tools ("Opération démarrée: " ^ operation_id ^ " sur " ^ source ^ ".");
        (match operation with
        | Specific_terms_hierarchy ->
            show_hierarchy_specific_terms_dialog ui source;
            set_status ui ("Source: " ^ source ^ " | Opération: " ^ operation_label operation ^ " | Sélection requise.")
        | Quiz_open | Quiz_mcq -> reveal_quiz_answer ui source operation
        | _ ->
            let markup = operation_markup ui source operation query in
            set_output ui markup;
            set_status ui ("Source: " ^ source ^ " | Opération: " ^ operation_label operation));
        log_text_tools ("Opération terminée: " ^ operation_id ^ " sur " ^ source ^ "."))
  | _ ->
      update_query_visibility ui;
      set_status ui "Sélection incomplète."

let launch root source_id =
  Gtk_bindings.init ();
  let names =
    match Book_names.load ~root with
    | Ok names -> names
    | Error message -> failwith message
  in
  let corpus =
    match Text_process.load ~root ~source:source_id with
    | Ok corpus -> corpus
    | Error message -> failwith message
  in
  let source_count = Text_process.sources corpus |> List.length in
  log_text_tools (Printf.sprintf "Corpus chargé pour la source %s. %d source disponible." source_id source_count);
  let window = Gtk_bindings.window_new () in
  let root_box = Gtk_bindings.box_new ~vertical:true ~spacing:6 in
  let row = Gtk_bindings.box_new ~vertical:false ~spacing:6 in
  let output_label = Gtk_bindings.label_new "" in
  let status_label = create_label "" in
  let source_combo = { widget = Gtk_bindings.combo_box_text_new (); entries = [] } in
  let operation_combo = { widget = Gtk_bindings.combo_box_text_new (); entries = [] } in
  let query_label = create_label "Question" in
  let query_entry = Gtk_bindings.entry_new () in
  let run_button = Gtk_bindings.button_new "OK" in
  let reroll_button = Gtk_bindings.button_new "Nouvelle réponse aléatoire" in
  let new_question_button = Gtk_bindings.button_new "Nouvelle question aléatoire" in
  let scroll = Gtk_bindings.scrolled_window_new () in
  Gtk_bindings.window_set_title window "text tools";
  Gtk_bindings.window_set_default_size window ~width:1000 ~height:760;
  Gtk_bindings.scrolled_window_set_policy scroll ~h:1 ~v:1;
  Gtk_bindings.label_set_line_wrap output_label true;
  Gtk_bindings.label_set_selectable output_label true;
  Gtk_bindings.container_add scroll output_label;
  let ui =
    {
      root;
      names;
      bible_translation = "bible_aelf";
      corpus;
      window;
      source_combo;
      operation_combo;
      query_label;
      query_entry;
      reroll_button;
      new_question_button;
      output_label;
      status_label;
      current_quiz = None;
      quiz_cache = None;
    }
  in
  List.iter connect_combo_scroll [ source_combo; operation_combo ];
  let pack_label text = Gtk_bindings.box_pack_start row (create_label text) ~expand:false ~fill:false ~padding:0 in
  let pack_widget widget = Gtk_bindings.box_pack_start row widget ~expand:false ~fill:false ~padding:0 in
  pack_label "Source";
  pack_widget source_combo.widget;
  pack_label "Opération";
  pack_widget operation_combo.widget;
  pack_widget query_label;
  Gtk_bindings.box_pack_start row query_entry ~expand:true ~fill:true ~padding:0;
  pack_widget run_button;
  pack_widget reroll_button;
  pack_widget new_question_button;
  Gtk_bindings.box_pack_start root_box row ~expand:false ~fill:false ~padding:0;
  Gtk_bindings.box_pack_start root_box scroll ~expand:true ~fill:true ~padding:0;
  Gtk_bindings.box_pack_start root_box status_label ~expand:false ~fill:false ~padding:0;
  Gtk_bindings.container_add window root_box;
  fill_combo source_combo (Text_process.sources corpus |> List.map (fun (source : Text_process.source_info) -> (source.id, source.label)));
  fill_combo operation_combo
    [
      ("search-lexical", "Recherche lexicale");
      ("search-semantic", "Recherche sémantique");
      ("specific-terms", "Vocabulaire spécifique");
      ("specific-terms-hierarchy", "Vocabulaire spécifique hiérarchique");
      ("central-concepts", "Concepts centraux");
      ("themes", "Thèmes");
      ("summary", "Résumé");
      ("generate", "Génération");
      ("quiz-open", "Quizz");
      ("quiz-mcq", "QCM");
    ];
  Gtk_bindings.connect_destroy window Gtk_bindings.main_quit;
  Gtk_bindings.connect_ctrl_q window (fun () -> Gtk_bindings.main_quit ());
  Gtk_bindings.connect_clicked run_button (fun () -> run ui);
  Gtk_bindings.connect_clicked reroll_button (fun () -> run ui);
  Gtk_bindings.connect_clicked new_question_button (fun () ->
      match combo_value ui.source_combo, selected_operation ui with
      | Some source, Some (Quiz_open as operation) | Some source, Some (Quiz_mcq as operation) -> new_quiz_question ui source operation
      | _ -> ());
  Gtk_bindings.connect_activate query_entry (fun () -> run ui);
  Gtk_bindings.connect_activate_link output_label (fun uri ->
      try open_uri uri with Unix.Unix_error (_error, _fn, _arg) -> set_status ui ("Impossible d'ouvrir le lien: " ^ uri));
  Gtk_bindings.connect_changed source_combo.widget (fun () ->
      ui.current_quiz <- None;
      ui.quiz_cache <- None;
      run ui);
  Gtk_bindings.connect_changed operation_combo.widget (fun () ->
      ui.current_quiz <- None;
      run ui);
  Gtk_bindings.widget_show_all window;
  update_query_visibility ui;
  run ui;
  Gtk_bindings.main ()
