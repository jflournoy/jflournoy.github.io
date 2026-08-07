#!/usr/bin/env python3
"""Build oa-links.json: citekey -> best open-access full-text link.

Runs from `pre-render`, so new Zotero entries pick up links automatically.
Two rules keep that safe:

  * Incremental -- only entries missing from the cache are looked up, so a
    normal render makes zero network calls.
  * Never fatal -- any network failure leaves the existing cache in place and
    exits 0. A render must not break because a third-party API is down.

Use --refresh to re-check every entry (link rot, new OA versions).

Unpaywall distinguishes a direct PDF (`url_for_pdf`) from an OA landing page
(`url_for_landing_page`). Only ~a third of this bibliography has the former,
so we record which kind each link is and let the Lua filter label it
accurately -- promising "PDF" and delivering an abstract page is worse than
saying "free full text".
"""

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
BIB = os.path.join(HERE, "Flournoy.bib")
OUT = os.path.join(HERE, "oa-links.json")
EMAIL = os.environ.get("UNPAYWALL_EMAIL", "jocoflo@pm.me")
API = "https://api.unpaywall.org/v2/"


def load_entries():
    """Read the bib via pandoc, which already parses biblatex correctly."""
    proc = subprocess.run(
        ["pandoc", "-f", "biblatex", "-t", "csljson", BIB],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        sys.exit(f"pandoc failed to read {BIB}:\n{proc.stderr}")
    return json.loads(proc.stdout)


def durable(url):
    """Drop URLs that are signed and time-limited.

    Some publishers (Frontiers via Azure blob storage, notably) hand Unpaywall
    a pre-signed download link carrying its own expiry in the query string.
    Those 403 once the signature lapses -- one in this bibliography had expired
    in 2021 -- so they must never be cached as a permanent link.
    """
    if not url:
        return None
    query = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)
    if "sig" in query or "Signature" in query or "se" in query:
        return None
    if "blob.core.windows.net" in url or "amazonaws.com" in url:
        return None
    return url


def pick_location(data):
    """Choose the OA copy most likely to actually be readable.

    Unpaywall's own `best_oa_location` prefers the published version at the
    publisher, which for hybrid-OA journals is often a page that still shows a
    paywall (APA and Springer both do this). A repository copy -- PMC, PsyArXiv,
    an institutional archive -- is the accepted manuscript rather than the
    typeset version, but it is genuinely free to read, which is what the link
    promises. So rank:

      1. any direct PDF                      (best: it is the file itself)
      2. a repository landing page           (free, even if not typeset)
      3. a publisher landing page            (last resort; may be paywalled)
    """
    locations = data.get("oa_locations") or []
    if not locations and data.get("best_oa_location"):
        locations = [data["best_oa_location"]]

    def rank(loc):
        is_repo = loc.get("host_type") == "repository"
        if loc.get("url_for_pdf"):
            return 0 if is_repo else 1
        return 2 if is_repo else 3

    for loc in sorted(locations, key=rank):
        pdf = durable(loc.get("url_for_pdf"))
        landing = durable(loc.get("url_for_landing_page"))
        if not (pdf or landing):
            continue
        return {
            "url": pdf or landing,
            "kind": "pdf" if pdf else "landing",
            "host": loc.get("host_type"),
            "version": loc.get("version"),
        }
    return None


def query(doi):
    url = API + urllib.parse.quote(doi) + "?email=" + urllib.parse.quote(EMAIL)
    with urllib.request.urlopen(url, timeout=30) as resp:
        return json.load(resp)


def load_cache():
    if not os.path.exists(OUT):
        return {}
    try:
        with open(OUT) as fh:
            return json.load(fh)
    except (json.JSONDecodeError, OSError):
        return {}  # corrupt cache: rebuild rather than crash the render


def main():
    refresh = "--refresh" in sys.argv
    entries = load_entries()
    links = {} if refresh else load_cache()

    # Only look up what we don't already have; a normal render hits the
    # network zero times.
    todo = [
        (e["id"], e["DOI"])
        for e in entries
        if e.get("DOI") and e["id"] not in links
    ]
    print(f"{len(entries)} entries; {len(todo)} need lookup, {len(links)} cached")

    failures = []
    for i, (key, doi) in enumerate(todo, 1):
        try:
            data = query(doi)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            failures.append((key, str(exc)[:80]))
            continue

        chosen = pick_location(data)
        if chosen:
            links[key] = chosen
        time.sleep(0.12)  # be polite to a free API
        if i % 15 == 0:
            print(f"  ...{i}/{len(todo)}", file=sys.stderr)

    if failures:
        # Unreachable entries simply stay unlinked this run; the cache keeps
        # whatever it already had. Never fatal -- see module docstring.
        print(f"\n{len(failures)} lookup(s) failed (entries left unlinked):")
        for key, err in failures[:5]:
            print(f"  {key}: {err}")

    # Drop entries no longer in the bib so the cache can't outlive its source.
    valid = {e["id"] for e in entries}
    orphans = [k for k in links if k not in valid]
    for k in orphans:
        del links[k]
    if orphans:
        print(f"removed {len(orphans)} orphaned key(s): {', '.join(orphans)}")

    with open(OUT, "w") as fh:
        json.dump(dict(sorted(links.items())), fh, indent=1, sort_keys=True)
        fh.write("\n")

    n_pdf = sum(1 for v in links.values() if v["kind"] == "pdf")
    print(
        f"\nwrote oa-links.json: {len(links)}/{len(entries)} entries linked "
        f"({n_pdf} direct PDF, {len(links) - n_pdf} OA landing page)"
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001 -- must never break a render
        print(f"fetch-oa-links: skipped ({type(exc).__name__}: {exc})",
              file=sys.stderr)
        sys.exit(0)
