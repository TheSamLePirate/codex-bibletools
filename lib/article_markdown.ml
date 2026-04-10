let escape_markup text =
  text |> String.split_on_char '&' |> String.concat "&amp;" |> String.split_on_char '<' |> String.concat "&lt;" |> String.split_on_char '>' |> String.concat "&gt;"

let escape_attribute text =
  text |> escape_markup |> String.split_on_char '"' |> String.concat "&quot;" |> String.split_on_char '\'' |> String.concat "&apos;"

let sanitize_text text =
  let buffer = Buffer.create (String.length text) in
  let rec loop index =
    if index >= String.length text then ()
    else
      let byte = Char.code text.[index] in
      if byte < 32 then (
        if text.[index] = '\n' || text.[index] = '\r' || text.[index] = '\t' then Buffer.add_char buffer text.[index];
        loop (index + 1))
      else if index + 1 < String.length text && byte = 0xC2 && Char.code text.[index + 1] = 0xA0 then (
        Buffer.add_char buffer ' ';
        loop (index + 2))
      else if index + 1 < String.length text && byte = 0xC2 && Char.code text.[index + 1] = 0xAD then (
        loop (index + 2))
      else if index + 2 < String.length text && byte = 0xE2 && Char.code text.[index + 1] = 0x80
              && List.mem (Char.code text.[index + 2]) [ 0x8B; 0xA8; 0xA9 ] then
        loop (index + 3)
      else if index + 2 < String.length text && byte = 0xE2 && Char.code text.[index + 1] = 0x81
              && Char.code text.[index + 2] = 0xA0 then
        loop (index + 3)
      else if index + 2 < String.length text && byte = 0xEF && Char.code text.[index + 1] = 0xBB
              && Char.code text.[index + 2] = 0xBF then
        loop (index + 3)
      else (
        Buffer.add_char buffer text.[index];
        loop (index + 1))
  in
  loop 0;
  Buffer.contents buffer

let apply_highlights highlights text =
  List.fold_left
    (fun acc pattern ->
      let pattern = String.trim pattern in
      if pattern = "" then acc
      else
        try
          let regexp = Str.regexp pattern in
          let buffer = Buffer.create (String.length acc + 32) in
          let rec loop start =
            try
              let _ = Str.search_forward regexp acc start in
              let match_start = Str.match_beginning () in
              let match_end = Str.match_end () in
              let matched = Str.matched_string acc in
              Buffer.add_substring buffer acc start (match_start - start);
              Buffer.add_string buffer ("**" ^ matched ^ "**");
              loop match_end
            with Not_found ->
              Buffer.add_substring buffer acc start (String.length acc - start)
          in
          loop 0;
          Buffer.contents buffer
        with Failure _ | Invalid_argument _ -> acc)
    text highlights

let rec replace_bold text =
  try
    let start_index = String.index text '*' in
    if start_index + 1 >= String.length text || text.[start_index + 1] <> '*' then text
    else
      let search_from = start_index + 2 in
      let rec find_end index =
        if index + 1 >= String.length text then None
        else if text.[index] = '*' && text.[index + 1] = '*' then Some index
        else find_end (index + 1)
      in
      match find_end search_from with
      | None -> text
      | Some end_index ->
          let before = String.sub text 0 start_index in
          let content = String.sub text (start_index + 2) (end_index - start_index - 2) in
          let after = String.sub text (end_index + 2) (String.length text - end_index - 2) in
          replace_bold (before ^ "<b>" ^ escape_markup content ^ "</b>" ^ after)
  with Not_found -> text

