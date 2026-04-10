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
  references : string option;
}

type navigation = {
  has_previous : bool;
  has_next : bool;
}

type direction =
  | Previous
  | Next

val list_sources : root:string -> source_descriptor list
val selector_count : root:string -> names:Book_names.t -> bible_translation:string -> source:string -> path:string list -> (int option, string) result
val selector_options : root:string -> names:Book_names.t -> bible_translation:string -> source:string -> path:string list -> (selector_option list, string) result
val selector_path_of_reference : root:string -> names:Book_names.t -> bible_translation:string -> reference:string -> (string * string list, string) result
val compile_reference : root:string -> names:Book_names.t -> bible_translation:string -> source:string -> path:string list -> (string, string) result
val render_reference : root:string -> names:Book_names.t -> bible_translation:string -> reference:string -> (rendered, string) result
val chapter_reference : root:string -> names:Book_names.t -> bible_translation:string -> reference:string -> (string option, string) result
val navigation : root:string -> names:Book_names.t -> bible_translation:string -> reference:string -> (navigation, string) result
val navigate : root:string -> names:Book_names.t -> bible_translation:string -> reference:string -> direction -> (string, string) result
val decode_site_reference_url : string -> string option
