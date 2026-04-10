type view =
  | Reference of string
  | Article of string

type t

val empty : t
val current : t -> view option
val can_go_back : t -> bool
val visit : t -> view -> t
val pop : t -> (view * t) option
