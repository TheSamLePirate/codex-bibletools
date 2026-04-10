#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <stdlib.h>

typedef void GtkWidget;
typedef void GtkTextBuffer;
typedef void PangoFontDescription;
typedef char gchar;
typedef unsigned int guint;
typedef unsigned long gulong;
typedef int gboolean;
typedef void *gpointer;
typedef void (*GCallback)(void);
typedef void (*GClosureNotify)(gpointer, gpointer);

extern void gtk_init(int *argc, char ***argv);
extern void gtk_main(void);
extern void gtk_main_quit(void);
extern GtkWidget *gtk_window_new(int window_type);
extern void gtk_window_set_title(gpointer window, const gchar *title);
extern void gtk_window_set_default_size(gpointer window, int width, int height);
extern GtkWidget *gtk_box_new(int orientation, int spacing);
extern void gtk_container_add(gpointer container, gpointer widget);
extern void gtk_box_pack_start(gpointer box, gpointer child, gboolean expand, gboolean fill, guint padding);
extern GtkWidget *gtk_label_new(const gchar *text);
extern void gtk_label_set_text(gpointer label, const gchar *text);
extern void gtk_label_set_line_wrap(gpointer label, gboolean wrap);
extern void gtk_widget_override_font(gpointer widget, const PangoFontDescription *font_desc);
extern GtkWidget *gtk_entry_new(void);
extern const gchar *gtk_entry_get_text(gpointer entry);
extern void gtk_entry_set_text(gpointer entry, const gchar *text);
extern GtkWidget *gtk_button_new_with_label(const gchar *label);
extern GtkWidget *gtk_combo_box_text_new(void);
extern void gtk_combo_box_text_remove_all(gpointer combo);
extern void gtk_combo_box_text_append_text(gpointer combo, const gchar *text);
extern gchar *gtk_combo_box_text_get_active_text(gpointer combo);
extern void gtk_combo_box_set_active(gpointer combo, int index);
extern GtkWidget *gtk_scrolled_window_new(gpointer hadj, gpointer vadj);
extern void gtk_scrolled_window_set_policy(gpointer sw, int hpolicy, int vpolicy);
extern GtkWidget *gtk_text_view_new(void);
extern void gtk_text_view_set_wrap_mode(gpointer text_view, int mode);
extern void gtk_text_view_set_editable(gpointer text_view, gboolean setting);
extern void gtk_text_view_set_cursor_visible(gpointer text_view, gboolean setting);
extern GtkTextBuffer *gtk_text_view_get_buffer(gpointer text_view);
extern void gtk_text_buffer_set_text(gpointer buffer, const gchar *text, int len);
extern void gtk_widget_set_sensitive(gpointer widget, gboolean sensitive);
extern void gtk_widget_show(gpointer widget);
extern void gtk_widget_hide(gpointer widget);
extern void gtk_widget_show_all(gpointer widget);
extern PangoFontDescription *pango_font_description_from_string(const gchar *str);
extern void pango_font_description_free(PangoFontDescription *desc);
extern void g_free(gpointer mem);
extern gulong g_signal_connect_data(gpointer instance, const gchar *detailed_signal, GCallback c_handler, gpointer data, GClosureNotify destroy_data, int connect_flags);

#define GTK_WINDOW_TOPLEVEL 0
#define GTK_ORIENTATION_HORIZONTAL 0
#define GTK_ORIENTATION_VERTICAL 1

static value wrap_ptr(void *ptr)
{
  value result = caml_alloc_small(1, Abstract_tag);
  *((void **)Data_abstract_val(result)) = ptr;
  return result;
}

static void *unwrap_ptr(value v)
{
  return *((void **)Data_abstract_val(v));
}

struct callback_data {
  value closure;
};

static void destroy_callback_data(gpointer data, gpointer closure)
{
  (void)closure;
  struct callback_data *cb = (struct callback_data *)data;
  caml_remove_global_root(&cb->closure);
  free(cb);
}

static void generic_callback(gpointer widget, gpointer data)
{
  CAMLparam0();
  CAMLlocal1(unit);
  (void)widget;
  unit = Val_unit;
  caml_callback(((struct callback_data *)data)->closure, unit);
  CAMLreturn0;
}

