#!/usr/bin/env bash
# Tests for project-tags.lua: the happy path tags the right entries, and every
# misconfiguration that would put wrong tags on the page fails the render.
#
# Runs on the host pandoc (no container needed):
#
#   tests/test-project-tags.sh

set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
filter="$here/project-tags.lua"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

cat > refs.bib <<'EOF'
@article{alphaPaper2020,
  title = {Alpha},
  author = {Flournoy, John C.},
  date = {2020},
  journaltitle = {J},
}
@article{betaPaper2021,
  title = {Beta},
  author = {Flournoy, John C.},
  date = {2021},
  journaltitle = {J},
}
EOF

cat > doc.md <<'EOF'
---
bibliography: refs.bib
nocite: |
  @*
---

::: {#refs}
:::
EOF

pass=0
fail=0

render() {
  pandoc doc.md --citeproc --lua-filter "$filter" -t html 2>err.txt > out.html
}

ok() { echo "ok   - $1"; pass=$((pass + 1)); }
not_ok() { echo "FAIL - $1"; fail=$((fail + 1)); }

expect_error() {
  local name="$1" pattern="$2"
  if render; then
    not_ok "$name (render succeeded, expected an error)"
  elif grep -q -- "$pattern" err.txt; then
    ok "$name"
  else
    not_ok "$name (error did not mention '$pattern'):"
    sed 's/^/       /' err.txt
  fi
}

write_good() {
  cat > projects.json <<'EOF'
{
  "projects": [
    { "id": "AAA", "label": "A-A", "name": "Study A", "url": "https://example.org/a" },
    { "id": "BBB", "label": "B", "name": "Study B" }
  ],
  "papers": {
    "_comment": "underscore keys are ignored",
    "alphaPaper2020": ["AAA", "BBB"],
    "betaPaper2021": ["BBB"]
  }
}
EOF
}

# --- happy path -------------------------------------------------------------
write_good
if render; then
  ok "valid config renders"
  grep -q 'id="ref-alphaPaper2020"[^>]*data-projects="AAA BBB"' out.html \
    && ok "entry carries all its project ids" || not_ok "entry carries all its project ids"
  grep -q 'id="ref-betaPaper2021"[^>]*data-projects="BBB"' out.html \
    && ok "second entry tagged" || not_ok "second entry tagged"
  [ "$(grep -o 'class="pub-project"' out.html | wc -l)" -eq 3 ] \
    && ok "one tag link per (paper, project) pair" || not_ok "one tag link per (paper, project) pair"
  grep -q 'href="#project-AAA"' out.html \
    && ok "tag links to the filter hash" || not_ok "tag links to the filter hash"
  grep -q 'data-project="AAA"[^>]*>A-A <span class="pub-project-count">1</span>' out.html \
    && ok "filter bar counts AAA once" || not_ok "filter bar counts AAA once"
  grep -q 'data-project="BBB"[^>]*>B <span class="pub-project-count">2</span>' out.html \
    && ok "filter bar counts BBB twice" || not_ok "filter bar counts BBB twice"
  grep -q 'project-tags.lua: 2/2 entries tagged (AAA=1, BBB=2)' err.txt \
    && ok "coverage line logged" || not_ok "coverage line logged"
else
  not_ok "valid config renders:"
  sed 's/^/       /' err.txt
fi

# --- failures ---------------------------------------------------------------
rm -f projects.json
expect_error "missing projects.json" "projects.json not found"

echo '{ "projects": [' > projects.json
expect_error "malformed JSON" "could not parse"

write_good
sed -i 's/"betaPaper2021": \["BBB"\]/"betaPaper2021": ["CCC"]/' projects.json
expect_error "undefined project id" "undefined project id 'CCC'"

write_good
sed -i 's/"betaPaper2021"/"betaPaper2021a"/' projects.json
expect_error "citekey not in bibliography" "match no bibliography entry: betaPaper2021a"

write_good
sed -i 's/"alphaPaper2020": \["AAA", "BBB"\]/"alphaPaper2020": ["BBB"]/' projects.json
expect_error "project with no papers" "no tagged papers.*AAA"

write_good
sed -i 's/"betaPaper2021": \["BBB"\]/"betaPaper2021": []/' projects.json
expect_error "empty project list for a paper" "non-empty array of project ids"

write_good
sed -i 's/"betaPaper2021": \["BBB"\]/"betaPaper2021": ["BBB", "BBB"]/' projects.json
expect_error "duplicate project on one paper" "lists 'BBB' twice"

write_good
sed -i 's/"id": "BBB"/"id": "AAA"/' projects.json
expect_error "duplicate project id" "defined twice"

write_good
sed -i 's/, "name": "Study B"//' projects.json
expect_error "project missing name" "missing \`name\`"

write_good
sed -i 's#https://example.org/a#ftp://example.org/a#' projects.json
expect_error "non-http url" "not http(s)"

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
