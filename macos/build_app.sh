#!/usr/bin/env bash
# Build Pascatho.app for macOS.
#
# Bundles the dune-built pascatho.exe together with the runtime resources
# (datas/, articles/, highlights/, bg.jpeg, logo.jpeg) inside the .app so
# the result is self-contained. Resources are copied (not symlinked) because
# macOS TCC blocks access to ~/Documents, ~/Desktop, ~/Downloads from
# unsigned apps launched via LaunchServices — symlinks are resolved before
# the check and would still be denied.
#
# The .app ends up around 400 MB. Re-run after `dune build` or after
# updating datas/articles. For iterative dev, use `dune exec pascatho`
# directly.
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

# Copy runtime resources into the bundle. Project_root.is_project_root accepts
# any directory containing both `datas` and `articles`, so dropping them here
# with bg.jpeg / logo.jpeg / highlights is enough.
echo "Copying runtime resources into the bundle (this can take a moment)..."
for item in datas articles highlights bg.jpeg logo.jpeg; do
  src="$REPO_ROOT/$item"
  if [[ ! -e "$src" ]]; then
    echo "build_app.sh: missing $src" >&2
    exit 1
  fi
  cp -R "$src" "$RESOURCES_DIR/"
done

# Launcher: point PASCATHO_ROOT at the bundled Resources dir and exec the binary.
cat > "$MACOS_DIR/Pascatho" <<'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PASCATHO_ROOT="$DIR/../Resources"
exec "$DIR/pascatho-bin" "$@"
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
