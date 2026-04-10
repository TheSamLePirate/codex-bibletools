let ( let* ) result f = match result with Ok value -> f value | Error _ as e -> e

type verse_range = {
  first_verse : int option;
  last_verse : int option;
}

type t = {
  book : string;
  chapter : int;
  verses : verse_range;
}

let roman_value = function
  | 'I' -> Some 1
  | 'V' -> Some 5
  | 'X' -> Some 10
  | 'L' -> Some 50
  | 'C' -> Some 100
  | 'D' -> Some 500
  | 'M' -> Some 1000
  | _ -> None

let roman_to_int text =
  let upper = String.uppercase_ascii (String.trim text) in
  if upper = "" then None
  else
    let rec loop index previous total =
      if index < 0 then Some total
      else
        match roman_value upper.[index] with
        | None -> None
        | Some value ->
            let total' = if value < previous then total - value else total + value in
            loop (index - 1) value total'
    in
    loop (String.length upper - 1) 0 0

let parse_int text =
  let trimmed = String.trim text in
  match int_of_string_opt trimmed with
  | Some value -> Some value
  | None -> roman_to_int trimmed

let parse_verses rest =
  let trimmed = String.trim rest in
  if trimmed = "" then Ok { first_verse = None; last_verse = None }
  else
    let re = Str.regexp "^\\([0-9]+\\)\\([ \t]*[-–][ \t]*\\([0-9]+\\)\\)?$" in
    if Str.string_match re trimmed 0 then
      let first_verse = int_of_string (Str.matched_group 1 trimmed) in
      let last_verse =
        try Some (int_of_string (Str.matched_group 3 trimmed)) with Not_found | Invalid_argument _ -> None
      in
      Ok { first_verse = Some first_verse; last_verse }
    else Error ("Référence de versets invalide: " ^ trimmed)

let parse ~names input =
  let try_alias alias =
    let prefix = alias in
    let input_trimmed = String.trim input in
    let alias_len = String.length prefix in
    if String.length input_trimmed < alias_len then None
    else
      let candidate = String.sub input_trimmed 0 alias_len in
      if String.equal (String.lowercase_ascii candidate) (String.lowercase_ascii prefix) then
        let next_is_separator =
          String.length input_trimmed = alias_len
          || match input_trimmed.[alias_len] with ' ' | '\t' -> true | _ -> false
        in
        if next_is_separator then Some (String.trim (String.sub input_trimmed alias_len (String.length input_trimmed - alias_len))) else None
      else None
  in
  let all_candidates =
    let dedup = Hashtbl.create 128 in
    let add acc value =
      if Hashtbl.mem dedup value then acc
      else (
        Hashtbl.add dedup value ();
        value :: acc)
    in
    List.fold_left add [] (Book_names.all_aliases names)
    |> List.sort (fun a b -> compare (String.length b) (String.length a))
  in
  let rec find_match = function
    | [] -> Error ("Livre biblique introuvable dans la référence: " ^ input)
    | alias :: rest -> (
        match try_alias alias with
        | None -> find_match rest
        | Some trailing -> (
            let re =
              Str.regexp
                "^\\([0-9IVXLCDM]+\\)\\([ \t]*[,.:][ \t]*\\(.+\\)\\)?$"
            in
            if Str.string_match re trailing 0 then
              let chapter_text = Str.matched_group 1 trailing in
              let chapter =
                match parse_int chapter_text with
                | Some value when value > 0 -> Ok value
                | _ -> Error ("Chapitre invalide: " ^ chapter_text)
              in
              let verse_text =
                try Some (Str.matched_group 3 trailing) with Not_found | Invalid_argument _ -> None
              in
              let* chapter = chapter in
              let* verses =
                match verse_text with Some text -> parse_verses text | None -> Ok { first_verse = None; last_verse = None }
              in
              let* book =
                match Book_names.canonical_title names alias with
                | Some title -> Ok title
                | None -> Error ("Livre inconnu: " ^ alias)
              in
              Ok { book; chapter; verses }
            else Error ("Référence invalide: " ^ input)))
  in
  find_match all_candidates

let with_single_verse reference verse =
  { reference with verses = { first_verse = Some verse; last_verse = None } }

let format reference =
  let prefix = Printf.sprintf "%s %d" reference.book reference.chapter in
  match reference.verses.first_verse, reference.verses.last_verse with
  | None, _ -> prefix
  | Some verse, None -> Printf.sprintf "%s,%d" prefix verse
  | Some first_verse, Some last_verse -> Printf.sprintf "%s,%d-%d" prefix first_verse last_verse