static value connect_signal(value widget, const char *signal_name, value closure)
{
  CAMLparam2(widget, closure);
  struct callback_data *data = malloc(sizeof(struct callback_data));
  if (data == NULL) caml_failwith("malloc");
  data->closure = closure;
  caml_register_global_root(&data->closure);
  g_signal_connect_data(unwrap_ptr(widget), signal_name, (GCallback)generic_callback, data, destroy_callback_data, 0);
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_init(value unit)
{
  CAMLparam1(unit);
  int argc = 0;
  char **argv = NULL;
  gtk_init(&argc, &argv);
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_main(value unit)
{
  CAMLparam1(unit);
  gtk_main();
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_main_quit(value unit)
{
  CAMLparam1(unit);
  gtk_main_quit();
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_window_new(value unit)
{
  CAMLparam1(unit);
  CAMLreturn(wrap_ptr(gtk_window_new(GTK_WINDOW_TOPLEVEL)));
}

CAMLprim value caml_gtk_window_set_title(value widget, value title)
{
  CAMLparam2(widget, title);
  gtk_window_set_title(unwrap_ptr(widget), String_val(title));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_window_set_default_size(value widget, value width, value height)
{
  CAMLparam3(widget, width, height);
  gtk_window_set_default_size(unwrap_ptr(widget), Int_val(width), Int_val(height));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_window_set_default_size_bc(value *argv, int argn)
{
  (void)argn;
  return caml_gtk_window_set_default_size(argv[0], argv[1], argv[2]);
}

CAMLprim value caml_gtk_box_new(value vertical, value spacing)
{
  CAMLparam2(vertical, spacing);
  CAMLreturn(wrap_ptr(gtk_box_new(Bool_val(vertical) ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL, Int_val(spacing))));
}

CAMLprim value caml_gtk_box_new_bc(value *argv, int argn)
{
  (void)argn;
  return caml_gtk_box_new(argv[0], argv[1]);
}

CAMLprim value caml_gtk_container_add(value container, value widget)
{
  CAMLparam2(container, widget);
  gtk_container_add(unwrap_ptr(container), unwrap_ptr(widget));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_box_pack_start(value box, value child, value expand, value fill, value padding)
{
  CAMLparam5(box, child, expand, fill, padding);
  gtk_box_pack_start(unwrap_ptr(box), unwrap_ptr(child), Bool_val(expand), Bool_val(fill), Int_val(padding));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_box_pack_start_bc(value *argv, int argn)
{
  (void)argn;
  return caml_gtk_box_pack_start(argv[0], argv[1], argv[2], argv[3], argv[4]);
}

CAMLprim value caml_gtk_label_new(value text)
{
  CAMLparam1(text);
  CAMLreturn(wrap_ptr(gtk_label_new(String_val(text))));
}

CAMLprim value caml_gtk_label_set_text(value widget, value text)
{
  CAMLparam2(widget, text);
  gtk_label_set_text(unwrap_ptr(widget), String_val(text));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_label_set_line_wrap(value widget, value wrap)
{
  CAMLparam2(widget, wrap);
  gtk_label_set_line_wrap(unwrap_ptr(widget), Bool_val(wrap));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_widget_override_font(value widget, value font)
{
  CAMLparam2(widget, font);
  PangoFontDescription *desc = pango_font_description_from_string(String_val(font));
  if (desc == NULL) caml_failwith("pango_font_description_from_string");
  gtk_widget_override_font(unwrap_ptr(widget), desc);
  pango_font_description_free(desc);
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_entry_new(value unit)
{
  CAMLparam1(unit);
  CAMLreturn(wrap_ptr(gtk_entry_new()));
}

CAMLprim value caml_gtk_entry_get_text(value widget)
{
  CAMLparam1(widget);
  CAMLreturn(caml_copy_string(gtk_entry_get_text(unwrap_ptr(widget))));
}

CAMLprim value caml_gtk_entry_set_text(value widget, value text)
{
  CAMLparam2(widget, text);
  gtk_entry_set_text(unwrap_ptr(widget), String_val(text));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_button_new(value text)
{
  CAMLparam1(text);
  CAMLreturn(wrap_ptr(gtk_button_new_with_label(String_val(text))));
}

CAMLprim value caml_gtk_combo_box_text_new(value unit)
{
  CAMLparam1(unit);
  CAMLreturn(wrap_ptr(gtk_combo_box_text_new()));
}

CAMLprim value caml_gtk_combo_box_text_remove_all(value widget)
{
  CAMLparam1(widget);
  gtk_combo_box_text_remove_all(unwrap_ptr(widget));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_combo_box_text_append_text(value widget, value text)
{
  CAMLparam2(widget, text);
  gtk_combo_box_text_append_text(unwrap_ptr(widget), String_val(text));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_combo_box_text_get_active_text(value widget)
{
  CAMLparam1(widget);
  CAMLlocal2(result, text);
  gchar *active = gtk_combo_box_text_get_active_text(unwrap_ptr(widget));
  if (active == NULL) {
    result = Val_int(0);
  } else {
    text = caml_copy_string(active);
    result = caml_alloc(1, 0);
    Field(result, 0) = text;
    g_free(active);
  }
  CAMLreturn(result);
}

CAMLprim value caml_gtk_combo_box_set_active(value widget, value index)
{
  CAMLparam2(widget, index);
  gtk_combo_box_set_active(unwrap_ptr(widget), Int_val(index));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_scrolled_window_new(value unit)
{
  CAMLparam1(unit);
  CAMLreturn(wrap_ptr(gtk_scrolled_window_new(NULL, NULL)));
}

CAMLprim value caml_gtk_scrolled_window_set_policy(value widget, value h, value v)
{
  CAMLparam3(widget, h, v);
  gtk_scrolled_window_set_policy(unwrap_ptr(widget), Int_val(h), Int_val(v));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_scrolled_window_set_policy_bc(value *argv, int argn)
{
  (void)argn;
  return caml_gtk_scrolled_window_set_policy(argv[0], argv[1], argv[2]);
}

CAMLprim value caml_gtk_text_view_new(value unit)
{
  CAMLparam1(unit);
  CAMLreturn(wrap_ptr(gtk_text_view_new()));
}

CAMLprim value caml_gtk_text_view_set_wrap_mode(value widget, value mode)
{
  CAMLparam2(widget, mode);
  gtk_text_view_set_wrap_mode(unwrap_ptr(widget), Int_val(mode));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_text_view_set_editable(value widget, value setting)
{
  CAMLparam2(widget, setting);
  gtk_text_view_set_editable(unwrap_ptr(widget), Bool_val(setting));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_text_view_set_cursor_visible(value widget, value setting)
{
  CAMLparam2(widget, setting);
  gtk_text_view_set_cursor_visible(unwrap_ptr(widget), Bool_val(setting));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_text_view_get_buffer(value widget)
{
  CAMLparam1(widget);
  CAMLreturn(wrap_ptr(gtk_text_view_get_buffer(unwrap_ptr(widget))));
}

CAMLprim value caml_gtk_text_buffer_set_text(value buffer, value text)
{
  CAMLparam2(buffer, text);
  gtk_text_buffer_set_text(unwrap_ptr(buffer), String_val(text), -1);
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_widget_set_sensitive(value widget, value sensitive)
{
  CAMLparam2(widget, sensitive);
  gtk_widget_set_sensitive(unwrap_ptr(widget), Bool_val(sensitive));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_widget_show(value widget)
{
  CAMLparam1(widget);
  gtk_widget_show(unwrap_ptr(widget));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_widget_hide(value widget)
{
  CAMLparam1(widget);
  gtk_widget_hide(unwrap_ptr(widget));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_widget_show_all(value widget)
{
  CAMLparam1(widget);
  gtk_widget_show_all(unwrap_ptr(widget));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_connect_destroy(value widget, value closure)
{
  return connect_signal(widget, "destroy", closure);
}

CAMLprim value caml_gtk_connect_clicked(value widget, value closure)
{
  return connect_signal(widget, "clicked", closure);
}

CAMLprim value caml_gtk_connect_changed(value widget, value closure)
{
  return connect_signal(widget, "changed", closure);
}

CAMLprim value caml_gtk_connect_activate(value widget, value closure)
{
  return connect_signal(widget, "activate", closure);
}
