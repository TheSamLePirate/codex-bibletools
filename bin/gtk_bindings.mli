type widget
type text_buffer

val init : unit -> unit
val main : unit -> unit
val main_quit : unit -> unit

val window_new : unit -> widget
val window_set_title : widget -> string -> unit
val window_set_default_size : widget -> width:int -> height:int -> unit

val box_new : vertical:bool -> spacing:int -> widget
val container_add : widget -> widget -> unit
val box_pack_start : widget -> widget -> expand:bool -> fill:bool -> padding:int -> unit

val label_new : string -> widget
val label_set_text : widget -> string -> unit
val label_set_line_wrap : widget -> bool -> unit
val widget_override_font : widget -> string -> unit

val entry_new : unit -> widget
val entry_get_text : widget -> string
val entry_set_text : widget -> string -> unit

val button_new : string -> widget

val combo_box_text_new : unit -> widget
val combo_box_text_remove_all : widget -> unit
val combo_box_text_append_text : widget -> string -> unit
val combo_box_text_get_active_text : widget -> string option
val combo_box_set_active : widget -> int -> unit

val scrolled_window_new : unit -> widget
val scrolled_window_set_policy : widget -> h:int -> v:int -> unit

val text_view_new : unit -> widget
val text_view_set_wrap_mode : widget -> int -> unit
val text_view_set_editable : widget -> bool -> unit
val text_view_set_cursor_visible : widget -> bool -> unit
val text_view_get_buffer : widget -> text_buffer
val text_buffer_set_text : text_buffer -> string -> unit

val widget_set_sensitive : widget -> bool -> unit
val widget_show : widget -> unit
val widget_hide : widget -> unit
val widget_show_all : widget -> unit

val connect_destroy : widget -> (unit -> unit) -> unit
val connect_clicked : widget -> (unit -> unit) -> unit
val connect_changed : widget -> (unit -> unit) -> unit
val connect_activate : widget -> (unit -> unit) -> unit
