let ( let* ) result f = match result with Ok value -> f value | Error _ as error -> error

let bible_translation = "bible_aelf"

let text_of_reference reference =
  let* root = Project_root.find () in
  let* names = Book_names.load ~root in
  let* source, path = Sources.selector_path_of_reference ~root ~names ~bible_translation ~reference in
  let* normalized_reference = Sources.compile_reference ~root ~names ~bible_translation ~source ~path in
  let* rendered = Sources.render_reference ~root ~names ~bible_translation ~reference:normalized_reference in
  Ok rendered.body

let main () =
  if Array.length Sys.argv < 2 then (
    prerr_endline "Usage: cli REFERENCE";
    1)
  else
    match text_of_reference Sys.argv.(1) with
    | Ok text ->
        print_endline text;
        0
    | Error message ->
        prerr_endline message;
        1

let () = exit (main ())