let render_inline ~highlights ~resolve_internal text =
  let regexp = Str.regexp "\\[\\([^]]+\\)\\](\\([^)]*\\))" in
  let rec loop start acc =
    try
      let _ = Str.search_forward regexp text start in
      let match_begin = Str.match_beginning () in
      let match_end = Str.match_end () in
      let before = String.sub text start (match_begin - start) in
      let label = Str.matched_group 1 text in
      let url = Str.matched_group 2 text in
      let href =
        match resolve_internal url with
        | Some reference -> "ref:" ^ escape_attribute reference
        | None -> escape_attribute url
      in
      let link = Printf.sprintf "<a href=\"%s\">%s</a>" href (escape_markup label) in
      loop match_end (acc ^ replace_bold (escape_markup (apply_highlights highlights before)) ^ link)
    with Not_found ->
      acc ^ replace_bold (escape_markup (apply_highlights highlights (String.sub text start (String.length text - start))))
  in
  loop 0 ""

let render_line ~highlights ~resolve_internal line =
  if Str.string_match (Str.regexp "^# \\(.*\\)$") line 0 then
    let title = Str.matched_group 1 line in
    Printf.sprintf "<span size=\"x-large\" weight=\"bold\">%s</span>" (render_inline ~highlights ~resolve_internal title)
  else if Str.string_match (Str.regexp "^## \\(.*\\)$") line 0 then
    let title = Str.matched_group 1 line in
    Printf.sprintf "<span size=\"large\" weight=\"bold\">%s</span>" (render_inline ~highlights ~resolve_internal title)
  else if Str.string_match (Str.regexp "^\\* \\(.*\\)$") line 0 then
    let item = Str.matched_group 1 line in
    "• " ^ render_inline ~highlights ~resolve_internal item
  else render_inline ~highlights ~resolve_internal line

let render_plain_line ~highlights line =
  line |> sanitize_text |> apply_highlights highlights |> escape_markup |> replace_bold

let render_to_pango_markup ?(highlights = []) ~resolve_internal markdown =
  markdown |> sanitize_text |> String.split_on_char '\n' |> List.map (render_line ~highlights ~resolve_internal) |> String.concat "\n"

let render_plain_to_pango_markup ?(highlights = []) text =
  text |> sanitize_text |> String.split_on_char '\n' |> List.map (render_plain_line ~highlights) |> String.concat "\n"

let normalize_bible_reference text =
  List.fold_left
    (fun acc (fullname, name) -> Str.global_replace (Str.regexp_case_fold fullname) name acc)
    text BibleTools.inverse_aliases

let int_of_roman_or_decimal text =
  let text = String.trim text in
  match int_of_string_opt text with Some value -> value | None -> BibleTools.rm2num text

