Include tests/spec/contracts/spec_helper.sh

Describe 'cumaru migrate prose delivery'
  BASE_DOC="$CONTRACT_ROOT/domains/__base/migration.md"
  BeforeEach 'contract_tmp_setup'
  AfterEach 'contract_tmp_cleanup'

  migrate_fixture() {
    project=$(make_migration_project "$1" "$2")
    shift 2
    cd "$project" && bash "$CONTRACT_CLI" migrate "$@"
  }

  It 'ships the base document and valid optional domain extensions'
    The path "$BASE_DOC" should be file
    for domain in design-as-code sdlc-full sdlc-light iac-basic qa-basic vault-memory; do
      The path "$CONTRACT_ROOT/domains/$domain" should be directory
      doc="$CONTRACT_ROOT/domains/$domain/migration.md"
      if [ -f "$doc" ]; then
        The value "$(sed -n '1p' "$doc")" should equal '---'
      fi
    done
  End

  It 'has retired TSV manifests and the v6 adapter module'
    The path "$CONTRACT_ROOT/src/cmd_migrate_v6.sh" should not be exist
    The value "$(for path in "$CONTRACT_ROOT"/domains/*/migrations; do [ -e "$path" ] && printf found; done)" should equal ''
  End

  It 'resolves the installed domain from legacy schema.yaml'
    When call migrate_fixture full sdlc-full
    The status should be success
    The stderr should equal ''
    The output should include '# Migration — sdlc-full'
  End

  migrate_current() {
    project=$(make_migration_project current sdlc-full)
    mv "$project/.cumaru/schema.yaml" "$project/.cumaru/config.yaml"
    cd "$project" && bash "$CONTRACT_CLI" migrate
  }
  It 'resolves the installed domain from config.yaml'
    When call migrate_current
    The status should be success
    The stderr should equal ''
    The output should include '# Migration — sdlc-full'
  End

  migrate_both() {
    project=$(make_migration_project both sdlc-full)
    cp "$project/.cumaru/schema.yaml" "$project/.cumaru/config.yaml"
    cd "$project" && bash "$CONTRACT_CLI" migrate
  }
  It 'makes config.yaml authoritative when both configuration names exist'
    When call migrate_both
    The status should be success
    The stderr should equal ''
    The output should include '# Migration — sdlc-full'
  End

  migrate_without_frontmatter() {
    migrate_fixture frontmatter sdlc-full >"$CONTRACT_TMP/frontmatter.out" || return
    ! grep -Eq '^(release:|targets:|  framework-version:|---)$' "$CONTRACT_TMP/frontmatter.out"
  }
  It 'succeeds before asserting that frontmatter is absent'
    When call migrate_without_frontmatter
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End

  migration_order() {
    migrate_fixture full sdlc-full | awk '
      /^## 1\. Preflight/{preflight=NR}
      /^## 3\. Discover preservation work/{preservation=NR}
      /^## sdlc-full — domain notes/{extension=NR}
      /^## 4\. Namespaced touched-file marker/{conversion=NR}
      END{exit !(preflight < preservation && preservation < extension && extension < conversion)}'
  }
  It 'inserts the domain extension at the preservation checkpoint'
    When call migration_order
    The status should be success
  End

  It 'prints only the base body for a domain without an extension'
    When call migrate_fixture vault vault-memory
    The status should be success
    The output should include '## 1. Preflight'
    The output should not include 'domain notes'
  End

  readonly_migrate() {
    project=$(make_migration_project readonly sdlc-full)
    before=$(project_manifest "$project")
    (cd "$project" && bash "$CONTRACT_CLI" migrate) >/dev/null || return
    after=$(project_manifest "$project")
    [ "$before" = "$after" ]
  }
  It 'is read-only'
    When call readonly_migrate
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End

  repeated_migrate_is_identical() {
    project=$(make_migration_project repeated design-as-code)
    before=$(project_manifest "$project")
    (cd "$project" && bash "$CONTRACT_CLI" migrate) >"$CONTRACT_TMP/first.out" || return
    (cd "$project" && bash "$CONTRACT_CLI" migrate) >"$CONTRACT_TMP/second.out" || return
    after=$(project_manifest "$project")
    cmp -s "$CONTRACT_TMP/first.out" "$CONTRACT_TMP/second.out" && [ "$before" = "$after" ]
  }
  It 'delivers the complete sequence idempotently'
    When call repeated_migrate_is_identical
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End

  delivery_is_version_driven() {
    plain=$(make_migration_project plain-state sdlc-full)
    retired=$(make_migration_project retired-state sdlc-full)
    printf '%s\n' 'meta:' '  tags:' '    absorptions: table' >>"$retired/.cumaru/schema.yaml"
    (cd "$plain" && bash "$CONTRACT_CLI" migrate) >"$CONTRACT_TMP/plain.out" || return
    (cd "$retired" && bash "$CONTRACT_CLI" migrate) >"$CONTRACT_TMP/retired.out" || return
    cmp -s "$CONTRACT_TMP/plain.out" "$CONTRACT_TMP/retired.out"
  }
  It 'delivers the same direct v9 migration for older state with or without retired fields'
    When call delivery_is_version_driven
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End

  direct_versions_share_one_document() {
    v4=$(make_migration_project populated-v4 sdlc-full)
    perl -pi -e 's/version: 6/version: 4/' "$v4/.cumaru/schema.yaml"
    printf '%s\n' '<!-- cumaru:touched -->' '| [local](local.md) | adopter data |' '<!-- /cumaru:touched -->' >>"$v4/.cumaru/index.md"
    mkdir -p "$v4/.cumaru/local-only"; printf 'keep\n' >"$v4/.cumaru/local-only/note.md"

    v8=$(make_migration_project populated-v8 sdlc-full)
    mv "$v8/.cumaru/schema.yaml" "$v8/.cumaru/config.yaml"
    perl -pi -e 's/version: 6/version: 8/' "$v8/.cumaru/config.yaml"

    v9=$(make_migration_project populated-v9 sdlc-full)
    mv "$v9/.cumaru/schema.yaml" "$v9/.cumaru/config.yaml"
    perl -pi -e 's/version: 6/version: 9/' "$v9/.cumaru/config.yaml"

    (cd "$v4" && bash "$CONTRACT_CLI" migrate) >"$CONTRACT_TMP/v4.out" || return
    (cd "$v8" && bash "$CONTRACT_CLI" migrate) >"$CONTRACT_TMP/v8.out" || return
    (cd "$v9" && bash "$CONTRACT_CLI" migrate) >"$CONTRACT_TMP/v9.out" || return
    cmp -s "$CONTRACT_TMP/v4.out" "$CONTRACT_TMP/v8.out" &&
      cmp -s "$CONTRACT_TMP/v8.out" "$CONTRACT_TMP/v9.out" &&
      grep -Fq 'An already-valid v9 tree needs no migration' "$CONTRACT_TMP/v9.out" &&
      ! grep -Eqi 'v8-to-v9|version: 8|checkout.*v8' "$CONTRACT_TMP/v4.out"
  }
  It 'delivers one direct v9 procedure to populated v4, v8, and v9 adopters'
    When call direct_versions_share_one_document
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End

  It 'delivers one preservation-first direct N-to-v9 procedure'
    The contents of file "$BASE_DOC" should include '## 9. Reconcile configuration and converge directly on version 9'
    The contents of file "$BASE_DOC" should include 'every `<!-- cumaru:... -->` body'
    The value "$(file_has_compact_text "$BASE_DOC" 'ownership and `optional` do not inherit'; printf '%s' $?)" should equal 0
    The contents of file "$BASE_DOC" should include 'temporary candidate'
    The contents of file "$BASE_DOC" should include 'sole version field'
    The contents of file "$BASE_DOC" should not include 'V8-to-v9 direct-tree migration'
    The contents of file "$BASE_DOC" should not include 'version: 8'
  End

  It 'refuses --apply with an explanation'
    When call migrate_fixture full sdlc-full --apply
    The status should be failure
    The output should include 'no --apply'
    The stderr should equal ''
  End

  It 'honors an explicit source checkout'
    When call migrate_fixture full sdlc-full --from "$CONTRACT_ROOT"
    The status should be success
    The output should include '## 1. Preflight'
    The stderr should equal ''
  End

  migrate_help_outside() { cd "$CONTRACT_TMP" && bash "$CONTRACT_CLI" migrate --help; }
  It 'shows help outside a project'
    When call migrate_help_outside
    The status should be success
    The output should include 'cumaru migrate'
    The stderr should equal ''
  End

  migrate_outside() { cd "$CONTRACT_TMP" && bash "$CONTRACT_CLI" migrate; }
  It 'refuses outside an adopted project'
    When call migrate_outside
    The status should be failure
    The stdout should include 'no installed .cumaru/config.yaml or legacy schema.yaml'
    The stderr should equal ''
  End

