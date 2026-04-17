external raw_address_space_limit_bytes : unit -> int64 = "caml_process_limits_get_address_space_limit"

external raw_set_address_space_limit_bytes : int64 -> unit = "caml_process_limits_set_address_space_limit"

let address_space_limit_bytes () =
  try
    let bytes = raw_address_space_limit_bytes () in
    Ok (if Int64.compare bytes 0L < 0 then None else Some bytes)
  with Failure message -> Error message

let set_address_space_limit_bytes ~bytes =
  if Int64.compare bytes 0L <= 0 then Error "La limite mémoire doit être strictement positive."
  else
    try
      raw_set_address_space_limit_bytes bytes;
      Ok ()
    with Failure message -> Error message
