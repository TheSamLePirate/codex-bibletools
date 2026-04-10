let rec search path =
  let candidate = Filename.concat path "bibleTools.js" in
  if Sys.file_exists candidate then Ok path
  else
    let parent = Filename.dirname path in
    if String.equal parent path then
      Error "Impossible de trouver la racine du projet depuis le répertoire courant."
    else search parent

let find () = search (Sys.getcwd ())
