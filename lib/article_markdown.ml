let escape_markup text =
  text |> String.split_on_char '&' |> String.concat "&amp;" |> String.split_on_char '<' |> String.concat "&lt;" |> String.split_on_char '>' |> String.concat "&gt;"

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
        | Some reference -> "ref:" ^ escape_markup reference
        | None -> escape_markup url
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
  line |> apply_highlights highlights |> escape_markup |> replace_bold

let render_to_pango_markup ?(highlights = []) ~resolve_internal markdown =
  markdown |> String.split_on_char '\n' |> List.map (render_line ~highlights ~resolve_internal) |> String.concat "\n"

let render_plain_to_pango_markup ?(highlights = []) text =
  text |> String.split_on_char '\n' |> List.map (render_plain_line ~highlights) |> String.concat "\n"
