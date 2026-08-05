#!/usr/bin/env bash
# Generate the BibTeX file served for download on the publications page.
#
# Flournoy.bib is a Zotero export, regenerated automatically whenever a
# citation is added. It carries `file = {/home/jflournoy/Zotero/storage/...}`
# local paths and publisher-copyrighted `abstract` fields, neither of which
# belongs on a public site. So the site serves this stripped copy instead.
#
# Wired to `pre-render` in _quarto.yml, so it reruns on every render and
# cannot fall out of sync with Zotero's output. The generated file is
# gitignored; Flournoy.bib remains the tracked source of truth.

set -euo pipefail
cd "$(dirname "$0")"

SRC=Flournoy.bib
OUT=flournoy-publications.bib

# Drop private/bulky fields. All three are single-line in Zotero's biblatex
# export; `file` and `abstract` are the disclosure risks, `keywords` is just
# noise for a download.
awk '
  /^[[:space:]]*(file|abstract|keywords)[[:space:]]*=/ { next }
  { print }
' "$SRC" > "$OUT"

# Entry count must survive the strip — a mismatch means the awk pattern ate a
# line it should not have (e.g. Zotero switched to multi-line fields).
src_n=$(grep -c '^@' "$SRC")
out_n=$(grep -c '^@' "$OUT")
if [ "$src_n" -ne "$out_n" ]; then
  echo "make-public-bib.sh: entry count changed ($src_n -> $out_n)" >&2
  exit 1
fi

# Fail loudly rather than publish anything that still looks like a local path.
# Broader than /home/ so a Zotero export from another machine still trips it.
if grep -nE '(/home/|/Users/|/Zotero/|[A-Za-z]:\\\\)' "$OUT" >&2; then
  echo "make-public-bib.sh: $OUT still contains local paths (above)" >&2
  exit 1
fi

echo "make-public-bib.sh: wrote $OUT ($out_n entries)"
