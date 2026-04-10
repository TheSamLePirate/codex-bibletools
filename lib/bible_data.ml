let ( let* ) result f = match result with Ok value -> f value | Error _ as e -> e

open Yojson.Safe.Util

type verse = {
  number : int;
  text : string;
}

type chapter = {
  number : int;
  verses : verse array;
}

type book = {
  title : string;
  canonical_title : string;
  aliases : string list;
  chapters : chapter array;
}

type translation = {
  title : string;
  books : book array;
  by_key : (string, int) Hashtbl.t;
  flat_index : (book * chapter * verse) array Lazy.t;
  by_reference : (string, int) Hashtbl.t Lazy.t;
}

type translation_info = {
  id : string;
  title : string;
}

type book_info = {
  canonical_title : string;
  display_title : string;
  chapter_count : int;
}

type navigation = {
  has_previous : bool;
  has_next : bool;
}

type direction =
  | Previous
  | Next

let builtin_titles =
  [
    ("bible", "Louis Segond");
    ("bibleEpee", "Bible de l'Épée");
    ("bibleMartin", "Bible Martin");
    ("bibleParoleDeVie", "Parole de Vie");
    ("bibleTOB", "TOB");
    ("bible_aelf", "AELF");
    ("bible_jehovah", "Traduction du monde nouveau");
  ]

let translation_title id =
  match List.assoc_opt id builtin_titles with
  | Some title -> title
  | None -> id

let json_cache : (string, (Yojson.Safe.t, string) result) Hashtbl.t = Hashtbl.create 32
let translation_cache : (string, (translation, string) result) Hashtbl.t = Hashtbl.create 16

let list_bible_files ~root =
  let datas = Filename.concat root "datas" in
  try
    let files = Sys.readdir datas |> Array.to_list in
    let ids =
      files
      |> List.filter (fun file ->
             Filename.check_suffix file ".json"
             && String.length file >= 5
             && String.sub file 0 5 = "bible")
      |> List.map (fun file -> Filename.remove_extension file)
      |> List.sort String.compare
    in
    Ok ids
  with Sys_error message -> Error message

let available_translations ~root =
  let* ids = list_bible_files ~root in
  Ok (List.map (fun id -> { id; title = translation_title id }) ids)

let read_json_file path =
  match Hashtbl.find_opt json_cache path with
  | Some cached -> cached
  | None ->
      let loaded =
        try Ok (Yojson.Safe.from_file path) with Yojson.Json_error message -> Error message | Sys_error message -> Error message
      in
      Hashtbl.replace json_cache path loaded;
      loaded

