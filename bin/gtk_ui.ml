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
  root : string;
  names : Book_names.t;
  mutable block : bool;
  mutable suppress_history : bool;
  mutable translation : string;
  mutable current_ref : string;
  mutable current_title : string;
  mutable current_body : string;
  mutable current_references : string option;
  mutable displayed_refs : string list;
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
  lucky_button : Gtk_bindings.widget;
  chapter_button : Gtk_bindings.widget;
  append_prev_button : Gtk_bindings.widget;
  prev_button : Gtk_bindings.widget;
  next_button : Gtk_bindings.widget;
  append_next_button : Gtk_bindings.widget;
}

let set_status ui text =
  ui.status <- text;
  Gtk_bindings.label_set_text ui.status_label text

let random_choice list =
  match list with
  | [] -> None
  | _ -> Some (List.nth list (Random.int (List.length list)))

let apply_font_sizes ui =
  Gtk_bindings.widget_override_font ui.title_label (Printf.sprintf "Sans Bold %d" ui.title_size);
  Gtk_bindings.widget_override_font ui.ref_label (Printf.sprintf "Sans %d" (max 12 (ui.text_size - 1)));
  Gtk_bindings.widget_override_font ui.status_label (Printf.sprintf "Sans %d" (max 11 (ui.text_size - 2)));
  Gtk_bindings.widget_override_font ui.output_label (Printf.sprintf "Sans %d" ui.text_size)

let compact_text max_chars text =
  if String.length text <= max_chars then text
  else String.sub text 0 (max_chars - 1) ^ "…"

let fill_combo ?(max_chars = 10) ui combo entries =
  ui.block <- true;
  combo.entries <- entries;
  Gtk_bindings.combo_box_text_remove_all combo.widget;
  List.iter (fun (_value, label) -> Gtk_bindings.combo_box_text_append_text combo.widget (compact_text max_chars label)) entries;
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
  match Gtk_bindings.combo_box_get_active combo.widget with
  | index when index >= 0 && index < List.length combo.entries -> Some (fst (List.nth combo.entries index))
  | _ -> None

let plain_markup ui text references =
  Article_markdown.render_source_to_pango_markup ~highlights:ui.highlights ?references text
  |> String.split_on_char '\n' |> String.concat "&#10;"

let reference_summary refs =
  match refs with
  | [] -> ""
  | [ reference ] -> reference
  | first :: rest ->
      let last = List.hd (List.rev rest) in
      Printf.sprintf "%s … %s" first last

let set_output ui ~title ~reference ~body ~references =
  ui.current_title <- title;
  ui.current_body <- body;
  ui.current_references <- references;
  Gtk_bindings.label_set_text ui.title_label title;
  Gtk_bindings.label_set_text ui.ref_label reference;
  Gtk_bindings.label_set_markup ui.output_label (plain_markup ui body references)

let translation_of_ui ui = ui.translation

let chapter_target ui reference =
  match Sources.chapter_reference ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui) ~reference with
  | Ok target -> target
  | Error message ->
      set_status ui ("Chapitre indisponible: " ^ message);
      None

let resolve_internal_article_url ui url =
  let _ = ui in
  Sources.decode_site_reference_url url

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
  let first_ref = match ui.displayed_refs with first :: _ -> first | [] -> ui.current_ref in
  let last_ref = match List.rev ui.displayed_refs with last :: _ -> last | [] -> ui.current_ref in
  let first_status =
    Sources.navigation ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui) ~reference:first_ref
  in
  let last_status =
    Sources.navigation ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui) ~reference:last_ref
  in
  let has_previous = match first_status with Ok status -> status.has_previous | Error _ -> false in
  let has_next = match last_status with Ok status -> status.has_next | Error _ -> false in
  Gtk_bindings.widget_set_sensitive ui.append_prev_button has_previous;
  Gtk_bindings.widget_set_sensitive ui.prev_button has_previous;
  Gtk_bindings.widget_set_sensitive ui.next_button has_next;
  Gtk_bindings.widget_set_sensitive ui.append_next_button has_next;
  Gtk_bindings.widget_set_sensitive ui.chapter_button (Option.is_some (chapter_target ui ui.current_ref))

