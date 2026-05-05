#!/usr/bin/env bash
set -euo pipefail

REPO="git@github.com:rntgspr/dot-llm.git"
DEST="$HOME/.dot-llm"
BIN="$HOME/.local/bin"

echo "Installing dot-llm to $DEST..."

if [[ -d "$DEST/.git" ]]; then
  git -C "$DEST" pull --ff-only
else
  git clone --depth=1 "$REPO" "$DEST"
fi

mkdir -p "$BIN"
ln -sf "$DEST/llm" "$BIN/llm"

echo "Done. Make sure $BIN is on your PATH."
echo "  llm help"
