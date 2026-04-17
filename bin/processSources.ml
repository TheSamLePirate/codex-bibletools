open Cmdliner

let memory_limit_bytes = Int64.mul 8L 1_073_741_824L

let main () =
  match Process_limits.set_address_space_limit_bytes ~bytes:memory_limit_bytes with
  | Error message ->
      prerr_endline message;
      exit 1
  | Ok () -> (
      match Project_root.find () with
  | Error message ->
      prerr_endline message;
      exit 1
  | Ok root -> (
      match Text_process.preprocess_and_save ~root with
      | Ok () ->
          print_endline ("Prétraitement écrit dans " ^ Text_process.artifact_path ~root);
          ()
      | Error message ->
          prerr_endline message;
          exit 1))

let cmd =
  let info = Cmd.info "processSources" ~doc:"Prétraite les corpus pour textTools" in
  Cmd.v info Term.(const main $ const ())

let () = exit (Cmd.eval cmd)
