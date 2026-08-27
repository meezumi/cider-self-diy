#!/usr/bin/env bash
# Restore a previous archive. Needs sudo. QUIT CIDER FIRST.
#     scripts/rollback.sh                       -> pristine (app.asar.orig)
#     scripts/rollback.sh app.asar.v1-sidebar-only
source "$(dirname "$0")/_common.sh"
DST=/opt/Cider/resources
WANT="${1:-app.asar.orig}"

if pgrep -f 'sh.cider.Cider' >/dev/null; then
  echo "Cider is still running. Quit it fully, then re-run."; exit 1
fi

if   [ -f "$BUILD/$WANT" ];   then SRC="$BUILD/$WANT"
elif [ -f "$DST/app.asar.orig" ] && [ "$WANT" = "app.asar.orig" ]; then SRC="$DST/app.asar.orig"
else echo "no such archive: $WANT (looked in build/ and $DST)"; exit 1; fi

echo "==> restoring from $SRC"
sudo install -m 0644 -o root -g root "$SRC" "$DST/app.asar"
echo "==> restored. Launch Cider."
