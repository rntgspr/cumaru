#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-intake-layout.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok: %s\n' "$*"; }

PROJECT="$TMP/project"
MOCK_BIN="$TMP/mock-bin"
mkdir -p "$PROJECT" "$MOCK_BIN"
cp -R "$ROOT/domains/sdlc-full" "$PROJECT/.cumaru"
yq -i --front-matter=process '.tracker = ["clickup"]' "$PROJECT/.cumaru/intake/index.md"

cat > "$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-o" ]]; then out="$2"; shift 2; continue; fi
  shift
done
printf '%s\n' '{"name":"Flat intake item","status":{"status":"Open"},"text_content":"Tracker body"}' > "$out"
printf '200'
EOF
chmod +x "$MOCK_BIN/curl"

(cd "$PROJECT" && PATH="$MOCK_BIN:$PATH" CLICKUP_API_TOKEN=test \
  bash "$ROOT/cumaru" intake ABC-42 --tracker clickup) > "$TMP/first.out" 2>&1 \
  || { sed 's/^/  /' "$TMP/first.out" >&2; fail "first intake sync failed"; }

ITEM="$PROJECT/.cumaru/intake/ABC-42.md"
[[ -f "$ITEM" ]] || fail "sdlc-full intake did not create a flat Markdown file"
[[ ! -d "$PROJECT/.cumaru/intake/ABC-42" ]] || fail "sdlc-full intake created a legacy item directory"
[[ "$(yq --front-matter=extract -r '.key' "$ITEM")" == "ABC-42" ]] || fail "flat intake item lost its key"
[[ "$(yq --front-matter=extract -r '.tracker' "$ITEM")" == "clickup" ]] || fail "flat intake item lost its tracker"

(cd "$PROJECT" && PATH="$MOCK_BIN:$PATH" CLICKUP_API_TOKEN=test \
  bash "$ROOT/cumaru" intake ABC-42) > "$TMP/refresh.out" 2>&1 \
  || { sed 's/^/  /' "$TMP/refresh.out" >&2; fail "intake refresh failed"; }

grep -q 'refreshed .cumaru/intake/ABC-42.md' "$TMP/refresh.out" \
  || fail "intake refresh did not preserve the flat path"
pass "sdlc-full intake uses one Markdown file per tracker item"
