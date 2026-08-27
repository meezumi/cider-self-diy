#!/usr/bin/env bash
# extract -> patch -> repack -> verify, from the pristine archive.
source "$(dirname "$0")/_common.sh"
[ -f "$ORIG" ] || "$ROOT/scripts/fetch-base.sh"
"$ROOT/scripts/extract.sh"
"$ROOT/scripts/apply-patches.sh"
"$ROOT/scripts/repack.sh"
"$ROOT/scripts/verify.sh" "$@"
