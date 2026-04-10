open Yojson.Safe.Util

let ( let* ) result f = match result with Ok value -> f value | Error _ as e -> e

type selector_option = {
  value : string;
  label : string;
}

type source_descriptor = {
  id : string;
  label : string;
  nomenclature : string list;
}

type rendered = {
  source_id : string;
  reference : string;
  title : string;
  subtitle : string option;
  body : string;
}

type navigation = {
  has_previous : bool;
  has_next : bool;
}

type direction =
  | Previous
  | Next

type vatican_doc = {
  date_key : string;
  title : string;
  text : string list;
  has_intro : bool;
}

type parsed_ref =
  | Bible of Bible_reference.t
  | Quran of int * int * int option
  | Vatican of string * string * int * int option
  | Simple of string * int * int option
  | Rael of int * int * int * int option
  | Compendium of int * int option
  | CompendiumSocial of int * int option
  | CatechismeX of int * int * int * int option
  | CatechismeTrente of int * int * int * int * int option
  | HadithBook of string * string * int * int option
  | HadithNumber of string * string

type simple_config = {
  source_id : string;
  title : string;
  file : string;
  prefix : string;
}

let simple_sources =
  [
    { source_id = "Can"; title = "Code canonique"; file = "can.json"; prefix = "Can." };
    { source_id = "Can1917"; title = "Code canonique 1917"; file = "can1917.json"; prefix = "Can1917." };
    {
      source_id = "Can1990";
      title = "Code canonique des églises orientales de 1990";
      file = "can1990.json";
      prefix = "Can1990.";
    };
    { source_id = "Catechisme"; title = "Catéchisme"; file = "catechisme.json"; prefix = "Cat." };
    {
      source_id = "CatechismeE";
      title = "Catéchisme des évêques de France";
      file = "catechismeEveques.json";
      prefix = "CatE.";
    };
  ]

let find_simple_config source_id = List.find_opt (fun cfg -> String.equal cfg.source_id source_id) simple_sources

let read_json path =
  try Ok (Yojson.Safe.from_file path) with Yojson.Json_error msg -> Error msg | Sys_error msg -> Error msg

let datas_path root file = Filename.concat (Filename.concat root "datas") file

let source_descriptors =
  [
    { id = "Bible"; label = "Bible"; nomenclature = [ "livre"; "chapitre"; "verset" ] };
    { id = "Coran"; label = "Coran"; nomenclature = [ "sourate"; "verset" ] };
    { id = "Vatican"; label = "Vatican"; nomenclature = [ "dossier"; "date"; "article" ] };
    { id = "Can"; label = "Code canonique"; nomenclature = [ "article" ] };
    { id = "Can1917"; label = "Code canonique 1917"; nomenclature = [ "article" ] };
    { id = "Can1990"; label = "Code canonique 1990"; nomenclature = [ "article" ] };
    { id = "Catechisme"; label = "Catéchisme"; nomenclature = [ "article" ] };
    { id = "CatechismeE"; label = "Catéchisme des évêques"; nomenclature = [ "article" ] };
    { id = "Rael"; label = "Rael"; nomenclature = [ "livre"; "chapitre"; "page" ] };
    { id = "Compendium"; label = "Compendium du catéchisme"; nomenclature = [ "article" ] };
    { id = "CompendiumSocial"; label = "Compendium de la doctrine sociale"; nomenclature = [ "article" ] };
    { id = "CatechismeX"; label = "Catéchisme de Pie X"; nomenclature = [ "partie"; "chapitre"; "page" ] };
    {
      id = "CatechismeTrente";
      label = "Catéchisme du concile de Trente";
      nomenclature = [ "partie"; "chapitre"; "paragraphe"; "phrase" ];
    };
    { id = "Hadiths"; label = "Hadiths par livre"; nomenclature = [ "auteur"; "livre"; "numéro" ] };
    { id = "Hadiths2"; label = "Hadiths par numéro"; nomenclature = [ "auteur"; "numéro" ] };
  ]

let list_sources ~root:_ = source_descriptors

let hadith_author_candidates =
  [
    "tirmidhi";
    "shamail";
    "muslim";
    "bukhari";
    "ibnmajah";
    "nasai";
    "ahmad";
    "abudawud";
    "riyadussalihin";
    "mishkat";
    "bulugh";
    "adab";
    "nawawi40";
    "shahwaliullah40";
    "qudsi40";
    "hisn";
  ]

let source_exists id = List.exists (fun source -> String.equal source.id id) source_descriptors

let load_bible ~root ~names ~translation = Bible_data.load_translation ~root ~names ~id:translation
let load_quran ~root = read_json (datas_path root "quran.json")

let load_simple_array ~root file =
  let* json = read_json (datas_path root file) in
  Ok
    (json |> to_list
    |> List.map (function
         | `Null -> ""
         | `String value -> value
         | value -> raise (Type_error ("Expected string or null", value))))

let vatican_map ~root =
  let* json = read_json (datas_path root "Vatican_map.json") in
  Ok (json |> to_assoc)

let load_vatican_dossier ~root dossier =
  let* mapping = vatican_map ~root in
  let* file =
    match List.assoc_opt dossier mapping with
    | Some file -> Ok (to_string file)
    | None -> Error ("Dossier Vatican introuvable: " ^ dossier)
  in
  let* json = read_json (datas_path root file) in
  let docs : vatican_doc list =
    json |> to_list
    |> List.map (fun doc : vatican_doc ->
           {
             date_key = doc |> member "date" |> to_string_option |> Option.value ~default:"";
             title = doc |> member "title" |> to_string_option |> Option.value ~default:"(sans titre)";
             text = doc |> member "text" |> to_list |> filter_string;
             has_intro = doc |> member "hasIntro" |> to_bool_option |> Option.value ~default:false;
           })
    |> List.sort (fun (left : vatican_doc) (right : vatican_doc) -> String.compare left.title right.title)
  in
  let seen = Hashtbl.create 64 in
  Ok
    (List.map
       (fun doc ->
         let count = Option.value (Hashtbl.find_opt seen doc.date_key) ~default:0 in
         Hashtbl.replace seen doc.date_key (count + 1);
         if count = 0 then doc else { doc with date_key = Printf.sprintf "%s-%d" doc.date_key count })
       docs)

let load_hadith_file ~root author =
  let* json = read_json (datas_path root (String.lowercase_ascii author ^ ".json")) in
  Ok (json |> to_list)

let available_hadith_authors ~root =
  hadith_author_candidates |> List.filter (fun author -> Sys.file_exists (datas_path root (author ^ ".json")))

let hadith_in_book item =
  let reference = item |> member "ref" |> member "In-book reference" in
  match reference with
  | `Assoc assoc -> (
      try
        let book = assoc |> List.assoc "Book" |> to_string in
        let hadith = assoc |> List.assoc "Hadith" |> to_string |> int_of_string in
        Ok (book, hadith)
      with Not_found | Failure _ -> Error "Structure hadith inattendue.")
  | `String text ->
      if Str.string_match (Str.regexp "^Introduction, \\(Hadith\\|Narration\\) \\([0-9]+\\)$") text 0 then
        Ok ("Introduction", int_of_string (Str.matched_group 2 text))
      else if Str.string_match (Str.regexp "^Book \\([0-9]+[a-z]?\\), Hadith \\([0-9]+\\)$") text 0 then
        Ok (Str.matched_group 1 text, int_of_string (Str.matched_group 2 text))
      else Error "Structure hadith inattendue."
  | _ -> Error "Structure hadith inattendue."

