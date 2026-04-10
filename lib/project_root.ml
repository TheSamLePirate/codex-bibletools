let rec search path =
  let candidate = Filename.concat path "bibleTools.js" in
  if Sys.file_exists candidate then Ok path
  else
    let parent = Filename.dirname path in
    if String.equal parent path then
      Error "Impossible de trouver la racine du projet depuis le répertoire courant."
    else search parent

let search_from paths =
  let rec loop = function
    | [] -> Error "Impossible de trouver la racine du projet depuis le répertoire courant."
    | path :: rest -> (
        match search path with
        | Ok root -> Ok root
        | Error _ -> loop rest)
  in
  loop paths

let executable_search_paths () =
  let executable = Sys.executable_name in
  let executable_dir = Filename.dirname executable in
  [ executable_dir; Filename.dirname executable_dir; Filename.dirname (Filename.dirname executable_dir) ]

let find () = search_from (Sys.getcwd () :: executable_search_paths ())
