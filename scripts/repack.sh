#!/usr/bin/env bash
# Repack the patched tree into build/app.asar.patched.
source "$(dirname "$0")/_common.sh"
need_deps
[ -d "$TREE" ] || { echo "no extracted tree. run: scripts/extract.sh"; exit 1; }
rm -rf "$OUT" "$OUT.unpacked"
node "$ROOT/scripts/lib/pack.js" "$TREE" "$OUT"
echo "==> unpacked files: $(find "$OUT.unpacked" -type f | wc -l)  (expected 65)"
