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

let load ~root:_ =
  let alias_to_title = Hashtbl.create 256 in
  let title_to_aliases = Hashtbl.create 128 in
  let ordered_aliases =
    BibleTools.abbreviations
    |> List.fold_left
         (fun ordered (alias, title) ->
           add_alias alias title alias_to_title title_to_aliases;
           add_alias title title alias_to_title title_to_aliases;
           alias :: title :: ordered)
         []
    |> List.rev
  in
  List.iter
    (fun (alias, canonical_alias) ->
      match List.assoc_opt canonical_alias BibleTools.abbreviations with
      | Some title -> add_alias alias title alias_to_title title_to_aliases
      | None -> ())
    BibleTools.inverse_aliases;
  Ok { alias_to_title; title_to_aliases; ordered_aliases }

let canonical_title t candidate =
  Hashtbl.find_opt t.alias_to_title (normalize candidate)

let aliases t title =
  match Hashtbl.find_opt t.title_to_aliases (normalize title) with
  | Some values -> List.rev values
  | None ->
      let normalized = normalize title in
      if Hashtbl.mem t.alias_to_title normalized then [ title ] else []

let all_aliases t = t.ordered_aliases
