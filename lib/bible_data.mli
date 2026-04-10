type verse = {
  number : int;
  text : string;
}

type chapter = {
  number : int;
  verses : verse array;
}

type translation

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

val available_translations : root:string -> (translation_info list, string) result
val load_translation : root:string -> names:Book_names.t -> id:string -> (translation, string) result
val books : translation -> book_info list
val chapter_numbers : translation -> book:string -> (int list, string) result
val verse_numbers : translation -> book:string -> chapter:int -> (int list, string) result
val lookup : translation -> Bible_reference.t -> (string * verse list, string) result
val chapter : translation -> Bible_reference.t -> (string * chapter, string) result
val navigate : translation -> Bible_reference.t -> direction -> (Bible_reference.t, string) result
val navigation : translation -> Bible_reference.t -> (navigation, string) result
val random_reference : ?book:string -> translation -> unit -> (Bible_reference.t, string) result
