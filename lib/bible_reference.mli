type verse_range = {
  first_verse : int option;
  last_verse : int option;
}

type t = {
  book : string;
  chapter : int;
  verses : verse_range;
}

val parse : names:Book_names.t -> string -> (t, string) result
val with_single_verse : t -> int -> t
val format : t -> string
