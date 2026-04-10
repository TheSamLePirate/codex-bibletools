let env_var = "PASCATHO_ROOT"

let is_project_root path =
  Sys.file_exists (Filename.concat path "dune-project") || Sys.file_exists (Filename.concat path "bibleTools.js")

let rec search path =
  if is_project_root path then Ok path
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

let env_search_paths () =
  [ Sys.getenv_opt env_var; Sys.getenv_opt "DUNE_SOURCEROOT"; Sys.getenv_opt "BUILD_PATH_PREFIX_MAP"; Sys.getenv_opt "PWD" ]
  |> List.filter_map (fun value -> value)
  |> List.map (fun value ->
         match String.split_on_char '=' value with
         | _left :: right :: _ when Sys.file_exists right -> right
         | _ -> value)

let proc_self_exe_search_paths () =
  try
    let exe = Unix.readlink "/proc/self/exe" in
    let dir = Filename.dirname exe in
    [ dir; Filename.dirname dir; Filename.dirname (Filename.dirname dir); Filename.dirname (Filename.dirname (Filename.dirname dir)) ]
  with Unix.Unix_error _ -> []

let uniq_paths paths =
  let seen = Hashtbl.create 16 in
  List.filter
    (fun path ->
      if path = "" || Hashtbl.mem seen path then false
      else (
        Hashtbl.add seen path ();
        true))
    paths

let find () =
  uniq_paths (Sys.getcwd () :: env_search_paths () @ proc_self_exe_search_paths () @ executable_search_paths ())
  |> search_from