let apply_rendered ui ~fallback_reference ~status_prefix (rendered : Sources.rendered) =
  let resolved_reference = if rendered.reference = "" then fallback_reference else rendered.reference in
  record_view ui (View_history.Reference resolved_reference);
  ui.current_ref <- resolved_reference;
  ui.displayed_refs <- [ resolved_reference ];
  Gtk_bindings.entry_set_text ui.reference_entry resolved_reference;
  set_output ui ~title:rendered.title ~reference:resolved_reference ~body:rendered.body ~references:rendered.references;
  set_status ui (status_prefix ^ resolved_reference);
  refresh_action_buttons ui

let source_of_ui ui =
  match combo_value ui.source_combo with Some source -> source | None -> ""

let count_for_path ui path =
  let source = source_of_ui ui in
  if source = "" then None
  else
    match
      Sources.selector_count ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui) ~source ~path
    with
    | Ok count -> count
    | Error message ->
        set_status ui ("countArticles(" ^ source ^ ") erreur: " ^ message);
        None

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
  Gtk_bindings.widget_hide state.label;
  Gtk_bindings.widget_show state.combo.widget;
  Gtk_bindings.widget_hide state.entry;
  Gtk_bindings.widget_set_sensitive state.combo.widget true;
  fill_combo ui state.combo entries

let set_level_integer ui level label count =
  let state = ui.levels.(level) in
  state.mode <- Integer_input count;
  Gtk_bindings.label_set_text state.label (Printf.sprintf "%s (1-%d)" label count);
  Gtk_bindings.widget_hide state.label;
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
          (match
             Sources.selector_options ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui) ~source ~path
           with
          | Error message -> set_status ui ("index(" ^ source ^ ") erreur: " ^ message)
          | Ok options ->
              let entries = List.map (fun (option : Sources.selector_option) -> (option.value, option.label)) options in
              if entries = [] then clear_levels_from ui level
              else (
                clear_levels_from ui (level + 1);
                set_level_combo ui level (List.nth labels level) entries;
                set_status ui (Printf.sprintf "index(%s, path='%s') -> %d options" source path_text (List.length entries));
                if level + 1 < List.length labels then load_source_level ui (level + 1)))

let refresh_level_visibility ui =
  let labels = Option.value (Hashtbl.find_opt ui.source_labels (source_of_ui ui)) ~default:[] in
  Array.iteri
    (fun index state ->
      if index < List.length labels then (
        Gtk_bindings.label_set_text state.label (List.nth labels index);
        match state.mode with
        | Hidden -> ()
        | Combo ->
            Gtk_bindings.widget_hide state.label;
            Gtk_bindings.widget_show state.combo.widget;
            Gtk_bindings.widget_hide state.entry
        | Integer_input count ->
            Gtk_bindings.label_set_text state.label (Printf.sprintf "%s (1-%d)" (List.nth labels index) count);
            Gtk_bindings.widget_hide state.label;
            Gtk_bindings.widget_hide state.combo.widget;
            Gtk_bindings.widget_show state.entry)
      else set_level_hidden ui index)
    ui.levels

let load_source_catalog ui =
  let source_entries =
    Sources.list_sources ~root:ui.root
    |> List.map (fun (source : Sources.source_descriptor) ->
           Hashtbl.replace ui.source_labels source.id source.nomenclature;
           (source.id, source.id))
  in
  fill_combo ui ui.source_combo source_entries;
  clear_levels_from ui 0;
  refresh_level_visibility ui;
  load_source_level ui 0

let load_translations ui =
  match Bible_data.available_translations ~root:ui.root with
  | Error message -> set_status ui ("Traductions: " ^ message)
  | Ok translations ->
      let entries = List.map (fun (translation : Bible_data.translation_info) -> (translation.id, translation.id)) translations in
      fill_combo ui ui.translation_combo entries

let sync_selectors_to_reference ui reference =
  match
    Sources.selector_path_of_reference ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui)
      ~reference
  with
  | Ok (source, path) ->
      select_combo_value ui ui.source_combo source;
      clear_levels_from ui 0;
      refresh_level_visibility ui;
      load_source_level ui 0;
      List.iteri
        (fun index value ->
          if index < Array.length ui.levels then (
            let state = ui.levels.(index) in
            (match state.mode with
            | Hidden -> ()
            | Combo -> select_combo_value ui state.combo value
            | Integer_input _ ->
                ui.block <- true;
                Gtk_bindings.entry_set_text state.entry value;
                ui.block <- false);
            if index + 1 < Array.length ui.levels then load_source_level ui (index + 1)))
        path
  | Error _ -> ()

