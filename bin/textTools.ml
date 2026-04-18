open Cmdliner

let memory_limit_bytes = Int64.mul 4L 1_073_741_824L

let log_text_tools message = prerr_endline ("[textTools] " ^ message)

let available_sources_help () =
  match Project_root.find () with
  | Error _ -> "Sources disponibles: indisponibles hors workspace."
  | Ok root ->
      let sources =
        Sources.list_sources ~root
        |> List.map (fun (source : Sources.source_descriptor) -> source.id)
        |> String.concat ", "
      in
      "Sources disponibles: " ^ sources ^ "."

let main source =
  match source with
  | None ->
      prerr_endline "L'option --source est obligatoire.";
      prerr_endline (available_sources_help ());
      1
  | Some source -> (
      Random.self_init ();
      match Process_limits.set_address_space_limit_bytes ~bytes:memory_limit_bytes with
      | Error message ->
          prerr_endline message;
          1
      | Ok () -> (
          log_text_tools "Limite mémoire appliquée: 4 Gio.";
          match Project_root.find () with
          | Error message ->
              prerr_endline message;
              1
          | Ok root ->
              Text_process.ensure_preprocessed ~root;
              log_text_tools ("Chargement du corpus prétraité pour la source " ^ source ^ "...");
              Text_tools_ui.launch root source;
              0))

let cmd =
  let info = Cmd.info "textTools" ~doc:"Fenêtre de traitement lexical et thématique" in
  let source =
    let doc = "Identifiant de la source à charger. " ^ available_sources_help () in
    Arg.(value & opt (some string) None & info [ "source" ] ~docv:"SOURCE" ~doc)
  in
  Cmd.v info Term.(const main $ source)

let () = exit (Cmd.eval' cmd)
