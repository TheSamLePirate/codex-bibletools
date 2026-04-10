#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef void GtkWidget;
typedef void GtkTextBuffer;
typedef void GtkClipboard;
typedef void GdkDisplay;
typedef void PangoFontDescription;
typedef char gchar;
typedef unsigned int guint;
typedef unsigned long gulong;
typedef int gboolean;
typedef void *gpointer;
typedef void cairo_t;
typedef void (*GCallback)(void);
typedef void (*GClosureNotify)(gpointer, gpointer);
typedef gboolean (*GSourceFunc)(gpointer);

extern void gtk_init(int *argc, char ***argv);
extern void gtk_main(void);
extern void gtk_main_quit(void);
extern GtkWidget *gtk_window_new(int window_type);
extern void gtk_window_set_title(gpointer window, const gchar *title);
extern void gtk_window_set_default_size(gpointer window, int width, int height);
extern void gtk_window_set_icon(gpointer window, gpointer icon);
extern void gtk_widget_set_app_paintable(gpointer widget, gboolean app_paintable);
extern int gtk_widget_get_allocated_width(gpointer widget);
extern int gtk_widget_get_allocated_height(gpointer widget);
extern void gtk_widget_set_size_request(gpointer widget, int width, int height);
extern void gtk_widget_queue_draw(gpointer widget);
extern GtkWidget *gtk_box_new(int orientation, int spacing);
extern GtkWidget *gtk_flow_box_new(void);
extern void gtk_flow_box_set_selection_mode(gpointer box, int mode);
extern void gtk_container_add(gpointer container, gpointer widget);
extern void gtk_box_pack_start(gpointer box, gpointer child, gboolean expand, gboolean fill, guint padding);
extern GtkWidget *gtk_label_new(const gchar *text);
extern void gtk_label_set_text(gpointer label, const gchar *text);
extern void gtk_label_set_markup(gpointer label, const gchar *str);
extern void gtk_label_set_line_wrap(gpointer label, gboolean wrap);
extern void gtk_label_set_selectable(gpointer label, gboolean setting);
extern void gtk_widget_override_font(gpointer widget, const PangoFontDescription *font_desc);
extern GtkWidget *gtk_entry_new(void);
extern const gchar *gtk_entry_get_text(gpointer entry);
extern void gtk_entry_set_text(gpointer entry, const gchar *text);
extern GtkWidget *gtk_button_new_with_label(const gchar *label);
extern GdkDisplay *gtk_widget_get_display(gpointer widget);
extern GtkClipboard *gtk_clipboard_get_default(GdkDisplay *display);
extern void gtk_clipboard_set_text(GtkClipboard *clipboard, const gchar *text, int len);
extern void gtk_clipboard_store(GtkClipboard *clipboard);
extern GtkWidget *gtk_image_new_from_file(const gchar *filename);
extern void gtk_image_set_from_pixbuf(gpointer image, gpointer pixbuf);
extern GtkWidget *gtk_combo_box_text_new(void);
extern void gtk_combo_box_text_remove_all(gpointer combo);
extern void gtk_combo_box_text_append_text(gpointer combo, const gchar *text);
extern gchar *gtk_combo_box_text_get_active_text(gpointer combo);
extern int gtk_combo_box_get_active(gpointer combo);
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
extern guint g_timeout_add(guint interval, GSourceFunc function, gpointer data);
extern gboolean g_source_remove(guint tag);
extern gulong g_signal_connect_data(gpointer instance, const gchar *detailed_signal, GCallback c_handler, gpointer data, GClosureNotify destroy_data, int connect_flags);
extern gpointer gdk_pixbuf_new_from_file(const gchar *filename, gpointer error);
extern int gdk_pixbuf_get_width(gpointer pixbuf);
extern int gdk_pixbuf_get_height(gpointer pixbuf);
extern void gdk_cairo_set_source_pixbuf(cairo_t *cr, gpointer pixbuf, double pixbuf_x, double pixbuf_y);
extern gpointer gdk_pixbuf_new_from_file_at_scale(const gchar *filename, int width, int height, gboolean preserve_aspect_ratio, gpointer error);
extern void g_object_unref(gpointer object);
extern void cairo_set_source_rgb(cairo_t *cr, double red, double green, double blue);
extern void cairo_paint(cairo_t *cr);
extern void cairo_paint_with_alpha(cairo_t *cr, double alpha);
extern void cairo_set_line_width(cairo_t *cr, double width);
extern void cairo_move_to(cairo_t *cr, double x, double y);
extern void cairo_line_to(cairo_t *cr, double x, double y);
extern void cairo_stroke(cairo_t *cr);