let sort_book_id left right =
  match int_of_string_opt left, int_of_string_opt right with
  | Some l, Some r -> Int.compare l r
  | _ -> String.compare left right

let load_catechisme_x ~root = read_json (datas_path root "catechisme_pieX.json")
let load_catechisme_trente ~root = read_json (datas_path root "catechisme_trente.json")
let load_rael ~root = read_json (datas_path root "Rael.json")
let load_compendium ~root = read_json (datas_path root "compendium.json")
let load_compendium_social ~root = read_json (datas_path root "compendium_sociale.json")

let rael_books json = json |> to_list
let compendium_items json = json |> to_list
let compendium_social_items json = json |> to_list

let rael_book_title book = book |> member "title" |> to_string
let rael_sections book = book |> member "sections" |> to_list
let rael_section_title section = section |> member "title" |> to_string
let rael_pages section = section |> member "pages" |> to_list
let rael_page_number page = page |> member "page" |> to_int

let rael_page_text page =
  page |> member "text" |> to_list |> filter_string |> List.map String.trim
  |> List.filter (fun line -> line <> "")
  |> String.concat "\n"

let render_compendium_item index item =
  let question = item |> member "Q" |> to_string_option |> Option.value ~default:"" |> String.trim in
  let response = item |> member "R" |> to_string_option |> Option.value ~default:"" |> String.trim in
  Printf.sprintf "%d. %s\n\n%s" index question response |> String.trim

let render_compendium_social_item index item =
  let lines = item |> to_list |> filter_string |> List.map String.trim |> List.filter (fun line -> line <> "") in
  match lines with
  | [] -> Printf.sprintf "%d." index
  | _ -> Printf.sprintf "%d. %s" index (String.concat "\n" lines)

let quran_sourates json = json |> member "sourates" |> to_list
let catechisme_x_sections json = json |> member "sections" |> to_list
let catechisme_trente_parts json = json |> member "parts" |> to_list

let range_to_bounds ~first ~last ~min_value ~max_value =
  let actual_last = Option.value last ~default:first in
  if first < min_value || actual_last < first || actual_last > max_value then Error "Référence hors limites."
  else Ok (first, actual_last)

let find_nth list index error_message =
  match List.nth_opt list index with Some value -> Ok value | None -> Error error_message

let find_index predicate list =
  let rec loop index = function
    | [] -> None
    | item :: rest -> if predicate item then Some index else loop (index + 1) rest
  in
  loop 0 list

let json_stringish json =
  match json with
  | `Int value -> string_of_int value
  | `String value -> value
  | _ -> raise (Type_error ("Expected string or int", json))

let simple_selector_options ~root source_id =
  let* cfg =
    match find_simple_config source_id with
    | Some cfg -> Ok cfg
    | None -> Error ("Source simple inconnue: " ^ source_id)
  in
  let* items = load_simple_array ~root cfg.file in
  Ok (List.init (List.length items) (fun i -> let n = i + 1 in { value = string_of_int n; label = string_of_int n }))

let selector_count ~root ~names:_ ~bible_translation:_ ~source ~path =
  match source, path with
  | ("Can" | "Can1917" | "Can1990" | "Catechisme" | "CatechismeE"), [] ->
      let* cfg =
        match find_simple_config source with
        | Some cfg -> Ok cfg
        | None -> Error ("Source simple inconnue: " ^ source)
      in
      let* items = load_simple_array ~root cfg.file in
      Ok (Some (List.length items))
  | "Compendium", [] ->
      let* items = load_compendium ~root in
      Ok (Some (List.length (to_list items)))
  | "CompendiumSocial", [] ->
      let* items = load_compendium_social ~root in
      Ok (Some (List.length (to_list items)))
  | "Hadiths", [ author; book ] ->
      let* items = load_hadith_file ~root author in
      let count =
        items
        |> List.fold_left
             (fun acc item ->
               match hadith_in_book item with
               | Ok (item_book, _) when String.equal item_book book -> acc + 1
               | _ -> acc)
             0
      in
      Ok (Some count)
  | "Hadiths2", [ author ] ->
      let* items = load_hadith_file ~root author in
      Ok (Some (List.length items))
  | _ -> Ok None

