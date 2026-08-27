#!/usr/bin/env bash
# Install the patched archive into /opt/Cider. Needs sudo. QUIT CIDER FIRST.
source "$(dirname "$0")/_common.sh"
DST=/opt/Cider/resources

[ -f "$OUT" ]  || { echo "nothing built. run: scripts/build-all.sh"; exit 1; }
[ -f "$ORIG" ] || { echo "missing build/app.asar.orig -- refusing to install without a backup"; exit 1; }

if pgrep -f 'sh.cider.Cider' >/dev/null; then
  echo "Cider is still running. Quit it fully, then re-run."; exit 1
fi

# Keep a second copy of the pristine archive next to the installed one, so a
# rollback is possible even if this checkout goes away.
if [ ! -f "$DST/app.asar.orig" ]; then
  echo "==> placing backup in /opt as well"
  sudo install -m 0644 -o root -g root "$ORIG" "$DST/app.asar.orig"
fi

echo "==> installing patched archive"
sudo install -m 0644 -o root -g root "$OUT" "$DST/app.asar"
echo "==> done. Launch Cider."