#define GTK_WINDOW_TOPLEVEL 0
#define GTK_ORIENTATION_HORIZONTAL 0
#define GTK_ORIENTATION_VERTICAL 1
#define GTK_SELECTION_NONE 0

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

struct string_callback_data {
  value closure;
};

struct background_data {
  gpointer widget;
  double angle;
  guint timer_id;
  char *bg_path;
  gpointer bg_original_pixbuf;
  int bg_original_width;
  int bg_original_height;
  gpointer bg_pixbuf;
  int bg_width;
  int bg_height;
};

static void destroy_string_callback_data(gpointer data, gpointer closure)
{
  (void)closure;
  struct string_callback_data *cb = (struct string_callback_data *)data;
  caml_remove_global_root(&cb->closure);
  free(cb);
}

static gboolean activate_link_callback(gpointer widget, const gchar *uri, gpointer data)
{
  CAMLparam0();
  CAMLlocal1(argument);
  (void)widget;
  argument = caml_copy_string(uri);
  caml_callback(((struct string_callback_data *)data)->closure, argument);
  CAMLreturnT(gboolean, 1);
}

static value connect_string_signal(value widget, const char *signal_name, value closure)
{
  CAMLparam2(widget, closure);
  struct string_callback_data *data = malloc(sizeof(struct string_callback_data));
  if (data == NULL) caml_failwith("malloc");
  data->closure = closure;
  caml_register_global_root(&data->closure);
  g_signal_connect_data(unwrap_ptr(widget), signal_name, (GCallback)activate_link_callback, data, destroy_string_callback_data, 0);
  CAMLreturn(Val_unit);
}

static char *sanitize_label_text(const char *text)
{
  size_t len = strlen(text);
  char *out = malloc(len + 1);
  size_t i = 0;
  size_t j = 0;
  if (out == NULL) caml_failwith("malloc");
  while (i < len) {
    unsigned char c = (unsigned char)text[i];
    if (c < 32) {
      if (c == '\n' || c == '\r' || c == '\t') out[j++] = (char)c;
      i++;
    } else if (i + 1 < len && c == 0xC2 && (unsigned char)text[i + 1] == 0xA0) {
      out[j++] = ' ';
      i += 2;
    } else if (i + 1 < len && c == 0xC2 && (unsigned char)text[i + 1] == 0xAD) {
      i += 2;
    } else if (i + 2 < len && c == 0xE2 && (unsigned char)text[i + 1] == 0x80 &&
               (((unsigned char)text[i + 2] == 0x8B) || ((unsigned char)text[i + 2] == 0xA8) || ((unsigned char)text[i + 2] == 0xA9))) {
      i += 3;
    } else if (i + 2 < len && c == 0xE2 && (unsigned char)text[i + 1] == 0x81 && (unsigned char)text[i + 2] == 0xA0) {
      i += 3;
    } else if (i + 2 < len && c == 0xEF && (unsigned char)text[i + 1] == 0xBB && (unsigned char)text[i + 2] == 0xBF) {
      i += 3;
    } else {
      out[j++] = text[i++];
    }
  }
  out[j] = '\0';
  return out;
}

static void rotate_point(double x, double y, double z, double angle, double *out_x, double *out_y, double *out_z)
{
  double ay = angle;
  double ax = angle * 0.6;
  double cy = cos(ay);
  double sy = sin(ay);
  double cx = cos(ax);
  double sx = sin(ax);
  double x1 = x * cy + z * sy;
  double z1 = -x * sy + z * cy;
  double y2 = y * cx - z1 * sx;
  double z2 = y * sx + z1 * cx;
  *out_x = x1;
  *out_y = y2;
  *out_z = z2;
}

static void project_point(double x, double y, double z, int width, int height, double *out_x, double *out_y)
{
  double distance = 5.0;
  double perspective = 1.0 / (distance - z);
  double scale = ((width < height) ? width : height) * 0.23;
  *out_x = width * 0.78 + x * perspective * scale;
  *out_y = height * 0.24 + y * perspective * scale;
}

