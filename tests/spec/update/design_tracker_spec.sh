Include tests/spec/update/support/update_helpers.sh

Describe 'design tracker provenance across framework updates'
  # Create isolated state for each tracker update example.
  setup() { update_tmp_create; }

  # Remove isolated state after each tracker update example.
  cleanup() { update_tmp_remove; }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  # Materialize one local tracker brief from the shipped template.
  write_design_brief() {
    local project="$1" key="$2" tracker="$3" note="$4"
    local file="$project/.cumaru/intake/$key.md"

    cp "$project/.cumaru/templates/intake-brief.md" "$file"
    yq -i --front-matter=process \
      ".key = \"$key\" | .type = \"story\" | .tracker = \"$tracker\" | .status = \"open\" | .\"synced-at\" = \"2026-09-11T00:00:00Z\" | .targets = [\"meta\"] | .relates = []" \
      "$file"
    printf '\n## Refined local context\n\n%s\n' "$note" >> "$file"
  }

  # Create a tracked design-domain project accepted by update apply.
  make_design_tracker_project() {
    local project="$1"

    mkdir -p "$project"
    run_cumaru "$project" install --domain design-as-code >/dev/null || return
    git -C "$project" init >/dev/null 2>&1 || return
  }

  # Prove per-brief non-Jira provenance survives canonical index refresh twice.
  current_tracker_survives_update() {
    local project="$UPDATE_TMP/current" brief preview canonical_summary

    make_design_tracker_project "$project" || return
    write_design_brief "$project" LIN-101 linear 'Curated Linear acceptance remains adopter-owned.' || return
    brief="$project/.cumaru/intake/LIN-101.md"
    yq -i --front-matter=process \
      '.summary = "Stale framework intake summary that update must replace canonically."' \
      "$project/.cumaru/intake/index.md" || return
    commit_update_project "$project" 'design tracker baseline' || return
    shasum "$brief" > "$UPDATE_TMP/brief.before"

    preview=$(run_cumaru "$project" update intake/index.md --from "$UPDATE_ROOT") || return
    [[ "$preview" != *jira* ]] || return 1
    run_cumaru "$project" update intake/index.md --from "$UPDATE_ROOT" --apply >/dev/null || return

    canonical_summary=$(yq --front-matter=extract -r '.summary' \
      "$UPDATE_ROOT/domains/design-as-code/intake/index.md") || return
    [ "$(yq --front-matter=extract -r '.summary' "$project/.cumaru/intake/index.md")" = "$canonical_summary" ] || return 1
    [ "$(yq --front-matter=extract -r '.tracker' "$brief")" = linear ] || return 1
    [ "$(yq --front-matter=extract -r '.tracker // "absent"' "$project/.cumaru/intake/index.md")" = absent ] || return 1
    shasum "$brief" > "$UPDATE_TMP/brief.after"
    cmp -s "$UPDATE_TMP/brief.before" "$UPDATE_TMP/brief.after" || return 1

    commit_update_project "$project" 'canonical intake index' || return
    shasum "$project/.cumaru/intake/index.md" "$brief" > "$UPDATE_TMP/current.before"
    run_cumaru "$project" update intake/index.md --from "$UPDATE_ROOT" --apply >/dev/null || return
    shasum "$project/.cumaru/intake/index.md" "$brief" > "$UPDATE_TMP/current.after"
    cmp -s "$UPDATE_TMP/current.before" "$UPDATE_TMP/current.after"
  }

  # Reconcile one legacy index choice without overwriting existing brief provenance.
  legacy_registry_reconciles_to_briefs() {
    local project="$UPDATE_TMP/legacy" linear_brief jira_brief legacy_tracker

    make_design_tracker_project "$project" || return
    write_design_brief "$project" LIN-202 linear 'Linear-specific refinement survives registry retirement.' || return
    write_design_brief "$project" JIR-303 jira 'Jira-specific refinement keeps its original provenance.' || return
    linear_brief="$project/.cumaru/intake/LIN-202.md"
    jira_brief="$project/.cumaru/intake/JIR-303.md"
    yq -i --front-matter=process 'del(.tracker)' "$linear_brief" || return
    yq -i --front-matter=process '.tracker = ["linear"]' "$project/.cumaru/intake/index.md" || return
    yq -i '.root.intake.frontmatter = {"tracker": {}}' "$project/.cumaru/config.yaml" || return
    commit_update_project "$project" 'legacy tracker registry' || return

    legacy_tracker=$(yq --front-matter=extract -r '.tracker[0]' "$project/.cumaru/intake/index.md") || return
    CUMARU_TEST_TRACKER="$legacy_tracker" yq -i --front-matter=process \
      '.tracker = strenv(CUMARU_TEST_TRACKER)' "$linear_brief" || return
    yq -i 'del(.root.intake.frontmatter)' "$project/.cumaru/config.yaml" || return
    commit_update_project "$project" 'reconcile tracker provenance' || return

    run_cumaru "$project" update intake/index.md --from "$UPDATE_ROOT" --apply >/dev/null || return
    [ "$(yq --front-matter=extract -r '.tracker' "$linear_brief")" = linear ] || return 1
    [ "$(yq --front-matter=extract -r '.tracker' "$jira_brief")" = jira ] || return 1
    [ "$(yq --front-matter=extract -r '.tracker // "absent"' "$project/.cumaru/intake/index.md")" = absent ] || return 1
    grep -Fq 'Linear-specific refinement survives registry retirement.' "$linear_brief" || return 1
    grep -Fq 'Jira-specific refinement keeps its original provenance.' "$jira_brief"
  }

  It 'preserves a non-Jira brief while canonical index frontmatter refreshes idempotently'
    When call current_tracker_survives_update
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'moves a legacy single-tracker choice to missing briefs without changing other trackers'
    When call legacy_registry_reconciles_to_briefs
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End
End
