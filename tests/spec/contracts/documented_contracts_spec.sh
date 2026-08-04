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

  It 'documents immediate clear as the exception to update previews'
    files="$CONTRACT_ROOT/docs/update.md $CONTRACT_ROOT/docs/agent-adapters.md $CONTRACT_ROOT/domains/__base/skills/cumaru-update/SKILL.md $CONTRACT_ROOT/domains/__base/disciplines/cumaru-first.md $CONTRACT_ROOT/.memory/specs/update.md"
    When call cli_help update
    The status should be success
    The output should include '--clear removes immediately'
    The output should include 'This is not a preview'
    The value "$(grep -L 'immediate' $files || true)" should equal ''
    The value "$(grep -F -e 'Every update is dry-run unless' -e 'Every mode previews by default' -e 'which previews unless `--apply` is explicit' $files || true)" should equal ''
  End

  It 'uses Git recovery when available without requiring a Git project'
    files="$CONTRACT_ROOT/docs/update.md $CONTRACT_ROOT/docs/agent-adapters.md $CONTRACT_ROOT/domains/__base/skills/cumaru-update/SKILL.md $CONTRACT_ROOT/.memory/specs/update.md $CONTRACT_ROOT/.memory/specs/architecture.md"
    When call cli_help update
    The status should be success
    The output should include 'Outside Git, Cumaru warns and continues without a Git recovery point.'
    The value "$(grep -L -E 'Outside Git|outside Git|non-Git' $files || true)" should equal ''
    The value "$(grep -F 'requires a Git work tree' $files || true)" should equal ''
  End

  It 'documents doctor and its v8 migration gate'
    When call cli_help doctor
    The status should be success
    The stderr should equal ''
    The output should include '  cumaru doctor [--quiet]'
    The output should include 'nine mechanical checks'
    The output should include 'Run `cumaru migrate`'
  End

  It 'keeps current contracts aligned with stateless adapters and doctor boundaries'
    When call bash -c '
        grep -Fq "nine mechanical checks" "$1/src/cmd_doctor.sh" &&
        grep -Fq "The 9 v8 checks" "$1/docs/doctor.md" &&
        grep -Fq "Retired adapter config" "$1/docs/doctor.md" &&
        grep -Fq "does not persist an active agent" "$1/docs/agent-adapters.md" &&
        ! grep -E "persist(s|ed)? (an |the )?(active )?agent|selected agent adapter|transactionally refresh" \
          "$1/README.md" "$1/.memory/specs/agent-adapters.md" \
          "$1/.memory/specs/domains.md" "$1/.memory/specs/install-upgrade.md" >/dev/null &&
        ! grep -F "Validators warn" "$1"/domains/*/roles/lead.md >/dev/null &&
        test -z "$(grep -L "doctor does not validate" "$1"/domains/{design-as-code,sdlc-full,sdlc-light,qa-basic}/roles/lead.md)"
    ' _ "$CONTRACT_ROOT"
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End

  Parameters
    doctor '  cumaru doctor [--quiet]'
    migrate '  cumaru migrate [--from <source>]'
    tree '  cumaru tree [<directory-or-md>] [--deep] [--rows]'
    map '  cumaru map [<directory-or-md>] [--rows]'
    fs '  cumaru fs <src> move <dst>'
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

  It 'routes existing installs and opt-in additions through update help'
    install_output="$CONTRACT_TMP/install.help"
    top_output="$CONTRACT_TMP/top-level.help"

    bash "$CONTRACT_CLI" install --help >"$install_output" 2>"$CONTRACT_TMP/install.err"
    install_status=$?
    bash "$CONTRACT_CLI" help >"$top_output" 2>"$CONTRACT_TMP/top-level.err"
    top_status=$?

    When call file_has_exact_line "$install_output" 'Install is only for initial project adoption and refuses an existing `.cumaru/`.'
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
    The value "$install_status" should equal 0
    The value "$top_status" should equal 0
    The contents of file "$install_output" should include 'cumaru update skills <agent> --with <skill> [--apply]'
    The contents of file "$install_output" should not include 'dot-llm checkout'
    The contents of file "$top_output" should include 'cumaru update skills codex --with git --apply'
    The contents of file "$CONTRACT_TMP/install.err" should equal ''
    The contents of file "$CONTRACT_TMP/top-level.err" should equal ''
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

  It 'resolves documented authoring workflows to shipped skills'
    The path "$CONTRACT_ROOT/domains/sdlc-full/skills/cumaru-specs/SKILL.md" should be file
    The path "$CONTRACT_ROOT/domains/sdlc-light/skills/cumaru-specs/SKILL.md" should be file
    The path "$CONTRACT_ROOT/domains/iac-basic/skills/cumaru-topology/SKILL.md" should be file
    The path "$CONTRACT_ROOT/domains/qa-basic/skills/cumaru-coverage/SKILL.md" should be file
    The path "$CONTRACT_ROOT/domains/sdlc-full/skills/cumaru-absorb/SKILL.md" should be file

    The contents of file "$CONTRACT_ROOT/domains/sdlc-full/templates/bootstrap.md" should include '`cumaru-specs` bootstrap recipe'
    The contents of file "$CONTRACT_ROOT/domains/sdlc-light/templates/bootstrap.md" should include '`cumaru-specs` bootstrap recipe'
    The contents of file "$CONTRACT_ROOT/domains/iac-basic/templates/bootstrap.md" should include '`cumaru-topology` bootstrap recipe'
    The contents of file "$CONTRACT_ROOT/domains/qa-basic/templates/bootstrap.md" should include '`cumaru-coverage` bootstrap'
    The contents of file "$CONTRACT_ROOT/domains/sdlc-full/templates/bootstrap.md" should not include 'cumaru specs bootstrap'
    The contents of file "$CONTRACT_ROOT/domains/sdlc-light/templates/bootstrap.md" should not include 'cumaru specs bootstrap'
    The contents of file "$CONTRACT_ROOT/domains/iac-basic/templates/bootstrap.md" should not include 'cumaru topology bootstrap'
  End

  It 'ships direct absorption without archive artifacts in delivery domains'
    for domain in sdlc-full iac-basic qa-basic; do
      The path "$CONTRACT_ROOT/domains/$domain/archive" should not be exist
      The path "$CONTRACT_ROOT/domains/$domain/skills/cumaru-archive" should not be exist
      The path "$CONTRACT_ROOT/domains/$domain/commands/cumaru/archive.md" should not be exist
      The path "$CONTRACT_ROOT/domains/$domain/templates/delta.md" should not be exist
      The path "$CONTRACT_ROOT/domains/$domain/skills/cumaru-absorb/SKILL.md" should be file
      The path "$CONTRACT_ROOT/domains/$domain/commands/cumaru/absorb.md" should be file
      The value "$(yq -r '.root | has("archive")' "$CONTRACT_ROOT/domains/$domain/config.yaml")" should equal false
    done
  End

  It 'keeps Ghost handoffs within its existing plan boundary'
    role="$CONTRACT_ROOT/domains/sdlc-full/roles/ghost.md"

    The contents of file "$role" should include 'plans/<KEY>/handoff-ghost-<YYYY-MM-DD>.md'
    The contents of file "$role" should include 'return the hand-off in chat'
    The contents of file "$role" should include 'route any durable authoring, structured planning, or closure to Lead'
    The contents of file "$role" should include 'Do not create an intake subdirectory or invent a plan.'
    The contents of file "$role" should include 'grants Ghost no absorption or cleanup authority'
    The contents of file "$role" should not include 'intake/<type>/<KEY>/handoff-ghost'
    The contents of file "$role" should not include 'cumaru archive <KEY>'
    The contents of file "$role" should not include 'archive finalize'
  End

  It 'promotes exploration notes through an executable file copy without overwrite'
    project="$CONTRACT_TMP/exploration-promotion"
    mkdir -p "$project/.cumaru/exploring/auth-redesign" "$project/.cumaru/plans/maintenance-auth-redesign"
    printf '%s\n' '# Exploration' '' 'required finding' >"$project/.cumaru/exploring/auth-redesign/index.md"

    first=$(cd "$project" && bash "$CONTRACT_CLI" fs exploring/auth-redesign/index.md copy plans/maintenance-auth-redesign/exploration.md)
    first_status=$?
    copied=$(cat "$project/.cumaru/plans/maintenance-auth-redesign/exploration.md")
    printf '%s\n' 'existing destination' >"$project/.cumaru/plans/maintenance-auth-redesign/exploration.md"
    second_status=0
    second=$(cd "$project" && bash "$CONTRACT_CLI" fs exploring/auth-redesign/index.md copy plans/maintenance-auth-redesign/exploration.md 2>&1) || second_status=$?

    The value "$first_status" should equal 0
    The value "$first" should include 'copy: exploring/auth-redesign/index.md'
    The value "$copied" should include 'required finding'
    The value "$second_status" should equal 1
    The value "$second" should include 'destination already exists'
    The contents of file "$project/.cumaru/plans/maintenance-auth-redesign/exploration.md" should equal 'existing destination'

    for domain in sdlc-full sdlc-light iac-basic qa-basic; do
      skill="$CONTRACT_ROOT/domains/$domain/skills/cumaru-explore/SKILL.md"
      The contents of file "$skill" should include 'fs exploring/<slug>/index.md copy plans/<PLAN-ID>/exploration.md'
      The contents of file "$skill" should not include 'fs exploring/<slug> copy plans/<PLAN-ID>/exploration.md'
    done
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
    The contents of file "$canonical" should include 'cumaru fs'
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
    for domain in iac-basic qa-basic sdlc-full sdlc-light vault-memory; do
      The value "$(files_equal "$canonical" "$CONTRACT_ROOT/domains/$domain/disciplines/code-comments.md"; printf '%s' $?)" should equal 0
      The contents of file "$CONTRACT_ROOT/domains/$domain/domain.md" should include '| code-comments | code or related artifacts are written, edited, reviewed, refactored, or documented'
    done
  End

  It 'bounds discipline actions to ownership, evidence, and existing authorization'
    tdd="$CONTRACT_ROOT/domains/sdlc-full/disciplines/test-driven-development.md"
    debugging="$CONTRACT_ROOT/domains/sdlc-full/disciplines/systematic-debugging.md"
    engineering="$CONTRACT_ROOT/domains/sdlc-full/disciplines/engineering.md"
    comments="$CONTRACT_ROOT/domains/__base/disciplines/code-comments.md"

    The contents of file "$tdd" should include 'Pre-existing code and other contributors'
    The contents of file "$tdd" should not include 'production code already exists without its test, delete it'
    The contents of file "$debugging" should include 'the attempt count alone proves nothing about the design'
    The contents of file "$debugging" should include 'attributable logs, traces, reports, or captured state'
    The contents of file "$engineering" should include 'authorization for the requested scope as durable'
    The contents of file "$engineering" should include 'unresolved scope or ownership, destructive cleanup'
    The contents of file "$comments" should include 'function body may be versioned'
    The contents of file "$comments" should include 'does not prove that the linked prose is accurate or meaningful'

    for domain in sdlc-full sdlc-light; do
      The value "$(files_equal "$tdd" "$CONTRACT_ROOT/domains/$domain/disciplines/test-driven-development.md"; printf '%s' $?)" should equal 0
      The value "$(files_equal "$debugging" "$CONTRACT_ROOT/domains/$domain/disciplines/systematic-debugging.md"; printf '%s' $?)" should equal 0
      The value "$(files_equal "$engineering" "$CONTRACT_ROOT/domains/$domain/disciplines/engineering.md"; printf '%s' $?)" should equal 0
    done

    for skill in "$CONTRACT_ROOT"/domains/{design-as-code,sdlc-full,sdlc-light}/skills/cumaru-specs/SKILL.md; do
      The contents of file "$skill" should include 'routine metadata'
      The contents of file "$skill" should include 'unresolved scope or ownership'
      The contents of file "$skill" should not include 'Confirm with the user'
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

  It 'defines one bounded atomic repository startup policy'
    index="$CONTRACT_ROOT/.memory/index.md"
    instructions="$CONTRACT_ROOT/AGENTS.md"
    issue="$CONTRACT_ROOT/.memory/issues/issue_040.md"
    The contents of file "$index" should include '1. `.memory/index.md`.'
    The contents of file "$index" should include '2. `.memory/advisor_mode.md`.'
    The contents of file "$index" should include '3. Every regular `.memory/disciplines/*.md` file in `LC_ALL=C` path order.'
    The contents of file "$index" should include '32 KiB (32,768-byte) budget'
    The contents of file "$index" should include 'selected file count and total byte count'
    The contents of file "$index" should include 'emit none of the selected file bodies'
    The contents of file "$index" should include 'Specifications are current reference material selected on demand'
    The contents of file "$index" should include 'history are historical or task-scoped material'
    The contents of file "$instructions" should include 'never bulk-load the `.memory/` tree'
    The contents of file "$issue" should include '`.memory/index.md` order'
    The contents of file "$index" should not include '@./specs/*.md'
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

  It 'starts dispatched Dev work from bounded acceptance context and reserves DAG ownership for Lead'
    for domain in sdlc-full iac-basic qa-basic; do
      dev="$CONTRACT_ROOT/domains/$domain/roles/dev.md"
      lead="$CONTRACT_ROOT/domains/$domain/roles/lead.md"
      plan="$CONTRACT_ROOT/domains/$domain/skills/cumaru-plan/SKILL.md"

      The value "$(file_has_compact_text "$dev" 'canonical acceptance source'; printf '%s' $?)" should equal 0
      The contents of file "$dev" should include 'do not list'
      The value "$(file_has_compact_text "$dev" 'Do not edit the plan'; printf '%s' $?)" should equal 0
      The contents of file "$dev" should include 'Lead reconciles them'
      The contents of file "$dev" should not include 'List available work numbered'
      The contents of file "$dev" should not include 'wait for the user to choose'
      The value "$(file_has_compact_text "$lead" 'canonical acceptance source'; printf '%s' $?)" should equal 0
      The value "$(file_has_compact_text "$lead" 'returned task status and handoff'; printf '%s' $?)" should equal 0
      The contents of file "$plan" should include 'Dev does not edit the'
      The contents of file "$plan" should include 'Lead reconciles them'
      The contents of file "$plan" should not include 'Update the DAG Status'
    done
  End

  It 'keeps SDLC Light acceptance and close-out inside its declared pillars'
    light="$CONTRACT_ROOT/domains/sdlc-light"
    plan="$light/templates/plan.md"
    delta="$light/templates/delta-draft.md"
    acceptance="$light/disciplines/acceptance-testing.md"

    The contents of file "$plan" should include 'preserve the tracker provenance and curated intent here'
    The contents of file "$plan" should not include 'intake/<KEY>'
    The contents of file "$delta" should include 'absorbs these claims directly into their owning spec areas'
    The contents of file "$delta" should not include 'archive/<PLAN-ID>'
    The contents of file "$acceptance" should include '`plans/<PLAN-ID>/index.md`'
    The contents of file "$acceptance" should include 'tracker-backed and maintenance plans'
    The contents of file "$acceptance" should not include '`intake/<KEY>/`'
    The contents of file "$light/domain.md" should include 'There is no intake or archive pillar.'
    The value "$(file_has_compact_text "$light/plans/index.md" 'removes the complete plan'; printf '%s' $?)" should equal 0
    The contents of file "$light/plans/index.md" should not include 'completed work'
    The contents of file "$light/specs/index.md" should include 'by the Lead'
    The contents of file "$light/exploring/index.md" should not include 'The Admin'
    The contents of file "$light/skills/cumaru-specs/SKILL.md" should not include 'Admin-only'
  End

  It 'requires completion evidence before close-out in every affected domain'
    for skill in \
      "$CONTRACT_ROOT/domains/sdlc-full/skills/cumaru-absorb/SKILL.md" \
      "$CONTRACT_ROOT/domains/sdlc-light/skills/cumaru-absorb/SKILL.md" \
      "$CONTRACT_ROOT/domains/iac-basic/skills/cumaru-absorb/SKILL.md" \
      "$CONTRACT_ROOT/domains/qa-basic/skills/cumaru-absorb/SKILL.md"
    do
      The value "$(file_has_compact_text "$skill" 'A `status: done` label, a completed attempt'; printf '%s' $?)" should equal 0
      The value "$(file_has_compact_text "$skill" 'does not prove'; printf '%s' $?)" should equal 0
      The value "$(file_has_compact_text "$skill" 'incomplete, infeasible, blocked, partially delivered'; printf '%s' $?)" should equal 0
      The value "$(file_has_compact_text "$skill" 'separate explicit user decision'; printf '%s' $?)" should equal 0
      The value "$(file_has_compact_text "$skill" 'never a ghost delta'; printf '%s' $?)" should equal 0
    done
  End

  It 'orders validation and committed recovery before cleanup'
    for skill in \
      "$CONTRACT_ROOT/domains/sdlc-full/skills/cumaru-absorb/SKILL.md" \
      "$CONTRACT_ROOT/domains/sdlc-light/skills/cumaru-absorb/SKILL.md" \
      "$CONTRACT_ROOT/domains/iac-basic/skills/cumaru-absorb/SKILL.md" \
      "$CONTRACT_ROOT/domains/qa-basic/skills/cumaru-absorb/SKILL.md"
    do
      validation=$(grep -nF '## Phase 2 — validate the durable result' "$skill" | cut -d: -f1)
      recovery=$(grep -nF '## Phase 3 — establish the recovery point' "$skill" | cut -d: -f1)
      cleanup=$(grep -nF '## Phase 4 — clean transient work' "$skill" | cut -d: -f1)
      The value "$validation" should be present
      The value "$recovery" should be present
      The value "$cleanup" should be present
      The value "$([ "$validation" -lt "$recovery" ] && [ "$recovery" -lt "$cleanup" ] && printf yes)" should equal yes
      The contents of file "$skill" should include 'git show HEAD:'
      The contents of file "$skill" should include 'git diff HEAD --'
      The contents of file "$skill" should include 'git status --porcelain=v1'
      The value "$(file_has_compact_text "$skill" '--untracked-files=all --ignored=traditional'; printf '%s' $?)" should equal 0
      The value "$(file_has_compact_text "$skill" 'status check without ignored files can miss evidence'; printf '%s' $?)" should equal 0
      The value "$(file_has_compact_text "$skill" 'does not establish semantic completion.'; printf '%s' $?)" should equal 0
    done
  End

  It 'keeps source plans intact until the recovery commit exists'
    for domain in sdlc-full iac-basic qa-basic; do
      skill="$CONTRACT_ROOT/domains/$domain/skills/cumaru-absorb/SKILL.md"
      The contents of file "$skill" should include 'Finalize the delta in place before durable edits'
      The contents of file "$skill" should not include 'archive/<KEY>'
      The contents of file "$skill" should include 'remains intact throughout absorption and validation.'
      The contents of file "$skill" should include 'Only after Phase 3 succeeds'
    done
  End

  It 'routes Lead close-out through the canonical domain skill'
    for domain in sdlc-full iac-basic qa-basic; do
      role="$CONTRACT_ROOT/domains/$domain/roles/lead.md"
      The contents of file "$role" should include 'Use the canonical `cumaru-absorb` skill'
      The contents of file "$role" should include 'status is a routing signal, not completion evidence'
      The contents of file "$role" should not include 'git add'
      The value "$(grep -E 'cumaru fs .* remove' "$role" || true)" should equal ''
    done
    role="$CONTRACT_ROOT/domains/sdlc-light/roles/lead.md"
    The contents of file "$role" should include 'Use the canonical `cumaru-absorb` skill'
    The contents of file "$role" should include 'status is a routing signal, not completion evidence'
    The contents of file "$role" should not include 'git add'
    The value "$(grep -E 'cumaru fs .* remove' "$role" || true)" should equal ''
  End

  It 'documents direct absorption and gated removal'
    flow="$CONTRACT_ROOT/docs/fs.md"
    The contents of file "$flow" should include 'Copy supporting evidence while the original remains intact.'
    The contents of file "$flow" should include 'cumaru-absorb'
    The contents of file "$flow" should include 'establishes a committed recovery point containing every target'
    The contents of file "$flow" should not include 'non-destructive moves and copies'
  End

  It 'detects untracked and ignored close-out evidence without mutation'
    project="$CONTRACT_TMP/closeout-dirty"
    plan="$project/.cumaru/plans/AAA-1234"
    mkdir -p "$plan"
    printf '%s\n' '.cumaru/plans/*/ignored-evidence.md' >"$project/.gitignore"
    printf '%s\n' '# Plan' >"$plan/index.md"
    printf '%s\n' '# Task' >"$plan/t1.md"
    printf '%s\n' '# Handoff' >"$plan/handoff-t1.md"
    printf '%s\n' '# Delta' >"$plan/delta-draft.md"
    (
      cd "$project" || exit 1
      git init -q
      git config user.email test@example.com
      git config user.name 'Cumaru Test'
      git add -- .gitignore .cumaru/plans/AAA-1234
      git commit -qm '🧪 seed close-out fixture'
    )
    printf '%s\n' '# Untracked task' >"$plan/t2.md"
    printf '%s\n' '# Ignored evidence' >"$plan/ignored-evidence.md"
    cp -R "$project/.cumaru" "$CONTRACT_TMP/closeout-dirty.before"

    status=$(cd "$project" && git status --porcelain=v1 --untracked-files=all --ignored=traditional -- .cumaru/plans/AAA-1234)
    inventory=$(cd "$project" && find .cumaru/plans/AAA-1234 -type f -print | LC_ALL=C sort)
    tracked=$(cd "$project" && git ls-files --full-name -- .cumaru/plans/AAA-1234 | LC_ALL=C sort)

    The value "$status" should include '?? .cumaru/plans/AAA-1234/t2.md'
    The value "$status" should include '!! .cumaru/plans/AAA-1234/ignored-evidence.md'
    The value "$inventory" should not equal "$tracked"
    The value "$(diff -r "$CONTRACT_TMP/closeout-dirty.before" "$project/.cumaru")" should equal ''
  End

  It 'retains every cleanup target and the durable result in the recovery commit'
    project="$CONTRACT_TMP/closeout-recovery"
    plan="$project/.cumaru/plans/AAA-1234"
    spec="$project/.cumaru/specs/auth/index.md"
    mkdir -p "$plan" "$(dirname "$spec")"
    printf '%s\n' '# Plan' >"$plan/index.md"
    printf '%s\n' '# Task' >"$plan/t1.md"
    printf '%s\n' '# Handoff' >"$plan/handoff-t1.md"
    printf '%s\n' '# Delta draft' >"$plan/delta-draft.md"
    printf '%s\n' '# Old durable state' >"$spec"
    (
      cd "$project" || exit 1
      git init -q
      git config user.email test@example.com
      git config user.name 'Cumaru Test'
      git add -- .cumaru
      git commit -qm '🧪 seed close-out fixture'
    )
    printf '%s\n' '# Finalized delta' >"$plan/delta-draft.md"
    printf '%s\n' '# Verified durable state' >"$spec"
    (
      cd "$project" || exit 1
      git add -- .cumaru/specs/auth/index.md .cumaru/plans/AAA-1234
      git commit -qm '🧪 record recoverable close-out'
    )
    recovery=$(cd "$project" && git rev-parse HEAD)
    inventory=$(cd "$project" && find .cumaru/plans/AAA-1234 -type f -print | LC_ALL=C sort)
    tracked=$(cd "$project" && git ls-files --full-name -- .cumaru/plans/AAA-1234 | LC_ALL=C sort)
    blobs=$(cd "$project" && for path in $tracked .cumaru/specs/auth/index.md; do git show "$recovery:$path" >/dev/null || exit 1; done)
    clean=$(cd "$project" && git diff --quiet HEAD -- .cumaru/plans/AAA-1234 .cumaru/specs/auth/index.md; printf '%s' $?)
    rm -r "$plan"
    restored=$(cd "$project" && git show "$recovery:.cumaru/plans/AAA-1234/t1.md")

    The value "$inventory" should equal "$tracked"
    The value "$blobs" should equal ''
    The value "$clean" should equal 0
    The path "$plan" should not be exist
    The value "$restored" should equal '# Task'
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
    project="$CONTRACT_TMP/pre-v8"
    mkdir -p "$project"
    (cd "$project" && bash "$CONTRACT_CLI" install --domain base) >/dev/null 2>&1 || return
    git -C "$CONTRACT_ROOT" show HEAD:domains/__base/config.yaml > "$project/.cumaru/config.yaml" || return
    yq -i '.version = 5' "$project/.cumaru/config.yaml"
    cd "$project" && bash "$CONTRACT_CLI" doctor
  }

  It 'rejects pre-v8 trees before running the eight checks'
    When call doctor_pre_v7
    The status should be failure
    The output should include 'Run: cumaru migrate'
    The output should not include 'Summary:'
  End
