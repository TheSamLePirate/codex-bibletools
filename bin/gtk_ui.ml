type combo_state = {
  widget : Gtk_bindings.widget;
  mutable entries : (string * string) list;
}

type level_mode =
  | Hidden
  | Combo
  | Integer_input of int

type level_state = {
  label : Gtk_bindings.widget;
  combo : combo_state;
  entry : Gtk_bindings.widget;
  mutable mode : level_mode;
}

type t = {
  backend : string;
  mutable block : bool;
  mutable suppress_history : bool;
  mutable translation : string;
  mutable current_ref : string;
  mutable source : string;
  mutable source_labels : (string, string list) Hashtbl.t;
  mutable status : string;
  mutable text_size : int;
  mutable title_size : int;
  highlights : string list;
  mutable history : View_history.t;
  window : Gtk_bindings.widget;
  status_label : Gtk_bindings.widget;
  title_label : Gtk_bindings.widget;
  ref_label : Gtk_bindings.widget;
  output_label : Gtk_bindings.widget;
  translation_combo : combo_state;
  source_combo : combo_state;
  levels : level_state array;
  article_combo : combo_state;
  reference_entry : Gtk_bindings.widget;
  back_button : Gtk_bindings.widget;
  chapter_button : Gtk_bindings.widget;
  prev_button : Gtk_bindings.widget;
  next_button : Gtk_bindings.widget;
}

let run backend args =
  let command = Array.of_list (backend :: args) in
  let input = Unix.open_process_args_in backend command in
  Fun.protect
    ~finally:(fun () -> ignore (Unix.close_process_in input))
    (fun () ->
      let buffer = Buffer.create 4096 in
      (try
         while true do
           Buffer.add_string buffer (input_line input);
           Buffer.add_char buffer '\n'
         done
       with End_of_file -> ());
      Buffer.contents buffer)

let set_status ui text =
  ui.status <- text;
  Gtk_bindings.label_set_text ui.status_label text

let escape_markup text =
  text |> String.split_on_char '&' |> String.concat "&amp;" |> String.split_on_char '<' |> String.concat "&lt;" |> String.split_on_char '>' |> String.concat "&gt;"

let apply_font_sizes ui =
  Gtk_bindings.widget_override_font ui.title_label (Printf.sprintf "Sans Bold %d" ui.title_size);
  Gtk_bindings.widget_override_font ui.ref_label (Printf.sprintf "Sans %d" (max 12 (ui.text_size - 1)));
  Gtk_bindings.widget_override_font ui.status_label (Printf.sprintf "Sans %d" (max 11 (ui.text_size - 2)));
  Gtk_bindings.widget_override_font ui.output_label (Printf.sprintf "Sans %d" ui.text_size)

let parse_lines text =
  text |> String.split_on_char '\n' |> List.filter (fun line -> line <> "")

let fill_combo ui combo entries =
  ui.block <- true;
  combo.entries <- entries;
  Gtk_bindings.combo_box_text_remove_all combo.widget;
  List.iter (fun (_value, label) -> Gtk_bindings.combo_box_text_append_text combo.widget label) entries;
  if entries = [] then Gtk_bindings.combo_box_set_active combo.widget (-1)
  else Gtk_bindings.combo_box_set_active combo.widget 0;
  ui.block <- false

let clear_combo ui combo =
  ui.block <- true;
  combo.entries <- [];
  Gtk_bindings.combo_box_text_remove_all combo.widget;
  Gtk_bindings.combo_box_set_active combo.widget (-1);
  ui.block <- false

let combo_value combo =
  match Gtk_bindings.combo_box_text_get_active_text combo.widget with
  | None -> None
  | Some label ->
      List.find_map (fun (value, text) -> if String.equal text label then Some value else None) combo.entries

let plain_markup ui text =
  Article_markdown.render_plain_to_pango_markup ~highlights:ui.highlights text
  |> String.split_on_char '\n' |> String.concat "&#10;"

let set_output ui ~title ~reference ~body =
  Gtk_bindings.label_set_text ui.title_label title;
  Gtk_bindings.label_set_text ui.ref_label reference;
  Gtk_bindings.label_set_markup ui.output_label (plain_markup ui body)

let translation_of_ui ui = ui.translation

