Include tests/spec/update/support/update_helpers.sh

Describe 'intake tracker provenance across framework updates'
  # Create isolated state for each tracker update example.
  setup() { update_tmp_create; }

  # Remove isolated state after each tracker update example.
  cleanup() { update_tmp_remove; }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  # Resolve the installed path for one domain intake item.
  intake_item_path() {
    local project="$1" domain="$2" key="$3"

    if [ "$domain" = sdlc-full ]; then
      printf '%s/.cumaru/intake/%s.md\n' "$project" "$key"
    else
      printf '%s/.cumaru/intake/%s/index.md\n' "$project" "$key"
    fi
  }

  # Materialize one local intake item from the domain's shipped template.
  write_intake_item() {
    local project="$1" domain="$2" key="$3" tracker="$4" note="$5"
    local file

    file=$(intake_item_path "$project" "$domain" "$key") || return
    mkdir -p "$(dirname "$file")"
    cp "$project/.cumaru/templates/intake-ticket.md" "$file"
    CUMARU_TEST_KEY="$key" CUMARU_TEST_TRACKER="$tracker" yq -i --front-matter=process \
      '.key = strenv(CUMARU_TEST_KEY) | .type = "task" | .tracker = strenv(CUMARU_TEST_TRACKER) | .status = "open" | ."synced-at" = "2026-09-16T00:00:00Z" | .targets = ["meta"] | .relates = []' \
      "$file"
    printf '\n## Refined local context\n\n%s\n' "$note" >> "$file"
  }

  # Create a tracked project accepted by update apply.
  make_tracker_project() {
    local project="$1" domain="$2"

    mkdir -p "$project"
    run_cumaru "$project" install --domain "$domain" >/dev/null || return
    git -C "$project" init >/dev/null 2>&1
  }

  # Prove mixed per-item provenance survives canonical index refresh twice.
  current_trackers_survive_update() {
    local domain project linear_item jira_item preview canonical_summary

    for domain in sdlc-full iac-basic qa-basic; do
      project="$UPDATE_TMP/$domain-current"
      make_tracker_project "$project" "$domain" || return
      write_intake_item "$project" "$domain" LIN-101 linear \
        'Curated Linear acceptance remains adopter-owned.' || return
      write_intake_item "$project" "$domain" JIR-202 jira \
        'Curated Jira acceptance retains independent provenance.' || return
      linear_item=$(intake_item_path "$project" "$domain" LIN-101) || return
      jira_item=$(intake_item_path "$project" "$domain" JIR-202) || return
      yq -i --front-matter=process \
        '.summary = "Stale framework intake summary that update must replace canonically."' \
        "$project/.cumaru/intake/index.md" || return
      commit_update_project "$project" 'tracker baseline' || return
      shasum "$linear_item" "$jira_item" > "$UPDATE_TMP/$domain.items.before"

      preview=$(run_cumaru "$project" update intake/index.md --from "$UPDATE_ROOT") || return
      [[ "$preview" != *'tracker: [jira]'* ]] || return 1
      run_cumaru "$project" update intake/index.md --from "$UPDATE_ROOT" --apply >/dev/null || return

      canonical_summary=$(yq --front-matter=extract -r '.summary' \
        "$UPDATE_ROOT/domains/$domain/intake/index.md") || return
      [ "$(yq --front-matter=extract -r '.summary' "$project/.cumaru/intake/index.md")" = "$canonical_summary" ] || return 1
      [ "$(yq --front-matter=extract -r '.tracker' "$linear_item")" = linear ] || return 1
      [ "$(yq --front-matter=extract -r '.tracker' "$jira_item")" = jira ] || return 1
      [ "$(yq --front-matter=extract -r '.tracker // "absent"' "$project/.cumaru/intake/index.md")" = absent ] || return 1
      shasum "$linear_item" "$jira_item" > "$UPDATE_TMP/$domain.items.after"
      cmp -s "$UPDATE_TMP/$domain.items.before" "$UPDATE_TMP/$domain.items.after" || return 1

      commit_update_project "$project" 'canonical intake index' || return
      shasum "$project/.cumaru/intake/index.md" "$linear_item" "$jira_item" \
        > "$UPDATE_TMP/$domain.second.before"
      run_cumaru "$project" update intake/index.md --from "$UPDATE_ROOT" --apply >/dev/null || return
      shasum "$project/.cumaru/intake/index.md" "$linear_item" "$jira_item" \
        > "$UPDATE_TMP/$domain.second.after"
      cmp -s "$UPDATE_TMP/$domain.second.before" "$UPDATE_TMP/$domain.second.after" || return 1
    done
  }

  # Prove the documented sole-registry reconciliation preserves other item values.
  legacy_registry_reconciles_to_items() {
    local domain project linear_item jira_item legacy_tracker

    for domain in sdlc-full iac-basic qa-basic; do
      project="$UPDATE_TMP/$domain-legacy"
      make_tracker_project "$project" "$domain" || return
      write_intake_item "$project" "$domain" LIN-303 linear \
        'Linear refinement survives registry retirement.' || return
      write_intake_item "$project" "$domain" JIR-404 jira \
        'Jira refinement keeps its original provenance.' || return
      linear_item=$(intake_item_path "$project" "$domain" LIN-303) || return
      jira_item=$(intake_item_path "$project" "$domain" JIR-404) || return
      yq -i --front-matter=process 'del(.tracker)' "$linear_item" || return
      yq -i --front-matter=process '.tracker = ["linear"]' \
        "$project/.cumaru/intake/index.md" || return
      yq -i '.root.intake.frontmatter = {"tracker": {}}' \
        "$project/.cumaru/config.yaml" || return
      commit_update_project "$project" 'legacy tracker registry' || return

      legacy_tracker=$(yq --front-matter=extract -r '.tracker[0]' \
        "$project/.cumaru/intake/index.md") || return
      CUMARU_TEST_TRACKER="$legacy_tracker" yq -i --front-matter=process \
        '.tracker = strenv(CUMARU_TEST_TRACKER)' "$linear_item" || return
      yq -i 'del(.root.intake.frontmatter)' \
        "$project/.cumaru/config.yaml" || return
      commit_update_project "$project" 'reconcile tracker provenance' || return

      run_cumaru "$project" update intake/index.md --from "$UPDATE_ROOT" --apply >/dev/null || return
      [ "$(yq --front-matter=extract -r '.tracker' "$linear_item")" = linear ] || return 1
      [ "$(yq --front-matter=extract -r '.tracker' "$jira_item")" = jira ] || return 1
      [ "$(yq --front-matter=extract -r '.tracker // "absent"' "$project/.cumaru/intake/index.md")" = absent ] || return 1
      grep -Fq 'Linear refinement survives registry retirement.' "$linear_item" || return 1
      grep -Fq 'Jira refinement keeps its original provenance.' "$jira_item" || return 1
    done
  }

  # Verify source contracts reject guessing ambiguous legacy provenance.
  source_contracts_use_per_item_provenance() {
    local domain template

    for domain in sdlc-full iac-basic qa-basic; do
      [ "$(yq --front-matter=extract -r '.tracker // "absent"' \
        "$UPDATE_ROOT/domains/$domain/intake/index.md")" = absent ] || return 1
      [ "$(yq -r '.root.intake.frontmatter // "absent"' \
        "$UPDATE_ROOT/domains/$domain/config.yaml")" = absent ] || return 1
      grep -Fq 'There is no project-wide tracker registry' \
        "$UPDATE_ROOT/domains/$domain/intake/index.md" || return 1
      grep -Fq 'never default to Jira' \
        "$UPDATE_ROOT/domains/$domain/migration.md" || return 1
      grep -Fq 'multiple or conflicting candidates' \
        "$UPDATE_ROOT/domains/$domain/migration.md" || return 1
      grep -Fq 'Do not configure a tracker registry' \
        "$UPDATE_ROOT/domains/$domain/skills/cumaru-install/SKILL.md" || return 1

      for template in intake-epic.md intake-story.md intake-ticket.md; do
        grep -Fq 'tracker: <TRACKER>' \
          "$UPDATE_ROOT/domains/$domain/templates/$template" || return 1
      done
    done
  }

  It 'preserves mixed Jira and Linear items while refreshing each canonical index idempotently'
    When call current_trackers_survive_update
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'moves a sole legacy tracker to missing items without changing existing provenance'
    When call legacy_registry_reconciles_to_items
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'ships per-item contracts and blocks ambiguous legacy defaults in every affected domain'
    When call source_contracts_use_per_item_provenance
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End
End
