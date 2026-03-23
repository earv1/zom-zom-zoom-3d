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

# --- Cache-busting ----------------------------------------------------------
# Append ?v=<short-sha> to asset references so browsers fetch fresh files.
CACHE_SHA=$(git log --format="%h" --grep="^build: " --invert-grep -1 2>/dev/null)
if [ -n "$CACHE_SHA" ] && [ -f "$OUT_DIR/index.html" ]; then
  echo ""
  echo "Adding cache-busting query strings (v=$CACHE_SHA) ..."
  # Add no-cache meta tag for the HTML itself
  sed -i '' 's|<head>|<head>\n<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">|' "$OUT_DIR/index.html"
  # Bust .js, .wasm, .pck, .png references
  sed -i '' "s|\(index\.js\)\"|index.js?v=$CACHE_SHA\"|g" "$OUT_DIR/index.html"
  sed -i '' "s|\(index\.wasm\)\"|index.wasm?v=$CACHE_SHA\"|g" "$OUT_DIR/index.html"
  sed -i '' "s|\(index\.pck\)\"|index.pck?v=$CACHE_SHA\"|g" "$OUT_DIR/index.html"
  sed -i '' "s|\(index\.png\)\"|index.png?v=$CACHE_SHA\"|g" "$OUT_DIR/index.html"
  sed -i '' "s|\(index\.icon\.png\)\"|index.icon.png?v=$CACHE_SHA\"|g" "$OUT_DIR/index.html"
  sed -i '' "s|\(index\.audio\.worklet\.js\)\"|index.audio.worklet.js?v=$CACHE_SHA\"|g" "$OUT_DIR/index.html"
  sed -i '' "s|\(index\.audio\.position\.worklet\.js\)\"|index.audio.position.worklet.js?v=$CACHE_SHA\"|g" "$OUT_DIR/index.html"
  echo "Cache-busting applied."
fi

# --- Zip for Git LFS --------------------------------------------------------
echo ""
echo "Zipping to build/build.zip ..."
zip -r build/build.zip "$OUT_DIR/" -x "*.DS_Store"
rm -rf "$OUT_DIR"
echo "Zipped: $(du -sh build/build.zip | cut -f1)"

# --- Record source SHA for staleness check ----------------------------------
# Store the latest non-build commit SHA so the pre-push hook can verify
# the build is current before allowing a push.
LAST_CODE_SHA=$(git log --format="%H" --grep="^build: " --invert-grep -1 2>/dev/null)
echo "$LAST_CODE_SHA" > build/build.sha
echo "Recorded source SHA: $LAST_CODE_SHA"

# --- Commit build artifacts -------------------------------------------------
git add build/build.zip build/build.sha

if git diff --cached --quiet; then
  echo "Build unchanged, nothing to commit."
else
  LAST_MSG=$(git log -1 --format="%s" 2>/dev/null)
  if [[ "$LAST_MSG" == build:* ]]; then
    git commit --amend --no-edit
    echo "Amended previous build commit."
  else
    git commit -m "build: update web export"
    echo "Committed build artifacts."
  fi
fi

# --- Summary ----------------------------------------------------------------
echo ""
echo "Done! Run: git push"
