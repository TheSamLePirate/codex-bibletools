let is_continuation_byte text index =
  index < String.length text
  &&
  let byte = Char.code text.[index] in
  byte >= 0x80 && byte <= 0xBF

let add_utf8_bytes buffer text start count =
  for index = start to start + count - 1 do
    Buffer.add_char buffer text.[index]
  done

let sanitize_text text =
  let buffer = Buffer.create (String.length text) in
  let rec loop index =
    if index >= String.length text then ()
    else
      let byte = Char.code text.[index] in
      if byte < 32 || byte = 0x7F then (
        if text.[index] = '\n' || text.[index] = '\r' || text.[index] = '\t' then Buffer.add_char buffer text.[index];
        loop (index + 1))
      else if index + 1 < String.length text && byte = 0xC2 && Char.code text.[index + 1] = 0xA0 then (
        Buffer.add_char buffer ' ';
        loop (index + 2))
      else if index + 1 < String.length text && byte = 0xC2 && Char.code text.[index + 1] = 0xAD then
        loop (index + 2)
      else if index + 2 < String.length text && byte = 0xE2 && Char.code text.[index + 1] = 0x80
              && List.mem (Char.code text.[index + 2]) [ 0x8B; 0xA8; 0xA9 ] then
        loop (index + 3)
      else if index + 2 < String.length text && byte = 0xE2 && Char.code text.[index + 1] = 0x81
              && Char.code text.[index + 2] = 0xA0 then
        loop (index + 3)
      else if index + 2 < String.length text && byte = 0xEF && Char.code text.[index + 1] = 0xBB
              && Char.code text.[index + 2] = 0xBF then
        loop (index + 3)
      else if byte <= 0x7E then (
        Buffer.add_char buffer text.[index];
        loop (index + 1))
      else if byte >= 0xC2 && byte <= 0xDF && is_continuation_byte text (index + 1) then (
        add_utf8_bytes buffer text index 2;
        loop (index + 2))
      else if byte = 0xE0 && index + 2 < String.length text then
        let b1 = Char.code text.[index + 1] in
        if b1 >= 0xA0 && b1 <= 0xBF && is_continuation_byte text (index + 2) then (
          add_utf8_bytes buffer text index 3;
          loop (index + 3))
        else (
          Buffer.add_char buffer '?';
          loop (index + 1))
      else if ((byte >= 0xE1 && byte <= 0xEC) || byte = 0xEE || byte = 0xEF) && index + 2 < String.length text
              && is_continuation_byte text (index + 1) && is_continuation_byte text (index + 2) then (
        add_utf8_bytes buffer text index 3;
        loop (index + 3))
      else if byte = 0xED && index + 2 < String.length text then
        let b1 = Char.code text.[index + 1] in
        if b1 >= 0x80 && b1 <= 0x9F && is_continuation_byte text (index + 2) then (
          add_utf8_bytes buffer text index 3;
          loop (index + 3))
        else (
          Buffer.add_char buffer '?';
          loop (index + 1))
      else if byte = 0xF0 && index + 3 < String.length text then
        let b1 = Char.code text.[index + 1] in
        if b1 >= 0x90 && b1 <= 0xBF && is_continuation_byte text (index + 2) && is_continuation_byte text (index + 3) then (
          add_utf8_bytes buffer text index 4;
          loop (index + 4))
        else (
          Buffer.add_char buffer '?';
          loop (index + 1))
      else if byte >= 0xF1 && byte <= 0xF3 && index + 3 < String.length text
              && is_continuation_byte text (index + 1) && is_continuation_byte text (index + 2)
              && is_continuation_byte text (index + 3) then (
        add_utf8_bytes buffer text index 4;
        loop (index + 4))
      else if byte = 0xF4 && index + 3 < String.length text then
        let b1 = Char.code text.[index + 1] in
        if b1 >= 0x80 && b1 <= 0x8F && is_continuation_byte text (index + 2) && is_continuation_byte text (index + 3) then (
          add_utf8_bytes buffer text index 4;
          loop (index + 4))
        else (
          Buffer.add_char buffer '?';
          loop (index + 1))
      else (
        Buffer.add_char buffer '?';
        loop (index + 1))
  in
  loop 0;
  Buffer.contents buffer
