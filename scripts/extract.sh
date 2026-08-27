#!/usr/bin/env bash
# Extract the pristine archive into build/asar/ for patching.
source "$(dirname "$0")/_common.sh"
need_deps; need_orig
[ -d "$ORIG.unpacked" ] || {
  echo "missing build/app.asar.orig.unpacked/"
  echo "the base archive needs its sidecar dir too. run: scripts/fetch-base.sh"
  exit 1; }
rm -rf "$TREE"
node "$ROOT/scripts/lib/extract.js" "$ORIG" "$TREE"
