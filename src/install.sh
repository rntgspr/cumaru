#!/usr/bin/env bash
set -euo pipefail

REPO="git@github.com:rntgspr/dot-llm.git"
DEST="$HOME/.cumaru"
BIN="$HOME/.local/bin"

echo "Installing cumaru to $DEST..."

# $DEST is treated as a plain framework snapshot, not a working tree the
# user maintains. Every run replaces it wholesale: wipe, fresh shallow
# clone, strip .git/ so re-runs cannot diverge or be blocked by a dirty
# index. This is the upgrade path — no prompt before overwrite by design.
rm -rf "$DEST"
git clone --depth=1 "$REPO" "$DEST"
rm -rf "$DEST/.git"

# Kernel integrity check: index.md, every universal skill under skills/, every
# hook under hooks/, and every command under commands/cumaru/ are authored once in
# frameworks/__base and propagated verbatim into every domain. A snapshot where
# any domain's copy of a universal artifact diverges from __base's is a broken
# distribution — refuse it.
#
# Exception: skills/cumaru-install/ is DOMAIN-OWNED — its post-install recipe
# hands off to the domain's durable-pillar skill (cumaru-specs / cumaru-topology /
# cumaru-coverage), so each domain ships its own tuned copy.
BASE_DIR="$DEST/frameworks/__base"

# 1) index.md — single file at the domain root.
for domain_index in "$DEST"/frameworks/*/index.md; do
  [[ "$domain_index" == "$BASE_DIR/index.md" ]] && continue
  if ! cmp -s "$BASE_DIR/index.md" "$domain_index"; then
    echo "✗ kernel drift: $domain_index differs from frameworks/__base/index.md" >&2
    echo "  The snapshot is inconsistent — report this upstream. Aborting." >&2
    exit 1
  fi
done

# 2) Universal skills + hooks + commands — every file under __base/skills/,
# __base/hooks/, and __base/commands/ must exist byte-identical in each domain.
while IFS= read -r src; do
  rel="${src#"$BASE_DIR"/}"
  case "$rel" in
    skills/cumaru-install/*) continue ;;   # domain-owned — see the exception note above
  esac
  for domain_dir in "$DEST"/frameworks/*/; do
    domain_dir="${domain_dir%/}"
    [[ "$domain_dir" == "$BASE_DIR" ]] && continue
    dest="$domain_dir/$rel"
    if [[ ! -f "$dest" ]]; then
      echo "✗ kernel drift: $dest missing (must mirror frameworks/__base/$rel verbatim)" >&2
      exit 1
    fi
    if ! cmp -s "$src" "$dest"; then
      echo "✗ kernel drift: $dest differs from frameworks/__base/$rel" >&2
      exit 1
    fi
  done
done < <(find "$BASE_DIR"/skills "$BASE_DIR"/hooks "$BASE_DIR"/commands -type f 2>/dev/null)

mkdir -p "$BIN"
ln -sf "$DEST/cumaru" "$BIN/cumaru"

echo "Done. Make sure $BIN is on your PATH."
echo "  cumaru help"