let selector_options ~root ~names ~bible_translation ~source ~path =
  match source, path with
  | "Bible", [] ->
      let* bible = load_bible ~root ~names ~translation:bible_translation in
      Ok
        (Bible_data.books bible
        |> List.map (fun (book : Bible_data.book_info) -> { value = book.canonical_title; label = book.display_title }))
  | "Bible", [ book ] ->
      let* bible = load_bible ~root ~names ~translation:bible_translation in
      let* chapters = Bible_data.chapter_numbers bible ~book in
      Ok (List.map (fun number -> { value = string_of_int number; label = string_of_int number }) chapters)
  | "Bible", [ book; chapter ] ->
      let* bible = load_bible ~root ~names ~translation:bible_translation in
      let* verses = Bible_data.verse_numbers bible ~book ~chapter:(int_of_string chapter) in
      Ok (List.map (fun number -> { value = string_of_int number; label = string_of_int number }) verses)
  | "Bible", _ -> Ok []
  | "Coran", [] ->
      let* quran = load_quran ~root in
      Ok
        (quran_sourates quran
        |> List.map (fun sourate ->
               let number = sourate |> member "position" |> to_int in
               let name = sourate |> member "nom_sourate" |> to_string in
               { value = string_of_int number; label = Printf.sprintf "%d %s" number name }))
  | "Coran", [ sourate ] ->
      let* quran = load_quran ~root in
      let* sourate_json = find_nth (quran_sourates quran) (int_of_string sourate - 1) "Sourate introuvable." in
      Ok
        (sourate_json |> member "versets" |> to_list
        |> List.map (fun verse ->
               let number = verse |> member "position_ds_sourate" |> to_int in
               { value = string_of_int number; label = string_of_int number }))
  | "Coran", _ -> Ok []
  | "Vatican", [] ->
      let* mapping = vatican_map ~root in
      Ok
        (mapping |> List.map fst |> List.sort String.compare |> List.map (fun dossier -> { value = dossier; label = dossier }))
  | "Vatican", [ dossier ] ->
      let* docs = load_vatican_dossier ~root dossier in
      Ok (List.map (fun doc -> { value = doc.date_key; label = doc.date_key ^ " " ^ doc.title }) docs)
  | "Vatican", [ dossier; date ] ->
      let* docs = load_vatican_dossier ~root dossier in
      let* doc =
        match List.find_opt (fun doc -> String.equal doc.date_key date) docs with
        | Some doc -> Ok doc
        | None -> Error "Document Vatican introuvable."
      in
      let first = if doc.has_intro then 0 else 1 in
      let last = first + List.length doc.text - 1 in
      Ok (List.init (last - first + 1) (fun i -> let n = first + i in { value = string_of_int n; label = string_of_int n }))
  | "Vatican", _ -> Ok []
  | ("Can" | "Can1917" | "Can1990" | "Catechisme" | "CatechismeE"), [] -> simple_selector_options ~root source
  | ("Can" | "Can1917" | "Can1990" | "Catechisme" | "CatechismeE"), _ -> Ok []
  | "Rael", [] ->
      let* doc = load_rael ~root in
      Ok (doc |> to_list |> List.map (fun book -> { value = book |> member "title" |> to_string; label = book |> member "title" |> to_string }))
  | "Rael", [ book_title ] ->
      let* doc = load_rael ~root in
      let books = doc |> to_list in
      let* book =
        match List.find_opt (fun book -> String.equal (book |> member "title" |> to_string) book_title) books with
        | Some book -> Ok book
        | None -> Error "Livre Rael introuvable."
      in
      Ok
        (book |> member "sections" |> to_list
        |> List.map (fun section -> { value = section |> member "title" |> to_string; label = section |> member "title" |> to_string }))
  | "Rael", [ book_title; section_title ] ->
      let* doc = load_rael ~root in
      let books = doc |> to_list in
      let* book =
        match List.find_opt (fun book -> String.equal (book |> member "title" |> to_string) book_title) books with
        | Some book -> Ok book
        | None -> Error "Livre Rael introuvable."
      in
      let* section =
        match List.find_opt (fun section -> String.equal (section |> member "title" |> to_string) section_title) (book |> member "sections" |> to_list) with
        | Some section -> Ok section
        | None -> Error "Chapitre Rael introuvable."
      in
      Ok
        (section |> member "pages" |> to_list
        |> List.map (fun page ->
               let number = page |> member "page" |> to_int in
               { value = string_of_int number; label = string_of_int number }))
  | "Rael", _ -> Ok []
  | "Compendium", [] ->
      let* items = load_compendium ~root in
      let items = items |> to_list in
      Ok (List.init (List.length items) (fun i -> let n = i + 1 in { value = string_of_int n; label = string_of_int n }))
  | "Compendium", _ -> Ok []
  | "CompendiumSocial", [] ->
      let* items = load_compendium_social ~root in
      let items = items |> to_list in
      Ok (List.init (List.length items) (fun i -> let n = i + 1 in { value = string_of_int n; label = string_of_int n }))
  | "CompendiumSocial", _ -> Ok []
  | "CatechismeX", [] ->
      let* doc = load_catechisme_x ~root in
      Ok (catechisme_x_sections doc |> List.map (fun section -> { value = section |> member "title" |> to_string; label = section |> member "title" |> to_string }))
  | "CatechismeX", [ section_title ] ->
      let* doc = load_catechisme_x ~root in
      let* section =
        match List.find_opt (fun section -> String.equal (section |> member "title" |> to_string) section_title) (catechisme_x_sections doc) with
        | Some section -> Ok section
        | None -> Error "Partie introuvable."
      in
      Ok
        (section |> member "chapters" |> to_list
        |> List.map (fun chapter -> { value = chapter |> member "title" |> to_string; label = chapter |> member "title" |> to_string }))
  | "CatechismeX", [ section_title; chapter_title ] ->
      let* doc = load_catechisme_x ~root in
      let* section =
        match List.find_opt (fun section -> String.equal (section |> member "title" |> to_string) section_title) (catechisme_x_sections doc) with
        | Some section -> Ok section
        | None -> Error "Partie introuvable."
      in
      let* chapter =
        match
          List.find_opt
            (fun chapter -> String.equal (chapter |> member "title" |> to_string) chapter_title)
            (section |> member "chapters" |> to_list)
        with
        | Some chapter -> Ok chapter
        | None -> Error "Chapitre introuvable."
      in
      Ok
        (chapter |> member "pages" |> to_list
        |> List.map (fun page ->
               let number = page |> member "page" |> to_int in
               { value = string_of_int number; label = string_of_int number }))
  | "CatechismeX", _ -> Ok []
  | "CatechismeTrente", [] ->
      let* doc = load_catechisme_trente ~root in
      Ok (catechisme_trente_parts doc |> List.map (fun part -> { value = part |> member "title" |> to_string; label = part |> member "title" |> to_string }))
  | "CatechismeTrente", [ part_title ] ->
      let* doc = load_catechisme_trente ~root in
      let* part =
        match List.find_opt (fun part -> String.equal (part |> member "title" |> to_string) part_title) (catechisme_trente_parts doc) with
        | Some part -> Ok part
        | None -> Error "Partie introuvable."
      in
      Ok
        (part |> member "chapters" |> to_list
        |> List.map (fun chapter -> { value = chapter |> member "title" |> to_string; label = chapter |> member "title" |> to_string }))
  | "CatechismeTrente", [ part_title; chapter_title ] ->
      let* doc = load_catechisme_trente ~root in
      let* part =
        match List.find_opt (fun part -> String.equal (part |> member "title" |> to_string) part_title) (catechisme_trente_parts doc) with
        | Some part -> Ok part
        | None -> Error "Partie introuvable."
      in
      let* chapter =
        match
          List.find_opt
            (fun chapter -> String.equal (chapter |> member "title" |> to_string) chapter_title)
            (part |> member "chapters" |> to_list)
        with
        | Some chapter -> Ok chapter
        | None -> Error "Chapitre introuvable."
      in
      Ok
        (chapter |> member "paras" |> to_list
        |> List.map (fun para -> { value = para |> member "title" |> to_string; label = para |> member "title" |> to_string }))
  | "CatechismeTrente", [ part_title; chapter_title; para_title ] ->
      let* doc = load_catechisme_trente ~root in
      let* part =
        match List.find_opt (fun part -> String.equal (part |> member "title" |> to_string) part_title) (catechisme_trente_parts doc) with
        | Some part -> Ok part
        | None -> Error "Partie introuvable."
      in
      let* chapter =
        match
          List.find_opt
            (fun chapter -> String.equal (chapter |> member "title" |> to_string) chapter_title)
            (part |> member "chapters" |> to_list)
        with
        | Some chapter -> Ok chapter
        | None -> Error "Chapitre introuvable."
      in
      let* para =
        match List.find_opt (fun para -> String.equal (para |> member "title" |> to_string) para_title) (chapter |> member "paras" |> to_list) with
        | Some para -> Ok para
        | None -> Error "Paragraphe introuvable."
      in
      Ok
        (para |> member "text" |> to_list
        |> List.mapi (fun index _ -> let n = index + 1 in { value = string_of_int n; label = string_of_int n }))
  | "CatechismeTrente", _ -> Ok []
  | "Hadiths", [] ->
      Ok (List.map (fun author -> { value = author; label = author }) (available_hadith_authors ~root))
  | "Hadiths", [ author ] ->
      let* items = load_hadith_file ~root author in
      let books =
        items
        |> List.filter_map (fun item ->
               match hadith_in_book item with Ok (book, _) -> Some book | Error _ -> None)
        |> List.sort_uniq sort_book_id
      in
      Ok (List.map (fun book -> { value = book; label = book }) books)
  | "Hadiths", [ author; book ] ->
      let* items = load_hadith_file ~root author in
      let numbers =
        items
        |> List.filter_map (fun item ->
               match hadith_in_book item with
               | Ok (item_book, number) when String.equal item_book book -> Some number
               | _ -> None)
        |> List.sort_uniq Int.compare
      in
      Ok (List.map (fun number -> { value = string_of_int number; label = string_of_int number }) numbers)
  | "Hadiths", _ -> Ok []
  | "Hadiths2", [] ->
      Ok (List.map (fun author -> { value = author; label = author }) (available_hadith_authors ~root))
  | "Hadiths2", [ author ] ->
      let* items = load_hadith_file ~root author in
      let numbers =
        items |> List.map (fun item -> item |> member "number" |> json_stringish) |> List.sort_uniq String.compare
      in
      Ok (List.map (fun number -> { value = number; label = number }) numbers)
  | "Hadiths2", _ -> Ok []
  | _ -> Error ("Source inconnue: " ^ source)