let show_reference ui reference =
  match
    Sources.render_reference ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui) ~reference
  with
  | Error message -> set_status ui ("Affichage impossible: " ^ message)
  | Ok rendered ->
      let resolved_reference = if rendered.reference = "" then reference else rendered.reference in
      apply_rendered ui ~fallback_reference:reference ~status_prefix:"Affichage: " rendered;
      sync_selectors_to_reference ui resolved_reference

let fetch_reference ui reference =
  match
    Sources.render_reference ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui) ~reference
  with
  | Ok rendered ->
      let resolved_reference = if rendered.reference = "" then reference else rendered.reference in
      Ok (resolved_reference, rendered.title, rendered.body)
  | Error message -> Error message

let append_reference ui direction =
  let edge_ref =
    match direction, ui.displayed_refs with
    | "previous", first :: _ -> first
    | "next", [] -> ui.current_ref
    | "next", refs -> List.hd (List.rev refs)
    | _, [] -> ui.current_ref
    | _, first :: _ -> first
  in
  let source_direction = if String.equal direction "previous" then Sources.Previous else Sources.Next in
  match
    Sources.navigate ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui) ~reference:edge_ref
      source_direction
  with
  | Error message -> set_status ui ("Ajout impossible: " ^ message)
  | Ok next_reference -> (
      match fetch_reference ui next_reference with
      | Error message -> set_status ui ("Ajout impossible: " ^ message)
      | Ok (resolved_reference, title, body) ->
          let combined_refs =
            match direction with
            | "previous" -> resolved_reference :: ui.displayed_refs
            | _ -> ui.displayed_refs @ [ resolved_reference ]
          in
          let combined_body =
            match direction with
            | "previous" -> body ^ "\n" ^ ui.current_body
            | _ -> ui.current_body ^ "\n" ^ body
          in
          let combined_title = if ui.current_title <> "" then ui.current_title else title in
          ui.displayed_refs <- combined_refs;
          ui.current_ref <- resolved_reference;
          set_output ui ~title:combined_title ~reference:(reference_summary combined_refs) ~body:combined_body ~references:None;
          sync_selectors_to_reference ui resolved_reference;
          set_status ui (Printf.sprintf "Ajout %s: %s" (if String.equal direction "previous" then "avant" else "après") resolved_reference);
          refresh_action_buttons ui)

let render_article_by_name ui article =
  select_combo_value ui ui.article_combo article;
  match Article_store.read ~root:ui.root ~name:article with
  | Error message -> set_status ui ("Article impossible: " ^ message)
  | Ok body ->
      let markup =
        Article_markdown.render_to_pango_markup ~highlights:ui.highlights
          ~resolve_internal:(resolve_internal_article_url ui) body
      in
      record_view ui (View_history.Article article);
      ui.displayed_refs <- [];
      Gtk_bindings.label_set_text ui.title_label article;
      Gtk_bindings.label_set_text ui.ref_label "";
      Gtk_bindings.label_set_markup ui.output_label markup;
      set_status ui ("Article: " ^ article);
      Gtk_bindings.widget_set_sensitive ui.chapter_button false;
      Gtk_bindings.widget_set_sensitive ui.append_prev_button false;
      Gtk_bindings.widget_set_sensitive ui.prev_button false;
      Gtk_bindings.widget_set_sensitive ui.next_button false;
      Gtk_bindings.widget_set_sensitive ui.append_next_button false

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
    match
      Sources.compile_reference ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui) ~source ~path
    with
    | Ok reference -> show_reference ui reference
    | Error message -> set_status ui ("Référence impossible: " ^ message)

let randomize_source ui =
  let source = source_of_ui ui in
  if source = "" then set_status ui "Aucune source sélectionnée."
  else
    let rec choose level =
      if level >= Array.length ui.levels then true
      else
        let state = ui.levels.(level) in
        match state.mode with
        | Hidden -> true
        | Combo -> (
            match random_choice state.combo.entries with
            | None -> false
            | Some (value, _) ->
                select_combo_value ui state.combo value;
                if level + 1 < Array.length ui.levels then load_source_level ui (level + 1);
                choose (level + 1))
        | Integer_input count ->
            if count <= 0 then false
            else (
              ui.block <- true;
              Gtk_bindings.entry_set_text state.entry (string_of_int (1 + Random.int count));
              ui.block <- false;
              if level + 1 < Array.length ui.levels then load_source_level ui (level + 1);
              choose (level + 1))
    in
    if choose 0 then goto_source ui else set_status ui ("Aucune sélection aléatoire disponible pour " ^ source)

