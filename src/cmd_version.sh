# cmd_version.sh — distribution version of the installed snapshot, and the
# explicit staleness check behind `cumaru upgrade --check`.
#
# src/install.sh writes the installed release tag (plain `X.Y.Z`, or `main`
# when no tag existed) into VERSION at the snapshot root. A Git checkout has
# no VERSION file and reports a development build.
#
# `config.version` (the integer contract) is independent of this value; the
# release tag major must equal it.

CUMARU_REMOTE="https://github.com/rntgspr/cumaru.git"

# Prints usage for `cumaru version`.
cmd_version_help() {
  cat <<'EOF'
cumaru version — print the installed distribution and contract versions

Usage:
  cumaru version

Offline. Reads the VERSION file written by the installer: a release tag
(`X.Y.Z`) or `main`. A Git checkout reports a development build. Compare with
GitHub explicitly through `cumaru upgrade --check`.
EOF
}

# Prints the installed distribution version, or `development build` when the
# snapshot has no VERSION file.
_version_installed() {
  local installed=""

  [[ -f "$SCRIPT_DIR/VERSION" ]] && installed=$(sed -n 1p "$SCRIPT_DIR/VERSION")
  printf '%s\n' "${installed:-development build}"
}

# Prints the integer framework contract version pinned by the shipped schema.
_version_contract() {
  jq -r '.properties.version.const // "unknown"' "$SCRIPT_DIR/schemas/config.schema.json" 2>/dev/null ||
    printf 'unknown\n'
}

# Reads `X.Y.Z` lines on stdin and prints the highest one.
_version_highest() {
  sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1
}

# `cumaru version`: print the installed distribution version and the integer
# contract version. Offline; exit 0.
cmd_version() {
  case "${1:-}" in
    "") ;;
    -h|--help|help) cmd_version_help; return 0 ;;
    *) red "Unexpected argument: $1" >&2; cmd_version_help >&2; return 2 ;;
  esac

  printf 'version:  %s\n' "$(_version_installed)"
  printf 'contract: %s\n' "$(_version_contract)"
  return 0
}

# `cumaru upgrade --check`: compare the installed tag with the highest `X.Y.Z`
# tag on GitHub. Uses the network only here; never modifies ~/.cumaru.
# Exit 0 for up to date or behind; 1 when the comparison cannot be made.
cmd_upgrade_check() {
  local installed latest refs
  installed=$(_version_installed)

  printf 'installed: %s\n' "$installed"

  if ! refs=$(git ls-remote --tags --refs "$CUMARU_REMOTE" 2>/dev/null); then
    red "cannot check: unable to reach $CUMARU_REMOTE" >&2
    return 1
  fi

  latest=$(printf '%s\n' "$refs" | sed -n 's#^.*refs/tags/##p' |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | _version_highest)
  if [[ -z "$latest" ]]; then
    red "cannot check: no X.Y.Z release tag published at $CUMARU_REMOTE" >&2
    return 1
  fi

  printf 'latest:    %s\n' "$latest"

  if [[ "$installed" == "development build" ]]; then
    red "cannot check: a development build has no distribution version to compare" >&2
    return 1
  fi

  # `main` (installed before any tag) or a lower tag is behind; an equal or
  # higher tag (the latest was deleted) is up to date.
  if [[ "$installed" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ &&
        "$(printf '%s\n%s\n' "$installed" "$latest" | _version_highest)" == "$installed" ]]; then
    printf 'status:    up to date\n'
  else
    printf 'status:    behind\n'
  fi

  printf 'upgrade:   cumaru upgrade\n'
  return 0
}