let compile_reference ~root ~names ~bible_translation ~source ~path =
  let* _ = if source_exists source then Ok () else Error ("Source inconnue: " ^ source) in
  match source, path with
  | "Bible", [ book; chapter ] -> Ok (Printf.sprintf "%s %s" book chapter)
  | "Bible", [ book; chapter; verse ] -> Ok (Printf.sprintf "%s %s,%s" book chapter verse)
  | "Coran", [ sourate; verse ] -> Ok (Printf.sprintf "Coran:%s.%s" sourate verse)
  | "Vatican", [ dossier; date; article ] -> Ok (Printf.sprintf "Vatican %s %s %s" dossier date article)
  | ("Can" | "Can1917" | "Can1990" | "Catechisme" | "CatechismeE"), [ article ] ->
      let* cfg =
        match find_simple_config source with
        | Some cfg -> Ok cfg
        | None -> Error ("Source simple inconnue: " ^ source)
      in
      Ok (cfg.prefix ^ article)
  | "Rael", [ book_title; section_title; page ] ->
      let* doc = load_rael ~root in
      let books = doc |> to_list in
      let* book_index =
        match find_index (fun book -> String.equal (book |> member "title" |> to_string) book_title) books with
        | Some index -> Ok index
        | None -> Error "Livre Rael introuvable."
      in
      let book = List.nth books book_index in
      let sections = book |> member "sections" |> to_list in
      let* section_index =
        match find_index (fun section -> String.equal (section |> member "title" |> to_string) section_title) sections with
        | Some index -> Ok index
        | None -> Error "Chapitre Rael introuvable."
      in
      Ok (Printf.sprintf "Rael.%d.%d.%s" book_index section_index page)
  | "Compendium", [ article ] -> Ok ("Cat.Comp." ^ article)
  | "CompendiumSocial", [ article ] -> Ok ("Soc." ^ article)
  | "CatechismeX", [ section_title; chapter_title; page ] ->
      let* doc = load_catechisme_x ~root in
      let sections = catechisme_x_sections doc in
      let* section_index =
        match find_index (fun section -> String.equal (section |> member "title" |> to_string) section_title) sections with
        | Some index -> Ok index
        | None -> Error "Partie introuvable."
      in
      let section = List.nth sections section_index in
      let chapters = section |> member "chapters" |> to_list in
      let* chapter_index =
        match find_index (fun chapter -> String.equal (chapter |> member "title" |> to_string) chapter_title) chapters with
        | Some index -> Ok index
        | None -> Error "Chapitre introuvable."
      in
      Ok (Printf.sprintf "CatX.%d.%d.%s" section_index chapter_index page)
  | "CatechismeTrente", [ part_title; chapter_title; para_title; sentence ] ->
      let* doc = load_catechisme_trente ~root in
      let parts = catechisme_trente_parts doc in
      let* part_index =
        match find_index (fun part -> String.equal (part |> member "title" |> to_string) part_title) parts with
        | Some index -> Ok index
        | None -> Error "Partie introuvable."
      in
      let part = List.nth parts part_index in
      let chapters = part |> member "chapters" |> to_list in
      let* chapter_index =
        match find_index (fun chapter -> String.equal (chapter |> member "title" |> to_string) chapter_title) chapters with
        | Some index -> Ok index
        | None -> Error "Chapitre introuvable."
      in
      let chapter = List.nth chapters chapter_index in
      let paras = chapter |> member "paras" |> to_list in
      let* para_index =
        match find_index (fun para -> String.equal (para |> member "title" |> to_string) para_title) paras with
        | Some index -> Ok index
        | None -> Error "Paragraphe introuvable."
      in
      Ok (Printf.sprintf "CatT.%d.%d.%d.%s" part_index chapter_index para_index sentence)
  | "Hadiths", [ author; book; number ] -> Ok (Printf.sprintf "%s.%s.%s" (String.lowercase_ascii author) book number)
  | "Hadiths2", [ author; number ] -> Ok (Printf.sprintf "%s:%s" (String.lowercase_ascii author) number)
  | _ ->
      let* _ = selector_options ~root ~names ~bible_translation ~source ~path in
      Error "Sélection incomplète pour compiler une référence."

let parse_ref ~names text =
  match Bible_reference.parse ~names text with
  | Ok reference -> Ok (Bible reference)
  | Error _ ->
      if Str.string_match (Str.regexp "^Coran:\\([0-9]+\\)\\.\\([0-9]+\\)\\(-\\([0-9]+\\)\\)?$") text 0 then
        Ok (Quran (int_of_string (Str.matched_group 1 text), int_of_string (Str.matched_group 2 text), try Some (int_of_string (Str.matched_group 4 text)) with Not_found | Invalid_argument _ -> None))
      else if Str.string_match (Str.regexp "^Vatican \\([^ ]+\\) \\([^ ]+\\) \\([0-9]+\\)\\(-\\([0-9]+\\)\\)?$") text 0 then
        Ok (Vatican (Str.matched_group 1 text, Str.matched_group 2 text, int_of_string (Str.matched_group 3 text), try Some (int_of_string (Str.matched_group 5 text)) with Not_found | Invalid_argument _ -> None))
      else if Str.string_match (Str.regexp "^\\(Can1917\\|Can1990\\|Can\\|Cat\\|CatE\\)\\.\\([0-9]+\\)\\(-\\([0-9]+\\)\\)?$") text 0 then
        let kind =
          match Str.matched_group 1 text with
          | "Cat" -> "Catechisme"
          | "CatE" -> "CatechismeE"
          | kind -> kind
        in
        Ok (Simple (kind, int_of_string (Str.matched_group 2 text), try Some (int_of_string (Str.matched_group 4 text)) with Not_found | Invalid_argument _ -> None))
      else if Str.string_match (Str.regexp "^Rael\\.\\([0-9]+\\)\\.\\([0-9]+\\)\\.\\([0-9]+\\)\\(-\\([0-9]+\\)\\)?$") text 0 then
        Ok (Rael (int_of_string (Str.matched_group 1 text), int_of_string (Str.matched_group 2 text), int_of_string (Str.matched_group 3 text), try Some (int_of_string (Str.matched_group 5 text)) with Not_found | Invalid_argument _ -> None))
      else if Str.string_match (Str.regexp "^Cat\\.Comp\\.\\([0-9]+\\)\\(-\\([0-9]+\\)\\)?$") text 0 then
        Ok (Compendium (int_of_string (Str.matched_group 1 text), try Some (int_of_string (Str.matched_group 3 text)) with Not_found | Invalid_argument _ -> None))
      else if Str.string_match (Str.regexp "^Soc\\.\\([0-9]+\\)\\(-\\([0-9]+\\)\\)?$") text 0 then
        Ok (CompendiumSocial (int_of_string (Str.matched_group 1 text), try Some (int_of_string (Str.matched_group 3 text)) with Not_found | Invalid_argument _ -> None))
      else if Str.string_match (Str.regexp "^CatX\\.\\([0-9]+\\)\\.\\([0-9]+\\)\\.\\([0-9]+\\)\\(-\\([0-9]+\\)\\)?$") text 0 then
        Ok (CatechismeX (int_of_string (Str.matched_group 1 text), int_of_string (Str.matched_group 2 text), int_of_string (Str.matched_group 3 text), try Some (int_of_string (Str.matched_group 5 text)) with Not_found | Invalid_argument _ -> None))
      else if Str.string_match (Str.regexp "^CatT\\.\\([0-9]+\\)\\.\\([0-9]+\\)\\.\\([0-9]+\\)\\.\\([0-9]+\\)\\(-\\([0-9]+\\)\\)?$") text 0 then
        Ok (CatechismeTrente (int_of_string (Str.matched_group 1 text), int_of_string (Str.matched_group 2 text), int_of_string (Str.matched_group 3 text), int_of_string (Str.matched_group 4 text), try Some (int_of_string (Str.matched_group 6 text)) with Not_found | Invalid_argument _ -> None))
      else if Str.string_match (Str.regexp "^\\([a-z]+\\)\\.\\([0-9a-z]+\\)\\.\\([0-9]+\\)\\(-\\([0-9]+\\)\\)?$") (String.lowercase_ascii text) 0 then
        let lower = String.lowercase_ascii text in
        Ok (HadithBook (Str.matched_group 1 lower, Str.matched_group 2 lower, int_of_string (Str.matched_group 3 lower), try Some (int_of_string (Str.matched_group 5 lower)) with Not_found | Invalid_argument _ -> None))
      else if Str.string_match (Str.regexp "^\\([a-z]+\\):\\([0-9]+[a-z]?\\)$") (String.lowercase_ascii text) 0 then
        let lower = String.lowercase_ascii text in
        Ok (HadithNumber (Str.matched_group 1 lower, Str.matched_group 2 lower))
      else Error ("Référence non prise en charge: " ^ text)

