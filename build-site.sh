#!/usr/bin/env bash
# Build the whole site in the verse-cmdstan container.
#
# Quarto, XeLaTeX and the R toolchain live in the container, not on the host,
# so every render has to go through docker. This wraps the invocation
# documented in CLAUDE.md and handles the three things that bite when you type
# it by hand:
#
#   1. The container runs as root, so output lands root-owned and git can no
#      longer touch it. Ownership is handed back on the way out, including
#      when the render fails partway.
#   2. `quarto render <file>` prunes _site/site_libs to that one page, and two
#      files in one invocation render both into _site/index.html. This script
#      only ever does a full-site render, so neither can happen.
#   3. _site/ is git-tracked and is exactly what the Pages workflow deploys,
#      so a clobbered index.html publishes. Checked before we report success.
#
# The TeX Live packages reinstall on every run because --rm makes the
# container ephemeral, and `tlmgr update --self` is needed whenever the CTAN
# mirror carries a newer tlmgr than the image. Costs under a minute.
#
#   ./build-site.sh
#
# Renders into _site/. Does not commit and does not push — review the diff,
# then commit _site/ to deploy.

set -euo pipefail
cd "$(dirname "$0")"

IMAGE=jflournoy/verse-cmdstan
MOUNT=/home/rstudio/code/johnflournoy.science

if [ "$#" -gt 0 ]; then
  echo "build-site.sh: takes no arguments (full-site render only)" >&2
  echo "" >&2
  echo "Rendering a single .qmd prunes _site/site_libs to that one page, and" >&2
  echo "passing two renders both into _site/index.html. Both publish from" >&2
  echo "main, so this script does not offer either." >&2
  exit 2
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "build-site.sh: docker image $IMAGE not found locally" >&2
  echo "Pull it with: docker pull $IMAGE" >&2
  exit 1
fi

echo "build-site.sh: rendering in $IMAGE (this takes a few minutes)"
echo ""

docker run --rm -i \
  -e HOST_UID="$(id -u)" \
  -e HOST_GID="$(id -g)" \
  -v "$(pwd)":"$MOUNT" \
  -w "$MOUNT" \
  "$IMAGE" bash -s <<'CONTAINER'
set -uo pipefail

# Hand ownership back on every exit path, not just the happy one: a render
# that dies halfway still leaves root-owned files in _site/ and .quarto/.
# --from=0 touches only what this container created.
give_back_ownership() {
  status=$?
  if ! chown --from=0 -R "$HOST_UID:$HOST_GID" .; then
    echo "build-site.sh: chown failed — files may remain root-owned" >&2
  fi
  exit $status
}
trap give_back_ownership EXIT

set -e
tlmgr option repository https://mirror.ctan.org/systems/texlive/tlnet
tlmgr update --self
tlmgr install fontawesome5 enumitem changepage sectsty
set +e

quarto render
CONTAINER

echo ""

# _site/ is what GitHub Pages serves. A render that silently wrote the wrong
# page into index.html would otherwise reach the live site on the next commit.
if [ ! -f _site/index.html ]; then
  echo "build-site.sh: render finished but _site/index.html is missing" >&2
  exit 1
fi

if ! grep -q 'John C. Flournoy' _site/index.html; then
  echo "build-site.sh: _site/index.html is not the home page" >&2
  grep -o '<title>[^<]*</title>' _site/index.html >&2 || true
  exit 1
fi

echo "build-site.sh: rendered $(grep -o '<title>[^<]*</title>' _site/index.html)"
echo ""
# Render outputs that are tracked: _site/ is the published site, oa-links.json is the
# cache the pre-render hook refreshes, cv.tex is keep-tex output. Listing only _site/
# would leave the other two behind in a commit. Deliberately not the whole tree — that
# would sweep in editor and tool state. awk rather than `head`, which would close the
# pipe early and take git down with SIGPIPE under `set -o pipefail`.
echo "Changed files (all of these belong in the commit):"
changed=$(git status --short -- _site/ oa-links.json cv.tex)
if [ -z "$changed" ]; then
  echo "  (none — output matches what is already committed)"
else
  printf '%s\n' "$changed" | awk 'NR<=20'
  n_changed=$(printf '%s\n' "$changed" | wc -l)
  if [ "$n_changed" -gt 20 ]; then
    echo "  ... and $((n_changed - 20)) more"
  fi
fi
echo ""
echo "_site/ is git-tracked and is what Pages deploys. Review, then commit to publish."
