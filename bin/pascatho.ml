open Cmdliner

let ( let* ) result f = match result with Ok value -> f value | Error _ as e -> e

let root () = Project_root.find ()

let load_context translation_id =
  let* root = root () in
  let* names = Book_names.load ~root in
  let* translation = Bible_data.load_translation ~root ~names ~id:translation_id in
  Ok (root, names, translation)

let render_verses (verses : Bible_data.verse list) =
  verses
  |> List.map (fun (verse : Bible_data.verse) -> Printf.sprintf "%d. %s" verse.number verse.text)
  |> String.concat "\n"

let render_lookup translation_id reference_text =
  let* _, names, translation = load_context translation_id in
  let* reference = Bible_reference.parse ~names reference_text in
  let* book_title, verses = Bible_data.lookup translation reference in
  let header = "REF\t" ^ Bible_reference.format reference in
  Ok (String.concat "\n" [ header; "TEXT\t" ^ book_title; ""; render_verses verses ])

let render_chapter translation_id reference_text =
  let* _, names, translation = load_context translation_id in
  let* reference = Bible_reference.parse ~names reference_text in
  let* book_title, chapter = Bible_data.chapter translation reference in
  let chapter_reference =
    {
      reference with
      verses = { Bible_reference.first_verse = None; last_verse = None };
    }
  in
  let body =
    Array.to_list chapter.verses
    |> List.map (fun (verse : Bible_data.verse) -> Printf.sprintf "%d. %s" verse.number verse.text)
    |> String.concat "\n"
  in
  Ok
    (String.concat "\n" [ "REF\t" ^ Bible_reference.format chapter_reference; "TEXT\t" ^ book_title; body ])

let render_navigation translation_id reference_text direction =
  let* _, names, translation = load_context translation_id in
  let* reference = Bible_reference.parse ~names reference_text in
  let* next_reference = Bible_data.navigate translation reference direction in
  render_lookup translation_id (Bible_reference.format next_reference)

let render_status translation_id reference_text =
  let* _, names, translation = load_context translation_id in
  let* reference = Bible_reference.parse ~names reference_text in
  let* status = Bible_data.navigation translation reference in
  Ok
    (Printf.sprintf "prev=%d\nnext=%d" (if status.has_previous then 1 else 0) (if status.has_next then 1 else 0))

let render_lucky translation_id book_filter =
  let* _, names, translation = load_context translation_id in
  let* reference =
    match book_filter with
    | None -> Bible_data.random_reference translation ()
    | Some book ->
        let* parsed =
          match Bible_reference.parse ~names (book ^ " 1") with
          | Ok reference -> Ok reference.book
          | Error _ -> Ok book
        in
        Bible_data.random_reference ~book:parsed translation ()
  in
  render_lookup translation_id (Bible_reference.format reference)

let render_translations () =
  let* root = root () in
  let* translations = Bible_data.available_translations ~root in
  Ok
    (translations
    |> List.map (fun (translation : Bible_data.translation_info) -> translation.id ^ "\t" ^ translation.title)
    |> String.concat "\n")

let render_books translation_id =
  let* _, _, translation = load_context translation_id in
  Ok
    (Bible_data.books translation
    |> List.map (fun (book : Bible_data.book_info) ->
           String.concat "\t" [ book.canonical_title; book.display_title; string_of_int book.chapter_count ])
    |> String.concat "\n")

let render_chapters translation_id book =
  let* _, _, translation = load_context translation_id in
  let* chapters = Bible_data.chapter_numbers translation ~book in
  Ok (chapters |> List.map string_of_int |> String.concat "\n")

let render_verse_numbers translation_id book chapter =
  let* _, _, translation = load_context translation_id in
  let* verses = Bible_data.verse_numbers translation ~book ~chapter in
  Ok (verses |> List.map string_of_int |> String.concat "\n")