let selector_path_of_reference ~root ~names ~bible_translation:_ ~reference =
  let* parsed = parse_ref ~names reference in
  match parsed with
  | Bible bible_ref ->
      Ok
        ( "Bible",
          [
            bible_ref.book;
            string_of_int bible_ref.chapter;
            string_of_int (Option.value bible_ref.verses.first_verse ~default:1);
          ] )
  | Quran (sura, verse, _) -> Ok ("Coran", [ string_of_int sura; string_of_int verse ])
  | Vatican (dossier, date, article, _) -> Ok ("Vatican", [ dossier; date; string_of_int article ])
  | Simple (kind, first, _) -> Ok (kind, [ string_of_int first ])
  | Rael (book_index, section_index, page, _) ->
      let* doc = load_rael ~root in
      let* book = find_nth (rael_books doc) book_index "Livre Rael introuvable." in
      let* section = find_nth (rael_sections book) section_index "Chapitre Rael introuvable." in
      Ok ("Rael", [ rael_book_title book; rael_section_title section; string_of_int page ])
  | Compendium (first, _) -> Ok ("Compendium", [ string_of_int first ])
  | CompendiumSocial (first, _) -> Ok ("CompendiumSocial", [ string_of_int first ])
  | CatechismeX (section_index, chapter_index, page, _) ->
      let* doc = load_catechisme_x ~root in
      let* section = find_nth (catechisme_x_sections doc) section_index "Partie introuvable." in
      let* chapter = find_nth (section |> member "chapters" |> to_list) chapter_index "Chapitre introuvable." in
      Ok ("CatechismeX", [ section |> member "title" |> to_string; chapter |> member "title" |> to_string; string_of_int page ])
  | CatechismeTrente (part_index, chapter_index, para_index, sentence, _) ->
      let* doc = load_catechisme_trente ~root in
      let* part = find_nth (catechisme_trente_parts doc) part_index "Partie introuvable." in
      let* chapter = find_nth (part |> member "chapters" |> to_list) chapter_index "Chapitre introuvable." in
      let* para = find_nth (chapter |> member "paras" |> to_list) para_index "Paragraphe introuvable." in
      Ok
        ( "CatechismeTrente",
          [
            part |> member "title" |> to_string;
            chapter |> member "title" |> to_string;
            para |> member "title" |> to_string;
            string_of_int sentence;
          ] )
  | HadithBook (author, book, first_number, _) -> Ok ("Hadiths", [ author; book; string_of_int first_number ])
  | HadithNumber (author, number) -> Ok ("Hadiths2", [ author; number ])

let render_simple ~root kind first last =
  let* cfg =
    match find_simple_config kind with
    | Some cfg -> Ok cfg
    | None -> Error ("Source simple inconnue: " ^ kind)
  in
  let* items = load_simple_array ~root cfg.file in
  let* from_index, to_index = range_to_bounds ~first ~last ~min_value:1 ~max_value:(List.length items) in
  let body =
    items
    |> List.mapi (fun index item -> (index + 1, item))
    |> List.filter (fun (index, _) -> index >= from_index && index <= to_index)
    |> List.map (fun (index, item) -> Printf.sprintf "%d. %s" index item)
    |> String.concat "\n"
  in
  let reference =
    if from_index = to_index then cfg.prefix ^ string_of_int from_index
    else Printf.sprintf "%s%d-%d" cfg.prefix from_index to_index
  in
  Ok { source_id = kind; reference; title = cfg.title; subtitle = None; body }

let render_hadith_item item =
  let narrator = item |> member "french_narator" |> to_string_option |> Option.value ~default:"" in
  let text = item |> member "french" |> to_string_option |> Option.value ~default:"" in
  let parts = List.filter (fun line -> String.trim line <> "") [ narrator; text ] in
  let _, hadith_number = match hadith_in_book item with Ok value -> value | Error _ -> ("", 0) in
  (hadith_number, String.concat "\n\n" parts)

