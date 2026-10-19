#!/usr/bin/env bash
# Fetch a fresh Apple Music developer token for Cider, check it, and print
# the command that puts it in the launcher.
#
# Cider 1.6.3 gets its developer token from api.cider.sh, which is gone, and
# falls back to the TOKEN environment variable in its launcher. The token
# that works is the one Apple's own web player ships in its JavaScript
# (kid WebPlayKid, iss AMPWebPlay). It lasts about ten weeks, after which
# Cider stops at "token expired" on launch.
#
# This script never edits the launcher and never prints the token. It saves
# the token to a private file and prints the line to run.
#
#   ./scripts/refresh-token.sh           fetch, verify, save, print the command
#   ./scripts/refresh-token.sh --check   only report the launcher token's expiry
set -euo pipefail

LAUNCHER="${CIDER_LAUNCHER:-$HOME/.local/share/applications/sh.cider.Cider.desktop}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cider-self-diy"
TOKEN_FILE="$STATE_DIR/developer-token"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

for tool in curl python3; do
  command -v "$tool" >/dev/null || { echo "error: $tool is required" >&2; exit 1; }
done

# Prints "<iss> <kid> <exp-epoch>" for a JWT on stdin, or fails.
describe_jwt() {
  python3 -I -c '
import sys, json, base64
parts = sys.stdin.read().strip().split(".")
if len(parts) != 3:
    sys.exit(1)
def seg(s):
    return json.loads(base64.urlsafe_b64decode(s + "=" * (-len(s) % 4)))
head, body = seg(parts[0]), seg(parts[1])
print(body.get("iss", "?"), head.get("kid", "?"), int(body.get("exp", 0)))
'
}

days_left() { python3 -I -c 'import sys, time; print(int((int(sys.argv[1]) - time.time()) // 86400))' "$1"; }
as_date() { date -u -d "@$1" +%Y-%m-%d; }

launcher_token() {
  [ -f "$LAUNCHER" ] || return 1
  grep -oE 'TOKEN=eyJ[A-Za-z0-9._-]+' "$LAUNCHER" | head -n 1 | cut -d= -f2
}

report_launcher() {
  local tok info exp
  if ! tok="$(launcher_token)" || [ -z "$tok" ]; then
    echo "launcher:  no TOKEN=eyJ... in $LAUNCHER"
    return 0
  fi
  if ! info="$(printf '%s' "$tok" | describe_jwt)"; then
    echo "launcher:  token present but not a readable JWT"
    return 0
  fi
  exp="${info##* }"
  echo "launcher:  token expires $(as_date "$exp") ($(days_left "$exp") days)"
}

if [ "${1:-}" = "--check" ]; then
  report_launcher
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "==> fetching the web player"
curl -fsSL -A "$UA" "https://music.apple.com/us/browse" -o "$work/page.html"
grep -oE '/assets/index[~.-][A-Za-z0-9._~-]*\.js' "$work/page.html" | sort -u > "$work/assets.txt" || true
if [ ! -s "$work/assets.txt" ]; then
  echo "error: no /assets/index*.js on music.apple.com -- the page layout has changed" >&2
  exit 1
fi

# The token is a JWT whose header starts {"typ":... or {"alg":...
token=""
while read -r asset; do
  curl -fsSL -A "$UA" "https://music.apple.com$asset" -o "$work/asset.js" || continue
  token="$(grep -oE 'eyJ(0eXAi|hbGci)[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' "$work/asset.js" | head -n 1 || true)"
  [ -n "$token" ] && break
done < "$work/assets.txt"
if [ -z "$token" ]; then
  echo "error: no token found in the web player's scripts" >&2
  exit 1
fi

read -r iss kid exp < <(printf '%s' "$token" | describe_jwt) || { echo "error: found token is not a readable JWT" >&2; exit 1; }
left="$(days_left "$exp")"
echo "==> found token: iss=$iss kid=$kid, expires $(as_date "$exp") ($left days)"
if [ "$iss" != "AMPWebPlay" ]; then
  echo "warning: expected iss=AMPWebPlay; Apple may have changed how the web player signs in" >&2
fi
if [ "$left" -lt 7 ]; then
  echo "error: token expires in under a week -- try again later" >&2
  exit 1
fi

echo "==> checking it with Apple"
status="$(curl -s -o /dev/null -w '%{http_code}' -A "$UA" \
  -H "Authorization: Bearer $token" -H "Origin: https://music.apple.com" \
  "https://amp-api.music.apple.com/v1/catalog/us/search?term=test&types=songs&limit=1")"
if [ "$status" != "200" ]; then
  echo "error: Apple answered HTTP $status for the new token" >&2
  exit 1
fi
echo "    Apple accepts it (HTTP 200)"

old="$(launcher_token || true)"
if [ -n "$old" ] && [ "$old" = "$token" ]; then
  echo "==> the launcher already has this token -- nothing to do"
  report_launcher
  exit 0
fi

mkdir -p "$STATE_DIR"
umask 077
printf '%s' "$token" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"
echo "==> saved to $TOKEN_FILE (mode 600)"
report_launcher

cat <<EOF

Quit Cider, then run this to put it in the launcher (keeps a .bak copy):

  F="$LAUNCHER"; cp -p "\$F" "\$F.bak" && sed -i -E "s/TOKEN=eyJ[A-Za-z0-9._-]+/TOKEN=\$(cat "$TOKEN_FILE")/" "\$F" && echo updated

Then start Cider from the app menu, not a terminal.
EOF
