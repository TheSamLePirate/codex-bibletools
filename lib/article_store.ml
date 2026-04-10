type article = {
  name : string;
  path : string;
}

let articles_dir root = Filename.concat root "articles"

let list ~root =
  let directory = articles_dir root in
  if Sys.file_exists directory then
    Sys.readdir directory
    |> Array.to_list
    |> List.filter (fun name -> Filename.check_suffix name ".md")
    |> List.sort String.compare
    |> List.map (fun name -> { name; path = Filename.concat directory name })
  else []

let read ~root ~name =
  let path = Filename.concat (articles_dir root) name in
  try Ok (Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all) with Sys_error message -> Error message
