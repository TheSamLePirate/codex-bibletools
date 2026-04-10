type widget
type text_buffer

external init : unit -> unit = "caml_gtk_init"
external main : unit -> unit = "caml_gtk_main"
external main_quit : unit -> unit = "caml_gtk_main_quit"

external window_new : unit -> widget = "caml_gtk_window_new"
external window_set_title : widget -> string -> unit = "caml_gtk_window_set_title"
external window_set_default_size : widget -> width:int -> height:int -> unit = "caml_gtk_window_set_default_size_bc" "caml_gtk_window_set_default_size"

external box_new : vertical:bool -> spacing:int -> widget = "caml_gtk_box_new_bc" "caml_gtk_box_new"
external container_add : widget -> widget -> unit = "caml_gtk_container_add"
external box_pack_start : widget -> widget -> expand:bool -> fill:bool -> padding:int -> unit = "caml_gtk_box_pack_start_bc" "caml_gtk_box_pack_start"

external label_new : string -> widget = "caml_gtk_label_new"
external label_set_text : widget -> string -> unit = "caml_gtk_label_set_text"
external label_set_line_wrap : widget -> bool -> unit = "caml_gtk_label_set_line_wrap"
external widget_override_font : widget -> string -> unit = "caml_gtk_widget_override_font"

external entry_new : unit -> widget = "caml_gtk_entry_new"
external entry_get_text : widget -> string = "caml_gtk_entry_get_text"
external entry_set_text : widget -> string -> unit = "caml_gtk_entry_set_text"

external button_new : string -> widget = "caml_gtk_button_new"

external combo_box_text_new : unit -> widget = "caml_gtk_combo_box_text_new"
external combo_box_text_remove_all : widget -> unit = "caml_gtk_combo_box_text_remove_all"
external combo_box_text_append_text : widget -> string -> unit = "caml_gtk_combo_box_text_append_text"
external combo_box_text_get_active_text : widget -> string option = "caml_gtk_combo_box_text_get_active_text"
external combo_box_set_active : widget -> int -> unit = "caml_gtk_combo_box_set_active"

external scrolled_window_new : unit -> widget = "caml_gtk_scrolled_window_new"
external scrolled_window_set_policy : widget -> h:int -> v:int -> unit = "caml_gtk_scrolled_window_set_policy_bc" "caml_gtk_scrolled_window_set_policy"

external text_view_new : unit -> widget = "caml_gtk_text_view_new"
external text_view_set_wrap_mode : widget -> int -> unit = "caml_gtk_text_view_set_wrap_mode"
external text_view_set_editable : widget -> bool -> unit = "caml_gtk_text_view_set_editable"
external text_view_set_cursor_visible : widget -> bool -> unit = "caml_gtk_text_view_set_cursor_visible"
external text_view_get_buffer : widget -> text_buffer = "caml_gtk_text_view_get_buffer"
external text_buffer_set_text : text_buffer -> string -> unit = "caml_gtk_text_buffer_set_text"

external widget_set_sensitive : widget -> bool -> unit = "caml_gtk_widget_set_sensitive"
external widget_show : widget -> unit = "caml_gtk_widget_show"
external widget_hide : widget -> unit = "caml_gtk_widget_hide"
external widget_show_all : widget -> unit = "caml_gtk_widget_show_all"

external connect_destroy : widget -> (unit -> unit) -> unit = "caml_gtk_connect_destroy"
external connect_clicked : widget -> (unit -> unit) -> unit = "caml_gtk_connect_clicked"
external connect_changed : widget -> (unit -> unit) -> unit = "caml_gtk_connect_changed"
external connect_activate : widget -> (unit -> unit) -> unit = "caml_gtk_connect_activate"
