type t

val load : root:string -> (t, string) result
val canonical_title : t -> string -> string option
val aliases : t -> string -> string list
val all_aliases : t -> string list
