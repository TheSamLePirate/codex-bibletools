let escape_markup text =
  text |> String.split_on_char '&' |> String.concat "&amp;" |> String.split_on_char '<' |> String.concat "&lt;" |> String.split_on_char '>' |> String.concat "&gt;"

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

let render_inline ~resolve_internal text =
  let regexp = Str.regexp "\\[\\([^]]+\\)\\](\\([^)]*\\))" in
  let rec loop start acc =
    try
      let _ = Str.search_forward regexp text start in
      let before = String.sub text start (Str.match_beginning () - start) in
      let label = Str.matched_group 1 text in
      let url = Str.matched_group 2 text in
      let href =
        match resolve_internal url with
        | Some reference -> "ref:" ^ escape_markup reference
        | None -> escape_markup url
      in
      let link = Printf.sprintf "<a href=\"%s\">%s</a>" href (escape_markup label) in
      loop (Str.match_end ()) (acc ^ replace_bold (escape_markup before) ^ link)
    with Not_found -> acc ^ replace_bold (escape_markup (String.sub text start (String.length text - start)))
  in
  loop 0 ""

let render_line ~resolve_internal line =
  if Str.string_match (Str.regexp "^# \\(.*\\)$") line 0 then
    Printf.sprintf "<span size=\"x-large\" weight=\"bold\">%s</span>" (render_inline ~resolve_internal (Str.matched_group 1 line))
  else if Str.string_match (Str.regexp "^## \\(.*\\)$") line 0 then
    Printf.sprintf "<span size=\"large\" weight=\"bold\">%s</span>" (render_inline ~resolve_internal (Str.matched_group 1 line))
  else if Str.string_match (Str.regexp "^\\* \\(.*\\)$") line 0 then
    "• " ^ render_inline ~resolve_internal (Str.matched_group 1 line)
  else render_inline ~resolve_internal line

let render_to_pango_markup ~resolve_internal markdown =
  markdown |> String.split_on_char '\n' |> List.map (render_line ~resolve_internal) |> String.concat "\n"
