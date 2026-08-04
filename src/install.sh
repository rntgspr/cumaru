#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/rntgspr/cumaru"
DEST="$HOME/.cumaru"
BIN="$HOME/.local/bin"

# $DEST is treated as a plain framework snapshot, not a working tree the
# user maintains. Every run replaces it wholesale with GitHub's tarball of the
# highest plain `X.Y.Z` release tag (or `main` while no tag exists). GitHub's
# archive honors .gitattributes `export-ignore`, so maintainer-only paths never
# ship. No clone: Git is needed only for `ls-remote`. This is the upgrade path —
# no prompt before overwrite by design.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! TAGS="$(git ls-remote --tags --refs "$REPO.git")"; then
  echo "✗ cannot list release tags at $REPO.git; $DEST left untouched" >&2
  exit 1
fi

VERSION="$(printf '%s\n' "$TAGS" | sed -n 's#^.*refs/tags/##p' |
  grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1 || true)"
if [[ -n "$VERSION" ]]; then
  URL="$REPO/archive/refs/tags/$VERSION.tar.gz"
else
  VERSION="main"
  URL="$REPO/archive/refs/heads/main.tar.gz"
fi

echo "Installing cumaru $VERSION to $DEST..."

# Download and unpack into the temporary directory first, so a network or
# archive failure leaves the existing $DEST untouched.
mkdir "$TMP_DIR/snapshot"
if ! curl -fsSL "$URL" -o "$TMP_DIR/cumaru.tar.gz" ||
   ! tar -xzf "$TMP_DIR/cumaru.tar.gz" -C "$TMP_DIR/snapshot" --strip-components=1; then
  echo "✗ download failed: $URL; $DEST left untouched" >&2
  exit 1
fi
printf '%s\n' "$VERSION" > "$TMP_DIR/snapshot/VERSION"

rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mv "$TMP_DIR/snapshot" "$DEST"

# Kernel integrity check: index.md, every universal skill under skills/, every
# command under commands/cumaru/, and every universal discipline under
# disciplines/ are authored once in domains/__base and propagated verbatim into
# every domain. A snapshot where any domain's copy of a universal artifact
# diverges from __base's is a broken distribution — refuse it.
#
# Exception: skills/cumaru-install/ is DOMAIN-OWNED — its post-install recipe
# hands off to the domain's durable-pillar skill (cumaru-specs / cumaru-topology /
# cumaru-coverage), so each domain ships its own tuned copy.
#
# Exception: disciplines/index.md is DOMAIN-OWNED — it carries that domain's own
# trigger table, which lists domain-specific disciplines alongside the universal ones.
BASE_DIR="$DEST/domains/__base"

# 1) index.md — single file at the domain root.
for domain_index in "$DEST"/domains/*/index.md; do
  [[ "$domain_index" == "$BASE_DIR/index.md" ]] && continue
  if ! cmp -s "$BASE_DIR/index.md" "$domain_index"; then
    echo "✗ kernel drift: $domain_index differs from domains/__base/index.md" >&2
    echo "  The snapshot is inconsistent — report this upstream. Aborting." >&2
    exit 1
  fi
done

# 2) Universal skills + commands + disciplines — every file under __base/skills/,
# __base/commands/ and __base/disciplines/ must exist byte-identical in each domain.
while IFS= read -r src; do
  rel="${src#"$BASE_DIR"/}"
  case "$rel" in
    skills/cumaru-install/*) continue ;;   # domain-owned — see the exception note above
    disciplines/index.md)    continue ;;   # domain-owned — see the exception note above
  esac
  for domain_dir in "$DEST"/domains/*/; do
    domain_dir="${domain_dir%/}"
    [[ "$domain_dir" == "$BASE_DIR" ]] && continue
    dest="$domain_dir/$rel"
    if [[ ! -f "$dest" ]]; then
      echo "✗ kernel drift: $dest missing (must mirror domains/__base/$rel verbatim)" >&2
      exit 1
    fi
    if ! cmp -s "$src" "$dest"; then
      echo "✗ kernel drift: $dest differs from domains/__base/$rel" >&2
      exit 1
    fi
  done
done < <(find "$BASE_DIR"/skills "$BASE_DIR"/commands "$BASE_DIR"/disciplines -type f 2>/dev/null)

mkdir -p "$BIN"
ln -sf "$DEST/cumaru" "$BIN/cumaru"

echo "Done. Make sure $BIN is on your PATH."
echo "  cumaru help"
