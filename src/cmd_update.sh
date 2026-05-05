# cmd_update.sh — update the llm CLI itself (script + src/ + skills/).
#
# Source resolution (in priority order):
#
#   1. DOT_LLM_ROOT — when set in env (or in a `.env` at the current
#      directory), the CLI is updated from there. The value can be:
#      - a local directory path → the files are rsynced into the active
#        checkout (good when developing dot-llm itself);
#      - a git URL (https://, ssh://, git@..., or a path ending in `.git`)
#        → cloned shallowly into a tempdir, then rsynced into the active
#        checkout.
#
#   2. Existing git remote — when DOT_LLM_ROOT is unset and the active
#      checkout (the directory containing this `llm` script, with symlinks
#      resolved) is a git working tree with a remote, runs `git pull --ff-only`.
#      `--ref <name>` switches to a specific branch or tag instead.
#
# When neither applies, the command fails with a hint to re-bootstrap.
#
# This command runs from anywhere; it does NOT require a project. When `llm`
# is invoked via a global symlink, updating the underlying checkout
# propagates to every adopter using the symlink — no per-project action.
#
# Distinguish from `llm framework sync`:
#   - `update` updates the CLI itself globally.
#   - `framework sync` updates a project's `.llm/` tree per-project.
#
# Expects from the entry-point: SCRIPT_DIR.

cmd_update_help() {
  cat <<EOF
llm update — update the llm CLI itself

Usage:
  llm update [--ref <branch|tag>]

Options:
  --ref <name>   pull a specific branch or tag (git remote mode only).
                 Default: the current branch's upstream.

Source resolution:

  1. DOT_LLM_ROOT (env or .env at \$PWD) — directory or git URL.
     - Directory: rsync from there into the active checkout.
     - URL:       shallow clone into a tempdir, then rsync.

  2. Existing git remote on the active checkout: \`git pull --ff-only\`.

If neither is available, fails with a hint. Does NOT touch any project's
.llm/ tree — for that, use \`llm framework sync\`.
EOF
}

# Compute a short version string for a dot-llm checkout.
_llm_version_at() {
  local dir="$1"
  if [[ -d "$dir/.git" ]] && command -v git >/dev/null; then
    git -C "$dir" describe --tags --always --dirty 2>/dev/null \
      || git -C "$dir" rev-parse --short HEAD 2>/dev/null \
      || echo "?"
  else
    echo "non-git"
  fi
}

# Detect whether $1 looks like a git URL (vs a local path).
_is_git_url() {
  case "$1" in
    git@*|http://*|https://*|ssh://*) return 0 ;;
    *.git)                            return 0 ;;
    *)                                return 1 ;;
  esac
}

# Rsync the framework files we manage from $1 into $2. Avoids --delete to
# preserve local state (.git, .env, user-added files).
_sync_files_from() {
  local from="$1" to="$2"
  rsync -a \
    --include='llm' \
    --include='src/***' \
    --include='skills/***' \
    --include='dot-llm-framework/***' \
    --include='README.md' \
    --exclude='*' \
    "$from/" "$to/"
  chmod +x "$to/llm" 2>/dev/null || true
}

cmd_update() {
  local ref=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ref)          ref="${2:-}"; shift 2 ;;
      -h|--help|help) cmd_update_help; return 0 ;;
      *) red "unknown flag: $1"; cmd_update_help; return 2 ;;
    esac
  done

  # Auto-load .env from current dir (for DOT_LLM_ROOT).
  if [[ -f ".env" ]]; then
    set -a; . ./.env; set +a
  fi

  local checkout="$SCRIPT_DIR"
  local before
  before=$(_llm_version_at "$checkout")
  local source="${DOT_LLM_ROOT:-}"

  # Mode 1: DOT_LLM_ROOT (directory or URL)
  if [[ -n "$source" ]]; then
    command -v rsync >/dev/null || { red "✗ rsync not found on PATH (needed by update)"; return 1; }

    if _is_git_url "$source"; then
      command -v git >/dev/null || { red "✗ git not found on PATH"; return 1; }
      local tmpdir
      tmpdir=$(mktemp -d)
      trap 'rm -rf "$tmpdir"' RETURN
      say "Cloning DOT_LLM_ROOT=$source into $tmpdir ..."
      if ! git clone --depth 1 ${ref:+--branch "$ref"} "$source" "$tmpdir" >/dev/null 2>&1; then
        red "✗ git clone failed: $source"
        return 1
      fi
      if [[ ! -f "$tmpdir/llm" || ! -d "$tmpdir/dot-llm-framework" ]]; then
        red "✗ cloned source does not look like a dot-llm checkout"
        return 1
      fi
      say "Target: $checkout"
      say ""
      _sync_files_from "$tmpdir" "$checkout"
    else
      if [[ ! -d "$source" ]]; then
        red "✗ DOT_LLM_ROOT=$source is not a directory or recognized URL"
        return 1
      fi
      if [[ ! -f "$source/llm" || ! -d "$source/dot-llm-framework" ]]; then
        red "✗ DOT_LLM_ROOT=$source does not look like a dot-llm checkout"
        return 1
      fi
      say "Local source: $source"
      say "Target:       $checkout"
      say ""
      _sync_files_from "$source" "$checkout"
    fi

    local after
    after=$(_llm_version_at "$checkout")
    green "✓ updated from DOT_LLM_ROOT"
    say "  before: $before"
    say "  after:  $after"
    return 0
  fi

  # Mode 2: git pull on the active checkout
  command -v git >/dev/null || { red "✗ git not found on PATH"; return 1; }

  if [[ ! -d "$checkout/.git" ]]; then
    red "✗ $checkout is not a git checkout and DOT_LLM_ROOT is unset"
    yellow "  Set DOT_LLM_ROOT (env or .env) to a directory or git URL,"
    yellow "  or re-bootstrap by cloning dot-llm and re-symlinking llm."
    return 1
  fi

  if [[ -z "$(git -C "$checkout" remote)" ]]; then
    red "✗ no git remote on $checkout and DOT_LLM_ROOT is unset"
    return 1
  fi

  say "Git source: $(git -C "$checkout" config --get remote.origin.url 2>/dev/null || echo '(remote)')"
  say "Target:     $checkout"
  say ""

  if [[ -n "$ref" ]]; then
    if ! git -C "$checkout" fetch --depth 1 origin "$ref" 2>&1 | tail -3 >&2; then
      red "✗ git fetch failed for ref $ref"
      return 1
    fi
    if ! git -C "$checkout" checkout "$ref" 2>&1 | tail -3 >&2; then
      red "✗ git checkout failed for ref $ref"
      return 1
    fi
  else
    if ! git -C "$checkout" pull --ff-only 2>&1 | tail -3 >&2; then
      red "✗ git pull failed (non-fast-forward, conflict, or no upstream)"
      return 1
    fi
  fi

  local after
  after=$(_llm_version_at "$checkout")
  if [[ "$before" == "$after" ]]; then
    green "✓ already up to date ($after)"
  else
    green "✓ updated: $before → $after"
    say ""
    say "Latest commit:"
    git -C "$checkout" log -1 --format='  %h %s' 2>/dev/null
  fi
}
