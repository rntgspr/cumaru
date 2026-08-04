Include tests/spec/cli/support/helpers.sh

Describe 'cumaru tree'
  BeforeEach 'tree_setup'
  AfterEach 'tree_cleanup'

  It 'prints help outside a project without diagnostics'
    rm -rf "$TREE_PROJECT/.cumaru"
    When call cli_in "$TREE_PROJECT" tree --help
    The status should be success
    The output should include 'cumaru tree [<directory-or-md>] [--deep] [--rows]'
    The error should be blank
  End

  It 'fails outside a project on stderr'
    rm -rf "$TREE_PROJECT/.cumaru"
    When call cli_in "$TREE_PROJECT" tree
    The status should be failure
    The output should be blank
    The error should include '.cumaru/ not found'
  End

  It 'lists shallow candidates in sorted TSV and omits hidden and unindexed paths'
    When call cli_in "$TREE_PROJECT" tree --rows
    The status should be success
    The output should equal "alpha.md	Alpha behavior provides stable selection context.
area/	Area contracts group related behavior for navigation.
zeta.md	Zeta behavior provides stable selection context."
    The error should be blank
  End

  It 'escapes Markdown paths and summaries but keeps rows raw'
    write_md "$TREE_PROJECT/.cumaru/back\\name.md" 'Backslash \ and pipe | remain deterministic in summaries.'
    write_md "$TREE_PROJECT/.cumaru/pipe|name.md" 'Pipe paths remain deterministic in Markdown and TSV output.'
    markdown=$(cli_in "$TREE_PROJECT" tree)
    rows=$(cli_in "$TREE_PROJECT" tree --rows)
    The value "$markdown" should include 'back\\name.md | Backslash \\ and pipe \| remain deterministic'
    The value "$markdown" should include 'pipe\|name.md'
    The value "$rows" should include "back\name.md	Backslash \ and pipe | remain deterministic"
    The value "$rows" should include "pipe|name.md	Pipe paths remain deterministic"
  End

  It 'normalizes a Markdown target to its parent'
    When call cli_in "$TREE_PROJECT" tree alpha.md --rows
    The status should be success
    The output should include 'area/'
  End

  It 'lists an explicit directory root-relatively'
    When call cli_in "$TREE_PROJECT" tree area --rows
    The status should be success
    The output should equal "area/leaf.md	Area leaf behavior is available after explicit selection."
  End

  Context 'with invalid targets'
    Parameters
      '/tmp' 'target must be relative'
      'area/../alpha.md' '`..` path segments are not allowed'
      'note.txt' 'file target must end in .md'
      '.secret' 'hidden'
    End
    It 'rejects before candidate output'
      When call cli_in "$TREE_PROJECT" tree "$1"
      The status should be failure
      The output should be blank
      The error should include "$2"
    End
  End

  It 'composes domain, pillar, deep, and row filters using the canonical fixture'
    rm -rf "$TREE_PROJECT/.cumaru"
    cp -R "$REPO_ROOT/tests/fixtures/tree-filters/.cumaru" "$TREE_PROJECT/.cumaru"
    When call cli_in "$TREE_PROJECT" tree --domain test-domain --pillars specs --deep --rows
    The status should be success
    The output should equal "specs/	Specifications selected independently by schema-backed tree filters.
