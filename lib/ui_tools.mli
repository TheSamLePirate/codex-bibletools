(** Calcule la nouvelle sélection d'un menu déroulant après un cran de molette.
    [direction] doit être strictement positif pour avancer et strictement négatif
    pour reculer. Retourne [None] si aucun déplacement valide n'est possible. *)
val combo_scroll_target : current:int -> count:int -> direction:int -> int option