let json_intish json ~default =
  match json with
  | `Int value -> value
  | `Intlit text | `String text -> (
      match int_of_string_opt text with
      | Some value -> value
      | None -> default)
  | _ -> default

let chapter_list_of_json json =
  match json with
  | `List values -> values
  | `Assoc values ->
      values
      |> List.sort (fun (left, _) (right, _) -> compare left right)
      |> List.map snd
  | _ -> []

let canonical_title_from_url names url =
  let re = Str.regexp ".*/bible/\\([^/]+\\)/[0-9A-Za-z]+/?$" in
  if Str.string_match re url 0 then
    let abbrev = Str.matched_group 1 url in
    Book_names.canonical_title names abbrev
  else None

let verse_of_json json =
  {
    number = json |> member "ID" |> json_intish ~default:1;
    text = json |> member "Text" |> to_string_option |> Option.value ~default:"";
  }

let chapter_of_json json =
  {
    number = json |> member "ID" |> json_intish ~default:1;
    verses = json |> member "Verses" |> to_list |> List.map verse_of_json |> Array.of_list;
  }

let book_aliases names ?url title =
  let title_key =
    match Option.bind url (canonical_title_from_url names) with
    | Some canonical -> canonical
    | None -> (
        match Book_names.canonical_title names title with
        | Some canonical -> canonical
        | None -> title)
  in
  let aliases =
    match Book_names.aliases names title_key with
    | [] -> [ title ]
    | values -> title :: values
  in
  title_key, aliases

let book_of_json names json =
  let title = json |> member "Text" |> to_string_option |> Option.value ~default:"Livre sans titre" in
  let url = json |> member "url" |> to_string_option in
  let canonical_title, aliases = book_aliases names ?url title in
  let chapters =
    json |> member "Chapters" |> chapter_list_of_json |> List.map chapter_of_json |> Array.of_list
  in
  { title; canonical_title; aliases; chapters }

let index_books books =
  let index = Hashtbl.create 256 in
  Array.iteri
    (fun book_index (book : book) ->
      let add key =
        let normalized = String.lowercase_ascii (String.trim key) in
        if normalized <> "" then Hashtbl.replace index normalized book_index
      in
      add book.title;
      add book.canonical_title;
      List.iter add book.aliases)
    books;
  index

let reference_key book chapter verse_number = Printf.sprintf "%s\t%d\t%d" book chapter verse_number

let build_flat_index books =
  Array.to_list books
  |> List.concat_map (fun book ->
         Array.to_list book.chapters
         |> List.concat_map (fun chapter ->
                Array.to_list chapter.verses
                |> List.map (fun verse -> (book, chapter, verse))))
  |> Array.of_list

let build_reference_index verses =
  let index = Hashtbl.create (Array.length verses * 2) in
  Array.iteri
    (fun i ((book, chapter, verse) : book * chapter * verse) ->
      Hashtbl.replace index (reference_key book.canonical_title chapter.number verse.number) i)
    verses;
  index

let load_translation ~root ~names ~id =
  let path = Filename.concat (Filename.concat root "datas") (id ^ ".json") in
  match Hashtbl.find_opt translation_cache path with
  | Some cached -> cached
  | None ->
      let loaded =
        let* json = read_json_file path in
        let books =
          json |> member "Testaments" |> to_list
          |> List.concat_map (fun testament -> testament |> member "Books" |> to_list)
          |> List.map (book_of_json names)
          |> Array.of_list
        in
        let by_key = index_books books in
        let flat_index = lazy (build_flat_index books) in
        let by_reference = lazy (build_reference_index (Lazy.force flat_index)) in
        Ok { title = translation_title id; books; by_key; flat_index; by_reference }
      in
      Hashtbl.replace translation_cache path loaded;
      loaded

let books translation =
  Array.to_list translation.books
  |> List.map (fun (book : book) ->
         {
           canonical_title = book.canonical_title;
           display_title = book.title;
           chapter_count = Array.length book.chapters;
         })

let find_book translation book_name =
  let key = String.lowercase_ascii (String.trim book_name) in
  match Hashtbl.find_opt translation.by_key key with
  | Some index -> Ok translation.books.(index)
  | None -> Error ("Livre introuvable dans la traduction " ^ translation.title ^ ": " ^ book_name)

let get_chapter book chapter_number =
  if chapter_number <= 0 || chapter_number > Array.length book.chapters then
    Error (Printf.sprintf "Chapitre introuvable: %s %d" book.title chapter_number)
  else Ok book.chapters.(chapter_number - 1)

let chapter_numbers translation ~book =
  let* book = find_book translation book in
  Ok (List.init (Array.length book.chapters) (fun index -> index + 1))

let verse_numbers translation ~book ~chapter =
  let* book = find_book translation book in
  let* chapter = get_chapter book chapter in
  Ok (Array.to_list chapter.verses |> List.map (fun (verse : verse) -> verse.number))

let verse_bounds verses range =
  match range.Bible_reference.first_verse, range.Bible_reference.last_verse with
  | None, _ -> Ok (1, Array.length verses)
  | Some first_verse, None -> Ok (first_verse, first_verse)
  | Some first_verse, Some last_verse when last_verse >= first_verse -> Ok (first_verse, last_verse)
  | Some _, Some _ -> Error "Intervalle de versets invalide."

let slice_verses (chapter : chapter) range =
  let* first_verse, last_verse = verse_bounds chapter.verses range in
  if first_verse <= 0 || last_verse > Array.length chapter.verses then
    Error "Verset hors limites."
  else
    Ok
      (Array.to_list chapter.verses
      |> List.filter (fun (verse : verse) -> verse.number >= first_verse && verse.number <= last_verse))

let lookup translation reference =
  let* book = find_book translation reference.Bible_reference.book in
  let* chapter = get_chapter book reference.chapter in
  let* verses = slice_verses chapter reference.verses in
  Ok (book.title, verses)

let chapter translation reference =
  let* book = find_book translation reference.Bible_reference.book in
  let* chapter = get_chapter book reference.chapter in
  Ok (book.title, chapter)

let flatten_index translation =
  Lazy.force translation.flat_index

let find_reference_index translation reference =
  let verses = flatten_index translation in
  let verse_number = Option.value reference.Bible_reference.verses.first_verse ~default:1 in
  match Hashtbl.find_opt (Lazy.force translation.by_reference) (reference_key reference.book reference.chapter verse_number) with
  | Some index -> Some (verses, index)
  | None -> None

let navigate translation reference direction =
  match find_reference_index translation reference with
  | None -> Error ("Référence introuvable: " ^ Bible_reference.format reference)
  | Some (verses, index) ->
      let target =
        match direction with
        | Previous when index > 0 -> Some verses.(index - 1)
        | Next when index + 1 < Array.length verses -> Some verses.(index + 1)
        | _ -> None
      in
      (match target with
      | None -> Error "Navigation impossible à cette position."
      | Some ((book, chapter, verse) : book * chapter * verse) ->
          Ok
            {
              Bible_reference.book = book.canonical_title;
              chapter = chapter.number;
              verses = { first_verse = Some verse.number; last_verse = None };
            })

let navigation translation reference =
  match find_reference_index translation reference with
  | None -> Error ("Référence introuvable: " ^ Bible_reference.format reference)
  | Some (verses, index) ->
      Ok { has_previous = index > 0; has_next = index + 1 < Array.length verses }

let random_reference ?book translation () =
  Random.self_init ();
  let pool =
    match book with
    | None -> Ok (flatten_index translation)
    | Some book_name ->
        let* found_book = find_book translation book_name in
        Ok
          (Array.to_list found_book.chapters
          |> List.concat_map (fun chapter ->
                 Array.to_list chapter.verses |> List.map (fun verse -> (found_book, chapter, verse)))
          |> Array.of_list)
  in
  let* pool = pool in
  if Array.length pool = 0 then Error "Aucun verset disponible."
  else
    let (book, chapter, verse : book * chapter * verse) = pool.(Random.int (Array.length pool)) in
    Ok
      {
        Bible_reference.book = book.canonical_title;
        chapter = chapter.number;
        verses = { first_verse = Some verse.number; last_verse = None };
      }
