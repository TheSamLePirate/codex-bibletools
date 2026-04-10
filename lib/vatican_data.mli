type source = {
  id : string;
  file : string;
}

type hit = {
  source_id : string;
  title : string;
  url : string;
  date : string;
  snippet : string;
}

val sources : root:string -> (source list, string) result
val search : root:string -> sources:string list option -> query:string -> limit:int -> (hit list, string) result