let parse_bool_field text key =
  parse_lines text
  |> List.find_map (fun line ->
         match String.split_on_char '=' line with
         | [ field; value ] when String.equal field key -> Some (String.equal value "1")
         | _ -> None)

let chapter_target ui reference =
  match run ui.backend [ "chapter-ref"; "--translation"; translation_of_ui ui; "--reference"; reference ] |> String.trim with
  | "" -> None
  | target -> Some target

let resolve_internal_article_url ui url =
  match run ui.backend [ "decode-site-ref"; "--url"; url ] |> String.trim with
  | "" -> None
  | reference -> Some reference

let update_back_button ui =
  Gtk_bindings.widget_set_sensitive ui.back_button (View_history.can_go_back ui.history)

let record_view ui view =
  if not ui.suppress_history then ui.history <- View_history.visit ui.history view;
  update_back_button ui

let select_combo_value ui combo value =
  match List.find_mapi (fun index (entry_value, _label) -> if String.equal entry_value value then Some index else None) combo.entries with
  | Some index ->
      ui.block <- true;
      Gtk_bindings.combo_box_set_active combo.widget index;
      ui.block <- false
  | None -> ()

let refresh_action_buttons ui =
  let status_text = run ui.backend [ "status-ref"; "--translation"; translation_of_ui ui; "--reference"; ui.current_ref ] in
  let has_previous = Option.value (parse_bool_field status_text "prev") ~default:false in
  let has_next = Option.value (parse_bool_field status_text "next") ~default:false in
  Gtk_bindings.widget_set_sensitive ui.prev_button has_previous;
  Gtk_bindings.widget_set_sensitive ui.next_button has_next;
  Gtk_bindings.widget_set_sensitive ui.chapter_button (Option.is_some (chapter_target ui ui.current_ref))

let apply_rendered ui ~fallback_reference ~status_prefix (reference, title, body) =
  let resolved_reference = if reference = "" then fallback_reference else reference in
  record_view ui (View_history.Reference resolved_reference);
  ui.current_ref <- resolved_reference;
  Gtk_bindings.entry_set_text ui.reference_entry resolved_reference;
  set_output ui ~title ~reference:resolved_reference ~body;
  set_status ui (status_prefix ^ resolved_reference);
  refresh_action_buttons ui

let parse_rendered text =
  let lines = String.split_on_char '\n' text in
  let ref, title, rest =
    match lines with
    | first :: second :: tail when String.starts_with ~prefix:"REF\t" first && String.starts_with ~prefix:"TEXT\t" second ->
        ( String.sub first 4 (String.length first - 4),
          String.sub second 5 (String.length second - 5),
          tail )
    | _ -> ("", "", lines)
  in
  let body = String.concat "\n" rest |> String.trim in
  (ref, title, body)

let source_of_ui ui =
  match combo_value ui.source_combo with Some source -> source | None -> ""

let count_for_path ui path =
  let source = source_of_ui ui in
  if source = "" then None
  else
    let path_text = String.concat "\t" path in
    let raw =
      run ui.backend
        ([ "source-count"; "--translation"; translation_of_ui ui; "--source"; source ]
        @ if path = [] then [] else [ "--path"; path_text ])
      |> String.trim
    in
    int_of_string_opt raw

let set_level_hidden ui level =
  let state = ui.levels.(level) in
  state.mode <- Hidden;
  clear_combo ui state.combo;
  Gtk_bindings.entry_set_text state.entry "";
  Gtk_bindings.widget_hide state.label;
  Gtk_bindings.widget_hide state.combo.widget;
  Gtk_bindings.widget_hide state.entry

let set_level_combo ui level label entries =
  let state = ui.levels.(level) in
  state.mode <- Combo;
  Gtk_bindings.label_set_text state.label label;
  Gtk_bindings.widget_show state.label;
  Gtk_bindings.widget_show state.combo.widget;
  Gtk_bindings.widget_hide state.entry;
  Gtk_bindings.widget_set_sensitive state.combo.widget true;
  fill_combo ui state.combo entries

let set_level_integer ui level label count =
  let state = ui.levels.(level) in
  state.mode <- Integer_input count;
  Gtk_bindings.label_set_text state.label (Printf.sprintf "%s (1-%d)" label count);
  Gtk_bindings.widget_show state.label;
  Gtk_bindings.widget_hide state.combo.widget;
  clear_combo ui state.combo;
  Gtk_bindings.widget_show state.entry;
  Gtk_bindings.entry_set_text state.entry "";
  Gtk_bindings.widget_set_sensitive state.entry true