let chapter_reference ~root ~names ~bible_translation ~reference =
  let* parsed = parse_ref ~names reference in
  match parsed with
  | Bible bible_ref ->
      let* bible = load_bible ~root ~names ~translation:bible_translation in
      let* _book_title, chapter = Bible_data.chapter bible bible_ref in
      let max_verse = Array.length chapter.verses in
      Ok (Some (Printf.sprintf "%s %d,1-%d" bible_ref.book bible_ref.chapter max_verse))
  | Quran (sura, _, _) ->
      let* quran = load_quran ~root in
      let* sourate = find_nth (quran_sourates quran) (sura - 1) "Sourate introuvable." in
      let verse_count = List.length (sourate |> member "versets" |> to_list) in
      Ok (Some (Printf.sprintf "Coran:%d.1-%d" sura verse_count))
  | Vatican (dossier, date, _, _) ->
      let* docs = load_vatican_dossier ~root dossier in
      let* doc =
        match List.find_opt (fun doc -> String.equal doc.date_key date) docs with
        | Some doc -> Ok doc
        | None -> Error "Document Vatican introuvable."
      in
      let first = if doc.has_intro then 0 else 1 in
      let last = first + List.length doc.text - 1 in
      Ok (Some (Printf.sprintf "Vatican %s %s %d-%d" dossier date first last))
  | Simple (kind, _, _) ->
      let* cfg =
        match find_simple_config kind with
        | Some cfg -> Ok cfg
        | None -> Error ("Source simple inconnue: " ^ kind)
      in
      let* items = load_simple_array ~root cfg.file in
      Ok (Some (Printf.sprintf "%s1-%d" cfg.prefix (List.length items)))
  | Rael (book_index, section_index, _, _) ->
      let* doc = load_rael ~root in
      let* book = find_nth (rael_books doc) book_index "Livre Rael introuvable." in
      let* section = find_nth (rael_sections book) section_index "Chapitre Rael introuvable." in
      let pages = rael_pages section in
      let* first_page =
        match pages with
        | page :: _ -> Ok (rael_page_number page)
        | [] -> Error "Section Rael vide."
      in
      let last_page = first_page + List.length pages - 1 in
      Ok (Some (Printf.sprintf "Rael.%d.%d.%d-%d" book_index section_index first_page last_page))
  | Compendium _ ->
      let* items = load_compendium ~root in
      Ok (Some (Printf.sprintf "Cat.Comp.1-%d" (List.length (compendium_items items))))
  | CompendiumSocial _ ->
      let* items = load_compendium_social ~root in
      Ok (Some (Printf.sprintf "Soc.1-%d" (List.length (compendium_social_items items))))
  | CatechismeX (section_index, chapter_index, _, _) ->
      let* doc = load_catechisme_x ~root in
      let* section = find_nth (catechisme_x_sections doc) section_index "Partie introuvable." in
      let* chapter = find_nth (section |> member "chapters" |> to_list) chapter_index "Chapitre introuvable." in
      let pages = chapter |> member "pages" |> to_list in
      let first_page = chapter |> member "page" |> to_int in
      let last_page = first_page + List.length pages - 1 in
      Ok (Some (Printf.sprintf "CatX.%d.%d.%d-%d" section_index chapter_index first_page last_page))
  | CatechismeTrente (part_index, chapter_index, para_index, _, _) ->
      let* doc = load_catechisme_trente ~root in
      let* part = find_nth (catechisme_trente_parts doc) part_index "Partie introuvable." in
      let* chapter = find_nth (part |> member "chapters" |> to_list) chapter_index "Chapitre introuvable." in
      let* para = find_nth (chapter |> member "paras" |> to_list) para_index "Paragraphe introuvable." in
      let sentence_count = List.length (para |> member "text" |> to_list |> filter_string) in
      Ok (Some (Printf.sprintf "CatT.%d.%d.%d.1-%d" part_index chapter_index para_index sentence_count))
  | HadithBook _ | HadithNumber _ -> Ok None

