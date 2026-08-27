#!/usr/bin/env bash
# Apply every patch in patches/ to the extracted tree, in filename order.
source "$(dirname "$0")/_common.sh"
[ -d "$TREE" ] || { echo "no extracted tree. run: scripts/extract.sh"; exit 1; }
for p in "$ROOT"/patches/*.patch; do
  echo "==> $(basename "$p")"
  patch -p1 --forward --directory="$TREE" < "$p"
done
echo "==> all patches applied"
