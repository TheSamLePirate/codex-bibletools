type article = {
  name : string;
  path : string;
}

val list : root:string -> article list
val read : root:string -> name:string -> (string, string) result
