type combo_state = {
  widget : Gtk_bindings.widget;
  mutable entries : (string * string) list;
}

type operation =
  | Search_lexical
  | Search_semantic
  | Specific_terms
  | Central_concepts
  | Themes
  | Summary
  | Generate

type t = {
  corpus : Text_process.t;
  window : Gtk_bindings.widget;
  source_combo : combo_state;
  operation_combo : combo_state;
  query_label : Gtk_bindings.widget;
  query_entry : Gtk_bindings.widget;
  reroll_button : Gtk_bindings.widget;
  output_label : Gtk_bindings.widget;
  status_label : Gtk_bindings.widget;
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

let is_url_terminator = function
  | ' ' | '\n' | '\r' | '\t' -> true
  | _ -> false

let append_markup_escaped buffer = function
  | '&' -> Buffer.add_string buffer "&amp;"
  | '<' -> Buffer.add_string buffer "&lt;"
  | '>' -> Buffer.add_string buffer "&gt;"
  | '"' -> Buffer.add_string buffer "&quot;"
  | '\'' -> Buffer.add_string buffer "&#39;"
  | '\n' -> Buffer.add_string buffer "&#10;"
  | chr -> Buffer.add_char buffer chr

let markup_of_text text =
  let prefix = "pascatho://" in
  let prefix_length = String.length prefix in
  let buffer = Buffer.create (String.length text * 2) in
  let rec loop index =
    if index >= String.length text then ()
    else if index + prefix_length <= String.length text && String.sub text index prefix_length = prefix then
      let end_index =
        let rec find_end cursor =
          if cursor >= String.length text || is_url_terminator text.[cursor] then cursor else find_end (cursor + 1)
        in
        find_end (index + prefix_length)
      in
      let uri = String.sub text index (end_index - index) in
      Buffer.add_string buffer (Printf.sprintf "<a href=\"%s\">%s</a>" uri uri);
      loop end_index
    else (
      append_markup_escaped buffer text.[index];
      loop (index + 1))
  in
  loop 0;
  Buffer.contents buffer

let format_hits title hits =
  let body =
    if hits = [] then "Aucun résultat."
    else
      hits
      |> List.mapi (fun index (hit : Text_process.search_hit) ->
             Printf.sprintf "%d. %s [%s]\nscore=%.3f\nouvrir=%s\n%s" (index + 1) hit.title hit.reference hit.score
               (pascatho_url hit.reference) hit.excerpt)
      |> String.concat "\n\n"
  in
  title ^ "\n\n" ^ body

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
  | "central-concepts" -> Central_concepts
  | "themes" -> Themes
  | "summary" -> Summary
  | "generate" -> Generate
  | _ -> Search_lexical

let operation_requires_query = function
  | Search_lexical | Search_semantic | Summary | Generate -> true
  | Specific_terms | Central_concepts | Themes -> false

let operation_supports_reroll = function
  | Generate -> true
  | Search_lexical | Search_semantic | Specific_terms | Central_concepts | Themes | Summary -> false

let operation_query_label = function
  | Generate -> "Mot"
  | Search_lexical | Search_semantic | Summary -> "Question"
  | Specific_terms | Central_concepts | Themes -> "Question"

let operation_label = function
  | Search_lexical -> "Recherche lexicale"
  | Search_semantic -> "Recherche sémantique"
  | Specific_terms -> "Vocabulaire spécifique"
  | Central_concepts -> "Concepts centraux"
  | Themes -> "Hiérarchie thématique"
  | Summary -> "Résumé"
  | Generate -> "Génération depuis un mot"

let selected_operation ui = combo_value ui.operation_combo |> Option.map operation_of_string

let set_output ui text = Gtk_bindings.label_set_markup ui.output_label (markup_of_text text)

let set_status ui text = Gtk_bindings.label_set_text ui.status_label text

let log_text_tools message = prerr_endline ("[textTools] " ^ message)

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
  | None ->
      Gtk_bindings.widget_hide ui.query_label;
      Gtk_bindings.widget_hide ui.query_entry;
      Gtk_bindings.widget_hide ui.reroll_button

let operation_markup ui source operation query =
  match operation with
  | Search_lexical -> format_hits (operation_label operation) (Text_process.lexical_search ui.corpus ~source ~query)
  | Search_semantic -> format_hits (operation_label operation) (Text_process.semantic_search ui.corpus ~source ~query)
  | Specific_terms ->
      Text_process.specific_terms ui.corpus ~source
      |> List.mapi (fun index (term : Text_process.term_score) ->
             Printf.sprintf "%d. %s\nscore=%.3f\nfréquence=%d%s" (index + 1) term.term term.score term.frequency
               (match term.reference_frequency with
               | None -> ""
               | Some value -> Printf.sprintf "\nfréquence de référence=%d" value))
      |> String.concat "\n\n"
      |> fun text -> operation_label operation ^ "\n\n" ^ if text = "" then "Aucun résultat." else text
  | Central_concepts ->
      Text_process.central_concepts ui.corpus ~source
      |> List.mapi (fun index (concept : Text_process.concept) ->
             Printf.sprintf "%d. %s\nscore=%.3f\nvoisins=%s" (index + 1) concept.term concept.score
               (if concept.neighbours = [] then "aucun" else String.concat ", " concept.neighbours))
      |> String.concat "\n\n"
      |> fun text -> operation_label operation ^ "\n\n" ^ if text = "" then "Aucun résultat." else text
  | Themes ->
      Text_process.themes ui.corpus ~source |> flatten_themes 0 |> String.concat "\n\n"
      |> fun text -> operation_label operation ^ "\n\n" ^ if text = "" then "Aucun thème." else text
  | Summary ->
      let summary = Text_process.summarize ui.corpus ~source ~question:query in
      String.concat "\n\n"
        [
          operation_label operation;
          "Réponse courte:\n" ^ summary.short_answer;
          "Réponse longue:\n" ^ summary.long_answer;
          "Passages:\n"
          ^
          (summary.passages
          |> List.map (fun (reference, title, excerpt) -> Printf.sprintf "- %s | %s | %s | %s" reference title (pascatho_url reference) excerpt)
          |> String.concat "\n");
        ]
  | Generate ->
      Text_process.generate_from_word ui.corpus ~source ~word:query |> String.concat "\n\n"
      |> fun text -> operation_label operation ^ "\n\n" ^ if text = "" then "Aucune génération." else text

let run ui =
  update_query_visibility ui;
  match combo_value ui.source_combo, selected_operation ui with
  | Some source, Some operation ->
      let query = Gtk_bindings.entry_get_text ui.query_entry |> String.trim in
      if operation_requires_query operation && query = "" then (
        set_output ui (operation_label operation ^ "\n\nSaisie requise.");
        set_status ui ("Source: " ^ source ^ " | Opération: " ^ operation_label operation ^ " | Saisie requise."))
      else (
        let operation_id =
          match combo_value ui.operation_combo with
          | Some value -> value
          | None -> ""
        in
        log_text_tools ("Opération démarrée: " ^ operation_id ^ " sur " ^ source ^ ".");
        let markup = operation_markup ui source operation query in
        set_output ui markup;
        set_status ui ("Source: " ^ source ^ " | Opération: " ^ operation_label operation);
        log_text_tools ("Opération terminée: " ^ operation_id ^ " sur " ^ source ^ "."))
  | _ ->
      update_query_visibility ui;
      set_status ui "Sélection incomplète."

let launch root source_id =
  Gtk_bindings.init ();
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
  let run_button = Gtk_bindings.button_new "Exécuter" in
  let reroll_button = Gtk_bindings.button_new "Nouvelle réponse aléatoire" in
  let scroll = Gtk_bindings.scrolled_window_new () in
  Gtk_bindings.window_set_title window "text tools";
  Gtk_bindings.window_set_default_size window ~width:1000 ~height:760;
  Gtk_bindings.scrolled_window_set_policy scroll ~h:1 ~v:1;
  Gtk_bindings.label_set_line_wrap output_label true;
  Gtk_bindings.label_set_selectable output_label true;
  Gtk_bindings.container_add scroll output_label;
  let ui = { corpus; window; source_combo; operation_combo; query_label; query_entry; reroll_button; output_label; status_label } in
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
      ("central-concepts", "Concepts centraux");
      ("themes", "Thèmes");
      ("summary", "Résumé");
      ("generate", "Génération");
    ];
  Gtk_bindings.connect_destroy window Gtk_bindings.main_quit;
  Gtk_bindings.connect_ctrl_q window (fun () -> Gtk_bindings.main_quit ());
  Gtk_bindings.connect_clicked run_button (fun () -> run ui);
  Gtk_bindings.connect_clicked reroll_button (fun () -> run ui);
  Gtk_bindings.connect_activate query_entry (fun () -> run ui);
  Gtk_bindings.connect_activate_link output_label (fun uri ->
      try open_uri uri with Unix.Unix_error (_error, _fn, _arg) -> set_status ui ("Impossible d'ouvrir le lien: " ^ uri));
  Gtk_bindings.connect_changed source_combo.widget (fun () -> run ui);
  Gtk_bindings.connect_changed operation_combo.widget (fun () -> run ui);
  Gtk_bindings.widget_show_all window;
  update_query_visibility ui;
  run ui;
  Gtk_bindings.main ()