let render_search source_filter query =
  let* root = root () in
  let sources =
    match source_filter with
    | None -> None
    | Some "" -> None
    | Some csv -> Some (String.split_on_char ',' csv |> List.map String.trim |> List.filter (( <> ) ""))
  in
  let* hits = Vatican_data.search ~root ~sources ~query ~limit:20 in
  Ok
    (hits
    |> List.map (fun (hit : Vatican_data.hit) ->
           String.concat "\t" [ hit.source_id; hit.date; hit.title; hit.url; hit.snippet ])
    |> String.concat "\n")

let render_articles () =
  let* root = root () in
  let articles = Article_store.list ~root in
  Ok (articles |> List.map (fun (article : Article_store.article) -> article.name) |> String.concat "\n")

let render_article name =
  let* root = root () in
  Article_store.read ~root ~name

let split_path text =
  if String.trim text = "" then []
  else String.split_on_char '\t' text |> List.filter (fun item -> item <> "")

let render_source_list _translation_id =
  let* root = root () in
  let sources = Sources.list_sources ~root in
  Ok
    (sources
    |> List.map (fun (source : Sources.source_descriptor) ->
           String.concat "\t" [ source.id; source.label; String.concat "|" source.nomenclature ])
    |> String.concat "\n")

let render_source_options translation_id source path_text =
  let* root = root () in
  let* names = Book_names.load ~root in
  let options =
    Sources.selector_options ~root ~names ~bible_translation:translation_id ~source ~path:(split_path path_text)
  in
  let* options = options in
  Ok
    (options
    |> List.map (fun (option : Sources.selector_option) -> option.value ^ "\t" ^ option.label)
    |> String.concat "\n")

let render_source_count translation_id source path_text =
  let* root = root () in
  let* names = Book_names.load ~root in
  let* count = Sources.selector_count ~root ~names ~bible_translation:translation_id ~source ~path:(split_path path_text) in
  Ok
    (match count with
    | None -> ""
    | Some value -> string_of_int value)

let render_compile_reference translation_id source path_text =
  let* root = root () in
  let* names = Book_names.load ~root in
  Sources.compile_reference ~root ~names ~bible_translation:translation_id ~source ~path:(split_path path_text)

let render_selector_path translation_id reference_text =
  let* root = root () in
  let* names = Book_names.load ~root in
  let* source, path =
    Sources.selector_path_of_reference ~root ~names ~bible_translation:translation_id ~reference:reference_text
  in
  Ok (String.concat "\n" [ source; String.concat "\t" path ])

let render_source_reference translation_id reference_text =
  let* root = root () in
  let* names = Book_names.load ~root in
  let* rendered = Sources.render_reference ~root ~names ~bible_translation:translation_id ~reference:reference_text in
  Ok (String.concat "\n" [ "REF\t" ^ rendered.reference; "TEXT\t" ^ rendered.title; ""; rendered.body ])

let render_source_status translation_id reference_text =
  let* root = root () in
  let* names = Book_names.load ~root in
  let* status = Sources.navigation ~root ~names ~bible_translation:translation_id ~reference:reference_text in
  Ok (Printf.sprintf "prev=%d\nnext=%d" (if status.has_previous then 1 else 0) (if status.has_next then 1 else 0))

let render_chapter_ref translation_id reference_text =
  let* root = root () in
  let* names = Book_names.load ~root in
  let* chapter_ref = Sources.chapter_reference ~root ~names ~bible_translation:translation_id ~reference:reference_text in
  Ok (Option.value chapter_ref ~default:"")

let render_source_navigation translation_id reference_text direction =
  let* root = root () in
  let* names = Book_names.load ~root in
  let* next_reference =
    Sources.navigate ~root ~names ~bible_translation:translation_id ~reference:reference_text
      (match direction with
      | Bible_data.Previous -> Sources.Previous
      | Bible_data.Next -> Sources.Next)
  in
  render_source_reference translation_id next_reference

