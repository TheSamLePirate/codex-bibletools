let ( let* ) result f = match result with Ok value -> f value | Error _ as e -> e

open Yojson.Safe.Util

type source = {
  id : string;
  file : string;
}

type hit = {
  source_id : string;
  title : string;
  url : string;
  date : string;
  snippet : string;
}

let json_cache : (string, (Yojson.Safe.t, string) result) Hashtbl.t = Hashtbl.create 64

let read_json_file path =
  match Hashtbl.find_opt json_cache path with
  | Some cached -> cached
  | None ->
      let loaded =
        try Ok (Yojson.Safe.from_file path) with Yojson.Json_error message -> Error message | Sys_error message -> Error message
      in
      Hashtbl.replace json_cache path loaded;
      loaded

let sources ~root =
  let path = Filename.concat (Filename.concat root "datas") "Vatican_map.json" in
  let* json = read_json_file path in
  let mapped =
    json
    |> to_assoc
    |> List.map (fun (id, value) -> { id; file = to_string value })
    |> List.sort (fun left right -> String.compare left.id right.id)
  in
  Ok mapped

let collapse_text parts =
  String.concat "\n\n" parts |> String.trim

let snippet_for_query ~query text =
  let lower_text = String.lowercase_ascii text in
  let lower_query = String.lowercase_ascii query in
  try
    let index = Str.search_forward (Str.regexp_string lower_query) lower_text 0 in
    let start_index = max 0 (index - 80) in
    let end_index = min (String.length text) (index + String.length query + 160) in
    String.sub text start_index (end_index - start_index) |> String.trim
  with Not_found ->
    if String.length text <= 200 then text else String.sub text 0 200

let search_in_source ~root ~query limit source =
  let path = Filename.concat (Filename.concat root "datas") source.file in
  let* json = read_json_file path in
  let lower_query = String.lowercase_ascii query in
  let hits =
    json
    |> to_list
    |> List.filter_map (fun document ->
           let text = document |> member "text" |> to_list |> filter_string |> collapse_text in
           let haystack =
             String.lowercase_ascii
               (String.concat "\n" [ document |> member "title" |> to_string_option |> Option.value ~default:""; text ])
           in
           if not (Str.string_match (Str.regexp_string lower_query) haystack 0)
              && not
                   (try
                      ignore (Str.search_forward (Str.regexp_string lower_query) haystack 0);
                      true
                    with Not_found -> false)
           then None
           else
             Some
               {
                 source_id = source.id;
                 title = document |> member "title" |> to_string_option |> Option.value ~default:"(sans titre)";
                 url = document |> member "url" |> to_string_option |> Option.value ~default:"";
                 date = document |> member "date" |> to_string_option |> Option.value ~default:"";
                 snippet = snippet_for_query ~query text;
               })
    |> List.sort (fun left right -> String.compare right.date left.date)
  in
  let rec take remaining count acc =
    match remaining with
    | [] -> List.rev acc
    | _ when count <= 0 -> List.rev acc
    | value :: rest -> take rest (count - 1) (value :: acc)
  in
  Ok (take hits limit [])

let search ~root ~sources:source_filter ~query ~limit =
  let* all_sources = sources ~root in
  let selected =
    match source_filter with
    | None | Some [] -> all_sources
    | Some ids -> List.filter (fun source -> List.exists (String.equal source.id) ids) all_sources
  in
  let rec gather remaining acc =
    match remaining with
    | [] -> Ok acc
    | source :: rest ->
        let* hits = search_in_source ~root ~query limit source in
        gather rest (List.rev_append hits acc)
  in
  let* hits = gather selected [] in
  let items = List.sort (fun left right -> String.compare right.date left.date) hits in
  let rec take remaining count acc =
    match remaining with
    | [] -> List.rev acc
    | _ when count <= 0 -> List.rev acc
    | value :: rest -> take rest (count - 1) (value :: acc)
  in
  Ok (take items limit [])
