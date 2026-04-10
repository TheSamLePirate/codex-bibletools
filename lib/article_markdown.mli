val render_to_pango_markup : ?highlights:string list -> resolve_internal:(string -> string option) -> string -> string
val render_plain_to_pango_markup : ?highlights:string list -> string -> string
val render_source_to_pango_markup : ?highlights:string list -> ?references:string -> string -> string