let level_value ui level =
  let state = ui.levels.(level) in
  match state.mode with
  | Hidden -> None
  | Combo -> combo_value state.combo
  | Integer_input _ ->
      let text = Gtk_bindings.entry_get_text state.entry |> String.trim in
      if text = "" then None else Some text

let current_path ui upto =
  let rec loop index acc =
    if index >= upto then List.rev acc
    else
      match level_value ui index with
      | Some value -> loop (index + 1) (value :: acc)
      | None -> List.rev acc
  in
  loop 0 []

let clear_levels_from ui start =
  for index = start to Array.length ui.levels - 1 do
    set_level_hidden ui index
  done

let rec load_source_level ui level =
  let source = source_of_ui ui in
  if source = "" || level >= Array.length ui.levels then ()
  else
    let path = current_path ui level in
    let path_text = String.concat "\t" path in
    let labels = Option.value (Hashtbl.find_opt ui.source_labels source) ~default:[] in
    if level >= List.length labels then clear_levels_from ui level
    else
      match count_for_path ui path with
      | Some count when count > 0 ->
          clear_levels_from ui (level + 1);
          set_level_integer ui level (List.nth labels level) count;
          set_status ui (Printf.sprintf "countArticles(%s, path='%s') -> %d" source path_text count)
      | _ ->
          set_status ui (Printf.sprintf "index(%s, path='%s')" source path_text);
          let args =
            [
              "source-options";
              "--translation";
              translation_of_ui ui;
              "--source";
              source;
            ]
            @ if path = [] then [] else [ "--path"; path_text ]
          in
          let raw = run ui.backend args in
          let entries =
            raw |> parse_lines
            |> List.map (fun line ->
                   match String.split_on_char '\t' line with
                   | value :: label_parts -> (value, String.concat "\t" label_parts)
                   | [] -> ("", ""))
          in
          if entries = [] then clear_levels_from ui level
          else (
            clear_levels_from ui (level + 1);
            set_level_combo ui level (List.nth labels level) entries;
            set_status ui (Printf.sprintf "index(%s, path='%s') -> %d options" source path_text (List.length entries));
            if level + 1 < List.length labels then load_source_level ui (level + 1))

let refresh_level_visibility ui =
  let labels = Option.value (Hashtbl.find_opt ui.source_labels (source_of_ui ui)) ~default:[] in
  Array.iteri
    (fun index state ->
      if index < List.length labels then (
        Gtk_bindings.label_set_text state.label (List.nth labels index);
        match state.mode with
        | Hidden -> ()
        | Combo ->
            Gtk_bindings.widget_show state.label;
            Gtk_bindings.widget_show state.combo.widget;
            Gtk_bindings.widget_hide state.entry
        | Integer_input count ->
            Gtk_bindings.label_set_text state.label (Printf.sprintf "%s (1-%d)" (List.nth labels index) count);
            Gtk_bindings.widget_show state.label;
            Gtk_bindings.widget_hide state.combo.widget;
            Gtk_bindings.widget_show state.entry)
      else set_level_hidden ui index)
    ui.levels

let load_source_catalog ui =
  let raw = run ui.backend [ "source-list"; "--translation"; translation_of_ui ui ] in
  let source_entries =
    raw |> parse_lines
    |> List.map (fun line ->
           match String.split_on_char '\t' line with
           | id :: _label :: nomenclature :: _ ->
               Hashtbl.replace ui.source_labels id (if nomenclature = "" then [] else String.split_on_char '|' nomenclature);
               (id, id)
           | _ -> ("", ""))
  in
  fill_combo ui ui.source_combo source_entries;
  clear_levels_from ui 0;
  refresh_level_visibility ui;
  load_source_level ui 0

let load_translations ui =
  let raw = run ui.backend [ "translations" ] in
  let entries =
    raw |> parse_lines
    |> List.map (fun line ->
           match String.split_on_char '\t' line with
           | id :: _title :: _ -> (id, id)
           | _ -> ("", ""))
  in
  fill_combo ui ui.translation_combo entries

