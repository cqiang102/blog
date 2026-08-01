#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FONT_DIR="$PROJECT_DIR/test/fonts"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/blog-mimo-golden-fonts.XXXXXX")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

for command_name in curl pyftsubset rg python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

mkdir -p "$FONT_DIR"

corpus="$(
  rg -o --no-filename '.' \
    "$PROJECT_DIR/lib" \
    "$PROJECT_DIR/test" \
    --glob '*.dart' \
    | LC_ALL=C sort -u \
    | tr -d '\n'
)"
# Markdown renderers synthesize list markers that are not present literally in
# Dart source, so keep their glyphs in the deterministic test subset as well.
corpus="${corpus}•"
encoded="$(
  printf '%s' "$corpus" \
    | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()))'
)"
corpus_file="$WORK_DIR/corpus.txt"
printf '%s' "$corpus" >"$corpus_file"

fetch_css() {
  local family="$1"
  local output="$2"
  curl --connect-timeout 15 --max-time 60 -fsSL \
    -A 'Mozilla/5.0' \
    "https://fonts.googleapis.com/css2?family=${family}:wght@400;700&display=swap&text=$encoded" \
    -o "$output"
}

fetch_font() {
  local css_file="$1"
  local index="$2"
  local output="$3"
  local font_url
  local source_font="$WORK_DIR/$(basename "$output").source.ttf"
  font_url="$(rg -o 'https[^)]+' "$css_file" | sed -n "${index}p")"
  if [[ -z "$font_url" ]]; then
    echo "Google Fonts did not return font URL #$index for $css_file" >&2
    exit 1
  fi
  curl --connect-timeout 15 --max-time 60 -fsSL "$font_url" -o "$source_font"
  pyftsubset "$source_font" \
    --text-file="$corpus_file" \
    --output-file="$output" \
    --layout-features='*' \
    --glyph-names \
    --symbol-cmap \
    --legacy-cmap \
    --notdef-glyph \
    --notdef-outline \
    --recommended-glyphs \
    --name-IDs='*' \
    --name-legacy \
    --name-languages='*'
}

sans_css="$WORK_DIR/noto-sans-sc.css"
serif_css="$WORK_DIR/noto-serif-sc.css"
fetch_css 'Noto+Sans+SC' "$sans_css"
fetch_css 'Noto+Serif+SC' "$serif_css"

fetch_font "$sans_css" 1 "$FONT_DIR/NotoSansSC-Golden-400.ttf"
fetch_font "$sans_css" 2 "$FONT_DIR/NotoSansSC-Golden-700.ttf"
fetch_font "$serif_css" 2 "$FONT_DIR/NotoSerifSC-Golden-700.ttf"

curl --connect-timeout 15 --max-time 30 -fsSL \
  'https://raw.githubusercontent.com/google/fonts/2894aab31764f10f29c421bdfd2340d3b382d384/ofl/notosanssc/OFL.txt' \
  -o "$FONT_DIR/OFL.txt"

echo "Golden CJK font subsets updated in $FONT_DIR"
