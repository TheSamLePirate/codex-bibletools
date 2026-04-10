let ( let* ) result f = match result with Ok value -> f value | Error _ as e -> e

type t = {
  alias_to_title : (string, string) Hashtbl.t;
  title_to_aliases : (string, string list) Hashtbl.t;
  ordered_aliases : string list;
}

let normalize text =
  let lowered = String.lowercase_ascii text in
  let lowered =
    [
      ("’", "'");
      ("‘", "'");
      ("É", "e");
      ("È", "e");
      ("Ê", "e");
      ("Ë", "e");
      ("À", "a");
      ("Â", "a");
      ("Ä", "a");
      ("Î", "i");
      ("Ï", "i");
      ("Ô", "o");
      ("Ö", "o");
      ("Ù", "u");
      ("Û", "u");
      ("Ü", "u");
      ("Ç", "c");
      ("Œ", "oe");
      ("Æ", "ae");
      ("é", "e");
      ("è", "e");
      ("ê", "e");
      ("ë", "e");
      ("à", "a");
      ("â", "a");
      ("ä", "a");
      ("î", "i");
      ("ï", "i");
      ("ô", "o");
      ("ö", "o");
      ("ù", "u");
      ("û", "u");
      ("ü", "u");
      ("ç", "c");
      ("œ", "oe");
      ("æ", "ae");
    ]
    |> List.fold_left
         (fun acc (source, target) -> Str.global_replace (Str.regexp_string source) target acc)
         lowered
  in
  let buffer = Buffer.create (String.length lowered) in
  let push_space = ref false in
  String.iter
    (function
      | '\'' | '`' -> Buffer.add_char buffer '\''
      | '\n' | '\r' | '\t' | ' ' ->
          if Buffer.length buffer > 0 then push_space := true
      | c ->
          if !push_space then (
            Buffer.add_char buffer ' ';
            push_space := false);
          Buffer.add_char buffer c)
    lowered;
  Buffer.contents buffer |> String.trim

let add_alias alias title alias_to_title title_to_aliases =
  let alias_key = normalize alias in
  if alias_key <> "" then Hashtbl.replace alias_to_title alias_key title;
  let title_key = normalize title in
  let existing =
    match Hashtbl.find_opt title_to_aliases title_key with
    | Some values -> values
    | None -> []
  in
  if not (List.exists (String.equal alias) existing) then
    Hashtbl.replace title_to_aliases title_key (alias :: existing)

let parse_abrevs_section content =
  let start_marker = "let abrevs = {" in
  let end_marker = "let abrevsInverse" in
  let start_idx =
    try Some (Str.search_forward (Str.regexp_string start_marker) content 0)
    with Not_found -> None
  in
  match start_idx with
  | None -> Error "Section `abrevs` introuvable dans bibleTools.js."
  | Some idx ->
      let body_start = idx + String.length start_marker in
      let body_end =
        try Str.search_forward (Str.regexp_string end_marker) content body_start
        with Not_found -> String.length content
      in
      Ok (String.sub content body_start (body_end - body_start))

let load ~root =
  let path = Filename.concat root "bibleTools.js" in
  try
    let content = Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all in
    let* section = parse_abrevs_section content in
    let alias_to_title = Hashtbl.create 256 in
    let title_to_aliases = Hashtbl.create 128 in
    let pair_re = Str.regexp "\"\\([^\"]+\\)\":\"\\([^\"]+\\)\"" in
    let rec collect pos ordered =
      match Str.search_forward pair_re section pos with
      | exception Not_found -> List.rev ordered
      | match_start ->
          let alias = Str.matched_group 1 section in
          let title = Str.matched_group 2 section in
          let next_pos = match_start + String.length (Str.matched_string section) in
          add_alias alias title alias_to_title title_to_aliases;
          add_alias title title alias_to_title title_to_aliases;
          collect next_pos (alias :: title :: ordered)
    in
    let ordered_aliases = collect 0 [] in
    Ok { alias_to_title; title_to_aliases; ordered_aliases }
  with Sys_error message -> Error message

let canonical_title t candidate =
  Hashtbl.find_opt t.alias_to_title (normalize candidate)

let aliases t title =
  match Hashtbl.find_opt t.title_to_aliases (normalize title) with
  | Some values -> List.rev values
  | None ->
      let normalized = normalize title in
      if Hashtbl.mem t.alias_to_title normalized then [ title ] else []

let all_aliases t = t.ordered_aliases
