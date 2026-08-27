#!/usr/bin/env bash
# Check the built archive against the recorded manifest, and optionally
# deep-compare it against a reference archive:
#     scripts/verify.sh [reference-app.asar]
source "$(dirname "$0")/_common.sh"
need_deps
[ -f "$OUT" ] || { echo "nothing built. run: scripts/repack.sh"; exit 1; }

echo "==> archive checksum"
built="$(md5sum "$OUT" | cut -d' ' -f1)"
expected="$(awk '$2=="app.asar.patched"{print $1}' "$ROOT/manifest/archives.md5")"
echo "    built:    $built"
echo "    manifest: ${expected:-<none recorded>}"
if [ -n "${expected:-}" ] && [ "$built" = "$expected" ]; then
  echo "    MATCH -- byte-identical to the recorded build"
else
  echo "    NO MATCH -- expected on a different base archive; check the deep compare below"
fi

echo "==> unpacked native modules"
if (cd "$OUT.unpacked" && find . -type f -exec md5sum {} \; | sort) \
     | diff -q - "$ROOT/manifest/unpacked.md5" >/dev/null; then
  echo "    OK -- all $(wc -l < "$ROOT/manifest/unpacked.md5") files match the manifest"
else
  echo "    MISMATCH -- native modules differ. AirPlay is the usual casualty."
  (cd "$OUT.unpacked" && find . -type f -exec md5sum {} \; | sort) \
    | diff - "$ROOT/manifest/unpacked.md5" | head
fi

if [ $# -ge 1 ]; then
  echo "==> deep compare against $1"
  node "$ROOT/scripts/lib/compare.js" "$OUT" "$1"
fi
