#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# build_web.sh — Export Zom Zom Zoom to WebAssembly for GitHub Pages
# Usage: ./build_web.sh
# ---------------------------------------------------------------------------

OUT_DIR="build/web"

# --- Find Godot binary ------------------------------------------------------
find_godot() {
  # Check common macOS install locations for Godot 4.3
  local candidates=(
    "/Applications/Godot_v4.3-stable_macos.universal.app/Contents/MacOS/Godot"
    "/Applications/Godot_v4.3_macos.universal.app/Contents/MacOS/Godot"
    "/Applications/Godot.app/Contents/MacOS/Godot"
    "$(which godot 2>/dev/null)"
    "$(which godot4 2>/dev/null)"
  )
  for path in "${candidates[@]}"; do
    if [ -x "$path" ]; then
      echo "$path"
      return 0
    fi
  done
  return 1
}

GODOT=$(find_godot) || {
  echo "ERROR: Godot binary not found."
  echo "Set the path manually: GODOT=/path/to/Godot ./build_web.sh"
  exit 1
}

echo "Using Godot: $GODOT"
echo "Godot version: $("$GODOT" --version 2>/dev/null || echo 'unknown')"

# --- Check export templates are installed -----------------------------------
TEMPLATE_DIR="$HOME/Library/Application Support/Godot/export_templates"
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "ERROR: No export templates found at: $TEMPLATE_DIR"
  echo "Install them in Godot: Editor → Export → Manage Export Templates → Download"
  exit 1
fi

WEB_TEMPLATE=$(find "$TEMPLATE_DIR" -name "web_release.zip" 2>/dev/null | head -1)
if [ -z "$WEB_TEMPLATE" ]; then
  echo "ERROR: Web export templates not found. Install them in Godot:"
  echo "  Editor → Export → Manage Export Templates → Download"
  exit 1
fi

# --- Export -----------------------------------------------------------------
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
echo ""
echo "Exporting to $OUT_DIR/index.html ..."
"$GODOT" --headless --export-release "Web" "$OUT_DIR/index.html"
echo "Export complete."

# --- Inject coi-serviceworker (enables SharedArrayBuffer on static hosts) ---
COI_URL="https://raw.githubusercontent.com/gzuidhof/coi-serviceworker/master/coi-serviceworker.js"
COI_FILE="$OUT_DIR/coi-serviceworker.js"

if [ ! -f "$COI_FILE" ]; then
  echo ""
  echo "Downloading coi-serviceworker.js ..."
  curl -sSL "$COI_URL" -o "$COI_FILE" && echo "Downloaded." || echo "WARNING: Could not download coi-serviceworker.js."
fi

if [ -f "$COI_FILE" ] && [ -f "$OUT_DIR/index.html" ]; then
  if ! grep -q "coi-serviceworker" "$OUT_DIR/index.html"; then
    sed -i '' 's|<head>|<head>\n<script src="coi-serviceworker.js"></script>|' "$OUT_DIR/index.html"
    echo "Injected coi-serviceworker into index.html."
  fi
fi

# --- Zip for Git LFS --------------------------------------------------------
echo ""
echo "Zipping to build/build.zip ..."
zip -r build/build.zip "$OUT_DIR/" -x "*.DS_Store"
rm -rf "$OUT_DIR"
echo "Zipped: $(du -sh build/build.zip | cut -f1)"

# --- Summary ----------------------------------------------------------------
echo ""
echo "Done!"
echo ""
echo "Next steps:"
echo "  1. git add build/build.zip && git commit -m 'build: update web export'"
echo "  2. git push"