let render_reference ~root ~names ~bible_translation ~reference =
  let* parsed = parse_ref ~names reference in
  match parsed with
  | Bible bible_ref ->
      let* bible = load_bible ~root ~names ~translation:bible_translation in
      let* title, verses = Bible_data.lookup bible bible_ref in
      let body =
        verses
        |> List.map (fun (verse : Bible_data.verse) -> Printf.sprintf "%d. %s" verse.number verse.text)
        |> String.concat "\n"
      in
      Ok { source_id = "Bible"; reference = Bible_reference.format bible_ref; title; subtitle = Some bible_translation; body }
  | Quran (sura, first, last) ->
      let* quran = load_quran ~root in
      let* sourate = find_nth (quran_sourates quran) (sura - 1) "Sourate introuvable." in
      let verses = sourate |> member "versets" |> to_list in
      let* from_verse, to_verse = range_to_bounds ~first ~last ~min_value:1 ~max_value:(List.length verses) in
      let body =
        verses
        |> List.filter_map (fun verse ->
               let number = verse |> member "position_ds_sourate" |> to_int in
               if number < from_verse || number > to_verse then None
               else Some (Printf.sprintf "%d. %s" number (verse |> member "text" |> to_string)))
        |> String.concat "\n"
      in
      let title = Printf.sprintf "%d %s" (sourate |> member "position" |> to_int) (sourate |> member "nom_sourate" |> to_string) in
      Ok { source_id = "Coran"; reference; title; subtitle = Some (sourate |> member "nom_phonetique" |> to_string); body }
  | Vatican (dossier, date, first, last) ->
      let* docs = load_vatican_dossier ~root dossier in
      let* doc =
        match List.find_opt (fun doc -> String.equal doc.date_key date) docs with
        | Some doc -> Ok doc
        | None -> Error "Document Vatican introuvable."
      in
      let start_index = if doc.has_intro then first else first - 1 in
      let end_index = if doc.has_intro then Option.value last ~default:first else Option.value last ~default:first - 1 in
      let* from_index, to_index = range_to_bounds ~first:start_index ~last:(Some end_index) ~min_value:0 ~max_value:(List.length doc.text - 1) in
      let body =
        doc.text |> List.mapi (fun index paragraph -> (index, paragraph))
        |> List.filter (fun (index, _) -> index >= from_index && index <= to_index)
        |> List.map snd |> String.concat "\n\n"
      in
      Ok { source_id = "Vatican"; reference; title = doc.title; subtitle = Some dossier; body }
  | Simple (kind, first, last) -> render_simple ~root kind first last
  | Rael (book_index, section_index, first_page, last_page) ->
      let* doc = load_rael ~root in
      let* book = find_nth (rael_books doc) book_index "Livre Rael introuvable." in
      let* section = find_nth (rael_sections book) section_index "Chapitre Rael introuvable." in
      let pages = rael_pages section in
      let* minimum_page =
        match pages with
        | page :: _ -> Ok (rael_page_number page)
        | [] -> Error "Section Rael vide."
      in
      let maximum_page = minimum_page + List.length pages - 1 in
      let* from_page, to_page = range_to_bounds ~first:first_page ~last:last_page ~min_value:minimum_page ~max_value:maximum_page in
      let body =
        pages
        |> List.filter_map (fun page ->
               let number = rael_page_number page in
               if number < from_page || number > to_page then None
               else Some (Printf.sprintf "%d. %s" number (rael_page_text page)))
        |> String.concat "\n\n"
      in
      let reference =
        if from_page = to_page then Printf.sprintf "Rael.%d.%d.%d" book_index section_index from_page
        else Printf.sprintf "Rael.%d.%d.%d-%d" book_index section_index from_page to_page
      in
      Ok
        {
          source_id = "Rael";
          reference;
          title = rael_book_title book;
          subtitle = Some (rael_section_title section);
          body;
        }
  | Compendium (first, last) ->
      let* items = load_compendium ~root in
      let items = compendium_items items in
      let* from_index, to_index = range_to_bounds ~first ~last ~min_value:1 ~max_value:(List.length items) in
      let body =
        items
        |> List.mapi (fun index item -> (index + 1, item))
        |> List.filter (fun (index, _) -> index >= from_index && index <= to_index)
        |> List.map (fun (index, item) -> render_compendium_item index item)
        |> String.concat "\n\n"
      in
      let reference =
        if from_index = to_index then Printf.sprintf "Cat.Comp.%d" from_index
        else Printf.sprintf "Cat.Comp.%d-%d" from_index to_index
      in
      Ok
        {
          source_id = "Compendium";
          reference;
          title = "Compendium du Catéchisme de l'Eglise catholique";
          subtitle = None;
          body;
        }
  | CompendiumSocial (first, last) ->
      let* items = load_compendium_social ~root in
      let items = compendium_social_items items in
      let* from_index, to_index = range_to_bounds ~first ~last ~min_value:1 ~max_value:(List.length items) in
      let body =
        items
        |> List.mapi (fun index item -> (index + 1, item))
        |> List.filter (fun (index, _) -> index >= from_index && index <= to_index)
        |> List.map (fun (index, item) -> render_compendium_social_item index item)
        |> String.concat "\n\n"
      in
      let reference =
        if from_index = to_index then Printf.sprintf "Soc.%d" from_index
        else Printf.sprintf "Soc.%d-%d" from_index to_index
      in
      Ok
        {
          source_id = "CompendiumSocial";
          reference;
          title = "Compendium de la doctrine sociale de l'Eglise";
          subtitle = None;
          body;
        }
  | CatechismeX (section_index, chapter_index, first_page, last_page) ->
      let* doc = load_catechisme_x ~root in
      let* section = find_nth (catechisme_x_sections doc) section_index "Partie introuvable." in
      let* chapter = find_nth (section |> member "chapters" |> to_list) chapter_index "Chapitre introuvable." in
      let pages = chapter |> member "pages" |> to_list in
      let first_offset = chapter |> member "page" |> to_int in
      let max_page = first_offset + List.length pages - 1 in
      let* from_page, to_page = range_to_bounds ~first:first_page ~last:last_page ~min_value:first_offset ~max_value:max_page in
      let body =
        pages
        |> List.filter_map (fun page ->
               let page_number = page |> member "page" |> to_int in
               if page_number < from_page || page_number > to_page then None
               else Some (Printf.sprintf "%d. %s" page_number (String.concat " " (page |> member "text" |> to_list |> filter_string))))
        |> String.concat "\n"
      in
      let reference =
        if from_page = to_page then Printf.sprintf "CatX.%d.%d.%d" section_index chapter_index from_page
        else Printf.sprintf "CatX.%d.%d.%d-%d" section_index chapter_index from_page to_page
      in
      Ok
        {
          source_id = "CatechismeX";
          reference;
          title = section |> member "title" |> to_string;
          subtitle = Some (chapter |> member "title" |> to_string);
          body;
        }
  | CatechismeTrente (part_index, chapter_index, para_index, first_sentence, last_sentence) ->
      let* doc = load_catechisme_trente ~root in
      let* part = find_nth (catechisme_trente_parts doc) part_index "Partie introuvable." in
      let* chapter = find_nth (part |> member "chapters" |> to_list) chapter_index "Chapitre introuvable." in
      let* para = find_nth (chapter |> member "paras" |> to_list) para_index "Paragraphe introuvable." in
      let sentences = para |> member "text" |> to_list |> filter_string in
      let* from_sentence, to_sentence = range_to_bounds ~first:first_sentence ~last:last_sentence ~min_value:1 ~max_value:(List.length sentences) in
      let body =
        sentences
        |> List.mapi (fun index sentence -> (index + 1, sentence))
        |> List.filter (fun (index, _) -> index >= from_sentence && index <= to_sentence)
        |> List.map (fun (index, sentence) -> Printf.sprintf "%d. %s" index sentence)
        |> String.concat "\n"
      in
      let reference =
        if from_sentence = to_sentence then Printf.sprintf "CatT.%d.%d.%d.%d" part_index chapter_index para_index from_sentence
        else Printf.sprintf "CatT.%d.%d.%d.%d-%d" part_index chapter_index para_index from_sentence to_sentence
      in
      Ok
        {
          source_id = "CatechismeTrente";
          reference;
          title = part |> member "title" |> to_string;
          subtitle = Some ((chapter |> member "title" |> to_string) ^ " / " ^ (para |> member "title" |> to_string));
          body;
        }
  | HadithBook (author, book, first_number, last_number) ->
      let* items = load_hadith_file ~root author in
      let selected =
        items
        |> List.filter_map (fun item ->
               match hadith_in_book item with
               | Ok (item_book, number) when String.equal item_book book -> Some (number, item)
               | _ -> None)
        |> List.sort (fun (left, _) (right, _) -> Int.compare left right)
      in
      let max_number = match List.rev selected with (number, _) :: _ -> number | [] -> 0 in
      let* from_number, to_number = range_to_bounds ~first:first_number ~last:last_number ~min_value:1 ~max_value:max_number in
      let body =
        selected
        |> List.filter (fun (number, _) -> number >= from_number && number <= to_number)
        |> List.map (fun (_, item) ->
               let item_number, text = render_hadith_item item in
               Printf.sprintf "%d. %s" item_number text)
        |> String.concat "\n\n"
      in
      let reference =
        if from_number = to_number then Printf.sprintf "%s.%s.%d" author book from_number
        else Printf.sprintf "%s.%s.%d-%d" author book from_number to_number
      in
      Ok { source_id = "Hadiths"; reference; title = author; subtitle = Some ("livre " ^ book); body }
  | HadithNumber (author, number) ->
      let* items = load_hadith_file ~root author in
      let* item =
        match List.find_opt (fun item -> String.equal (item |> member "number" |> json_stringish) number) items with
        | Some item -> Ok item
        | None -> Error "Hadith introuvable."
      in
      let* book, _ = hadith_in_book item in
      let _, text = render_hadith_item item in
      Ok { source_id = "Hadiths2"; reference; title = author ^ ":" ^ number; subtitle = Some ("livre " ^ book); body = text }

let navigation ~root ~names ~bible_translation ~reference =
  let* parsed = parse_ref ~names reference in
  match parsed with
  | Bible bible_ref ->
      let* bible = load_bible ~root ~names ~translation:bible_translation in
      let* nav = Bible_data.navigation bible bible_ref in
      Ok { has_previous = nav.has_previous; has_next = nav.has_next }
  | Quran (sura, first, _) ->
      let* quran = load_quran ~root in
      let* sourate = find_nth (quran_sourates quran) (sura - 1) "Sourate introuvable." in
      let verses = sourate |> member "versets" |> to_list in
      Ok { has_previous = first > 1; has_next = first < List.length verses }
  | Vatican (dossier, date, first, _) ->
      let* docs = load_vatican_dossier ~root dossier in
      let* doc =
        match List.find_opt (fun doc -> String.equal doc.date_key date) docs with
        | Some doc -> Ok doc
        | None -> Error "Document Vatican introuvable."
      in
      let minimum = if doc.has_intro then 0 else 1 in
      let maximum = if doc.has_intro then List.length doc.text - 1 else List.length doc.text in
      Ok { has_previous = first > minimum; has_next = first < maximum }
  | Simple (kind, first, _) ->
      let* cfg =
        match find_simple_config kind with
        | Some cfg -> Ok cfg
        | None -> Error ("Source simple inconnue: " ^ kind)
      in
      let* items = load_simple_array ~root cfg.file in
      Ok { has_previous = first > 1; has_next = first < List.length items }
  | Rael (book_index, section_index, page, _) ->
      let* doc = load_rael ~root in
      let* book = find_nth (rael_books doc) book_index "Livre Rael introuvable." in
      let* section = find_nth (rael_sections book) section_index "Chapitre Rael introuvable." in
      let pages = rael_pages section in
      let* first_page =
        match pages with
        | item :: _ -> Ok (rael_page_number item)
        | [] -> Error "Section Rael vide."
      in
      let last_page = first_page + List.length pages - 1 in
      Ok { has_previous = page > first_page; has_next = page < last_page }
  | Compendium (first, _) ->
      let* items = load_compendium ~root in
      Ok { has_previous = first > 1; has_next = first < List.length (compendium_items items) }
  | CompendiumSocial (first, _) ->
      let* items = load_compendium_social ~root in
      Ok { has_previous = first > 1; has_next = first < List.length (compendium_social_items items) }
  | CatechismeX (section_index, chapter_index, page, _) ->
      let* doc = load_catechisme_x ~root in
      let* section = find_nth (catechisme_x_sections doc) section_index "Partie introuvable." in
      let* chapter = find_nth (section |> member "chapters" |> to_list) chapter_index "Chapitre introuvable." in
      let pages = chapter |> member "pages" |> to_list in
      let first_page = chapter |> member "page" |> to_int in
      let last_page = first_page + List.length pages - 1 in
      Ok { has_previous = page > first_page; has_next = page < last_page }
  | CatechismeTrente (part_index, chapter_index, para_index, sentence, _) ->
      let* doc = load_catechisme_trente ~root in
      let* part = find_nth (catechisme_trente_parts doc) part_index "Partie introuvable." in
      let* chapter = find_nth (part |> member "chapters" |> to_list) chapter_index "Chapitre introuvable." in
      let* para = find_nth (chapter |> member "paras" |> to_list) para_index "Paragraphe introuvable." in
      let sentences = para |> member "text" |> to_list |> filter_string in
      Ok { has_previous = sentence > 1; has_next = sentence < List.length sentences }
  | HadithBook _ | HadithNumber _ -> Ok { has_previous = false; has_next = false }

