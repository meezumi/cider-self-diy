#!/usr/bin/env bash
# Copy the pristine archive out of an installed Cider into build/.
#
# The base is TWO things: the archive and its .unpacked sidecar directory.
# Native .node binaries live in the sidecar, and extraction fails without it.
source "$(dirname "$0")/_common.sh"
DST="${1:-/opt/Cider/resources}"

mkdir -p "$BUILD"

if [ -f "$DST/app.asar.orig" ]; then
  SRC="$DST/app.asar.orig"          # backup left by scripts/install.sh
elif [ -f "$DST/app.asar" ]; then
  SRC="$DST/app.asar"               # untouched install
else
  echo "no archive found in $DST"; exit 1
fi

echo "==> archive:  $SRC"
cp "$SRC" "$ORIG"
echo "==> unpacked: $DST/app.asar.unpacked"
rm -rf "$ORIG.unpacked"
cp -r "$DST/app.asar.unpacked" "$ORIG.unpacked"
chmod -R u+w "$ORIG" "$ORIG.unpacked"

echo "==> md5: $(md5sum "$ORIG" | cut -d' ' -f1)"
echo "    expected for Cider 1.6.3 (AUR .20260321034536-2): 55c3c496efb53ad6f0c56351ba559923"
echo "    a different hash is not fatal, but the patches may not apply cleanly."
