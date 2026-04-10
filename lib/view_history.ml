type view =
  | Reference of string
  | Article of string

type t = {
  current : view option;
  previous : view list;
}

let empty = {
  current = None;
  previous = [];
}

let current history = history.current
let can_go_back history = history.previous <> []

let visit history view =
  match history.current with
  | Some current when current = view -> history
  | Some current -> { current = Some view; previous = current :: history.previous }
  | None -> { current = Some view; previous = history.previous }

let pop history =
  match history.previous with
  | previous :: rest -> Some (previous, { current = Some previous; previous = rest })
  | [] -> None
