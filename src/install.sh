#!/usr/bin/env bash
set -euo pipefail

REPO="git@github.com:rntgspr/dot-llm.git"
DEST="$HOME/.dot-llm"
BIN="$HOME/.local/bin"

echo "Installing dot-llm to $DEST..."

# $DEST is treated as a plain framework snapshot, not a working tree the
# user maintains. Every run replaces it wholesale: wipe, fresh shallow
# clone, strip .git/ so re-runs cannot diverge or be blocked by a dirty
# index. This is the upgrade path — no prompt before overwrite by design.
rm -rf "$DEST"
git clone --depth=1 "$REPO" "$DEST"
rm -rf "$DEST/.git"

mkdir -p "$BIN"
ln -sf "$DEST/llm" "$BIN/llm"

echo "Done. Make sure $BIN is on your PATH."
echo "  llm help"
