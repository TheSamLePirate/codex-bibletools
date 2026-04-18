type widget
type text_buffer

val init : unit -> unit
val main : unit -> unit
val main_quit : unit -> unit
val application_run : app_id:string -> argv:string array -> on_activate:(unit -> unit) -> on_command_line:(string -> unit) -> int

val window_new : unit -> widget
val window_set_title : widget -> string -> unit
val window_set_default_size : widget -> width:int -> height:int -> unit
val window_set_icon_from_file : widget -> string -> unit
val window_enable_cross_background : widget -> string -> unit
val window_present : widget -> unit
val widget_grab_focus : widget -> unit

val box_new : vertical:bool -> spacing:int -> widget
val flow_box_new : unit -> widget
val flow_box_set_selection_mode : widget -> int -> unit
val container_add : widget -> widget -> unit
val box_pack_start : widget -> widget -> expand:bool -> fill:bool -> padding:int -> unit

val label_new : string -> widget
val label_set_text : widget -> string -> unit
val label_set_markup : widget -> string -> unit
val label_set_line_wrap : widget -> bool -> unit
val label_set_selectable : widget -> bool -> unit
val widget_override_font : widget -> string -> unit

val entry_new : unit -> widget
val entry_get_text : widget -> string
val entry_set_text : widget -> string -> unit

val button_new : string -> widget
val widget_copy_text_to_clipboard : widget -> string -> unit
val image_new_from_file : string -> widget
val image_set_from_file_scaled : widget -> string -> height:int -> unit

val combo_box_text_new : unit -> widget
val combo_box_text_remove_all : widget -> unit
val combo_box_text_append_text : widget -> string -> unit
val combo_box_get_active : widget -> int
val combo_box_set_active : widget -> int -> unit

val scrolled_window_new : unit -> widget
val scrolled_window_set_policy : widget -> h:int -> v:int -> unit
val scrolled_window_scroll_vertical_ratio : widget -> float -> unit

val text_view_new : unit -> widget
val text_view_set_wrap_mode : widget -> int -> unit
val text_view_set_editable : widget -> bool -> unit
val text_view_set_cursor_visible : widget -> bool -> unit
val text_view_get_buffer : widget -> text_buffer
val text_buffer_set_text : text_buffer -> string -> unit

val widget_set_sensitive : widget -> bool -> unit
val widget_set_size_request : widget -> width:int -> height:int -> unit
val widget_get_allocated_height : widget -> int
val widget_show : widget -> unit
val widget_hide : widget -> unit
val widget_show_all : widget -> unit

val connect_destroy : widget -> (unit -> unit) -> unit
val connect_clicked : widget -> (unit -> unit) -> unit
val connect_changed : widget -> (unit -> unit) -> unit
val connect_activate : widget -> (unit -> unit) -> unit
val connect_activate_link : widget -> (string -> unit) -> unit
val connect_ctrl_f : widget -> (unit -> unit) -> unit
val connect_ctrl_q : widget -> (unit -> unit) -> unit
