#!/bin/bash

PLAYLIST_URL="$1"

if [ -z "$PLAYLIST_URL" ]; then
  echo "Usage: ./fetch_transcripts.sh <playlist_url>"
  exit 1
fi

OUT_DIR="transcripts"
mkdir -p "$OUT_DIR"

echo "Fetching transcripts from playlist: $PLAYLIST_URL"
yt-dlp \
  --skip-download \
  --write-auto-sub \
  --sub-lang en \
  --sub-format vtt \
  --yes-playlist \
  --output "$OUT_DIR/%(playlist_index)02d - %(title)s" \
  "$PLAYLIST_URL"

echo ""
echo "Cleaning up VTT formatting..."
for vtt in "$OUT_DIR"/*.vtt; do
  txt="${vtt%.vtt}.txt"
  grep -v "^WEBVTT" "$vtt" \
    | grep -v "^[0-9][0-9]:.*-->" \
    | grep -v "^$" \
    | grep -v "^[0-9]*$" \
    | awk '!seen[$0]++' \
    > "$txt"
  echo "  → $txt"
done

echo ""
echo "Done. Transcripts saved to: $OUT_DIR/"