specs/auth/	Authentication specifications exercise filtered deep navigation.
specs/auth/session.md	Session behavior remains inside the selected specification pillar.
specs/overview.md	Specification overview available from shallow filtered navigation."
    The error should be blank
  End

  It 'rejects unknown pillars before candidate output'
    rm -rf "$TREE_PROJECT/.cumaru"; cp -R "$REPO_ROOT/tests/fixtures/tree-filters/.cumaru" "$TREE_PROJECT/.cumaru"
    When call cli_in "$TREE_PROJECT" tree --pillars unknown --rows
    The status should be failure
    The output should be blank
    The error should include 'unknown pillar for domain test-domain: unknown'
  End

  Context 'with complete schema filters'
    Parameters
      '--pillars plans' 0 'plans/' ''
      '--pillars=plans,specs --rows' 0 'specs/' ''
      '--pillars plans,plans,specs --rows' 0 'plans/' ''
      'specs --pillars specs --rows' 0 'specs/overview.md' ''
      'specs/overview.md --pillars specs --rows' 0 'specs/auth/' ''
      '--domain test-domain --rows' 0 'plans/' ''
      '--pillars plans,,specs --rows' 1 '' 'invalid pillar filter'
      '--pillars= --rows' 2 '' '--pillars requires a value'
      '--pillars plans specs --rows' 1 '' 'invalid pillar filter'
      'plans --pillars specs --rows' 1 '' 'target is outside the selected pillars'
      'plans/active.md --pillars specs --rows' 1 '' 'target is outside the selected pillars'
      '--domain wrong-domain --rows' 1 '' 'installed domain is test-domain, not wrong-domain'
    End
    It 'accepts or rejects each filter combination deterministically'
      rm -rf "$TREE_PROJECT/.cumaru"; cp -R "$REPO_ROOT/tests/fixtures/tree-filters/.cumaru" "$TREE_PROJECT/.cumaru"
      args=$1 expected_status=$2 expected_output=$3 expected_error=$4
      if [ "$args" = '--pillars plans specs --rows' ]; then
        When call cli_in "$TREE_PROJECT" tree --pillars 'plans specs' --rows
      else
        set -- $args
        When call cli_in "$TREE_PROJECT" tree "$@"
      fi
      The status should equal "$expected_status"
      if [ "$expected_status" -eq 0 ]; then
        The output should include "$expected_output"
        The error should be blank
      else
        The output should be blank
        The error should include "$expected_error"
      fi
    End
  End

  Context 'with invalid filter configuration'
    Parameters
      missing 'filters require a regular .cumaru/config.yaml'
      malformed 'cannot read domain from .cumaru/config.yaml'
      no-entities 'unknown pillar for domain test-domain: plans'
      no-domain 'config domain must be a non-empty string'
    End
    It 'fails before candidate output'
      rm -rf "$TREE_PROJECT/.cumaru"; cp -R "$REPO_ROOT/tests/fixtures/tree-filters/.cumaru" "$TREE_PROJECT/.cumaru"
      case "$1" in
        missing) rm "$TREE_PROJECT/.cumaru/config.yaml" ;;
        malformed) printf 'domain: [unterminated\n' > "$TREE_PROJECT/.cumaru/config.yaml" ;;
        no-entities) printf 'domain: test-domain\nroot: {}\n' > "$TREE_PROJECT/.cumaru/config.yaml" ;;
        no-domain) printf 'root:\n  entities:\n    plans: {}\n' > "$TREE_PROJECT/.cumaru/config.yaml" ;;
      esac
      When call cli_in "$TREE_PROJECT" tree --pillars plans --rows
      The status should be failure
      The output should be blank
      The error should include "$2"
    End
  End

  It 'deep mode emits valid descendants and reports all navigation defects'
    mkdir -p "$TREE_PROJECT/.cumaru/noindex" "$TREE_PROJECT/.cumaru/empty"
    write_md "$TREE_PROJECT/.cumaru/noindex/leaf.md" 'A valid leaf remains discoverable below a missing index.'
    write_md "$TREE_PROJECT/.cumaru/bad.md" 'too short'
    When call cli_in "$TREE_PROJECT" tree --deep --rows
    The status should be failure
    The output should include 'noindex/leaf.md'
    The output should not include 'bad.md'
    The error should include 'noindex/index.md'
    The error should include 'empty/index.md'
  End

  It 'deep mode rejects control-character paths while retaining valid descendants'
    control=$(printf 'control\nname.md')
    write_md "$TREE_PROJECT/.cumaru/$control" 'Control character paths must never reach output records.'
    When call cli_in "$TREE_PROJECT" tree --deep --rows
    The status should be failure
    The output should include 'alpha.md'
    The error should include 'control character'
  End

  Context 'with summary boundaries and YAML forms'
    Parameters
      valid32 valid 32
      invalid31 invalid 31
      valid512 valid 512
      invalid513 invalid 513
      unicode32 valid unicode
      bool invalid bool
      padded invalid padded
      tab invalid tab
      folded valid folded
      literal invalid literal
      malformed invalid malformed
    End
    It 'classifies the complete summary matrix'
      rm -rf "$TREE_PROJECT/.cumaru/unindexed"
      file="$TREE_PROJECT/.cumaru/candidate.md"
      case "$3" in
        32|31|512|513) value=$(printf "%${3}s" '' | tr ' ' a); write_md "$file" "$value" ;;
        unicode) value=''; i=0; while [ "$i" -lt 32 ]; do value="${value}é"; i=$((i + 1)); done; write_md "$file" "$value" ;;
        bool) write_raw_md "$file" $'---\nsummary: true\n---\n# Bool\n' ;;
        padded) write_md "$file" ' This padded summary has invalid surrounding whitespace. ' ;;
        tab) write_raw_md "$file" $'---\nsummary: "This otherwise valid summary contains\\tone tab."\n---\n# Tab\n' ;;
        folded) write_raw_md "$file" $'---\nsummary: >-\n  This folded summary remains valid\n  as one resolved line for navigation.\n---\n# Folded\n' ;;
        literal) write_raw_md "$file" $'---\nsummary: |-\n  This literal summary retains a newline\n  and therefore cannot be a selection signal.\n---\n# Literal\n' ;;
        malformed) write_raw_md "$file" $'---\nsummary: [unterminated\n---\n# Malformed\n' ;;
      esac
      When call cli_in "$TREE_PROJECT" tree --deep --rows
      if [ "$2" = valid ]; then
        The status should be success
        The output should include 'candidate.md'
        The error should be blank
      else
        The status should be failure
        The output should not include 'candidate.md'
        The error should include 'candidate.md'
      fi
    End
  End

  It 'rejects discovered and direct symlinks without emitting them'
    ln -s alpha.md "$TREE_PROJECT/.cumaru/link.md"
    When call cli_in "$TREE_PROJECT" tree --deep --rows
    The status should be failure
    The output should not include 'link.md'
    The error should include 'link.md'
  End

  It 'rejects broken, directory, escaping, cyclic, and descendant symlinks'
    write_md "$TREE_PROJECT/outside.md" 'Outside content must never be read through an escaping link.'
    ln -s absent.md "$TREE_PROJECT/.cumaru/broken.md"
    ln -s area "$TREE_PROJECT/.cumaru/link-dir"
    ln -s "$TREE_PROJECT/outside.md" "$TREE_PROJECT/.cumaru/escape.md"
    ln -s .. "$TREE_PROJECT/.cumaru/area/cycle"
    ln -s ../alpha.md "$TREE_PROJECT/.cumaru/area/descendant.md"
    When call cli_in "$TREE_PROJECT" tree --deep --rows
    The status should be failure
    The output should not include 'link-dir/'
    The output should not include 'escape.md'
    The error should include 'broken.md'
    The error should include 'area/cycle'
    The error should include 'area/descendant.md'
  End

  It 'rejects direct and intermediate symlink targets'
    ln -s area "$TREE_PROJECT/.cumaru/target-link"
    direct=$(cli_in "$TREE_PROJECT" tree target-link --rows 2>&1; printf ':status=%s' "$?")
    mkdir -p "$TREE_PROJECT/.cumaru/actual/child"
    write_md "$TREE_PROJECT/.cumaru/actual/index.md" 'Actual parent directory exists for intermediate link testing.'
    write_md "$TREE_PROJECT/.cumaru/actual/child/index.md" 'Actual child directory exists for intermediate link testing.'
    ln -s actual "$TREE_PROJECT/.cumaru/intermediate"
    When call cli_in "$TREE_PROJECT" tree intermediate/child --rows
    The status should be failure
    The error should include 'target contains a symlink'
    The value "$direct" should include 'target contains a symlink'
    The value "$direct" should include ':status=1'
  End

  It 'treats an incompatible yq as a hard runtime failure with no report'
    fake="$TREE_TMP/fake-bin"; mkdir -p "$fake"
    printf '#!/bin/sh\nprintf "yq 3.4.1\\n"\n' > "$fake/yq"; chmod +x "$fake/yq"
    When run env PATH="$fake:/usr/bin:/bin" /bin/bash -c 'cd "$1" && exec /bin/bash "$2" tree --rows' _ "$TREE_PROJECT" "$CLI"
    The status should be failure
    The output should be blank
    The error should include 'incompatible yq'
  End
End
