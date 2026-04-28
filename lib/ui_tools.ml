let combo_scroll_target ~current ~count ~direction =
  if count <= 0 || current < 0 || current >= count || direction = 0 then None
  else
    let next =
      if direction > 0 then min (count - 1) (current + 1)
      else max 0 (current - 1)
    in
    if next = current then None else Some next