let navigate ui direction =
  let source_direction = if String.equal direction "previous" then Sources.Previous else Sources.Next in
  match
    Sources.navigate ~root:ui.root ~names:ui.names ~bible_translation:(translation_of_ui ui) ~reference:ui.current_ref
      source_direction
  with
  | Error message -> set_status ui ("Navigation impossible: " ^ message)
  | Ok next_reference -> show_reference ui next_reference

let zoom ui delta =
  ui.text_size <- max 10 (ui.text_size + delta);
  ui.title_size <- max 12 (ui.title_size + delta);
  apply_font_sizes ui;
  set_status ui (Printf.sprintf "Taille du texte: %d" ui.text_size)

let create_label text =
  let label = Gtk_bindings.label_new text in
  Gtk_bindings.label_set_line_wrap label true;
  label

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

let make_ui root names =
  Gtk_bindings.init ();
  Random.self_init ();
  let background_path = Filename.concat root "bg.jpeg" in
  let logo_path = Filename.concat root "logo.jpeg" in
  let window = Gtk_bindings.window_new () in
  Gtk_bindings.window_set_title window "pas catho";
  Gtk_bindings.window_set_default_size window ~width:1200 ~height:850;
  Gtk_bindings.window_set_icon_from_file window logo_path;
  Gtk_bindings.window_enable_cross_background window background_path;
  let root_box = Gtk_bindings.box_new ~vertical:true ~spacing:4 in
  let row1 = Gtk_bindings.box_new ~vertical:false ~spacing:6 in
  let row2 = Gtk_bindings.box_new ~vertical:false ~spacing:6 in
  let source_row = Gtk_bindings.box_new ~vertical:false ~spacing:4 in
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
  Gtk_bindings.label_set_selectable output_label false;
  let scroll = Gtk_bindings.scrolled_window_new () in
  let show_button = Gtk_bindings.button_new "Afficher" in
  let copy_button = Gtk_bindings.button_new "📋" in
  let chapter_button = Gtk_bindings.button_new "Chapitre" in
  let append_prev_button = Gtk_bindings.button_new "+" in
  let prev_button = Gtk_bindings.button_new "Précédent" in
  let next_button = Gtk_bindings.button_new "Suivant" in
  let append_next_button = Gtk_bindings.button_new "+" in
  let zoom_out_button = Gtk_bindings.button_new "A-" in
  let zoom_in_button = Gtk_bindings.button_new "A+" in
  let goto_button = Gtk_bindings.button_new ">" in
  let lucky_button = Gtk_bindings.button_new "🍀" in
  let back_button = Gtk_bindings.button_new "Back" in
  let highlights = load_highlights root in
  let logo_image = Gtk_bindings.image_new_from_file logo_path in
  Gtk_bindings.flow_box_set_selection_mode source_flow 0;
  Gtk_bindings.scrolled_window_set_policy scroll ~h:1 ~v:1;
  Gtk_bindings.container_add scroll output_label;
  List.iter (Gtk_bindings.box_pack_start root_box ~expand:false ~fill:false ~padding:0)
    [ row1; row2; source_row; title_label; ref_label ];
  Gtk_bindings.box_pack_start source_row source_flow ~expand:true ~fill:true ~padding:0;
  Gtk_bindings.box_pack_start source_row goto_button ~expand:false ~fill:false ~padding:0;
  Gtk_bindings.box_pack_start source_row lucky_button ~expand:false ~fill:false ~padding:0;
  Gtk_bindings.box_pack_start row5 row5_left ~expand:true ~fill:true ~padding:0;
  Gtk_bindings.box_pack_start row5 row5_spacer ~expand:true ~fill:true ~padding:0;
  Gtk_bindings.box_pack_start row5 row5_right ~expand:false ~fill:false ~padding:0;
  Gtk_bindings.box_pack_start root_box scroll ~expand:true ~fill:true ~padding:0;
  Gtk_bindings.box_pack_start root_box row5 ~expand:false ~fill:false ~padding:0;
  Gtk_bindings.container_add window root_box;
  let ui =
    {
      root;
      names;
      block = false;
      suppress_history = false;
      translation = "bible_aelf";
      current_ref = "Jn 1,1";
      current_title = "";
      current_body = "";
      current_references = None;
      displayed_refs = [];
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
      lucky_button;
      chapter_button;
      append_prev_button;
      prev_button;
      next_button;
      append_next_button;
    }
  in
  let pack_label row text = Gtk_bindings.box_pack_start row (create_label text) ~expand:false ~fill:false ~padding:0 in
  let pack_widget row widget = Gtk_bindings.box_pack_start row widget ~expand:false ~fill:false ~padding:0 in
  let compact_width = 56 in
  let compact_entry_width = 36 in
  let article_width = 260 in
  Gtk_bindings.widget_set_size_request source_combo.widget ~width:compact_width ~height:(-1);
  Array.iter
    (fun level ->
      Gtk_bindings.widget_set_size_request level.combo.widget ~width:compact_width ~height:(-1);
      Gtk_bindings.widget_set_size_request level.entry ~width:compact_entry_width ~height:(-1))
    levels;
  Gtk_bindings.widget_set_size_request article_combo.widget ~width:article_width ~height:(-1);
  Gtk_bindings.widget_set_size_request goto_button ~width:22 ~height:(-1);
  Gtk_bindings.widget_set_size_request lucky_button ~width:28 ~height:(-1);
  pack_label row1 "Bible";
  pack_widget row1 translation_combo.widget;
  pack_label row1 "Référence";
  pack_widget row1 reference_entry;
  pack_widget row1 show_button;
  pack_widget row1 copy_button;
  List.iter (pack_widget row2) [ chapter_button; append_prev_button; prev_button; next_button; append_next_button ];
  Gtk_bindings.container_add source_flow source_combo.widget;
  Array.iter
    (fun level ->
      Gtk_bindings.container_add source_flow level.combo.widget;
      Gtk_bindings.container_add source_flow level.entry)
    levels;
  pack_widget row5_left back_button;
  pack_label row5_left "Article";
  Gtk_bindings.box_pack_start row5_left article_combo.widget ~expand:true ~fill:true ~padding:0;
  List.iter (pack_widget row5_right) [ logo_image; zoom_out_button; zoom_in_button ];
  Gtk_bindings.entry_set_text reference_entry ui.current_ref;
  apply_font_sizes ui;
  Gtk_bindings.connect_destroy window Gtk_bindings.main_quit;
  Gtk_bindings.connect_clicked show_button (fun () -> show_reference ui (Gtk_bindings.entry_get_text reference_entry));
  Gtk_bindings.connect_clicked copy_button (fun () ->
      let reference = String.trim ui.current_ref in
      if reference <> "" then Gtk_bindings.widget_copy_text_to_clipboard window reference);
  Gtk_bindings.connect_clicked chapter_button (fun () ->
      match chapter_target ui (Gtk_bindings.entry_get_text reference_entry |> String.trim) with
      | Some reference -> show_reference ui reference
      | None -> set_status ui "Chapitre indisponible pour cette source");
  Gtk_bindings.connect_clicked append_prev_button (fun () -> append_reference ui "previous");
  Gtk_bindings.connect_clicked prev_button (fun () -> navigate ui "previous");
  Gtk_bindings.connect_clicked next_button (fun () -> navigate ui "next");
  Gtk_bindings.connect_clicked append_next_button (fun () -> append_reference ui "next");
  Gtk_bindings.connect_clicked zoom_out_button (fun () -> zoom ui (-1));
  Gtk_bindings.connect_clicked zoom_in_button (fun () -> zoom ui 1);
  Gtk_bindings.connect_clicked goto_button (fun () -> goto_source ui);
  Gtk_bindings.connect_clicked lucky_button (fun () -> randomize_source ui);
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
  let article_entries = Article_store.list ~root |> List.map (fun (article : Article_store.article) -> (article.name, article.name)) in
  fill_combo ~max_chars:32 ui article_combo article_entries;
  load_source_catalog ui;
  show_reference ui ui.current_ref;
  refresh_action_buttons ui;
  update_back_button ui;
  ui

let launch root =
  match Book_names.load ~root with
  | Error message -> Error message
  | Ok names ->
      let _ui = make_ui root names in
      Gtk_bindings.main ();
      Ok ()
