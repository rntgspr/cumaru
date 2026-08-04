#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd -P)
DOMAINS_DIR="$ROOT_DIR/domains"
BASE_DIR="$DOMAINS_DIR/__base"
MODE=check

usage() {
  cat <<'EOF'
Usage: scripts/sync-domain-kernel.sh [--check|--apply]

Synchronize universal Cumaru kernel artifacts from domains/__base into every
shipped domain. Domain-owned skills/cumaru-install/ and disciplines/index.md
are never changed.

  --check  report missing or divergent mirrors without modifying files (default)
  --apply  copy missing or divergent mirrors from domains/__base
EOF
}

case ${1-} in
  '') ;;
  --check) MODE=check ;;
  --apply) MODE=sync ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

[[ $# -le 1 ]] || { usage >&2; exit 2; }
[[ -f "$BASE_DIR/index.md" ]] || {
  printf 'error: canonical domain not found at %s\n' "$BASE_DIR" >&2
  exit 1
}

status=0

sync_file() {
  src=$1
  dest=$2
  rel=${dest#"$ROOT_DIR"/}

  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    return
  fi

  if [[ "$MODE" == check ]]; then
    if [[ -e "$dest" ]]; then
      printf 'divergent: %s\n' "$rel"
    else
      printf 'missing: %s\n' "$rel"
    fi
    status=1
    return
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  printf 'synced: %s\n' "$rel"
}

for domain_dir in "$DOMAINS_DIR"/*/; do
  domain_dir=${domain_dir%/}
  [[ "$domain_dir" == "$BASE_DIR" ]] && continue
  sync_file "$BASE_DIR/index.md" "$domain_dir/index.md"

  while IFS= read -r src; do
    rel=${src#"$BASE_DIR"/}
    case "$rel" in
      skills/cumaru-install/*|disciplines/index.md) continue ;;
    esac
    sync_file "$src" "$domain_dir/$rel"
  done < <(find "$BASE_DIR/skills" "$BASE_DIR/commands" "$BASE_DIR/disciplines" -type f 2>/dev/null | LC_ALL=C sort)
done

if [[ "$MODE" == check && $status -eq 0 ]]; then
  printf 'Universal domain artifacts are synchronized.\n'
fi

exit "$status"