let render_decode_site_ref url =
  match Sources.decode_site_reference_url url with
  | Some reference -> Ok reference
  | None -> Ok ""

type tui_state = {
  root : string;
  names : Book_names.t;
  mutable translation : string;
  mutable current_ref : string;
  mutable source : string option;
  mutable path : string list;
  mutable status : string;
}

let print_block title content =
  print_endline ("== " ^ title ^ " ==");
  print_endline content;
  print_endline ""

let show_available_sources state =
  let sources = Sources.list_sources ~root:state.root in
  print_block "Sources"
    (sources
    |> List.map (fun (source : Sources.source_descriptor) ->
           Printf.sprintf "%s : %s" source.id (String.concat " > " source.nomenclature))
    |> String.concat "\n")

let show_articles state =
  let articles = Article_store.list ~root:state.root in
  print_block "Articles" (articles |> List.map (fun (article : Article_store.article) -> article.name) |> String.concat "\n")

let current_selector_options state =
  match state.source with
  | None -> Ok []
  | Some source ->
      Sources.selector_options ~root:state.root ~names:state.names ~bible_translation:state.translation ~source
        ~path:state.path

let show_state state =
  print_endline "=== Pascatho ===";
  print_endline ("Traduction : " ^ state.translation);
  print_endline ("Source     : " ^ Option.value state.source ~default:"(aucune)");
  print_endline ("Chemin     : " ^ if state.path = [] then "(vide)" else String.concat " > " state.path);
  print_endline ("Référence  : " ^ state.current_ref);
  print_endline ("Status     : " ^ state.status);
  print_endline "";
  match current_selector_options state with
  | Error message -> print_block "Options" ("Erreur : " ^ message)
  | Ok [] -> print_block "Options" "(aucune option supplémentaire)"
  | Ok options ->
      print_block "Options"
        (options
        |> List.mapi (fun index (option : Sources.selector_option) ->
               Printf.sprintf "%d. %s" (index + 1) option.label)
        |> String.concat "\n")

let show_reference_block state reference =
  match render_source_reference state.translation reference with
  | Ok text ->
      state.current_ref <- reference;
      state.status <- "Affichage de " ^ reference;
      print_block "Contenu" text
  | Error message ->
      state.status <- "Erreur : " ^ message;
      print_block "Erreur" message

let show_chapter_block state =
  match render_chapter state.translation state.current_ref with
  | Ok text ->
      state.status <- "Chapitre " ^ state.current_ref;
      print_block "Chapitre" text
  | Error message ->
      state.status <- "Erreur : " ^ message;
      print_block "Erreur" message

let navigate_block state direction =
  match render_source_navigation state.translation state.current_ref direction with
  | Ok text ->
      let lines = String.split_on_char '\n' text in
      let reference =
        match lines with
        | first :: _ when String.length first > 4 && String.sub first 0 4 = "REF\t" ->
            String.sub first 4 (String.length first - 4)
        | _ -> state.current_ref
      in
      state.current_ref <- reference;
      state.status <- "Navigation vers " ^ reference;
      print_block "Contenu" text
  | Error message ->
      state.status <- "Erreur : " ^ message;
      print_block "Erreur" message

let show_article_block state name =
  match Article_store.read ~root:state.root ~name with
  | Ok text ->
      state.status <- "Article " ^ name;
      print_block ("Article " ^ name) text
  | Error message ->
      state.status <- "Erreur : " ^ message;
      print_block "Erreur" message

let choose_source state source =
  if List.exists (fun (item : Sources.source_descriptor) -> String.equal item.id source) (Sources.list_sources ~root:state.root) then (
    state.source <- Some source;
    state.path <- [];
    state.status <- "Source sélectionnée : " ^ source;
    Ok ())
  else Error ("Source inconnue : " ^ source)

