#!/usr/bin/env bash
# Emit a dune sexp list of link flags for the GTK 3 stack.
# Uses pkg-config when available (works on macOS Homebrew + Linux distros).
# Falls back to the previously hardcoded Debian/Ubuntu .so paths.

set -eu

PKGS="gtk+-3.0 gdk-3.0 gobject-2.0 glib-2.0 gio-2.0 pangocairo pango harfbuzz cairo gdk-pixbuf-2.0 atk"

emit_sexp_from_flags() {
  printf '('
  for f in "$@"; do
    printf -- '-cclib %s ' "$f"
  done
  printf ')\n'
}

if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists gtk+-3.0 2>/dev/null; then
  # shellcheck disable=SC2046
  set -- $(pkg-config --libs $PKGS)
  emit_sexp_from_flags "$@"
  exit 0
fi

# Fallback: original Debian/Ubuntu multiarch paths.
emit_sexp_from_flags \
  /usr/lib/x86_64-linux-gnu/libgtk-3.so.0 \
  /lib/x86_64-linux-gnu/libgdk-3.so.0 \
  /lib/x86_64-linux-gnu/libgobject-2.0.so.0 \
  /lib/x86_64-linux-gnu/libglib-2.0.so.0 \
  /lib/x86_64-linux-gnu/libgio-2.0.so.0 \
  /lib/x86_64-linux-gnu/libpangocairo-1.0.so.0 \
  /lib/x86_64-linux-gnu/libpango-1.0.so.0 \
  /lib/x86_64-linux-gnu/libharfbuzz.so.0 \
  /lib/x86_64-linux-gnu/libcairo.so.2 \
  /lib/x86_64-linux-gnu/libgdk_pixbuf-2.0.so.0 \
  /lib/x86_64-linux-gnu/libatk-1.0.so.0
