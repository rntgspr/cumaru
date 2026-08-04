Include tests/spec/contracts/spec_helper.sh

Describe 'documented CLI contracts'
  BeforeEach 'contract_tmp_setup'
  AfterEach 'contract_tmp_cleanup'

  cli_help() { bash "$CONTRACT_CLI" "$1" --help; }

  help_has_exact_line() {
    command=$1
    line=$2
    output="$CONTRACT_TMP/$command.help"
    error="$CONTRACT_TMP/$command.help.err"
    cli_help "$command" >"$output" 2>"$error" || return
    [ ! -s "$error" ] && file_has_exact_line "$output" "$line"
  }

  It 'documents update exactly and retains current version/config semantics'
    When call cli_help update
    The status should be success
    The stderr should equal ''
    The output should include '  cumaru update [<path>] [--from <path|git-url>] [--apply]'
    The output should include 'integer migration'
    The output should include 'cumaru update config'
    The output should not include 'semantic schema merge conflict'
    The output should not include 'hook files wholesale'
  End

  It 'prints the exact update usage line'
    When call help_has_exact_line update '  cumaru update [<path>] [--from <path|git-url>] [--apply]'
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End

  It 'documents doctor and its v7 migration gate'
    When call cli_help doctor
    The status should be success
    The stderr should equal ''
    The output should include '  cumaru doctor [--quiet]'
    The output should include 'eight mechanical checks'
    The output should include 'Run `cumaru migrate`'
  End

  Parameters
    doctor '  cumaru doctor [--quiet]'
    migrate '  cumaru migrate [--from <source>]'
    tree '  cumaru tree [<directory-or-md>] [--deep] [--rows]'
    map '  cumaru map [<directory-or-md>] [--rows]'
    flow '  cumaru flow <src> move <dst>'
    tag '  cumaru tag                                  list tags declared for the root index.md'
    coverage '  cumaru coverage [--refs|--gaps|--rows] [--strict]'
    install '  cumaru install [agent <none|claude|codex|opencode>] [--domain <name>] [--with <skill>...]'
  End
  It 'exposes the exact help line for $1'
    When call help_has_exact_line "$1" "$2"
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End

  It 'moves domain discovery to the help topic'
    output="$CONTRACT_TMP/top-level.help"
    bash "$CONTRACT_CLI" help >"$output" 2>"$CONTRACT_TMP/top-level.err"
    status=$?
    When call file_has_exact_line "$output" 'cumaru — CLI for the .cumaru/ framework'
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
    The value "$status" should equal 0
    The contents of file "$CONTRACT_TMP/top-level.err" should equal ''
    The contents of file "$output" should include 'help [<topic>]'
    The contents of file "$output" should not include '    domains '
  End

  It 'enumerates installable domains in help domains'
    output="$CONTRACT_TMP/domains.help"
    bash "$CONTRACT_CLI" help domains >"$output" 2>"$CONTRACT_TMP/domains.err"
    status=$?
    When call file_has_exact_line "$output" 'Available domains (install one with `cumaru install --domain <name>`):'
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
    The value "$status" should equal 0
    The contents of file "$CONTRACT_TMP/domains.err" should equal ''
    The contents of file "$output" should include 'sdlc-full'
  End

  It 'rejects the removed domains subcommand'
    When call bash "$CONTRACT_CLI" domains
    The status should equal 2
    The output should be present
    The stderr should equal ''
  End

  It 'reports an unknown help topic on stderr only'
    When call bash "$CONTRACT_CLI" help absent-topic
    The status should equal 1
    The stdout should equal ''
    The stderr should equal "$(printf '\033[31mUnknown help topic: absent-topic\033[0m\n\033[31mAvailable topics: domains\033[0m')"
  End

  It 'keeps intake as a skill-only workflow without a mutating CLI'
    project="$CONTRACT_TMP/intake-probe"; mkdir -p "$project/existing/empty"
    printf 'keep me\n' >"$project/existing/file.txt"
    project_manifest "$project" >"$CONTRACT_TMP/intake.before"
    When run command bash -c 'cd "$1" && bash "$2" intake AAA-1234' _ "$project" "$CONTRACT_CLI"
    The status should equal 2
    The output should be present
    The stderr should equal ''
    The value "$(project_manifest "$project")" should equal "$(cat "$CONTRACT_TMP/intake.before")"
    The path "$CONTRACT_ROOT/src/cmd_intake.sh" should not be exist
    The path "$CONTRACT_ROOT/docs/intake.md" should not be exist
    The contents of file "$CONTRACT_ROOT/domains/sdlc-full/skills/cumaru-intake/SKILL.md" should not include 'cumaru intake'
    The contents of file "$CONTRACT_ROOT/domains/iac-basic/skills/cumaru-intake/SKILL.md" should not include 'cumaru intake'
    The contents of file "$CONTRACT_ROOT/domains/qa-basic/skills/cumaru-intake/SKILL.md" should not include 'cumaru intake'
    The value "$(files_equal "$CONTRACT_ROOT/domains/sdlc-full/commands/cumaru/intake.md" "$CONTRACT_ROOT/domains/iac-basic/commands/cumaru/intake.md"; printf '%s' $?)" should equal 0
    The value "$(files_equal "$CONTRACT_ROOT/domains/sdlc-full/commands/cumaru/intake.md" "$CONTRACT_ROOT/domains/qa-basic/commands/cumaru/intake.md"; printf '%s' $?)" should equal 0
  End

  It 'ships one canonical update skill in every domain'
    canonical="$CONTRACT_ROOT/domains/__base/skills/cumaru-update/SKILL.md"
    for domain in iac-basic qa-basic sdlc-full sdlc-light vault-memory; do
      The value "$(files_equal "$canonical" "$CONTRACT_ROOT/domains/$domain/skills/cumaru-update/SKILL.md"; printf '%s' $?)" should equal 0
    done
  End

  It 'ships one strict priority Cumaru discipline in every domain'
    canonical="$CONTRACT_ROOT/domains/__base/disciplines/cumaru-first.md"
    The value "$(yq --front-matter=extract -r '.name' "$canonical")" should equal cumaru-first
    The value "$(yq --front-matter=extract -r '.strictness' "$canonical")" should equal 10/10
    The contents of file "$canonical" should include 'cumaru tree'
    The contents of file "$canonical" should include 'cumaru flow'
    The contents of file "$canonical" should include 'cumaru tag'
    The contents of file "$canonical" should include 'cumaru coverage'
    The contents of file "$canonical" should include 'cumaru doctor'
    The contents of file "$canonical" should include 'cumaru update'
    The contents of file "$canonical" should include 'cumaru migrate'
    for domain in iac-basic qa-basic sdlc-full sdlc-light vault-memory; do
      The value "$(files_equal "$canonical" "$CONTRACT_ROOT/domains/$domain/disciplines/cumaru-first.md"; printf '%s' $?)" should equal 0
      The contents of file "$CONTRACT_ROOT/domains/$domain/domain.md" should include '| cumaru-first |'
    done
  End

  It 'ships a prominent code-comments discipline with an amplified trigger'
    canonical="$CONTRACT_ROOT/domains/__base/disciplines/code-comments.md"
    The value "$(yq --front-matter=extract -r '.name' "$canonical")" should equal code-comments
    The value "$(yq --front-matter=extract -r '.strictness' "$canonical")" should equal 9/10
    The contents of file "$canonical" should include 'writing, editing, reviewing, refactoring, or documenting code'
    The contents of file "$canonical" should include 'comments may be created, preserved, changed, or removed'
    for domain in design-as-code iac-basic qa-basic sdlc-full sdlc-light vault-memory; do
      The value "$(files_equal "$canonical" "$CONTRACT_ROOT/domains/$domain/disciplines/code-comments.md"; printf '%s' $?)" should equal 0
      The contents of file "$CONTRACT_ROOT/domains/$domain/domain.md" should include '| code-comments | code or related artifacts are written, edited, reviewed, refactored, or documented'
    done
  End

  It 'requires a closed strictness value on every discipline body'
    When run bash -c '
      root=$1
      for file in "$root"/domains/*/disciplines/*.md; do
        test "$(basename "$file")" = index.md && continue
        value=$(yq --front-matter=extract -r ".strictness // \"\"" "$file") || exit 1
        case "$value" in
          0/10|1/10|2/10|3/10|4/10|5/10|6/10|7/10|8/10|9/10|10/10) ;;
          *) printf "invalid strictness: %s: %s\n" "$file" "$value"; exit 1 ;;
        esac
      done
    ' _ "$CONTRACT_ROOT"
    The status should be success
    The output should equal ''
  End

  It 'documents eager discipline delivery without a selective-loading path'
    for domain in __base design-as-code iac-basic qa-basic sdlc-full sdlc-light vault-memory; do
      index="$CONTRACT_ROOT/domains/$domain/disciplines/index.md"
      The contents of file "$index" should include 'eager delivery does not mean universal application'
      The contents of file "$index" should include 'Strictness | Required consideration'
      The contents of file "$index" should include 'A missing value is treated as `0/10` but is invalid'
      The contents of file "$index" should include 'Apply every matching'
      The contents of file "$index" should not include 'load only the discipline'
      The contents of file "$index" should not include 'rather than loaded eagerly'
    done
    The contents of file "$CONTRACT_ROOT/domains/__base/index.md" should include '`disciplines/index.md`'
    The contents of file "$CONTRACT_ROOT/domains/__base/index.md" should include 'Apply every matching discipline'
  End

  It 'makes Lead roles prefer bounded sub-agent implementation'
    for domain in sdlc-full iac-basic qa-basic sdlc-light; do
      role="$CONTRACT_ROOT/domains/$domain/roles/lead.md"
      The contents of file "$role" should include '## Delegation default'
      The contents of file "$role" should include 'Delegation is the default for bounded implementation'
      The contents of file "$role" should include 'otherwise dispatch them sequentially'
      The contents of file "$role" should include 'Each dispatch must name'
      The contents of file "$role" should include 'Delegation never transfers'
    done
    for domain in sdlc-full iac-basic qa-basic; do
      The contents of file "$CONTRACT_ROOT/domains/$domain/roles/lead.md" should include 'Dev sub-agent'
    done
    The contents of file "$CONTRACT_ROOT/domains/sdlc-light/roles/lead.md" should include 'no separate Dev role'
    The path "$CONTRACT_ROOT/domains/sdlc-light/roles/dev.md" should not be exist
  End

  It 'documents agent-led config reconciliation without persistent backups'
    skill="$CONTRACT_ROOT/domains/__base/skills/cumaru-update/SKILL.md"
    migration="$CONTRACT_ROOT/domains/__base/migration.md"
    The value "$(grep -E 'schema --apply.*destructive|wholesale `cp`' "$skill" "$migration" || true)" should equal ''
    The contents of file "$skill" should include 'It never mutates'
    The contents of file "$skill" should include 'Do not create persistent backups'
    The contents of file "$migration" should include 'no persistent backup artifacts'
    The contents of file "$migration" should not include '.cumaru/config.yaml.backup'
  End

  doctor_pre_v7() {
    project="$CONTRACT_TMP/pre-v7"
    mkdir -p "$project"
    (cd "$project" && bash "$CONTRACT_CLI" install --domain base) >/dev/null 2>&1 || return
    yq -i '.version = 5' "$project/.cumaru/config.yaml"
    yq --front-matter=process -i '.["framework-version"] = 5' "$project/.cumaru/index.md"
    cd "$project" && bash "$CONTRACT_CLI" doctor
  }

  It 'rejects pre-v7 trees before running the eight checks'
    When call doctor_pre_v7
    The status should be failure
    The output should include 'Run: cumaru migrate'
    The output should not include 'Summary:'
  End
End
