type search_result = {
  markup : string;
  count : int;
  current : int option;
  current_offset : int option;
  visible_length : int;
}

val sanitize_text : string -> string
val render_to_pango_markup : ?highlights:string list -> resolve_internal:(string -> string option) -> string -> string
val render_plain_to_pango_markup : ?highlights:string list -> string -> string
val render_source_to_pango_markup : ?highlights:string list -> ?references:string -> string -> string
val highlight_search_markup : needle:string -> current:int -> string -> search_result