End

Describe 'migration prompt contract'
  BASE_DOC="$CONTRACT_ROOT/domains/__base/migration.md"

  delivered_contract() {
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-migrate-contract.XXXXXX") || return
    project="$tmp/project"; mkdir -p "$project/.cumaru"
    printf 'version: 6\ndomain: sdlc-full\n' >"$project/.cumaru/schema.yaml"
    (cd "$project" && bash "$CONTRACT_CLI" migrate)
    status=$?; rm -rf "$tmp"; return "$status"
  }
  It 'delivers the LLM execution header'
    When call delivered_contract
    The status should be success
    The output should include 'You (the LLM) execute this'
    The output should include 'has no `--apply`'
    The output should include 'Commit or stash first'
    The output should include 'detection-first and idempotent'
    The output should include 'STOP and ask'
  End

  It 'uses the per-step unit %1'
    for text in '**Applies when**' '**Detect**' '**Do**' '**Verify**' '**Blockers**'; do
      The contents of file "$BASE_DOC" should include "$text"
    done
  End

  It 'retains load-bearing migration instruction: %1'
    texts=('32 to 512' 'Drop the row only when nothing survives' 'Never truncate' \
      'resumable and parallelizable' 'ledger audit' \
      '`cumaru update config --from' 'agent must reconcile `config.yaml` deliberately' \
      'invalid local value is a blocker' '`version: 9`' 'Only `schema.yaml`' \
      'Both files' 'Only `config.yaml`' 'Neither file' 'rm -rf .cumaru/.state' 'completed-at')
    for text in "${texts[@]}"; do
      The contents of file "$BASE_DOC" should include "$text"
    done
  End

  It 'does not describe current config reconciliation as destructive'
    skill="$CONTRACT_ROOT/domains/__base/skills/cumaru-update/SKILL.md"
    The value "$(grep -E 'wholesale `cp`|schema --apply.*destructive' "$BASE_DOC" "$skill" || true)" should equal ''
  End

  It 'documents migration tooling and guardrail: %1'
    texts=('## 0. Tools you have' 'cumaru help' 'cumaru tree' 'cumaru tag' \
      'cumaru fs' 'cumaru doctor' 'cumaru coverage' 'is config-validated' \
      'audit runs before configuration reconciliation' 'it cannot delete a block' \
      'cumaru fs migrations remove` is **rejected**' 'rm -rf .cumaru/migrations')
    for text in "${texts[@]}"; do
      The contents of file "$BASE_DOC" should include "$text"
    done
  End

  It 'supports only adopted dot-cumaru layouts'
    The contents of file "$BASE_DOC" should include 'Supported starting layouts already use `.cumaru/`'
    The contents of file "$BASE_DOC" should not include '.llm/'
    The contents of file "$BASE_DOC" should not include '<!-- llm:'
    The contents of file "$CONTRACT_ROOT/src/cmd_migrate.sh" should not include '.llm/'
  End

  It 'distinguishes clean from tracked state: %1'
    for text in 'git ls-files .cumaru' 'A clean status alone is not recovery' 'STOP and ask for a committed baseline'; do
      The contents of file "$BASE_DOC" should include "$text"
    done
  End

  It 'pins safe ledger-refresh ordering: %1'
    for text in 'cumaru update --from <cumaru-checkout> --apply' 'at the top of the' 'Refresh before'; do
      The contents of file "$BASE_DOC" should include "$text"
    done
  End


  migration_phase_order() {
    normalize=$(grep -n '^## 2\. Normalize the configuration filename' "$BASE_DOC" | cut -d: -f1)
    discover=$(grep -n '^## 3\. Discover preservation work' "$BASE_DOC" | cut -d: -f1)
    reconcile=$(grep -n '^## 9\. Reconcile configuration' "$BASE_DOC" | cut -d: -f1)
    checkpoint=$(grep -n '^## 11\. Establish the pre-refresh recovery checkpoint' "$BASE_DOC" | cut -d: -f1)
    refresh=$(grep -n '^## 12\. Refresh framework Markdown' "$BASE_DOC" | cut -d: -f1)
    [ -n "$normalize" ] && [ "$normalize" -lt "$discover" ] &&
      [ "$discover" -lt "$reconcile" ] && [ "$reconcile" -lt "$checkpoint" ] &&
      [ "$checkpoint" -lt "$refresh" ]
  }
  It 'orders preservation and conversion before the clean refresh boundary'
    When call migration_phase_order
    The status should be success
  End

  delivered_design_sequence() {
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-migrate-design.XXXXXX") || return
    project="$tmp/project"
    mkdir -p "$project/.cumaru"
    printf 'version: 6\ndomain: design-as-code\n' >"$project/.cumaru/schema.yaml"
    output=$(cd "$project" && bash "$CONTRACT_CLI" migrate) || {
      rm -rf "$tmp"
      return 1
    }
    rm -rf "$tmp"
    printf '%s\n' "$output" | awk '
      /^## 3\. Discover preservation work/{discovery=NR}
      /^## design-as-code — pre-refresh tracker provenance/{tracker=NR}
      /^## 9\. Reconcile configuration and converge directly on version 9/{version=NR}
      /^## 11\. Establish the pre-refresh recovery checkpoint/{recovery=NR}
      /^## 12\. Refresh framework Markdown/{refresh=NR}
      /^## 13\. Verify the whole tree/{verify=NR}
      END { exit !(discovery < tracker && tracker < version && version < recovery && recovery < refresh && refresh < verify) }'
  }
  It 'delivers tracker preservation before version convergence and refresh'
    When call delivered_design_sequence
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End

  It 'converges directly on v9 by installed version instead of retired-field presence'
    The contents of file "$BASE_DOC" should include 'the installed version is lower than `9`'
    The value "$(file_has_compact_text "$BASE_DOC" 'This step is independent of whether `absorptions`, `deltas`, or `consolidated-at` exists.'; printf '%s' $?)" should equal 0
    The value "$(file_has_compact_text "$BASE_DOC" 'Write the sole version field last'; printf '%s' $?)" should equal 0
  End

  It 'defers v9 doctor until after conversion and refresh'
    The value "$(file_has_compact_text "$BASE_DOC" 'Unlike doctor, tree navigation remains useful before the installed version converges.'; printf '%s' $?)" should equal 0
    for domain in design-as-code iac-basic qa-basic; do
      The value "$(file_has_compact_text "$CONTRACT_ROOT/domains/$domain/migration.md" '`cumaru doctor` to base step 13'; printf '%s' $?)" should equal 0
    done
  End

  It 'requires Git recovery or warned non-Git continuation before update apply'
    for text in 'Git mutation is authorized' 'Do not commit implicitly' \
      'continue without a Git recovery point' 'Do not initialize a repository' \
      'STOP before `cumaru update --apply`' \
      'git status --porcelain --untracked-files=all'; do
      The contents of file "$BASE_DOC" should include "$text"
    done
  End

  It 'keeps framework and agent artifact refresh explicit'
    The contents of file "$BASE_DOC" should include 'General update does not refresh agent artifacts'
    The contents of file "$BASE_DOC" should include 'cumaru update agent <agent> --apply'
  End

  bash_blocks() { awk '/^   ```bash$/,/^   ```$/; /^```bash$/,/^```$/' "$BASE_DOC"; }
  It 'keeps executable migration blocks portable across BSD and GNU'
    When call bash_blocks
    The status should be success
    The output should not match pattern '*grep -*Z*'
    The output should not include 'xargs -0'
    The output should not include 'sed -i'
  End

  It 'documents shell portability trap: %1'
    for text in 'cannot assume which `grep` is on `PATH`' 'means `--null` only in GNU grep' 'use `perl -pi -e`' 'Prefer your own file-editing tools'; do
      The contents of file "$BASE_DOC" should include "$text"
    done
  End

  numbered_steps_have_commands() {
    grep '^## [0-9]' "$BASE_DOC" | while IFS= read -r section; do
      awk -v section="$section" '$0 == section {on=1; next} /^## /{on=0} on' "$BASE_DOC" |
        grep -Eq '`(cumaru|git|mv|sed|rm|yq|grep|xargs|test) ' || return 1
    done
  }
  It 'names at least one concrete command in every numbered step'
    When call numbered_steps_have_commands
    The status should be success
  End

  It 'distributes durable archive rows instead of deleting them in %1'
    for domain in iac-basic qa-basic; do
      doc="$CONTRACT_ROOT/domains/$domain/migration.md"
      The path "$doc" should be file
      The contents of file "$doc" should include 'durable'
      The contents of file "$doc" should include 'never deleted'
      The contents of file "$doc" should include 'STOP and ask'
      The contents of file "$doc" should include 'irreversible loss'
    done
  End

  It 'retains sdlc-light and sdlc-full migration nuance'
    The contents of file "$CONTRACT_ROOT/domains/sdlc-light/migration.md" should include 'the updated spec body is the record'
    The contents of file "$CONTRACT_ROOT/domains/sdlc-full/migration.md" should include 'STOP and ask'
  End

  It 'preserves design tracker provenance before canonical refresh'
    doc="$CONTRACT_ROOT/domains/design-as-code/migration.md"
    The contents of file "$doc" should include '## design-as-code — pre-refresh tracker provenance'
    The contents of file "$doc" should include 'base step 11 checkpoint before refresh'
    The contents of file "$doc" should include 'Preserve every existing scalar brief `tracker:` exactly'
    The value "$(file_has_compact_text "$doc" 'STOP before canonical refresh'; printf '%s' $?)" should equal 0
  End

  no_duplicate_headings() {
    base=$(grep '^## ' "$BASE_DOC" | sort -u)
    for domain in design-as-code sdlc-full sdlc-light iac-basic qa-basic vault-memory; do
      doc="$CONTRACT_ROOT/domains/$domain/migration.md"; [ -f "$doc" ] || continue
      while IFS= read -r heading; do
        [ -n "$heading" ] || continue
        printf '%s\n' "$base" | grep -Fxq "$heading" && return 1
      done < <(grep '^## ' "$doc")
    done
  }
  It 'does not restate base sections in domain extensions'
    When call no_duplicate_headings
    The status should be success
  End

  absorptions_markers_absent() {
    ! grep -rl 'cumaru:absorptions' "$CONTRACT_ROOT/domains" | grep -v '/migration\.md$' | grep -q .
  }
  It 'removes the absorptions tag from configs, starters, and doctor'
    When call absorptions_markers_absent
    The status should be success
    for domain in sdlc-full iac-basic qa-basic; do
      The contents of file "$CONTRACT_ROOT/domains/$domain/config.yaml" should not include 'absorptions'
    done
    The contents of file "$CONTRACT_ROOT/src/cmd_doctor_checks.sh" should not include 'absorptions'
  End
End