let show_reference ui reference =
  let raw = run ui.backend [ "show-ref"; "--translation"; translation_of_ui ui; "--reference"; reference ] in
  apply_rendered ui ~fallback_reference:reference ~status_prefix:"Affichage: " (parse_rendered raw)

let render_article_by_name ui article =
  select_combo_value ui ui.article_combo article;
  let body = run ui.backend [ "article"; "--name"; article ] in
  let markup =
    Article_markdown.render_to_pango_markup ~highlights:ui.highlights
      ~resolve_internal:(resolve_internal_article_url ui) body
  in
  record_view ui (View_history.Article article);
  Gtk_bindings.label_set_text ui.title_label article;
  Gtk_bindings.label_set_text ui.ref_label "";
  Gtk_bindings.label_set_markup ui.output_label markup;
  set_status ui ("Article: " ^ article);
  Gtk_bindings.widget_set_sensitive ui.chapter_button false;
  Gtk_bindings.widget_set_sensitive ui.prev_button false;
  Gtk_bindings.widget_set_sensitive ui.next_button false

let show_article ui =
  match combo_value ui.article_combo with
  | None -> ()
  | Some article -> render_article_by_name ui article

let render_view ui = function
  | View_history.Reference reference -> show_reference ui reference
  | View_history.Article article -> render_article_by_name ui article

let go_back ui =
  match View_history.pop ui.history with
  | None -> ()
  | Some (view, history) ->
      ui.history <- history;
      ui.suppress_history <- true;
      render_view ui view;
      ui.suppress_history <- false;
      update_back_button ui

let goto_source ui =
  let source = source_of_ui ui in
  let path = current_path ui (Array.length ui.levels) in
  if source <> "" && path <> [] then
    let reference =
      run ui.backend
        [ "compile-ref"; "--translation"; translation_of_ui ui; "--source"; source; "--path"; String.concat "\t" path ]
      |> String.trim
    in
    show_reference ui reference

let navigate ui direction =
  let raw =
    run ui.backend
      [ "navigate-ref"; "--translation"; translation_of_ui ui; "--reference"; ui.current_ref; "--direction"; direction ]
  in
  apply_rendered ui ~fallback_reference:ui.current_ref ~status_prefix:"Navigation: " (parse_rendered raw)

let zoom ui delta =
  ui.text_size <- max 10 (ui.text_size + delta);
  ui.title_size <- max 12 (ui.title_size + delta);
  apply_font_sizes ui;
  set_status ui (Printf.sprintf "Taille du texte: %d" ui.text_size)

let create_label text =
  let label = Gtk_bindings.label_new text in
  Gtk_bindings.label_set_line_wrap label true;
  label

let project_root_from_backend backend =
  backend |> Filename.dirname |> Filename.dirname |> Filename.dirname |> Filename.dirname

let load_highlights project_root =
  let path = Filename.concat project_root "highlights" in
  if Sys.file_exists path then
    let channel = open_in path in
    Fun.protect
      ~finally:(fun () -> close_in channel)
      (fun () ->
        let rec loop acc =
          match input_line channel with
          | line ->
              let line = String.trim line in
              if line = "" || String.starts_with ~prefix:"#" line then loop acc else loop (line :: acc)
          | exception End_of_file -> List.rev acc
        in
        loop [])
  else []

