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
    for domain in sdlc-full sdlc-light iac-basic qa-basic vault-memory; do
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
    migrate_fixture full sdlc-full | awk '/^## 1\. Preflight/{base=NR} /^## sdlc-full — domain notes/{ext=NR} END{exit !(base && ext && base < ext)}'
  }
  It 'concatenates the base body before the domain extension'
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
      'resumable and parallelizable' 'this step runs AFTER step 6' \
      '`cumaru update config`' 'agent must reconcile `config.yaml` deliberately' \
      'invalid local value is a blocker' '`version: 7`' 'Only `schema.yaml`' \
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
      'cumaru flow' 'cumaru doctor' 'cumaru coverage' 'is config-validated' \
      'This is why step 6 runs' 'it cannot delete a block' \
      'cumaru flow migrations remove` is **rejected**' 'rm -rf .cumaru/migrations')
    for text in "${texts[@]}"; do
      The contents of file "$BASE_DOC" should include "$text"
    done
  End

  It 'distinguishes clean from tracked state: %1'
    for text in 'git ls-files .cumaru' 'git is not a rollback for it' 'Do not start an untracked migration'; do
      The contents of file "$BASE_DOC" should include "$text"
    done
  End

  It 'pins safe step 5 ordering: %1'
    for text in 'cumaru update <pillar>/index.md' 'at the top of the' 'Remove the block first, then update'; do
      The contents of file "$BASE_DOC" should include "$text"
    done
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

  no_duplicate_headings() {
    base=$(grep '^## ' "$BASE_DOC" | sort -u)
    for domain in sdlc-full sdlc-light iac-basic qa-basic vault-memory; do
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
