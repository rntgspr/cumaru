Include tests/spec/update/support/update_helpers.sh

Describe 'every update dry-run'
  setup_dry_run() {
    update_tmp_create
    SOURCE="$UPDATE_TMP/source"; make_update_source "$SOURCE" 'Dry-run'
    PROJECT="$UPDATE_TMP/project"; install_base "$PROJECT" >/dev/null
    mkdir -p "$PROJECT/.agents/adopter-fixture" "$PROJECT/.claude" "$PROJECT/.codex" "$PROJECT/.opencode"
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$PROJECT/.agents/adopter-fixture/tool.sh"; chmod 755 "$PROJECT/.agents/adopter-fixture/tool.sh"
    ln -s tool.sh "$PROJECT/.agents/adopter-fixture/tool-link"
    printf '%s\n' 'adopter claude instructions' > "$PROJECT/CLAUDE.md"
    printf '%s\n' 'adopter codex instructions' > "$PROJECT/AGENTS.md"
    printf '%s\n' '{"instructions":["project.md"]}' > "$PROJECT/opencode.json"
    printf '%s\n' '{"project":true}' > "$PROJECT/.claude/project.json"
    printf '%s\n' '{"project":true}' > "$PROJECT/.codex/project.json"
    printf '%s\n' 'project command' > "$PROJECT/.opencode/project.md"
    snapshot_live "$PROJECT" "$UPDATE_TMP/baseline"
  }
  cleanup() { update_tmp_remove; }
  BeforeEach 'setup_dry_run'
  AfterEach 'cleanup'

  preview_is_read_only() {
    local expected="$1"; shift
    output=$(run_cumaru "$PROJECT" update "$@") || return
    [[ "$output" == *"$expected"* ]] || return 1
    snapshots_match "$PROJECT" "$UPDATE_TMP/baseline" >/dev/null && no_transaction_debris "$PROJECT"
  }

  Parameters
    'Update review (v7 steady state)' --from SOURCE
    'Path filter: domain.md' domain.md --from SOURCE
    'Dry-run only. Re-run with --apply to replace Cumaru skills for claude.' skills claude --from SOURCE
    'Dry-run only. Re-run with --apply to replace Cumaru commands for claude.' commands claude --from SOURCE
    'Configuration drift (local → candidate for agent review):' config --from SOURCE
    'Dry-run only. Re-run with --apply to install complete artifacts for opencode.' agent opencode
  End
  It "reports $1 and leaves all managed surfaces byte-identical without debris"
    run_parameterized_preview() {
      local expected="$1" arg; shift
      local args=()
      for arg in "$@"; do [ "$arg" = SOURCE ] && arg=$SOURCE; args+=("$arg"); done
      preview_is_read_only "$expected" "${args[@]}"
    }
    When call run_parameterized_preview "$@"
    The status should equal 0
  End
End
