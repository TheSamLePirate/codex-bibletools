let fail message =
  prerr_endline message;
  exit 1

let ( let* ) result f = match result with Ok value -> f value | Error message -> fail message

let assert_true condition message = if not condition then fail message

let assert_contains ~needle haystack message =
  try
    ignore (Str.search_forward (Str.regexp_string needle) haystack 0);
    ()
  with Not_found -> fail message

let assert_raises_failure f message =
  try
    ignore (f ());
    fail message
  with Failure _ -> ()

let rec read_all_lines channel acc =
  match input_line channel with
  | line -> read_all_lines channel (line :: acc)
  | exception End_of_file -> List.rev acc

let string_starts_with ~prefix text =
  let prefix_len = String.length prefix in
  String.length text >= prefix_len && String.sub text 0 prefix_len = prefix

let find_map predicate list =
  let rec loop = function
    | [] -> Error "Aucun élément valide trouvé."
    | item :: rest -> (
        match predicate item with Ok value -> Ok value | Error _ -> loop rest)
  in
  loop list

let run_command_capture_lines argv =
  let command = Array.of_list argv in
  let input = Unix.open_process_args_in (List.hd argv) command in
  Fun.protect
    ~finally:(fun () ->
      match Unix.close_process_in input with
      | Unix.WEXITED 0 -> ()
      | Unix.WEXITED code -> fail (Printf.sprintf "La commande a échoué avec le code %d." code)
      | Unix.WSIGNALED signal -> fail (Printf.sprintf "La commande a été interrompue par le signal %d." signal)
      | Unix.WSTOPPED signal -> fail (Printf.sprintf "La commande a été stoppée par le signal %d." signal))
    (fun () -> read_all_lines input [])

let run_command_capture_lines_in_dir dir argv =
  let previous = Sys.getcwd () in
  Fun.protect
    ~finally:(fun () -> Sys.chdir previous)
    (fun () ->
      Sys.chdir dir;
      run_command_capture_lines argv)

let rec find_renderable_path ~root ~names ~translation ~source path =
  let* options = Sources.selector_options ~root ~names ~bible_translation:translation ~source ~path in
  if options = [] then
    let* reference = Sources.compile_reference ~root ~names ~bible_translation:translation ~source ~path in
    let* rendered = Sources.render_reference ~root ~names ~bible_translation:translation ~reference in
    if String.trim rendered.body = "" then Error "Rendu vide." else Ok (reference, rendered)
  else
    find_map
      (fun (option : Sources.selector_option) ->
        find_renderable_path ~root ~names ~translation ~source (path @ [ option.value ]))
      options

let assert_source_roundtrip ~root ~names ~translation ~source =
  let* reference, rendered = find_renderable_path ~root ~names ~translation ~source [] in
  assert_true (String.equal rendered.reference reference) ("Round-trip cassé pour la source " ^ source ^ ".");
  assert_true (String.trim rendered.body <> "") ("Le rendu doit être non vide pour la source " ^ source ^ ".");
  Ok ()

let resolve_article_url url =
  if string_starts_with ~prefix:"https://pascatho.ovh/?" url then Sources.decode_site_reference_url url else None

let list_article_urls root =
  let articles_dir = Filename.concat root "articles" in
  Sys.readdir articles_dir |> Array.to_list
  |> List.filter (fun file -> Filename.check_suffix file ".md")
  |> List.map (fun file ->
         let path = Filename.concat articles_dir file in
         let channel = open_in path in
         Fun.protect
           ~finally:(fun () -> close_in channel)
           (fun () ->
             let text = String.concat "\n" (read_all_lines channel []) in
             let regexp = Str.regexp "\\[[^]]+\\](\\([^)]*\\))" in
             let rec loop start acc =
               try
                 let _ = Str.search_forward regexp text start in
                 let url = Str.matched_group 1 text in
                 loop (Str.match_end ()) ((file, url) :: acc)
               with Not_found -> List.rev acc
             in
             loop 0 []))
  |> List.flatten

let article_reference_supported reference =
  let lower = String.lowercase_ascii reference in
  not
    (string_starts_with ~prefix:"DH." reference
    || (Str.string_match (Str.regexp "^[a-z]+:") lower 0
       &&
       not
         (List.exists
            (fun prefix -> string_starts_with ~prefix lower)
            [ "ahmad:"; "bukhari:"; "muslim:"; "abudawud:"; "tirmidhi:"; "nasai:"; "riyadussalihin:"; "mishkat:"; "ibnmajah:"; "adab:" ])))

let with_temp_dir prefix f =
  let base = Filename.concat (Filename.get_temp_dir_name ()) (prefix ^ "_" ^ string_of_int (Unix.getpid ()) ^ "_" ^ string_of_int (Random.int 1_000_000)) in
  Unix.mkdir base 0o755;
  Fun.protect ~finally:(fun () -> ()) (fun () -> f base)