let navigate ~root ~names ~bible_translation ~reference direction =
  let* parsed = parse_ref ~names reference in
  match parsed with
  | Bible bible_ref ->
      let* bible = load_bible ~root ~names ~translation:bible_translation in
      let* next_ref =
        Bible_data.navigate bible bible_ref
          (match direction with Previous -> Bible_data.Previous | Next -> Bible_data.Next)
      in
      Ok (Bible_reference.format next_ref)
  | Quran (sura, first, _) ->
      Ok (Printf.sprintf "Coran:%d.%d" sura (match direction with Previous -> first - 1 | Next -> first + 1))
  | Vatican (dossier, date, first, _) ->
      Ok (Printf.sprintf "Vatican %s %s %d" dossier date (match direction with Previous -> first - 1 | Next -> first + 1))
  | Simple (kind, first, _) ->
      let* cfg =
        match find_simple_config kind with
        | Some cfg -> Ok cfg
        | None -> Error ("Source simple inconnue: " ^ kind)
      in
      Ok (cfg.prefix ^ string_of_int (match direction with Previous -> first - 1 | Next -> first + 1))
  | Rael (book_index, section_index, page, _) ->
      Ok (Printf.sprintf "Rael.%d.%d.%d" book_index section_index (match direction with Previous -> page - 1 | Next -> page + 1))
  | Compendium (first, _) ->
      Ok (Printf.sprintf "Cat.Comp.%d" (match direction with Previous -> first - 1 | Next -> first + 1))
  | CompendiumSocial (first, _) ->
      Ok (Printf.sprintf "Soc.%d" (match direction with Previous -> first - 1 | Next -> first + 1))
  | CatechismeX (section_index, chapter_index, page, _) ->
      Ok (Printf.sprintf "CatX.%d.%d.%d" section_index chapter_index (match direction with Previous -> page - 1 | Next -> page + 1))
  | CatechismeTrente (part_index, chapter_index, para_index, sentence, _) ->
      Ok (Printf.sprintf "CatT.%d.%d.%d.%d" part_index chapter_index para_index (match direction with Previous -> sentence - 1 | Next -> sentence + 1))
  | HadithBook _ | HadithNumber _ -> Error "Navigation impossible."

let html_unescape text =
  let text = Str.global_replace (Str.regexp "&amp;") "&" text in
  let text = Str.global_replace (Str.regexp "&lt;") "<" text in
  let text = Str.global_replace (Str.regexp "&gt;") ">" text in
  let text = Str.global_replace (Str.regexp "&quot;") "\"" text in
  let text = Str.global_replace (Str.regexp "&#39;\\|&apos;") "'" text in
  let replace_numeric regexp base text =
    let rec loop acc start =
      try
        let _ = Str.search_forward regexp text start in
        let digits = Str.matched_group 1 text in
        let value = int_of_string (base ^ digits) in
        let before = String.sub text start (Str.match_beginning () - start) in
        let chr = String.make 1 (Char.chr value) in
        loop (acc ^ before ^ chr) (Str.match_end ())
      with Not_found -> acc ^ String.sub text start (String.length text - start)
    in
    loop "" 0
  in
  text |> replace_numeric (Str.regexp "&#\\([0-9]+\\);") "" |> replace_numeric (Str.regexp "&#x\\([0-9A-Fa-f]+\\);") "0x"

let url_decode text =
  let buffer = Buffer.create (String.length text) in
  let rec loop index =
    if index >= String.length text then ()
    else
      match text.[index] with
      | '+' ->
          Buffer.add_char buffer ' ';
          loop (index + 1)
      | '%' when index + 2 < String.length text -> (
          let hex = String.sub text (index + 1) 2 in
          match int_of_string_opt ("0x" ^ hex) with
          | Some value ->
              Buffer.add_char buffer (Char.chr value);
              loop (index + 3)
          | None ->
              Buffer.add_char buffer '%';
              loop (index + 1))
      | chr ->
          Buffer.add_char buffer chr;
          loop (index + 1)
  in
  loop 0;
  Buffer.contents buffer

let normalize_spaces text =
  text |> String.trim |> Str.global_replace (Str.regexp "[ \n\r\t]+") " "

let rec decode_until_stable text =
  let decoded = text |> html_unescape |> url_decode in
  if String.equal decoded text then decoded else decode_until_stable decoded

let decode_site_reference_url url =
  let decoded_url = decode_until_stable url in
  match String.index_opt decoded_url '?' with
  | None -> None
  | Some index ->
      let query = String.sub decoded_url (index + 1) (String.length decoded_url - index - 1) |> decode_until_stable |> normalize_spaces in
      if String.equal query "" then None
      else if Str.string_match (Str.regexp "^[A-Za-z][A-Za-z0-9]*\\..*$") query 0 then Some query
      else if Str.string_match (Str.regexp "^Vatican .*$") query 0 then Some query
      else if Str.string_match (Str.regexp "^[a-z]+:[0-9A-Za-z.:-]+$") (String.lowercase_ascii query) 0 then Some query
      else if Str.string_match (Str.regexp "^\\(.*\\)-\\([0-9IVXLCDM]+\\):\\(.*\\)$") query 0 then
        let book = Str.matched_group 1 query in
        let chapter = Str.matched_group 2 query in
        let verse = Str.matched_group 3 query in
        Some (normalize_spaces (Printf.sprintf "%s %s,%s" book chapter verse))
      else if Str.string_match (Str.regexp "^\\(.*\\)-\\([0-9IVXLCDM]+\\)$") query 0 then
        let book = Str.matched_group 1 query in
        let chapter = Str.matched_group 2 query in
        Some (normalize_spaces (Printf.sprintf "%s %s" book chapter))
      else Some query
