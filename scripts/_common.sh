# Shared setup for the build scripts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
BUILD="$ROOT/build"
TREE="$BUILD/asar"
ORIG="$BUILD/app.asar.orig"
OUT="$BUILD/app.asar.patched"

need_deps() {
  [ -d "$ROOT/node_modules/@electron/asar" ] || {
    echo "dependencies missing. run:  npm install"; exit 1; }
}
need_orig() {
  [ -f "$ORIG" ] || {
    echo "missing build/app.asar.orig"
    echo "see README, 'Getting the base archive' -- it is not in this repo on purpose."
    exit 1; }
}
