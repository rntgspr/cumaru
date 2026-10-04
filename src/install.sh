#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/rntgspr/cumaru"
BIN_DIR="/usr/local/bin"
EXECUTABLE="cumaru"
CONFIG_DIR="$HOME/.config"
VERSION="${1:-}"

# Resolve the latest plain release when invoked directly through curl.
if [[ -z "$VERSION" ]]; then
  TAGS="$(git ls-remote --tags --refs "$REPO.git")"
  VERSION="$(printf '%s\n' "$TAGS" | sed -n 's#^.*refs/tags/##p' |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1 || true)"
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "cumaru install: no valid X.Y.Z release selected" >&2
  exit 1
fi

case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) TARGET="aarch64-apple-darwin" ;;
  Darwin/x86_64) TARGET="x86_64-apple-darwin" ;;
  Linux/aarch64|Linux/arm64) TARGET="aarch64-unknown-linux-musl" ;;
  Linux/x86_64) TARGET="x86_64-unknown-linux-musl" ;;
  *) echo "cumaru install: unsupported operating system or architecture" >&2; exit 1 ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
URL="$REPO/releases/download/$VERSION/cumaru-$TARGET"
if ! HTTP_STATUS="$(curl -fsSL "$URL" -o "$TMP_DIR/cumaru" -w '%{http_code}' 2> "$TMP_DIR/download-error")"; then
  if [[ "$HTTP_STATUS" == "404" ]]; then
    echo "$EXECUTABLE upgrade: binary file for version $VERSION was not found (HTTP 404): cumaru-$TARGET" >&2
    echo "Download: $URL" >&2
  else
    echo "$EXECUTABLE upgrade: failed to download version $VERSION from $URL" >&2
    cat "$TMP_DIR/download-error" >&2
  fi
  exit 1
fi
chmod 755 "$TMP_DIR/cumaru"

if [[ "$("$TMP_DIR/cumaru" --version)" != "cumaru $VERSION" ]]; then
  echo "cumaru install: downloaded binary does not report the selected version" >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"
CONFIG_TMP="$(mktemp "$CONFIG_DIR/.cumaru.json.XXXXXX")"
trap 'rm -rf "$TMP_DIR"; rm -f "$CONFIG_TMP"' EXIT
printf '{"version":"%s"}\n' "$VERSION" > "$CONFIG_TMP"
chmod 600 "$CONFIG_TMP"

PRIVILEGE=(env)
if [[ ! -d "$BIN_DIR" || ! -w "$BIN_DIR" ]]; then
  PRIVILEGE=(sudo)
fi

# Stage beside the installed binary so publication replaces it without truncating a running executable.
"${PRIVILEGE[@]}" mkdir -p "$BIN_DIR"
BIN_TMP="$("${PRIVILEGE[@]}" mktemp "$BIN_DIR/.cumaru.XXXXXX")"
trap 'rm -rf "$TMP_DIR"; rm -f "$CONFIG_TMP"; "${PRIVILEGE[@]}" rm -f "$BIN_TMP"' EXIT
"${PRIVILEGE[@]}" install -m 755 "$TMP_DIR/cumaru" "$BIN_TMP"
"${PRIVILEGE[@]}" mv -f "$BIN_TMP" "$BIN_DIR/$EXECUTABLE"
mv -f "$CONFIG_TMP" "$CONFIG_DIR/cumaru.json"

echo "Installed $EXECUTABLE $VERSION to $BIN_DIR/$EXECUTABLE"

# Warn when an earlier PATH entry, such as a legacy ~/.local/bin link, shadows this install.
ACTIVE="$(command -v "$EXECUTABLE" 2>/dev/null || true)"
if [[ -n "$ACTIVE" && "$ACTIVE" != "$BIN_DIR/$EXECUTABLE" ]]; then
  echo "Warning: $ACTIVE precedes $BIN_DIR/$EXECUTABLE in PATH; remove it or reorder PATH to use this install." >&2
fi