let source_link_rules =
  let make_fixed pattern build =
    (Str.regexp_case_fold pattern, build)
  in
  let roman = "[IVXLCDM0-9]+" in
  let books = Str.global_replace (Str.regexp_string "|") "\\|" BibleTools.bible_books_pattern in
  [
    make_fixed "UR \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1964/11/21-2 " ^ Str.matched_group 1 text));
    make_fixed "SC \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1963/12/4-1 " ^ Str.matched_group 1 text));
    make_fixed "PO \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1967/12/7 " ^ Str.matched_group 1 text));
    make_fixed "NA \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1965/10/28-2 " ^ Str.matched_group 1 text));
    make_fixed "LG \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1964/11/21 " ^ Str.matched_group 1 text));
    make_fixed "GS \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1965/12/7-3 " ^ Str.matched_group 1 text));
    make_fixed "GE \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1965/10/28-1 " ^ Str.matched_group 1 text));
    make_fixed "DV \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1965/11/18-1 " ^ Str.matched_group 1 text));
    make_fixed "DH \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1965/12/7-2 " ^ Str.matched_group 1 text));
    make_fixed "CD \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1965/10/28 " ^ Str.matched_group 1 text));
    make_fixed "AG \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1965/12/7 " ^ Str.matched_group 1 text));
    make_fixed "AA \\([0-9]+\\)" (fun text _ -> Some ("Vatican concil_ii_vatican_council 1965/11/18 " ^ Str.matched_group 1 text));
    make_fixed "CEC,?[ \t]*n+\\.[ \t]*\\([0-9]+\\)-\\([0-9]+\\)" (fun text _ -> Some (Printf.sprintf "Cat.%s-%s" (Str.matched_group 1 text) (Str.matched_group 2 text)));
    make_fixed "CEC,?[ \t]*n+\\.[ \t]*\\([0-9]+\\)" (fun text _ -> Some ("Cat." ^ Str.matched_group 1 text));
    make_fixed "CEC,?[ \t]*\\([0-9]+\\)-\\([0-9]+\\)" (fun text _ -> Some (Printf.sprintf "Cat.%s-%s" (Str.matched_group 1 text) (Str.matched_group 2 text)));
    make_fixed "CEC,?[ \t]*\\([0-9]+\\)" (fun text _ -> Some ("Cat." ^ Str.matched_group 1 text));
    make_fixed "Catéchisme[ \t]de[ \t]l[’'][ÉE]glise[ \t]catholique,[ \t]n\\.[ \t]*\\([0-9]+\\)" (fun text _ -> Some ("Cat." ^ Str.matched_group 1 text));
    make_fixed (Printf.sprintf "\\(Sourate\\|Coran\\)[ \t]*\\(%s\\),[ \t]*\\(%s\\)-\\(%s\\)" roman roman roman)
      (fun text _ ->
        Some
          (Printf.sprintf "Coran:%d.%d-%d" (int_of_roman_or_decimal (Str.matched_group 2 text))
             (int_of_roman_or_decimal (Str.matched_group 3 text)) (int_of_roman_or_decimal (Str.matched_group 4 text))));
    make_fixed (Printf.sprintf "\\(Sourate\\|Coran\\)[ \t]*\\(%s\\),[ \t]*\\(%s\\)" roman roman)
      (fun text _ ->
        Some
          (Printf.sprintf "Coran:%d.%d" (int_of_roman_or_decimal (Str.matched_group 2 text))
             (int_of_roman_or_decimal (Str.matched_group 3 text))));
    make_fixed (Printf.sprintf "\\(%s\\)\\.?[ \t]*\\(%s\\),[ \t]*\\(%s\\)-\\(%s\\)" books roman roman roman)
      (fun text _ ->
        Some
          (normalize_bible_reference
             (Printf.sprintf "%s %d,%d-%d" (Str.matched_group 1 text) (int_of_roman_or_decimal (Str.matched_group 2 text))
                (int_of_roman_or_decimal (Str.matched_group 3 text)) (int_of_roman_or_decimal (Str.matched_group 4 text)))));
    make_fixed (Printf.sprintf "\\(%s\\)\\.?[ \t]*\\(%s\\),[ \t]*\\(%s\\)" books roman roman)
      (fun text _ ->
        Some
          (normalize_bible_reference
             (Printf.sprintf "%s %d,%d" (Str.matched_group 1 text) (int_of_roman_or_decimal (Str.matched_group 2 text))
                (int_of_roman_or_decimal (Str.matched_group 3 text)))));
    make_fixed (Printf.sprintf "\\(%s\\),?[ \t]*\\(%s\\)-\\(%s\\)" books roman roman)
      (fun text _ ->
        Some
          (normalize_bible_reference
             (Printf.sprintf "%s %d,%d" (Str.matched_group 1 text) (int_of_roman_or_decimal (Str.matched_group 2 text))
                (int_of_roman_or_decimal (Str.matched_group 3 text)))));
    make_fixed "can\\.[ \t]*\\([0-9]+\\)" (fun text _ -> Some ("Can." ^ Str.matched_group 1 text));
    make_fixed "Denzinger-S\\.,[ \t]*\\([0-9]+\\)" (fun text _ -> Some ("DH." ^ Str.matched_group 1 text));
    make_fixed "Denzinger[ \t]*n[ \t]*\\([0-9]+\\)" (fun text _ -> Some ("DH." ^ Str.matched_group 1 text));
    make_fixed "Denzinger[ \t]*\\([0-9]+\\)-\\([0-9]+\\)" (fun text _ -> Some (Printf.sprintf "DH.%s-%s" (Str.matched_group 1 text) (Str.matched_group 2 text)));
    make_fixed "Denzinger[ \t]*\\([0-9]+\\)" (fun text _ -> Some ("DH." ^ Str.matched_group 1 text));
  ]