let make_ui backend =
  Gtk_bindings.init ();
  let project_root = project_root_from_backend backend in
  let background_path = Filename.concat project_root "bg.jpeg" in
  let window = Gtk_bindings.window_new () in
  Gtk_bindings.window_set_title window "Pascatho";
  Gtk_bindings.window_set_default_size window ~width:1200 ~height:850;
  Gtk_bindings.window_enable_cross_background window background_path;
  let root_box = Gtk_bindings.box_new ~vertical:true ~spacing:6 in
  let row1 = Gtk_bindings.box_new ~vertical:false ~spacing:6 in
  let row2 = Gtk_bindings.box_new ~vertical:false ~spacing:6 in
  let source_flow = Gtk_bindings.flow_box_new () in
  let row5 = Gtk_bindings.box_new ~vertical:false ~spacing:6 in
  let row5_left = Gtk_bindings.box_new ~vertical:false ~spacing:6 in
  let row5_spacer = Gtk_bindings.box_new ~vertical:false ~spacing:0 in
  let row5_right = Gtk_bindings.box_new ~vertical:false ~spacing:6 in
  let title_label = create_label "" in
  let ref_label = create_label "" in
  let status_label = create_label "" in
  let translation_combo = { widget = Gtk_bindings.combo_box_text_new (); entries = [] } in
  let source_combo = { widget = Gtk_bindings.combo_box_text_new (); entries = [] } in
  let levels =
    Array.init 4 (fun index ->
        {
          label = create_label (Printf.sprintf "niveau %d" (index + 1));
          combo = { widget = Gtk_bindings.combo_box_text_new (); entries = [] };
          entry = Gtk_bindings.entry_new ();
          mode = Hidden;
        })
  in
  let article_combo = { widget = Gtk_bindings.combo_box_text_new (); entries = [] } in
  let reference_entry = Gtk_bindings.entry_new () in
  let output_label = Gtk_bindings.label_new "" in
  Gtk_bindings.label_set_line_wrap output_label true;
  Gtk_bindings.label_set_selectable output_label true;
  let scroll = Gtk_bindings.scrolled_window_new () in
  let show_button = Gtk_bindings.button_new "Afficher" in
  let chapter_button = Gtk_bindings.button_new "Chapitre" in
  let prev_button = Gtk_bindings.button_new "Précédent" in
  let next_button = Gtk_bindings.button_new "Suivant" in
  let zoom_out_button = Gtk_bindings.button_new "A-" in
  let zoom_in_button = Gtk_bindings.button_new "A+" in
  let goto_button = Gtk_bindings.button_new "Aller" in
  let back_button = Gtk_bindings.button_new "Back" in
  let logo_path = Filename.concat project_root "logo.jpeg" in
  let highlights = load_highlights project_root in
  let logo_image = Gtk_bindings.image_new_from_file logo_path in
  Gtk_bindings.flow_box_set_selection_mode source_flow 0;
  Gtk_bindings.scrolled_window_set_policy scroll ~h:1 ~v:1;
  Gtk_bindings.container_add scroll output_label;
  List.iter (Gtk_bindings.box_pack_start root_box ~expand:false ~fill:false ~padding:0)
    [ row1; row2; source_flow; title_label; ref_label ];
  Gtk_bindings.box_pack_start row5 row5_left ~expand:false ~fill:false ~padding:0;
  Gtk_bindings.box_pack_start row5 row5_spacer ~expand:true ~fill:true ~padding:0;
  Gtk_bindings.box_pack_start row5 row5_right ~expand:false ~fill:false ~padding:0;
  Gtk_bindings.box_pack_start root_box scroll ~expand:true ~fill:true ~padding:0;
  Gtk_bindings.box_pack_start root_box row5 ~expand:false ~fill:false ~padding:0;
  Gtk_bindings.container_add window root_box;
  let ui =
    {
      backend;
      block = false;
      suppress_history = false;
      translation = "bible_aelf";
      current_ref = "Jn 1,1";
      source = "";
      source_labels = Hashtbl.create 16;
      status = "";
      text_size = 16;
      title_size = 22;
      highlights;
      history = View_history.empty;
      window;
      status_label;
      title_label;
      ref_label;
      output_label;
      translation_combo;
      source_combo;
      levels;
      article_combo;
      reference_entry;
      back_button;
      chapter_button;
      prev_button;
      next_button;
    }
  in
  let pack_label row text = Gtk_bindings.box_pack_start row (create_label text) ~expand:false ~fill:false ~padding:0 in
  let pack_widget row widget = Gtk_bindings.box_pack_start row widget ~expand:false ~fill:false ~padding:0 in
  let add_source_item label_text widget =
    let item = Gtk_bindings.box_new ~vertical:false ~spacing:6 in
    Gtk_bindings.box_pack_start item (create_label label_text) ~expand:false ~fill:false ~padding:0;
    Gtk_bindings.box_pack_start item widget ~expand:false ~fill:false ~padding:0;
    Gtk_bindings.container_add source_flow item
  in
  pack_label row1 "Bible";
  pack_widget row1 translation_combo.widget;
  pack_label row1 "Référence";
  pack_widget row1 reference_entry;
  pack_widget row1 show_button;
  List.iter (pack_widget row2) [ chapter_button; prev_button; next_button ];
  add_source_item "Source" source_combo.widget;
  Array.iter
    (fun level ->
      let combo_item = Gtk_bindings.box_new ~vertical:false ~spacing:6 in
      Gtk_bindings.box_pack_start combo_item level.label ~expand:false ~fill:false ~padding:0;
      Gtk_bindings.box_pack_start combo_item level.combo.widget ~expand:false ~fill:false ~padding:0;
      Gtk_bindings.box_pack_start combo_item level.entry ~expand:false ~fill:false ~padding:0;
      Gtk_bindings.container_add source_flow combo_item)
    levels;
  Gtk_bindings.container_add source_flow goto_button;
  pack_widget row5_left back_button;
  pack_label row5_left "Article";
  pack_widget row5_left article_combo.widget;
  List.iter (pack_widget row5_right) [ logo_image; zoom_out_button; zoom_in_button ];
  Gtk_bindings.entry_set_text reference_entry ui.current_ref;
  apply_font_sizes ui;
  Gtk_bindings.connect_destroy window Gtk_bindings.main_quit;
  Gtk_bindings.connect_clicked show_button (fun () -> show_reference ui (Gtk_bindings.entry_get_text reference_entry));
  Gtk_bindings.connect_clicked chapter_button (fun () ->
      match chapter_target ui (Gtk_bindings.entry_get_text reference_entry |> String.trim) with
      | Some reference -> show_reference ui reference
      | None -> set_status ui "Chapitre indisponible pour cette source");
  Gtk_bindings.connect_clicked prev_button (fun () -> navigate ui "previous");
  Gtk_bindings.connect_clicked next_button (fun () -> navigate ui "next");
  Gtk_bindings.connect_clicked zoom_out_button (fun () -> zoom ui (-1));
  Gtk_bindings.connect_clicked zoom_in_button (fun () -> zoom ui 1);
  Gtk_bindings.connect_clicked goto_button (fun () -> goto_source ui);
  Gtk_bindings.connect_clicked back_button (fun () -> go_back ui);
  Gtk_bindings.connect_activate reference_entry (fun () -> show_reference ui (Gtk_bindings.entry_get_text reference_entry));
  Gtk_bindings.connect_activate_link output_label (fun uri ->
      if String.length uri >= 4 && String.sub uri 0 4 = "ref:" then
        show_reference ui (String.sub uri 4 (String.length uri - 4))
      else
        match resolve_internal_article_url ui uri with
        | Some reference -> show_reference ui reference
        | None -> set_status ui ("Lien non pris en charge: " ^ uri));
  Gtk_bindings.connect_changed translation_combo.widget (fun () ->
      if not ui.block then (
        match combo_value translation_combo with
        | Some translation ->
            ui.translation <- translation;
            load_source_catalog ui
        | None -> ()));
  Gtk_bindings.connect_changed source_combo.widget (fun () ->
      if not ui.block then (
        clear_levels_from ui 0;
        refresh_level_visibility ui;
        load_source_level ui 0));
  Gtk_bindings.connect_changed article_combo.widget (fun () ->
      if not ui.block then show_article ui);
  Array.iteri
    (fun index level ->
      Gtk_bindings.connect_changed level.combo.widget (fun () ->
          if not ui.block && index + 1 < Array.length ui.levels then load_source_level ui (index + 1));
      Gtk_bindings.connect_changed level.entry (fun () ->
          if not ui.block && index + 1 < Array.length ui.levels then load_source_level ui (index + 1));
      Gtk_bindings.connect_activate level.entry (fun () -> goto_source ui))
    levels;
  Gtk_bindings.widget_show_all window;
  let button_height = Gtk_bindings.widget_get_allocated_height zoom_out_button in
  if button_height > 0 then Gtk_bindings.image_set_from_file_scaled logo_image logo_path ~height:(max 1 (button_height / 10));
  load_translations ui;
  let raw_articles = run ui.backend [ "articles" ] in
  let article_entries = raw_articles |> parse_lines |> List.map (fun name -> (name, name)) in
  fill_combo ui article_combo article_entries;
  load_source_catalog ui;
  show_reference ui ui.current_ref;
  refresh_action_buttons ui;
  update_back_button ui;
  ui

let launch backend =
  let _ui = make_ui backend in
  Gtk_bindings.main ();
  Ok ()