static void draw_box_edges_at(cairo_t *cr, double angle, int width, int height, double cx, double cy, double cz, double hx, double hy, double hz)
{
  static const int edges[12][2] = {
    {0, 1}, {1, 2}, {2, 3}, {3, 0},
    {4, 5}, {5, 6}, {6, 7}, {7, 4},
    {0, 4}, {1, 5}, {2, 6}, {3, 7}
  };
  double vertices[8][3] = {
    {cx - hx, cy - hy, cz - hz}, {cx + hx, cy - hy, cz - hz}, {cx + hx, cy + hy, cz - hz}, {cx - hx, cy + hy, cz - hz},
    {cx - hx, cy - hy, cz + hz}, {cx + hx, cy - hy, cz + hz}, {cx + hx, cy + hy, cz + hz}, {cx - hx, cy + hy, cz + hz}
  };
  int i;
  for (i = 0; i < 12; i++) {
    double ax, ay, az, bx, by, bz;
    double x1, y1, x2, y2;
    rotate_point(vertices[edges[i][0]][0], vertices[edges[i][0]][1], vertices[edges[i][0]][2], angle, &ax, &ay, &az);
    rotate_point(vertices[edges[i][1]][0], vertices[edges[i][1]][1], vertices[edges[i][1]][2], angle, &bx, &by, &bz);
    project_point(ax, ay, az, width, height, &x1, &y1);
    project_point(bx, by, bz, width, height, &x2, &y2);
    cairo_move_to(cr, x1, y1);
    cairo_line_to(cr, x2, y2);
  }
}

static gboolean background_draw_callback(gpointer widget, cairo_t *cr, gpointer data)
{
  struct background_data *background = (struct background_data *)data;
  int width = gtk_widget_get_allocated_width(widget);
  int height = gtk_widget_get_allocated_height(widget);
  if (background->bg_original_pixbuf != NULL && width > 0 && height > 0) {
    double scale_x = ((double)width) / ((double)background->bg_original_width);
    double scale_y = ((double)height) / ((double)background->bg_original_height);
    double scale = scale_x > scale_y ? scale_x : scale_y;
    int target_width = (int)ceil(background->bg_original_width * scale);
    int target_height = (int)ceil(background->bg_original_height * scale);
    if (background->bg_pixbuf == NULL || background->bg_width != target_width || background->bg_height != target_height) {
      if (background->bg_pixbuf != NULL) g_object_unref(background->bg_pixbuf);
      background->bg_pixbuf = gdk_pixbuf_new_from_file_at_scale(background->bg_path, target_width, target_height, 0, NULL);
      background->bg_width = background->bg_pixbuf == NULL ? 0 : gdk_pixbuf_get_width(background->bg_pixbuf);
      background->bg_height = background->bg_pixbuf == NULL ? 0 : gdk_pixbuf_get_height(background->bg_pixbuf);
    }
  }
  if (background->bg_pixbuf != NULL) {
    double travel = background->bg_width > width ? (double)(background->bg_width - width) : 0.0;
    double phase = (sin(background->angle * 0.10) + 1.0) * 0.5;
    double x = -travel * phase;
    double y = (height - background->bg_height) * 0.5;
    gdk_cairo_set_source_pixbuf(cr, background->bg_pixbuf, x, y);
    cairo_paint(cr);
  }
  cairo_set_source_rgb(cr, 0.95, 0.95, 0.96);
  cairo_paint_with_alpha(cr, 0.74);
  cairo_set_source_rgb(cr, 0.45, 0.28, 0.12);
  cairo_set_line_width(cr, 2.8);
  draw_box_edges_at(cr, background->angle, width, height, 0.0, 0.42, 0.0, 0.20, 1.72, 0.20);
  draw_box_edges_at(cr, background->angle, width, height, 0.0, -0.42, 0.0, 0.95, 0.20, 0.20);
  cairo_stroke(cr);
  return 0;
}

static gboolean background_tick(gpointer data)
{
  struct background_data *background = (struct background_data *)data;
  background->angle += 0.02;
  gtk_widget_queue_draw(background->widget);
  return 1;
}

