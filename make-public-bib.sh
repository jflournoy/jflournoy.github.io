#!/usr/bin/env bash
# Generate the BibTeX file served for download on the publications page.
#
# Flournoy.bib is a working Zotero export: it carries `file = {/home/jflournoy/
# Zotero/storage/...}` local paths and publisher-copyrighted `abstract` fields.
# Neither belongs on a public site, so strip them here and serve the result
# instead of the source. Both fields are single-line in this export.
#
# Run after editing Flournoy.bib, then re-render:
#   ./make-public-bib.sh && quarto render pubs.qmd

set -euo pipefail
cd "$(dirname "$0")"

SRC=Flournoy.bib
OUT=flournoy-publications.bib

awk '
  /^[[:space:]]*(file|abstract|keywords)[[:space:]]*=/ { next }
  { print }
' "$SRC" > "$OUT"

# Fail loudly rather than publish a file that still leaks local paths.
if grep -q '/home/' "$OUT"; then
  echo "make-public-bib.sh: $OUT still contains local paths" >&2
  exit 1
fi

echo "wrote $OUT ($(grep -c '^@' "$OUT") entries)"