End

Describe 'exact absorption ownership and provenance contracts'
  BeforeEach 'contract_tmp_setup'
  AfterEach 'contract_tmp_cleanup'

  It 'carries every delivery claim to its exact durable file'
    for skill in \
      "$CONTRACT_ROOT/domains/sdlc-full/skills/cumaru-absorb/SKILL.md" \
      "$CONTRACT_ROOT/domains/sdlc-light/skills/cumaru-absorb/SKILL.md" \
      "$CONTRACT_ROOT/domains/iac-basic/skills/cumaru-absorb/SKILL.md" \
      "$CONTRACT_ROOT/domains/qa-basic/skills/cumaru-absorb/SKILL.md"
    do
      The contents of file "$skill" should include 'claim-to-file map'
      The contents of file "$skill" should include 'exact file is the target'
      The contents of file "$skill" should include 'never duplicate a nested'
      The contents of file "$skill" should include 'consumed cleanup set'
      The contents of file "$skill" should include 'shared source'
    done

    The contents of file "$CONTRACT_ROOT/domains/sdlc-full/skills/cumaru-absorb/SKILL.md" should not include 'Edit `specs/<area>/index.md` body'
    The contents of file "$CONTRACT_ROOT/domains/sdlc-light/skills/cumaru-absorb/SKILL.md" should not include 'Edit `specs/<area>/index.md` body'
    The contents of file "$CONTRACT_ROOT/domains/iac-basic/skills/cumaru-absorb/SKILL.md" should not include 'Edit `topology/<area>/index.md` body'
    The contents of file "$CONTRACT_ROOT/domains/qa-basic/skills/cumaru-absorb/SKILL.md" should not include 'Edit `coverage/<area>/index.md` body'
    The contents of file "$CONTRACT_ROOT/domains/iac-basic/skills/cumaru-topology/SKILL.md" should not include 'History lives in `archive/'
    The contents of file "$CONTRACT_ROOT/domains/sdlc-full/domain.md" should not include 'all transient content for that cycle is removed'
  End

  It 'reconciles QA intake provenance before consumed cleanup'
    skill="$CONTRACT_ROOT/domains/qa-basic/skills/cumaru-absorb/SKILL.md"
    domain="$CONTRACT_ROOT/domains/qa-basic/domain.md"
    template="$CONTRACT_ROOT/domains/qa-basic/templates/coverage.md"

    The contents of file "$skill" should include 'acceptance fact'
    The contents of file "$skill" should include 'stable upstream tracker reference'
    The contents of file "$skill" should include 'remove or replace the local `relates:` edge'
    The value "$(file_has_compact_text "$domain" 'no absorption ledger'; printf '%s' $?)" should equal 0
    The contents of file "$template" should include 'stable upstream tracker URL in `## Decisions`'
    The contents of file "$domain" should not include 'records the absorbed campaign SHA'
  End

  It 'allows non-Git Vault distillation only after durable provenance retention'
    project="$CONTRACT_TMP/vault-distill"
    capture="$project/.cumaru/inbox/source-note"
    memory="$project/.cumaru/memories/durable-note/index.md"
    mkdir -p "$capture" "$(dirname "$memory")"
    printf '%s\n' '# Raw source' >"$capture/index.md"
    printf '%s\n' '---' 'derived-from: [https://example.test/source]' '---' '' '# Durable note' '' '## Notes' '' 'Source retained as stable URL.' >"$memory"

    output=$(cd "$project" && bash "$CONTRACT_CLI" fs inbox/source-note remove)

    The value "$output" should include 'remove: inbox/source-note'
    The path "$capture" should not be exist
    The contents of file "$memory" should include 'https://example.test/source'
    The path "$project/.git" should not be exist
    The contents of file "$CONTRACT_ROOT/domains/vault-memory/skills/cumaru-distill/SKILL.md" should include 'Missing provenance or uncertain ownership blocks removal'
    The value "$(file_has_compact_text "$CONTRACT_ROOT/domains/vault-memory/skills/cumaru-distill/SKILL.md" 'Git is not a prerequisite'; printf '%s' $?)" should equal 0
  End
End