static void destroy_background_data(gpointer data, gpointer closure)
{
  struct background_data *background = (struct background_data *)data;
  (void)closure;
  if (background->timer_id != 0) g_source_remove(background->timer_id);
  if (background->bg_original_pixbuf != NULL) g_object_unref(background->bg_original_pixbuf);
  if (background->bg_pixbuf != NULL) g_object_unref(background->bg_pixbuf);
  if (background->bg_path != NULL) free(background->bg_path);
  free(background);
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

CAMLprim value caml_gtk_window_set_icon_from_file(value widget, value path)
{
  CAMLparam2(widget, path);
  gpointer pixbuf = gdk_pixbuf_new_from_file(String_val(path), NULL);
  if (pixbuf != NULL) {
    gtk_window_set_icon(unwrap_ptr(widget), pixbuf);
    g_object_unref(pixbuf);
  }
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_window_enable_cross_background(value widget, value path)
{
  CAMLparam2(widget, path);
  struct background_data *background = malloc(sizeof(struct background_data));
  if (background == NULL) caml_failwith("malloc");
  background->widget = unwrap_ptr(widget);
  background->angle = 0.0;
  background->timer_id = 0;
  background->bg_path = strdup(String_val(path));
  if (background->bg_path == NULL) caml_failwith("strdup");
  background->bg_original_pixbuf = gdk_pixbuf_new_from_file(String_val(path), NULL);
  background->bg_original_width = background->bg_original_pixbuf == NULL ? 0 : gdk_pixbuf_get_width(background->bg_original_pixbuf);
  background->bg_original_height = background->bg_original_pixbuf == NULL ? 0 : gdk_pixbuf_get_height(background->bg_original_pixbuf);
  background->bg_pixbuf = NULL;
  background->bg_width = 0;
  background->bg_height = 0;
  gtk_widget_set_app_paintable(background->widget, 1);
  g_signal_connect_data(background->widget, "draw", (GCallback)background_draw_callback, background, destroy_background_data, 0);
  background->timer_id = g_timeout_add(16, background_tick, background);
  CAMLreturn(Val_unit);
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

CAMLprim value caml_gtk_flow_box_new(value unit)
{
  CAMLparam1(unit);
  CAMLreturn(wrap_ptr(gtk_flow_box_new()));
}

CAMLprim value caml_gtk_flow_box_set_selection_mode(value widget, value mode)
{
  CAMLparam2(widget, mode);
  gtk_flow_box_set_selection_mode(unwrap_ptr(widget), Int_val(mode));
  CAMLreturn(Val_unit);
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
  char *sanitized = sanitize_label_text(String_val(text));
  gtk_label_set_text(unwrap_ptr(widget), sanitized);
  free(sanitized);
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_label_set_markup(value widget, value text)
{
  CAMLparam2(widget, text);
  char *sanitized = sanitize_label_text(String_val(text));
  gtk_label_set_markup(unwrap_ptr(widget), sanitized);
  free(sanitized);
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_label_set_line_wrap(value widget, value wrap)
{
  CAMLparam2(widget, wrap);
  gtk_label_set_line_wrap(unwrap_ptr(widget), Bool_val(wrap));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_label_set_selectable(value widget, value setting)
{
  CAMLparam2(widget, setting);
  gtk_label_set_selectable(unwrap_ptr(widget), Bool_val(setting));
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

CAMLprim value caml_gtk_widget_copy_text_to_clipboard(value widget, value text)
{
  CAMLparam2(widget, text);
  GdkDisplay *display = gtk_widget_get_display(unwrap_ptr(widget));
  if (display != NULL) {
    GtkClipboard *clipboard = gtk_clipboard_get_default(display);
    if (clipboard != NULL) {
      gtk_clipboard_set_text(clipboard, String_val(text), -1);
      gtk_clipboard_store(clipboard);
    }
  }
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_image_new_from_file(value path)
{
  CAMLparam1(path);
  CAMLreturn(wrap_ptr(gtk_image_new_from_file(String_val(path))));
}

CAMLprim value caml_gtk_image_set_from_file_scaled(value widget, value path, value height)
{
  CAMLparam3(widget, path, height);
  gpointer pixbuf = gdk_pixbuf_new_from_file_at_scale(String_val(path), -1, Int_val(height), 1, NULL);
  if (pixbuf != NULL) {
    gtk_image_set_from_pixbuf(unwrap_ptr(widget), pixbuf);
    g_object_unref(pixbuf);
  }
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_image_set_from_file_scaled_bc(value *argv, int argn)
{
  (void)argn;
  return caml_gtk_image_set_from_file_scaled(argv[0], argv[1], argv[2]);
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

CAMLprim value caml_gtk_combo_box_get_active(value widget)
{
  CAMLparam1(widget);
  CAMLreturn(Val_int(gtk_combo_box_get_active(unwrap_ptr(widget))));
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

CAMLprim value caml_gtk_widget_set_size_request(value widget, value width, value height)
{
  CAMLparam3(widget, width, height);
  gtk_widget_set_size_request(unwrap_ptr(widget), Int_val(width), Int_val(height));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_gtk_widget_set_size_request_bc(value *argv, int argn)
{
  (void)argn;
  return caml_gtk_widget_set_size_request(argv[0], argv[1], argv[2]);
}

CAMLprim value caml_gtk_widget_get_allocated_height(value widget)
{
  CAMLparam1(widget);
  CAMLreturn(Val_int(gtk_widget_get_allocated_height(unwrap_ptr(widget))));
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

CAMLprim value caml_gtk_connect_activate_link(value widget, value closure)
{
  return connect_string_signal(widget, "activate-link", closure);
}