let select_next_option state selection =
  let* options = current_selector_options state in
  let* option =
    match int_of_string_opt selection with
    | Some index when index >= 1 && index <= List.length options -> Ok (List.nth options (index - 1))
    | _ -> (
        match
          List.find_opt
            (fun (option : Sources.selector_option) -> String.equal option.value selection || String.equal option.label selection)
            options
        with
        | Some option -> Ok option
        | None -> Error ("Option introuvable : " ^ selection))
  in
  state.path <- state.path @ [ option.value ];
  state.status <- "Sélection : " ^ option.label;
  Ok ()

let goto_selected state =
  match state.source with
  | None -> Error "Aucune source sélectionnée."
  | Some source ->
      let* reference =
        Sources.compile_reference ~root:state.root ~names:state.names ~bible_translation:state.translation ~source
          ~path:state.path
      in
      show_reference_block state reference;
      Ok ()

let print_help () =
  print_block "Commandes"
    (String.concat "\n"
       [
         "help : affiche cette aide";
         "translations : liste les traductions";
         "translation <id> : change la traduction";
         "sources : liste les sources";
         "source <id> : sélectionne une source";
         "select <n|valeur> : choisit l'option suivante";
         "back : remonte d'un niveau";
         "goto : compile la sélection courante et affiche";
         "ref <reference> : affiche une référence";
         "chapter : affiche le chapitre courant";
         "next / prev : navigation";
         "articles : liste les articles";
         "article <nom> : ouvre un article";
         "status : réaffiche l'état";
         "quit : quitte";
       ])

let _launch_tui () =
  let* root = root () in
  let* names = Book_names.load ~root in
  let state =
    {
      root;
      names;
      translation = "bible_aelf";
      current_ref = "Jn 1,1";
      source = Some "Bible";
      path = [];
      status = "Interface native OCaml (terminal).";
    }
  in
  print_help ();
  let rec loop () =
    show_state state;
    print_string "> ";
    flush stdout;
    match read_line () with
    | exception End_of_file -> Ok ()
    | line ->
        let words = String.split_on_char ' ' (String.trim line) |> List.filter (fun item -> item <> "") in
        let result =
          match words with
          | [] -> Ok ()
          | [ "help" ] ->
              print_help ();
              Ok ()
          | [ "translations" ] ->
              print_block "Traductions"
                (match render_translations () with Ok text -> text | Error message -> message);
              Ok ()
          | [ "translation"; translation ] ->
              state.translation <- translation;
              state.path <- [];
              state.status <- "Traduction sélectionnée : " ^ translation;
              Ok ()
          | [ "sources" ] ->
              show_available_sources state;
              Ok ()
          | [ "source"; source ] -> choose_source state source
          | [ "select"; selection ] -> select_next_option state selection
          | [ "back" ] ->
              state.path <- (match List.rev state.path with [] -> [] | _ :: rest -> List.rev rest);
              state.status <- "Retour arrière";
              Ok ()
          | [ "goto" ] -> goto_selected state
          | "ref" :: rest ->
              let reference = String.concat " " rest in
              show_reference_block state reference;
              Ok ()
          | [ "chapter" ] ->
              show_chapter_block state;
              Ok ()
          | [ "next" ] ->
              navigate_block state Bible_data.Next;
              Ok ()
          | [ "prev" ] ->
              navigate_block state Bible_data.Previous;
              Ok ()
          | [ "articles" ] ->
              show_articles state;
              Ok ()
          | "article" :: rest ->
              show_article_block state (String.concat " " rest);
              Ok ()
          | [ "status" ] -> Ok ()
          | [ "quit" ] -> Error "__quit__"
          | _ -> Error "Commande inconnue. Tape `help`."
        in
        match result with
        | Ok () -> loop ()
        | Error "__quit__" -> Ok ()
        | Error message ->
            state.status <- message;
            loop ()
  in
  loop ()

let print_or_fail output =
  match output with
  | Ok text ->
      print_endline text;
      0
  | Error message ->
      prerr_endline message;
      1

