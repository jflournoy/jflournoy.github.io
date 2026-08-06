#!/usr/bin/env bash
# Refresh oa-links.json — the open-access full-text link for each publication.
#
# Wired to `pre-render` in _quarto.yml. It only looks up entries missing from
# the cache, so an ordinary render makes no network calls; adding a paper in
# Zotero picks up its link on the next render automatically. Network failures
# are non-fatal — see fetch-oa-links.py.
#
# To re-check every entry (link rot, newly-deposited OA versions):
#
#   ./fetch-oa-links.sh --refresh
#
# Only DOIs (public metadata) are sent. Unpaywall requires a contact email;
# override with UNPAYWALL_EMAIL.

set -euo pipefail
cd "$(dirname "$0")"
exec python3 fetch-oa-links.py "$@"