let () =
  let* initial_address_space_limit = Process_limits.address_space_limit_bytes () in
  let eight_gib = Int64.mul 8L 1_073_741_824L in
  let requested_limit =
    match initial_address_space_limit with
    | Some current when Int64.compare current eight_gib < 0 -> current
    | _ -> eight_gib
  in
  let* () = Process_limits.set_address_space_limit_bytes ~bytes:requested_limit in
  let* updated_address_space_limit = Process_limits.address_space_limit_bytes () in
  assert_true
    (match updated_address_space_limit with Some current -> Int64.equal current requested_limit | None -> false)
    "La limite d'espace d'adressage doit pouvoir être définie explicitement.";
  let history =
    View_history.empty
    |> fun history -> View_history.visit history (View_history.Reference "Jn 1,1")
    |> fun history -> View_history.visit history (View_history.Article "inceste.md")
  in
  assert_true (View_history.can_go_back history) "L'historique doit permettre un retour après deux vues.";
  let previous_view, history_after_back =
    match View_history.pop history with
    | Some value -> value
    | None -> fail "Le retour arrière doit trouver une vue précédente."
  in
  assert_true
    (match previous_view with View_history.Reference "Jn 1,1" -> true | _ -> false)
    "Le retour arrière doit revenir à la référence précédente.";
  assert_true (not (View_history.can_go_back history_after_back)) "Après un seul retour, la pile doit être vide.";
  assert_true (BibleTools.rm2num "XIV" = 14) "La conversion des chiffres romains doit être disponible côté OCaml.";
  assert_true
    (String.equal (BibleTools.handle_romans "^Livre \\([IVX]+\\)$" "Livre XIV") "Livre 14")
    "Le helper de conversion des chiffres romains doit remplacer les groupes capturés.";
  assert_true
    (String.equal
       (BibleTools.simplify_book_label "Première lettre de saint Paul Apôtre aux Corinthiens")
       "1 Corinthiens")
    "La simplification des libellés doit préserver les raccourcis des lettres de saint Paul.";
  assert_true
    (String.equal
       (BibleTools.simplify_book_label "Deuxième lettre de saint Paul Apôtre à Timothée")
       "2 Timothée")
    "La simplification des libellés doit aussi préserver les raccourcis vers Timothée.";
  assert_true
    (String.equal (BibleTools.simplify_book_label "Livre de la Genèse") "la Genèse")
    "La simplification des libellés doit supprimer les préfixes de type `Livre de`.";
  let* names_without_js = Book_names.load ~root:"/tmp/does-not-need-bibletools-js" in
  assert_true
    (Book_names.canonical_title names_without_js "Jn" = Some "Jean")
    "Les noms bibliques ne doivent plus dépendre du fichier bibleTools.js.";
  let* () = with_temp_dir "textprocess" (fun temp_root ->
      let datas_dir = Filename.concat temp_root "datas" in
      Unix.mkdir datas_dir 0o755;
      let artifact =
        `Assoc
          [
            ( "sources",
              `List
                [
                  `Assoc
                    [
                      ("id", `String "demo");
                      ("label", `String "Demo");
                      ( "documents",
                        `List
                          [
                            `Assoc
                              [
                                ("id", `String "demo:1");
                                ("title", `String "Doc 1");
                                ("reference", `String "Demo 1");
                                ("text", `String "Grace et paix. La paix demeure.");
                                ("paragraphs", `List [ `String "Grace et paix. La paix demeure." ]);
                                ("sentences", `List [ `String "Grace et paix"; `String "La paix demeure" ]);
                                ("tokens", `List [ `String "grace"; `String "paix"; `String "paix"; `String "demeure" ]);
                              ];
                            `Assoc
                              [
                                ("id", `String "demo:2");
                                ("title", `String "Doc 2");
                                ("reference", `String "Demo 2");
                                ("text", `String "Parabole et justice. Justice profonde.");
                                ("paragraphs", `List [ `String "Parabole et justice. Justice profonde." ]);
                                ("sentences", `List [ `String "Parabole et justice"; `String "Justice profonde" ]);
                                ("tokens", `List [ `String "parabole"; `String "justice"; `String "justice"; `String "profonde" ]);
                              ];
                          ] );
                    ];
                  `Assoc
                    [
                      ("id", `String "filtered");
                      ("label", `String "Filtered");
                      ( "documents",
                        `List
                          [
                            `Assoc
                              [
                                ("id", `String "filtered:1");
                                ("title", `String "Filtered 1");
                                ("reference", `String "Filtered 1");
                                ("text", `String "J'ai 12 pains et il a été chez eux, mais ne dit jamais cela.");
                              ];
                          ] );
                    ];
                  `Assoc
                    [
                      ("id", `String "generator");
                      ("label", `String "Generator");
                      ( "documents",
                        `List
                          [
                            `Assoc
                              [
                                ("id", `String "generator:1");
                                ("title", `String "Generator 1");
                                ("reference", `String "Generator 1");
                                ("text", `String "Avec pain et eau. Sans pain et feu.");
                              ];
                          ] );
                    ];
                  `Assoc
                    [
                      ("id", `String "Coran");
                      ("label", `String "Coran");
                      ( "documents",
                        `List
                          [
                            `Assoc
                              [
                                ("id", `String "coran:1");
                                ("title", `String "Coran 1");
                                ("reference", `String "Coran:1.1");
                                ("text", `String "Miséricorde paix.");
                              ];
                            `Assoc
                              [
                                ("id", `String "coran:2");
                                ("title", `String "Coran 2");
                                ("reference", `String "Coran:2.1");
                                ("text", `String "Combat fer.");
                              ];
                          ] );
                    ];
                ] );
            ( "reference",
              `List
                [
                  `Assoc
                    [
                      ("id", `String "ref:1");
                      ("title", `String "Hugo 1");
                      ("reference", `String "Hugo 1");
                      ("text", `String "Paix et mer.");
                      ("paragraphs", `List [ `String "Paix et mer." ]);
                      ("sentences", `List [ `String "Paix et mer" ]);
                      ("tokens", `List [ `String "paix"; `String "mer" ]);
                    ];
                ] );
          ]
      in
      assert_true
        (String.equal (Text_process.artifact_path ~root:temp_root) (Filename.concat temp_root "datas/textprocess_manifest.json"))
        "Text_process.artifact_path doit pointer vers le manifeste attendu.";
      assert_true
        (String.equal Text_process.preprocess_command "dune exec processSources")
        "Text_process.preprocess_command doit exposer la commande de régénération.";
      assert_true
        (try
           ignore (Text_process.preprocess_and_save ~root:(Filename.concat temp_root "missing"));
           false
         with Unix.Unix_error _ -> true)
        "Text_process.preprocess_and_save doit échouer explicitement sur une racine invalide.";
      Yojson.Safe.to_file (Text_process.artifact_path ~root:temp_root) artifact;
      assert_raises_failure
        (fun () -> Text_process.ensure_preprocessed ~root:(Filename.concat temp_root "missing"))
        "Text_process.ensure_preprocessed doit échouer explicitement sans artefact.";
      Text_process.ensure_preprocessed ~root:temp_root;
      assert_true
        (match Text_process.load ~root:temp_root ~source:"missing" with Error message -> String.trim message <> "" | Ok _ -> false)
        "Text_process.load doit échouer explicitement sur une source inconnue.";
      let* text_corpus = Text_process.load ~root:temp_root ~source:"demo" in
      let text_sources = Text_process.sources text_corpus in
      assert_true
        (List.exists (fun (source : Text_process.source_info) -> String.equal source.id "demo" && source.document_count = 2) text_sources)
        "Le corpus texte chargé doit exposer les sources prétraitées.";
      let lexical_hits = Text_process.lexical_search text_corpus ~source:"demo" ~query:"paix" in
      assert_true
        (match lexical_hits with first :: _ -> String.equal first.reference "Demo 1" | [] -> false)
        "La recherche lexicale doit retrouver le document le plus pertinent.";
      let semantic_hits = Text_process.semantic_search text_corpus ~source:"demo" ~query:"justice" in
      assert_true (semantic_hits <> []) "La recherche sémantique doit produire au moins un résultat.";
      let specific_terms = Text_process.specific_terms text_corpus ~source:"demo" in
      assert_true
        (List.exists (fun (term : Text_process.term_score) -> String.equal term.term "parabole") specific_terms)
        "L'extraction de vocabulaire spécifique doit produire les termes saillants.";
      assert_true
        (List.exists (fun (term : Text_process.term_score) -> term.frequency >= 1 && term.score <> 0.0) specific_terms)
        "Le vocabulaire spécifique doit exposer des scores et fréquences utilisables.";
      let* filtered_corpus = Text_process.load ~root:temp_root ~source:"filtered" in
      let filtered_terms = Text_process.specific_terms filtered_corpus ~source:"filtered" |> List.map (fun (term : Text_process.term_score) -> term.term) in
      assert_true (List.exists (String.equal "pain") filtered_terms) "Le tokenizer doit conserver les mots de contenu utiles.";
      assert_true
        (not (List.exists (fun term -> List.mem term [ "12"; "j'ai"; "ai"; "il"; "a"; "été"; "ete"; "chez"; "dit"; "jamais" ]) filtered_terms))
        "Le tokenizer doit ignorer les chiffres, clitiques et mots-outils demandés.";
      let* project_root = Project_root.find () in
      let* project_names = Book_names.load ~root:project_root in
      let* quran_corpus = Text_process.load ~root:temp_root ~source:"Coran" in
      let* quran_terms =
        Text_process.specific_terms_for_path quran_corpus ~root:temp_root ~names:project_names ~bible_translation:"bible_aelf" ~source:"Coran" ~path:[ "1" ]
      in
      assert_true
        (List.exists (fun (term : Text_process.term_score) -> String.equal term.term "miséricorde") quran_terms)
        "Le vocabulaire spécifique hiérarchique doit isoler les termes saillants d'une sourate.";
      assert_true
        (not (List.exists (fun (term : Text_process.term_score) -> String.equal term.term "combat") quran_terms))
        "Le vocabulaire spécifique hiérarchique ne doit pas remonter les termes du reste du corpus comme spécifiques à la sous-hiérarchie.";
      let concepts = Text_process.central_concepts text_corpus ~source:"demo" in
      assert_true (concepts <> []) "Les concepts centraux doivent être calculés.";
      assert_true
        (List.exists (fun (concept : Text_process.concept) -> concept.neighbours <> [] && concept.score > 0.0) concepts)
        "Les concepts centraux doivent inclure des voisins et un score positif.";
      let themes = Text_process.themes text_corpus ~source:"demo" in
      assert_true (themes <> []) "La hiérarchie thématique doit être calculée.";
      assert_true
        (List.exists (fun (theme : Text_process.theme) -> theme.keywords <> [] && theme.document_ids <> []) themes)
        "Les thèmes doivent contenir des mots-clés et des documents.";
      let summary = Text_process.summarize text_corpus ~source:"demo" ~question:"justice" in
      assert_true (summary.passages <> []) "Le résumé par question doit renvoyer des passages source.";
      let* generator_corpus = Text_process.load ~root:temp_root ~source:"generator" in
      Random.init 0;
      let generator_generated = Text_process.generate_from_word generator_corpus ~source:"generator" ~word:"pain" in
      assert_true
        (List.exists
           (fun sentence ->
             let lower = String.lowercase_ascii sentence in
             try
               ignore (Str.search_forward (Str.regexp_string " pain ") (" " ^ lower) 0);
               not (String.starts_with ~prefix:"pain " lower)
             with Not_found -> false)
           generator_generated)
        "La génération doit pouvoir placer le mot pivot au milieu de la phrase.";
      assert_true
        (List.exists
           (fun sentence ->
             let lower = String.lowercase_ascii sentence in
             List.exists (fun needle ->
               try
                 ignore (Str.search_forward (Str.regexp_string needle) lower 0);
                 true
               with Not_found -> false)
               [ "avec pain"; "sans pain"; "pain et" ])
           generator_generated)
        "La génération doit conserver un contexte lexical autour du mot pivot.";
      Random.init 0;
      let generated = Text_process.generate_from_word text_corpus ~source:"demo" ~word:"paix" in
      assert_true (generated <> []) "La génération à partir d'un mot doit produire au moins une phrase.";
      assert_true
        (List.length (List.sort_uniq String.compare generated) >= 2)
        "La génération doit produire au moins deux phrases distinctes pour alimenter la relance aléatoire.";
      assert_true
        (List.for_all (fun sentence -> String.trim sentence <> "Grace et paix" && String.trim sentence <> "La paix demeure") generated)
        "La génération ne doit pas se contenter de recopier les phrases source.";
      Ok ())
  in
  let* root = Project_root.find () in
  let* names = Book_names.load ~root in
  let* parsed = Bible_reference.parse ~names "Jn 1,1" in
  assert_true (String.equal parsed.book "Jean") "Le parseur doit reconnaître Jean.";
  let* translation = Bible_data.load_translation ~root ~names ~id:"bible_aelf" in
  let* _, verses = Bible_data.lookup translation parsed in
  assert_true (List.length verses = 1) "Une référence simple doit retourner un verset.";
  let* navigation = Bible_data.navigation translation parsed in
  assert_true navigation.has_next "Jean 1,1 doit avoir un verset suivant.";
  let books = Bible_data.books translation in
  assert_true (List.exists (fun (book : Bible_data.book_info) -> String.equal book.canonical_title "Jean") books) "Jean doit apparaître dans la liste des livres.";
  let* chapters = Bible_data.chapter_numbers translation ~book:"Jean" in
  assert_true (List.length chapters >= 21) "Jean doit exposer ses chapitres.";
  let* verse_numbers = Bible_data.verse_numbers translation ~book:"Jean" ~chapter:1 in
  assert_true (List.exists (( = ) 1) verse_numbers) "Jean 1 doit exposer ses versets.";
  let* next_reference = Bible_data.navigate translation parsed Bible_data.Next in
  assert_true
    (next_reference.chapter = 1
    && next_reference.verses.first_verse = Some 2)
    "Jean 1,1 doit naviguer vers Jean 1,2.";
  let* random_reference = Bible_data.random_reference ~book:"Jean" translation () in
  assert_true (String.equal random_reference.book "Jean") "Le tirage filtré doit rester dans Jean.";
  let* hits = Vatican_data.search ~root ~sources:(Some [ "encyclicals_francesco" ]) ~query:"foi" ~limit:5 in
  assert_true (hits <> []) "La recherche Vatican doit renvoyer au moins un résultat.";
  let sources = Sources.list_sources ~root in
  assert_true (List.exists (fun (source : Sources.source_descriptor) -> String.equal source.id "Vatican") sources) "Le catalogue de sources doit inclure Vatican.";
  assert_true (List.exists (fun (source : Sources.source_descriptor) -> String.equal source.id "Hadiths") sources) "Le catalogue de sources doit inclure Hadiths.";
  assert_true (List.exists (fun (source : Sources.source_descriptor) -> String.equal source.id "Rael") sources) "Le catalogue de sources doit inclure Rael.";
  assert_true (List.exists (fun (source : Sources.source_descriptor) -> String.equal source.id "Compendium") sources) "Le catalogue de sources doit inclure le Compendium.";
  assert_true
    (List.exists (fun (source : Sources.source_descriptor) -> String.equal source.id "CompendiumSocial") sources)
    "Le catalogue de sources doit inclure le Compendium social.";
  let* quran_options = Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"Coran" ~path:[] in
  assert_true (List.length quran_options = 114) "Le Coran doit exposer 114 sourates.";
  let* quran_verse_options = Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"Coran" ~path:[ "1" ] in
  assert_true (quran_verse_options <> []) "La première sourate doit exposer ses versets.";
  assert_true ((List.hd quran_verse_options).value = "1") "La première sourate doit commencer au verset 1.";
  let* rendered = Sources.render_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Coran:1.1" in
  assert_true (String.equal rendered.source_id "Coran") "Le rendu de Coran:1.1 doit utiliser la source Coran.";
  let* coran_source, coran_path =
    Sources.selector_path_of_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Coran:1.1"
  in
  assert_true (String.equal coran_source "Coran" && coran_path = [ "1"; "1" ]) "Le chemin inverse Coran doit être résolu.";
  assert_true
    (List.exists (fun (source : Sources.source_descriptor) -> String.equal source.id "CatechismeTrente") sources)
    "Le catalogue doit inclure le catéchisme du concile de Trente.";
  let* cat_e_options = Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"CatechismeE" ~path:[] in
  assert_true (List.length cat_e_options = 687) "Le catéchisme des évêques doit exposer ses articles.";
  let* cat_x_parts = Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"CatechismeX" ~path:[] in
  assert_true (cat_x_parts <> []) "Le catéchisme de Pie X doit exposer ses parties.";
  let first_part = (List.hd cat_x_parts).value in
  let* cat_x_chapters = Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"CatechismeX" ~path:[ first_part ] in
  assert_true (cat_x_chapters <> []) "Le catéchisme de Pie X doit exposer ses chapitres.";
  let first_chapter = (List.hd cat_x_chapters).value in
  let* cat_x_ref =
    Sources.compile_reference ~root ~names ~bible_translation:"bible_aelf" ~source:"CatechismeX"
      ~path:[ first_part; first_chapter; "1" ]
  in
  assert_true (String.length cat_x_ref > 5) "La compilation de référence CatX doit produire un identifiant.";
  let* cat_t_parts =
    Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"CatechismeTrente" ~path:[]
  in
  assert_true (cat_t_parts <> []) "Le catéchisme du concile de Trente doit exposer ses parties.";
  let cat_t_part = (List.hd cat_t_parts).value in
  let* cat_t_chapters =
    Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"CatechismeTrente"
      ~path:[ cat_t_part ]
  in
  let cat_t_chapter = (List.hd cat_t_chapters).value in
  let* cat_t_paras =
    Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"CatechismeTrente"
      ~path:[ cat_t_part; cat_t_chapter ]
  in
  let cat_t_para = (List.hd cat_t_paras).value in
  let* cat_t_ref =
    Sources.compile_reference ~root ~names ~bible_translation:"bible_aelf" ~source:"CatechismeTrente"
      ~path:[ cat_t_part; cat_t_chapter; cat_t_para; "1" ]
  in
  let* rendered_cat_t = Sources.render_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:cat_t_ref in
  assert_true (String.equal rendered_cat_t.source_id "CatechismeTrente") "Le rendu CatT doit utiliser la bonne source.";
  let* rael_books = Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"Rael" ~path:[] in
  assert_true (rael_books <> []) "Rael doit exposer ses livres.";
  let rael_book = (List.hd rael_books).value in
  let* rael_sections = Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"Rael" ~path:[ rael_book ] in
  assert_true (rael_sections <> []) "Rael doit exposer ses chapitres.";
  let rael_section = (List.hd rael_sections).value in
  let* rael_ref =
    Sources.compile_reference ~root ~names ~bible_translation:"bible_aelf" ~source:"Rael"
      ~path:[ rael_book; rael_section; "3" ]
  in
  let* rendered_rael = Sources.render_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:rael_ref in
  assert_true (String.equal rendered_rael.source_id "Rael") "Le rendu Rael doit utiliser la bonne source.";
  assert_true (String.trim rendered_rael.body <> "") "Le rendu Rael doit être non vide.";
  let* compendium_count =
    Sources.selector_count ~root ~names ~bible_translation:"bible_aelf" ~source:"Compendium" ~path:[]
  in
  assert_true (compendium_count = Some 597) "Le Compendium doit exposer 597 articles.";
  let* rendered_compendium =
    Sources.render_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Cat.Comp.1"
  in
  assert_true (String.equal rendered_compendium.source_id "Compendium") "Le rendu Compendium doit utiliser la bonne source.";
  let* compendium_source, compendium_path =
    Sources.selector_path_of_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Cat.Comp.1"
  in
  assert_true
    (String.equal compendium_source "Compendium" && compendium_path = [ "1" ])
    "Le chemin inverse Compendium doit être résolu.";
  let* compendium_social_count =
    Sources.selector_count ~root ~names ~bible_translation:"bible_aelf" ~source:"CompendiumSocial" ~path:[]
  in
  assert_true (compendium_social_count = Some 583) "Le Compendium social doit exposer 583 articles.";
  let* rendered_compendium_social =
    Sources.render_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Soc.1"
  in
  assert_true
    (String.equal rendered_compendium_social.source_id "CompendiumSocial")
    "Le rendu Compendium social doit utiliser la bonne source.";
  let* hadith_authors = Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"Hadiths" ~path:[] in
  assert_true (List.exists (fun (option : Sources.selector_option) -> String.equal option.value "bukhari") hadith_authors) "Les hadiths doivent exposer Bukhari.";
  let* hadith_books =
    Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"Hadiths" ~path:[ "bukhari" ]
  in
  assert_true (hadith_books <> []) "Les hadiths par livre doivent exposer leurs livres.";
  let hadith_book = (List.hd hadith_books).value in
  let* hadith_count =
    Sources.selector_count ~root ~names ~bible_translation:"bible_aelf" ~source:"Hadiths"
      ~path:[ "bukhari"; hadith_book ]
  in
  assert_true (Option.value hadith_count ~default:0 > 0) "Les hadiths par livre doivent exposer un countArticles positif.";
  let* hadith_numbers =
    Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"Hadiths"
      ~path:[ "bukhari"; hadith_book ]
  in
  let hadith_number = (List.hd hadith_numbers).value in
  let* hadith_ref =
    Sources.compile_reference ~root ~names ~bible_translation:"bible_aelf" ~source:"Hadiths"
      ~path:[ "bukhari"; hadith_book; hadith_number ]
  in
  let* rendered_hadith = Sources.render_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:hadith_ref in
  assert_true (String.equal rendered_hadith.source_id "Hadiths") "Le rendu Hadiths doit utiliser la bonne source.";
  let* hadith_numbers_2 =
    Sources.selector_options ~root ~names ~bible_translation:"bible_aelf" ~source:"Hadiths2" ~path:[ "muslim" ]
  in
  assert_true (hadith_numbers_2 <> []) "Les hadiths par numéro doivent exposer leurs numéros.";
  let* hadith_count_2 =
    Sources.selector_count ~root ~names ~bible_translation:"bible_aelf" ~source:"Hadiths2" ~path:[ "muslim" ]
  in
  assert_true (Option.value hadith_count_2 ~default:0 = List.length hadith_numbers_2) "Le countArticles Hadiths2 doit correspondre au nombre de hadiths.";
  let first_hadith_number = (List.hd hadith_numbers_2).value in
  let* rendered_hadith_2 =
    Sources.render_reference ~root ~names ~bible_translation:"bible_aelf"
      ~reference:("muslim:" ^ first_hadith_number)
  in
  assert_true (String.equal rendered_hadith_2.source_id "Hadiths2") "Le rendu Hadiths2 doit utiliser la bonne source.";
  let* bible_source, bible_path =
    Sources.selector_path_of_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Jn 1,1"
  in
  assert_true
    (String.equal bible_source "Bible" && bible_path = [ "Jean"; "1"; "1" ])
    "Le chemin inverse Bible doit être résolu.";
  let* can_count = Sources.selector_count ~root ~names ~bible_translation:"bible_aelf" ~source:"Can" ~path:[] in
  assert_true (Option.value can_count ~default:0 > 1000) "Le code canonique doit exposer un countArticles significatif.";
  let* rendered_can_hole = Sources.render_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Can.376" in
  assert_true (String.equal rendered_can_hole.reference "Can.376") "Une case NULL ne doit pas casser l'adresse de Can.376.";
  assert_true (String.trim rendered_can_hole.body = "376.") "Une case NULL doit devenir une chaîne vide sans décaler l'index.";
  let* rendered_can_after_hole = Sources.render_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Can.377" in
  assert_true
    (String.starts_with ~prefix:"377. Can. 377 -" rendered_can_after_hole.body)
    "L'article après une case NULL ne doit pas être décalé.";
  let* quran_chapter_ref = Sources.chapter_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Coran:1.3" in
  assert_true (quran_chapter_ref = Some "Coran:1.1-7") "Le bouton chapitre doit viser la plage complète de la sourate.";
  let* can_chapter_ref = Sources.chapter_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Can.377" in
  assert_true (can_chapter_ref = Some "Can.1-1751") "Les sources simples doivent exposer leur plage complète via chapter_reference.";
  let* rael_chapter_ref = Sources.chapter_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:rael_ref in
  assert_true (Option.value rael_chapter_ref ~default:"" <> "") "Rael doit exposer une plage de chapitre.";
  let* compendium_chapter_ref =
    Sources.chapter_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Cat.Comp.1"
  in
  assert_true
    (compendium_chapter_ref = Some "Cat.Comp.1-597")
    "Le Compendium doit exposer sa plage complète via chapter_reference.";
  let* compendium_social_chapter_ref =
    Sources.chapter_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"Soc.1"
  in
  assert_true
    (compendium_social_chapter_ref = Some "Soc.1-583")
    "Le Compendium social doit exposer sa plage complète via chapter_reference.";
  let* hadith_chapter_ref = Sources.chapter_reference ~root ~names ~bible_translation:"bible_aelf" ~reference:"muslim:4a" in
  assert_true (hadith_chapter_ref = None) "Les hadiths sans navigation de chapitre doivent désactiver le bouton chapitre.";
  let decoded_problematic = Sources.decode_site_reference_url "https://pascatho.ovh/?Deut-13%3A6-10" in
  assert_true (decoded_problematic = Some "Deut 13,6-10") "Le décodage d'URL doit résoudre Deut-13:6-10.";
  let article_markup =
    Article_markdown.render_to_pango_markup
      ~resolve_internal:(fun url ->
        if String.equal url "https://pascatho.ovh/?Gn-20%3A11-12" then Some "Gn 20,11-12" else None)
      "**Bible.** [Gn-20:11-12](https://pascatho.ovh/?Gn-20%3A11-12)"
  in
  assert_true
    (Str.string_match (Str.regexp ".*<a href=\"ref:Gn 20,11-12\">Gn-20:11-12</a>.*") article_markup 0)
    "Les liens d'articles doivent devenir des liens internes quand la référence est connue.";
  let* homosexualite_article = Article_store.read ~root ~name:"homosexualite.md" in
  let homosexualite_markup =
    Article_markdown.render_to_pango_markup ~resolve_internal:resolve_article_url homosexualite_article
  in
  assert_contains ~needle:"href=\"ref:Coran:26.165-174\"" homosexualite_markup
    "Les références Coran présentes dans l'article homosexualite.md doivent rester des liens internes.";
  assert_contains ~needle:"href=\"ref:Lv 20,13\"" homosexualite_markup
    "Les références bibliques présentes dans l'article homosexualite.md doivent rester des liens internes.";
  assert_contains ~needle:"href=\"ref:Cat.2357-2359\"" homosexualite_markup
    "Les références du Catéchisme présentes dans l'article homosexualite.md doivent rester des liens internes.";
  assert_contains ~needle:"href=\"ref:Vatican congregations 2021/2/22 11\"" homosexualite_markup
    "Les références Vatican présentes dans l'article homosexualite.md doivent rester des liens internes.";
  let highlighted_markup =
    Article_markdown.render_to_pango_markup ~highlights:[ "[Ll]iberté"; "[Dd]ignité" ] ~resolve_internal:(fun _ -> None)
      "La liberté protège la dignité."
  in
  assert_true
    (Str.string_match (Str.regexp ".*<b>liberté</b> protège la <b>dignité</b>.*") highlighted_markup 0)
    "Le rendu d'article doit pouvoir mettre en gras les mots-clés du fichier highlights.";
  let heading_markup =
    Article_markdown.render_to_pango_markup ~highlights:[ "[Ll]iberté" ] ~resolve_internal:(fun _ -> None) "# Liberté"
  in
  assert_true
    (Str.string_match (Str.regexp ".*<span size=\"x-large\" weight=\"bold\"><b>Liberté</b></span>.*") heading_markup 0)
    "Le rendu markdown des titres ne doit pas lever d'exception Str.group_end.";
  let subheading_markup =
    Article_markdown.render_to_pango_markup ~resolve_internal:(fun _ -> None) "## Sous-titre"
  in
  assert_contains ~needle:"<span size=\"large\" weight=\"bold\">Sous-titre</span>" subheading_markup
    "Le rendu markdown doit gérer les titres de niveau 2.";
  let bullet_markup =
    Article_markdown.render_to_pango_markup ~resolve_internal:(fun _ -> None) "* Premier point"
  in
  assert_contains ~needle:"• Premier point" bullet_markup
    "Le rendu markdown doit gérer les listes simples.";
  let external_link_markup =
    Article_markdown.render_to_pango_markup ~resolve_internal:(fun _ -> None)
      "[Site](https://example.com)"
  in
  assert_contains ~needle:"<a href=\"https://example.com\">Site</a>" external_link_markup
    "Les liens markdown externes doivent rester externes quand aucune résolution interne n'est fournie.";
  let escaped_markup =
    Article_markdown.render_to_pango_markup ~resolve_internal:(fun _ -> None) "<b>&</b>"
  in
  assert_contains ~needle:"&lt;b&gt;&amp;&lt;/b&gt;" escaped_markup
    "Le rendu markdown doit échapper le markup XML/Pango contenu dans les articles.";
  let mixed_markdown_markup =
    Article_markdown.render_to_pango_markup ~resolve_internal:(fun _ -> None)
      "Avant **gras** puis [lien](https://example.com) après."
  in
  assert_contains ~needle:"Avant <b>gras</b> puis <a href=\"https://example.com\">lien</a> après."
    mixed_markdown_markup
    "Le rendu markdown doit gérer conjointement gras inline et liens.";
  let link_and_highlight_markup =
    Article_markdown.render_to_pango_markup ~highlights:[ "[Ff]emme" ]
      ~resolve_internal:(fun url -> if String.equal url "https://pascatho.ovh/?Gn-3%3A16" then Some "Gn 3,16" else None)
      "La femme est mentionnée ici : [Gn-3:16](https://pascatho.ovh/?Gn-3%3A16)"
  in
  assert_true
    (Str.string_match
       (Str.regexp ".*<b>femme</b>.*<a href=\"ref:gn 3,16\">gn-3:16</a>.*")
       (String.lowercase_ascii link_and_highlight_markup) 0)
    "Le rendu article avec highlights regex et liens ne doit pas planter.";
  let plain_highlight_markup =
    Article_markdown.render_plain_to_pango_markup ~highlights:[ "[Ll]iberté"; "[Dd]ignité" ]
      "Liberté\nDignité"
  in
  assert_true
    (Str.string_match (Str.regexp ".*<b>Liberté</b>\n<b>Dignité</b>.*") plain_highlight_markup 0)
    "Les highlights doivent aussi s'appliquer aux textes de sources non markdown.";
  let plain_markup_escapes =
    Article_markdown.render_plain_to_pango_markup "Texte <dangereux> & sûr"
  in
  assert_contains ~needle:"Texte &lt;dangereux&gt; &amp; sûr" plain_markup_escapes
    "Le rendu texte brut doit échapper les caractères réservés Pango.";
  let search_markup =
    Article_markdown.highlight_search_markup ~needle:"jean" ~current:1
      "<a href=\"ref:Jn 1,1\">Jean</a> puis jean encore"
  in
  assert_true (search_markup.count = 2) "La recherche doit compter les occurrences textuelles visibles.";
  assert_contains ~needle:"<a href=\"ref:Jn 1,1\"><span background=\"yellow\">Jean</span></a>" search_markup.markup
    "La recherche doit pouvoir surligner une occurrence à l'intérieur du texte visible d'un lien.";
  assert_contains ~needle:"<span background=\"yellow\" weight=\"bold\">jean</span>" search_markup.markup
    "La recherche doit mettre en évidence l'occurrence courante.";
  let source_markup =
    Article_markdown.render_source_to_pango_markup
      "L’action liturgique (cf. Jn 4, 23) selon GS 22 et CEC, n. 10 ; voir aussi can. 15."
  in
  assert_true
    (Str.string_match (Str.regexp ".*href=\"ref:Jn 4,23\".*href=\"ref:Vatican concil_ii_vatican_council 1965/12/7-3 22\".*href=\"ref:Cat.10\".*href=\"ref:Can.15\".*") source_markup 0)
    "Le rendu de source doit transformer les références bibliques, conciliaires, catéchétiques et canoniques en liens internes.";
  let source_with_notes_markup =
    Article_markdown.render_source_to_pango_markup ~references:"[1] Ac 17, 26.\n\n[2] CEC, n. 12."
      "Dieu a fait habiter tout le genre humain [1] et l'Eglise enseigne [2]."
  in
  assert_true
    ((try
        ignore (Str.search_forward (Str.regexp_string "<span weight=\"bold\" size=\"large\">Notes</span>") source_with_notes_markup 0);
        ignore (Str.search_forward (Str.regexp_string "href=\"ref:Ac 17,26\"") source_with_notes_markup 0);
        ignore (Str.search_forward (Str.regexp_string "href=\"ref:Cat.12\"") source_with_notes_markup 0);
        true
      with Not_found -> false))
    "Les notes Vatican doivent être affichées et leurs références internes résolues.";
  let source_with_partial_notes_markup =
    Article_markdown.render_source_to_pango_markup ~references:"[1] Ac 17, 26.\n\n[2] CEC, n. 12."
      "Dieu a fait habiter tout le genre humain [1]."
  in
  assert_true
    ((try
        ignore (Str.search_forward (Str.regexp_string "href=\"ref:Ac 17,26\"") source_with_partial_notes_markup 0);
        (try
           ignore (Str.search_forward (Str.regexp_string "href=\"ref:Cat.12\"") source_with_partial_notes_markup 0);
           false
         with Not_found -> true)
      with Not_found -> false))
    "Seules les notes Vatican effectivement citées doivent être affichées.";
  let sanitized_markup =
    Article_markdown.render_source_to_pango_markup "ABC\194\160DEF\226\128\139GHI\001JKL"
  in
  assert_true
    (String.equal sanitized_markup "ABC DEFGHIJKL")
    "Le rendu source doit neutraliser les caractères problématiques sans casser le texte.";
  let invalid_utf8 = Article_markdown.sanitize_text "Femme retint eaux nué revien \128\153ardeur.\194\160»" in
  assert_true
    (String.equal invalid_utf8 "Femme retint eaux nué revien ??ardeur. »")
    "La sanitisation doit rendre affichables les octets UTF-8 invalides sans casser le reste du texte.";
  let source_quran_markup =
    Article_markdown.render_source_to_pango_markup "Voir aussi Sourate II, 255-257."
  in
  assert_contains ~needle:"href=\"ref:Coran:2.255-257\"" source_quran_markup
    "Le rendu source doit reconnaître les références au Coran avec chiffres romains.";
  let source_denzinger_markup =
    Article_markdown.render_source_to_pango_markup "Cf. Denzinger 12-15."
  in
  assert_contains ~needle:"href=\"ref:DH.12-15\"" source_denzinger_markup
    "Le rendu source doit reconnaître les références Denzinger.";
  let* rendered_vatican =
    Sources.render_reference ~root ~names ~bible_translation:"bible_aelf"
      ~reference:"Vatican concil_ii_vatican_council 1965/10/28-2 1"
  in
  assert_true (Option.value rendered_vatican.references ~default:"" <> "") "Le rendu Vatican doit transporter les notes de bas de page.";
  let binary = Filename.concat root "_build/default/bin/pascatho.exe" in
  let text_tools_binary = Filename.concat root "_build/default/bin/textTools.exe" in
  let text_tools_command = Printf.sprintf "%s 2>&1" (Filename.quote text_tools_binary) in
  let text_tools_no_source = Unix.open_process_in text_tools_command in
  let text_tools_lines =
    Fun.protect
      ~finally:(fun () -> ignore (Unix.close_process_in text_tools_no_source))
      (fun () -> read_all_lines text_tools_no_source [])
  in
  assert_true
    (List.exists (fun line -> String.equal line "L'option --source est obligatoire.") text_tools_lines)
    "textTools doit signaler explicitement que --source manque.";
  assert_true
    (List.exists (fun line -> string_starts_with ~prefix:"Sources disponibles: " line) text_tools_lines)
    "textTools doit lister les sources disponibles quand --source est absent.";
  let translations_lines = run_command_capture_lines_in_dir "/tmp" [ binary; "translations" ] in
  assert_true (translations_lines <> []) "Le binaire doit retrouver la racine du projet même hors du dépôt.";
  let help_lines = run_command_capture_lines [ binary; "--help=plain" ] in
  assert_true
    (List.exists (fun line -> String.equal line "COMMANDS") help_lines)
    "Un argument unique correspondant à une option Cmdliner ne doit pas ouvrir l'interface graphique.";
  Unix.putenv Project_root.env_var root;
  let project_root_lines = run_command_capture_lines_in_dir "/tmp" [ binary; "project-root" ] in
  assert_true
    (project_root_lines = [ root ])
    "Le backend doit privilégier la racine explicitement transmise via l'environnement.";
  let chapter_lines =
    run_command_capture_lines
      [ binary; "chapter"; "--translation"; "bible_aelf"; "--reference"; "Jn 1,1" ]
  in
  assert_true (List.mem "REF\tJean 1" chapter_lines) "La commande chapter doit renvoyer la référence du chapitre.";
  assert_true
    (List.mem "TEXT\tEvangile de Jésus-Christ selon saint Jean" chapter_lines)
    "La commande chapter doit renvoyer le titre du livre.";
  let article_urls = list_article_urls root in
  let droits_article = Article_store.read ~root ~name:"droits-de-l-homme.md" in
  let* droits_article = droits_article in
  assert_true
    (not
       (try
          ignore (Str.search_forward (Str.regexp_string "🇻🇦") droits_article 0);
          true
        with Not_found -> false))
    "L'article droits-de-l-homme ne doit pas contenir le drapeau Vatican, source de bug d'affichage UTF-8.";
  let article_references =
    article_urls
    |> List.filter_map (fun (_, url) ->
           if string_starts_with ~prefix:"https://pascatho.ovh/?" url then Sources.decode_site_reference_url url else None)
    |> List.filter article_reference_supported
  in
  assert_true (List.length article_references > 200) "Les tests d'articles doivent couvrir un nombre significatif de références.";
  let rendered_count, failed_count =
    List.fold_left
      (fun (rendered_count, failed_count) reference ->
        match Sources.render_reference ~root ~names ~bible_translation:"bible_aelf" ~reference with
        | Ok rendered ->
            assert_true (String.trim rendered.title <> "" || String.trim rendered.body <> "") ("Référence article vide: " ^ reference);
            (rendered_count + 1, failed_count)
        | Error _ -> (rendered_count, failed_count + 1))
      (0, 0) article_references
  in
  assert_true (rendered_count > 200) "Les références d'articles doivent produire massivement du titre et du texte.";
  assert_true (failed_count < rendered_count) "Les références d'articles ne doivent pas échouer majoritairement.";
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"Bible" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"Coran" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"Can" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"Can1917" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"Can1990" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"Catechisme" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"CatechismeE" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"Rael" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"Compendium" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"CompendiumSocial" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"CatechismeX" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"CatechismeTrente" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"Hadiths" in
  let* () = assert_source_roundtrip ~root ~names ~translation:"bible_aelf" ~source:"Hadiths2" in
  print_endline "Tests OK"