let parse_reference_notes references =
  references
  |> sanitize_text
  |> String.split_on_char '\n'
  |> List.map String.trim
  |> List.filter (fun line -> line <> "")
  |> List.filter_map (fun line ->
         if Str.string_match (Str.regexp "^\\[\\([0-9]+\\)\\]\\s*\\(.*\\)$") line 0 then
           Some (Str.matched_group 1 line, Str.matched_group 2 line)
         else None)

let used_note_indexes text =
  let text = sanitize_text text in
  let regexp = Str.regexp "\\[\\([0-9]+\\)\\]" in
  let rec loop start acc =
    try
      let _ = Str.search_forward regexp text start in
      loop (Str.match_end ()) (Str.matched_group 1 text :: acc)
    with Not_found -> List.rev acc
  in
  loop 0 [] |> List.sort_uniq String.compare

let render_source_inline ~highlights text =
  let text = sanitize_text text in
  let render_plain_segment segment = segment |> apply_highlights highlights |> escape_markup |> replace_bold in
  let rec apply_rules segment rules =
    match rules with
    | [] ->
        let note_re = Str.regexp "\\[[0-9]+\\]" in
        let rec loop start acc =
          try
            let _ = Str.search_forward note_re segment start in
            let match_begin = Str.match_beginning () in
            let match_end = Str.match_end () in
            let before = String.sub segment start (match_begin - start) in
            let note = Str.matched_string segment in
            loop match_end (acc ^ render_plain_segment before ^ "<b>" ^ escape_markup note ^ "</b>")
          with Not_found ->
            acc ^ render_plain_segment (String.sub segment start (String.length segment - start))
        in
        loop 0 ""
    | (regexp, build) :: rest ->
        let rec loop start acc =
          try
            let _ = Str.search_forward regexp segment start in
            let match_begin = Str.match_beginning () in
            let match_end = Str.match_end () in
            let matched = Str.matched_string segment in
            let href = build segment matched in
            let before = String.sub segment start (match_begin - start) in
            let rendered_before = apply_rules before rest in
            let rendered_match =
              match href with
              | Some reference -> Printf.sprintf "<a href=\"ref:%s\">%s</a>" (escape_attribute reference) (escape_markup matched)
              | None -> render_plain_segment matched
            in
            loop match_end (acc ^ rendered_before ^ rendered_match)
          with Not_found ->
            acc ^ apply_rules (String.sub segment start (String.length segment - start)) rest
        in
        loop 0 ""
  in
  apply_rules text source_link_rules

let render_source_to_pango_markup ?(highlights = []) ?references text =
  let text = sanitize_text text in
  let body_markup =
    text |> String.split_on_char '\n' |> List.map (render_source_inline ~highlights) |> String.concat "\n"
  in
  match references with
  | None -> body_markup
  | Some references ->
      let used = used_note_indexes text in
      let notes = parse_reference_notes references |> List.filter (fun (index, _) -> List.mem index used) in
      if notes = [] then body_markup
      else
        let notes_markup =
          notes
          |> List.map (fun (index, note) ->
                 Printf.sprintf "<span weight=\"bold\">[%s]</span> %s" (escape_markup index) (render_source_inline ~highlights note))
          |> String.concat "\n"
        in
        body_markup ^ "\n\n<span weight=\"bold\" size=\"large\">Notes</span>\n" ^ notes_markup