let translation =
  let doc = Arg.info [ "translation" ] ~doc:"Identifiant de traduction biblique." in
  Arg.required (Arg.opt (Arg.some Arg.string) None doc)

let reference =
  let doc = Arg.info [ "reference" ] ~doc:"Référence biblique, par ex. `Jn 1,1`." in
  Arg.required (Arg.opt (Arg.some Arg.string) None doc)

let query =
  let doc = Arg.info [ "query" ] ~doc:"Texte à rechercher." in
  Arg.required (Arg.opt (Arg.some Arg.string) None doc)

let sources_arg =
  let doc = Arg.info [ "sources" ] ~doc:"Liste CSV de sources Vatican." in
  Arg.value (Arg.opt (Arg.some Arg.string) None doc)

let source_arg =
  let doc = Arg.info [ "source" ] ~doc:"Identifiant de source logique." in
  Arg.required (Arg.opt (Arg.some Arg.string) None doc)

let path_arg =
  let doc = Arg.info [ "path" ] ~doc:"Chemin de sélection encodé par tabulations." in
  Arg.value (Arg.opt Arg.string "" doc)

let url_arg =
  let doc = Arg.info [ "url" ] ~doc:"URL article à décoder en référence interne." in
  Arg.required (Arg.opt (Arg.some Arg.string) None doc)

let book_arg =
  let doc = Arg.info [ "book" ] ~doc:"Filtre sur un livre biblique." in
  Arg.value (Arg.opt (Arg.some Arg.string) None doc)

let required_book_arg =
  let doc = Arg.info [ "book" ] ~doc:"Livre biblique." in
  Arg.required (Arg.opt (Arg.some Arg.string) None doc)

let chapter_number_arg =
  let doc = Arg.info [ "chapter_number" ] ~doc:"Numéro de chapitre." in
  Arg.required (Arg.opt (Arg.some Arg.int) None doc)

