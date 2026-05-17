#!/usr/bin/env bash
# Build Pascatho.app for macOS.
#
# The bundle wraps the dune-built pascatho.exe with a launcher that points
# PASCATHO_ROOT at the source checkout, so the .app stays small (~5 MB) and
# always sees up-to-date datas/articles. Re-run after `dune build`.
#
# Outputs: dist/Pascatho.app

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
APP_DIR="$DIST_DIR/Pascatho.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
BINARY_SRC="$REPO_ROOT/_build/default/bin/pascatho.exe"
LOGO_SRC="$REPO_ROOT/logo.jpeg"
PLIST_SRC="$REPO_ROOT/macos/Info.plist.tmpl"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build_app.sh: macOS only (uname=$(uname -s))" >&2
  exit 1
fi

if [[ ! -f "$BINARY_SRC" ]]; then
  echo "build_app.sh: $BINARY_SRC missing — run 'dune build' first" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$PLIST_SRC" "$CONTENTS/Info.plist"
cp "$BINARY_SRC" "$MACOS_DIR/pascatho-bin"
chmod +x "$MACOS_DIR/pascatho-bin"

# Launcher: point PASCATHO_ROOT at the source checkout and exec the real binary.
cat > "$MACOS_DIR/Pascatho" <<EOF
#!/bin/bash
export PASCATHO_ROOT="$REPO_ROOT"
DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\$DIR/pascatho-bin" "\$@"
EOF
chmod +x "$MACOS_DIR/Pascatho"

# Convert logo.jpeg to a .icns using sips + iconutil (built into macOS).
ICONSET="$DIST_DIR/Pascatho.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for sz in 16 32 64 128 256 512; do
  sips -s format png -z "$sz" "$sz" "$LOGO_SRC" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
  dbl=$((sz * 2))
  sips -s format png -z "$dbl" "$dbl" "$LOGO_SRC" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/Pascatho.icns"
rm -rf "$ICONSET"

# Touch the bundle so Finder/LaunchServices pick up the new icon promptly.
touch "$APP_DIR"

echo "Built: $APP_DIR"
echo "Run:   open '$APP_DIR'"