let direction =
  let parse = function
    | "previous" -> Ok Bible_data.Previous
    | "next" -> Ok Bible_data.Next
    | value -> Error (`Msg ("Direction invalide: " ^ value))
  in
  let print formatter = function
    | Bible_data.Previous -> Format.pp_print_string formatter "previous"
    | Bible_data.Next -> Format.pp_print_string formatter "next"
  in
  let doc = Arg.info [ "direction" ] ~doc:"`previous` ou `next`." in
  Arg.required (Arg.opt (Arg.some (Arg.conv (parse, print))) None doc)

let name_arg =
  let doc = Arg.info [ "name" ] ~doc:"Nom d'article markdown." in
  Arg.required (Arg.opt (Arg.some Arg.string) None doc)

let mk_cmd name doc term =
  Cmd.v (Cmd.info name ~doc) term

let commands =
  [
    mk_cmd "translations" "Liste les traductions bibliques." Term.(const (fun () -> Stdlib.exit (print_or_fail (render_translations ()))) $ const ());
    mk_cmd "source-list" "Liste les sources applicatives." Term.(const (fun translation -> Stdlib.exit (print_or_fail (render_source_list translation))) $ translation);
    mk_cmd "source-options" "Liste les options d'un niveau de source." Term.(const (fun translation source path -> Stdlib.exit (print_or_fail (render_source_options translation source path))) $ translation $ source_arg $ path_arg);
    mk_cmd "source-count" "Compte d'articles attendu pour un niveau de source." Term.(const (fun translation source path -> Stdlib.exit (print_or_fail (render_source_count translation source path))) $ translation $ source_arg $ path_arg);
    mk_cmd "compile-ref" "Compile une référence depuis un chemin de source." Term.(const (fun translation source path -> Stdlib.exit (print_or_fail (render_compile_reference translation source path))) $ translation $ source_arg $ path_arg);
    mk_cmd "selector-path" "Résout une référence vers la source et le chemin de sélection." Term.(const (fun translation reference -> Stdlib.exit (print_or_fail (render_selector_path translation reference))) $ translation $ reference);
    mk_cmd "decode-site-ref" "Décode une URL pascatho.ovh en référence interne." Term.(const (fun url -> Stdlib.exit (print_or_fail (render_decode_site_ref url))) $ url_arg);
    mk_cmd "show-ref" "Affiche une référence générique." Term.(const (fun translation reference -> Stdlib.exit (print_or_fail (render_source_reference translation reference))) $ translation $ reference);
    mk_cmd "status-ref" "Statut de navigation d'une référence générique." Term.(const (fun translation reference -> Stdlib.exit (print_or_fail (render_source_status translation reference))) $ translation $ reference);
    mk_cmd "chapter-ref" "Référence de chapitre complète pour une référence générique." Term.(const (fun translation reference -> Stdlib.exit (print_or_fail (render_chapter_ref translation reference))) $ translation $ reference);
    mk_cmd "navigate-ref" "Navigation sur une référence générique." Term.(const (fun translation reference direction -> Stdlib.exit (print_or_fail (render_source_navigation translation reference direction))) $ translation $ reference $ direction);
    mk_cmd "books" "Liste les livres d'une traduction." Term.(const (fun translation -> Stdlib.exit (print_or_fail (render_books translation))) $ translation);
    mk_cmd "chapters" "Liste les chapitres d'un livre." Term.(const (fun translation book -> Stdlib.exit (print_or_fail (render_chapters translation book))) $ translation $ required_book_arg);
    mk_cmd "verses" "Liste les versets d'un chapitre." Term.(const (fun translation book chapter_number -> Stdlib.exit (print_or_fail (render_verse_numbers translation book chapter_number))) $ translation $ required_book_arg $ chapter_number_arg);
    mk_cmd "lookup" "Affiche une référence biblique." Term.(const (fun translation reference -> Stdlib.exit (print_or_fail (render_lookup translation reference))) $ translation $ reference);
    mk_cmd "chapter" "Affiche un chapitre complet." Term.(const (fun translation reference -> Stdlib.exit (print_or_fail (render_chapter translation reference))) $ translation $ reference);
    mk_cmd "navigate" "Navigue vers le verset précédent ou suivant." Term.(const (fun translation reference direction -> Stdlib.exit (print_or_fail (render_navigation translation reference direction))) $ translation $ reference $ direction);
    mk_cmd "status" "Indique les possibilités de navigation." Term.(const (fun translation reference -> Stdlib.exit (print_or_fail (render_status translation reference))) $ translation $ reference);
    mk_cmd "lucky" "Choisit un verset aléatoire." Term.(const (fun translation book -> Stdlib.exit (print_or_fail (render_lucky translation book))) $ translation $ book_arg);
    mk_cmd "search" "Recherche dans les sources Vatican." Term.(const (fun query sources -> Stdlib.exit (print_or_fail (render_search sources query))) $ query $ sources_arg);
    mk_cmd "articles" "Liste les articles markdown disponibles." Term.(const (fun () -> Stdlib.exit (print_or_fail (render_articles ()))) $ const ());
    mk_cmd "article" "Affiche un article markdown." Term.(const (fun name -> Stdlib.exit (print_or_fail (render_article name))) $ name_arg);
  ]

let main () =
  if Array.length Sys.argv = 1 then
    (match root () with
    | Ok root ->
        let backend = Filename.concat root "_build/default/bin/pascatho.exe" in
        let _ = Gtk_ui.launch backend in
        0
    | Error message ->
        prerr_endline message;
        1)
  else Cmd.eval (Cmd.group (Cmd.info "pascatho") commands)

let () =
  Printexc.record_backtrace true;
  try Stdlib.exit (main ()) with
  | exn ->
      prerr_endline ("Fatal error: exception " ^ Printexc.to_string exn);
      let backtrace = Printexc.get_backtrace () in
      if String.trim backtrace <> "" then prerr_endline backtrace;
      Stdlib.exit 2
