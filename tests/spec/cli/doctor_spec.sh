Include tests/spec/cli/support/helpers.sh

Describe 'cumaru doctor'
  BeforeEach 'doctor_setup'
  AfterEach 'doctor_cleanup'

  doctor_subprocess_counts() {
    local bin="$DOCTOR_TMP/bin" log="$DOCTOR_TMP/subprocesses.log" real_yq real_jq
    real_yq=$(command -v yq) || return 1
    real_jq=$(command -v jq) || return 1
    mkdir -p "$bin"
    printf '%s\n' '#!/bin/sh' 'printf "yq\n" >> "$CUMARU_COUNT_LOG"' 'exec "$CUMARU_REAL_YQ" "$@"' > "$bin/yq"
    printf '%s\n' '#!/bin/sh' 'printf "jq\n" >> "$CUMARU_COUNT_LOG"' 'exec "$CUMARU_REAL_JQ" "$@"' > "$bin/jq"
    chmod +x "$bin/yq" "$bin/jq"
    : > "$log"
    (
      cd "$DOCTOR_PROJECT" || exit 1
      PATH="$bin:$PATH" CUMARU_COUNT_LOG="$log" CUMARU_REAL_YQ="$real_yq" CUMARU_REAL_JQ="$real_jq" \
        /bin/bash "$CLI" doctor --quiet >/dev/null
    ) || return 1
    printf '%s\t%s\n' "$(grep -c '^yq$' "$log")" "$(grep -c '^jq$' "$log")"
  }

  doctor_tag_metadata_is_cached() {
    local baseline many i
    baseline=$(doctor_subprocess_counts) || return 1
    mkdir -p "$DOCTOR_PROJECT/src"
    {
      printf '%s\n' '<!-- cumaru:reference -->' '| Link | Description |' '|---|---|'
      i=1
      while [ "$i" -le 32 ]; do
        printf 'source %s\n' "$i" > "$DOCTOR_PROJECT/src/reference-$i.txt"
        printf '| [reference-%s](src/reference-%s.txt) | Source row %s stays valid. |\n' "$i" "$i" "$i"
        i=$((i + 1))
      done
      printf '%s\n' '<!-- /cumaru:reference -->'
    } >> "$DOCTOR_PROJECT/.cumaru/notes/leaf.md"
    many=$(doctor_subprocess_counts) || return 1
    [ "$baseline" = "$many" ]
  }

  # Create a valid custom v9 tree with an installed workflow skill.
  custom_doctor_project() {
    CUSTOM_DOCTOR_PROJECT="$DOCTOR_TMP/custom-project"
    mkdir -p "$CUSTOM_DOCTOR_PROJECT"
    cli_in "$CUSTOM_DOCTOR_PROJECT" install --domain base >/dev/null || return 1
    yq -i '.domain = "edm-music" | .root.beats = {"frontmatter": {"genre": {}}} | .workflows = {"flow": {"steps": {"first": {"skill": "cumaru-role"}}}}' "$CUSTOM_DOCTOR_PROJECT/.cumaru/config.yaml" || return 1
    mkdir -p "$CUSTOM_DOCTOR_PROJECT/.cumaru/beats"
    cp "$CUSTOM_DOCTOR_PROJECT/.cumaru/index.md" "$CUSTOM_DOCTOR_PROJECT/.cumaru/beats/index.md"
    yq -i --front-matter=process '.genre = "house"' "$CUSTOM_DOCTOR_PROJECT/.cumaru/beats/index.md"
  }

  It 'runs all eight checks on a healthy fixture'
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'Summary: 0 error(s), 3 warning(s), 5 ok'
    The error should be blank
  End

  It 'reports valid configuration drift for agent review without mutation'
    yq -i 'del(.rules.ears)' "$DOCTOR_PROJECT/.cumaru/config.yaml"
    cp "$DOCTOR_PROJECT/.cumaru/config.yaml" "$DOCTOR_TMP/config.before.yaml"
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'Configuration needs agent review'
    The output should include 'Schema:'
    The output should include "'cumaru update config'"
    The value "$(cmp -s "$DOCTOR_PROJECT/.cumaru/config.yaml" "$DOCTOR_TMP/config.before.yaml"; printf '%s' $?)" should equal 0
  End

  It 'uses base defaults for a custom v9 domain without requiring a source package'
    custom_doctor_project
    cp "$CUSTOM_DOCTOR_PROJECT/.cumaru/config.yaml" "$DOCTOR_TMP/custom-config.before.yaml"
    cp "$CUSTOM_DOCTOR_PROJECT/.cumaru/beats/index.md" "$DOCTOR_TMP/custom-index.before.md"
    When call cli_in "$CUSTOM_DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'Summary: 0 error(s)'
    The output should not include 'Source defaults unavailable'
    The output should not include 'Configuration needs agent review'
    The value "$(cmp -s "$CUSTOM_DOCTOR_PROJECT/.cumaru/config.yaml" "$DOCTOR_TMP/custom-config.before.yaml"; printf '%s' $?)" should equal 0
    The value "$(cmp -s "$CUSTOM_DOCTOR_PROJECT/.cumaru/beats/index.md" "$DOCTOR_TMP/custom-index.before.md"; printf '%s' $?)" should equal 0
  End

  It 'keeps missing custom direct-tree paths as doctor errors'
    custom_doctor_project
    yq -i '.root."missing.md" = {"frontmatter": {"summary": {}}}' "$CUSTOM_DOCTOR_PROJECT/.cumaru/config.yaml"
    When call cli_in "$CUSTOM_DOCTOR_PROJECT" doctor --quiet
    The status should be failure
    The output should include 'required entry is missing: missing.md'
  End

  It 'keeps required custom frontmatter as a doctor error'
    custom_doctor_project
    yq -i --front-matter=process 'del(.genre)' "$CUSTOM_DOCTOR_PROJECT/.cumaru/beats/index.md"
    When call cli_in "$CUSTOM_DOCTOR_PROJECT" doctor --quiet
    The status should be failure
    The output should include "beats/index.md: missing required frontmatter field 'genre'"
  End

  It 'rejects a custom workflow skill missing from every installed adapter'
    custom_doctor_project
    yq -i '.workflows.flow.steps.first.skill = "cumaru-not-real"' "$CUSTOM_DOCTOR_PROJECT/.cumaru/config.yaml"
    When call cli_in "$CUSTOM_DOCTOR_PROJECT" doctor --quiet
    The status should be failure
    The output should include 'workflow references unavailable domain skill: cumaru-not-real'
  End

  It 'parses tag metadata once regardless of reference row count'
    When call doctor_tag_metadata_is_cached
    The status should be success
  End

  It 'reports balanced nested tags as warning-only and names the host'
    cat >> "$DOCTOR_PROJECT/.cumaru/notes/leaf.md" <<'EOF'
<!-- cumaru:root -->
Outer context.
<!-- cumaru:relations -->
Nested context.
<!-- /cumaru:relations -->
<!-- /cumaru:root -->
EOF
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'notes/leaf.md: balanced nested tags are valid but need adopter review'
    The output should include 'Summary: 0 error(s), 3 warning(s), 5 ok'
  End

  Context 'with malformed semantic tags'
    Parameters
      unclosed 'tag "root" was never closed'
      crossing 'tags cross: "relations" is still open before "root"'
      unknown 'tag "custom-local" was never closed'
    End

    It 'attributes a doctor error to the host and preserves the entire tree'
      case "$1" in
        unclosed) printf '%s\n' '<!-- cumaru:root -->' 'Unclosed evidence.' ;;
        crossing) printf '%s\n' '<!-- cumaru:root -->' '<!-- cumaru:relations -->' '<!-- /cumaru:root -->' ;;
        unknown) printf '%s\n' '<!-- cumaru:custom-local -->' 'Opaque but unclosed evidence.' ;;
      esac >> "$DOCTOR_PROJECT/.cumaru/notes/leaf.md"
      cp -R "$DOCTOR_PROJECT/.cumaru" "$DOCTOR_TMP/cumaru.before"

      When call cli_in "$DOCTOR_PROJECT" doctor
      The status should equal 1
      The output should include 'Malformed semantic tags found'
      The output should include "notes/leaf.md $2"
      The output should include 'Summary: 1 error(s), 2 warning(s), 5 ok'
      The output should not include 'Marker contracts contain no retired structural inventories'
      The error should be blank
      The value "$(diff -r "$DOCTOR_TMP/cumaru.before" "$DOCTOR_PROJECT/.cumaru")" should be blank
    End
  End

  It 'accepts duplicate balanced tags without rewriting their bodies'
    printf '%s\n' '<!-- cumaru:root -->' 'First body.' '<!-- /cumaru:root -->' \
      '<!-- cumaru:root -->' 'Second body.' '<!-- /cumaru:root -->' >> "$DOCTOR_PROJECT/.cumaru/notes/leaf.md"
    cp "$DOCTOR_PROJECT/.cumaru/notes/leaf.md" "$DOCTOR_TMP/leaf.before.md"

    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'Summary: 0 error(s), 3 warning(s), 5 ok'
    The error should be blank
    The value "$(cmp -s "$DOCTOR_TMP/leaf.before.md" "$DOCTOR_PROJECT/.cumaru/notes/leaf.md"; printf '%s' $?)" should equal 0
  End

  It 'warns when no complete Claude, Codex, or OpenCode instructions remain'
    perl -0pi -e 's/<!-- END CUMARU-HOOK -->/<!-- END CUMARU-HOOK BROKEN -->/' "$DOCTOR_PROJECT/AGENTS.md"
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'No complete Cumaru agent instruction set is installed'
  End

  It 'fails when a local non-hidden directory lacks index.md'
    rm "$DOCTOR_PROJECT/.cumaru/support/index.md"
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be failure
    The output should include 'non-hidden directory lacks a real index.md: support/'
    The output should include 'cumaru tree --deep'
  End

  It 'fails missing discipline strictness with an effective zero diagnostic'
    write_doctor_md "$DOCTOR_PROJECT/.cumaru/disciplines/index.md" 'Discipline evaluation contract for the focused doctor fixture.'
    write_doctor_md "$DOCTOR_PROJECT/.cumaru/disciplines/example.md" 'Example execution discipline with intentionally incomplete metadata.' $'name: example\napplies-when: exercising missing strictness validation'
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be failure
    The output should include 'disciplines/example.md: strictness is required'
    The output should include 'treated as 0/10'
  End

  Context 'with invalid summaries'
    Parameters
      bool 'summary must be a YAML string'
      padded 'summary has leading or trailing whitespace'
      short 'shorter than 32 Unicode code points'
    End
    It 'enforces type, trim, and lower boundary contracts'
      leaf="$DOCTOR_PROJECT/.cumaru/notes/leaf.md"
      case "$1" in
        bool) yq -i '.summary = true' "$leaf" ;;
        padded) yq -i '.summary = " leading whitespace makes this summary invalid."' "$leaf" ;;
        short) yq -i '.summary = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "$leaf" ;;
      esac
      When call cli_in "$DOCTOR_PROJECT" doctor --quiet
      The status should be failure
      The output should include "$2"
    End
  End

  It 'rejects multiline summaries as control characters'
    leaf="$DOCTOR_PROJECT/.cumaru/notes/leaf.md"
    write_raw_md "$leaf" $'---\nhuman_revised: false\nsummary: |-\n  First valid-looking line has enough characters.\n  Second line makes the scalar invalid.\ngenerated: false\napps: [meta]\n---\n# Fixture\n'
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be failure
    The output should include 'summary contains a control character'
  End

  It 'accepts 32 multibyte code points'
    value=''; i=0; while [ "$i" -lt 32 ]; do value="${value}é"; i=$((i + 1)); done
    yq -i ".summary = \"$value\"" "$DOCTOR_PROJECT/.cumaru/notes/leaf.md"
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'Summary: 0 error(s), 3 warning(s), 5 ok'
  End

  It 'accepts 512 code points'
    value=$(printf '%512s' '' | tr ' ' a)
    yq -i ".summary = \"$value\"" "$DOCTOR_PROJECT/.cumaru/notes/leaf.md"
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'Summary: 0 error(s), 3 warning(s), 5 ok'
  End

  It 'rejects 513 code points'
    value=$(printf '%513s' '' | tr ' ' a)
    yq -i ".summary = \"$value\"" "$DOCTOR_PROJECT/.cumaru/notes/leaf.md"
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be failure
    The output should include 'longer than 512 Unicode code points'
  End

  It 'keeps unknown marker bodies opaque instead of resolving their paths'
    cat >> "$DOCTOR_PROJECT/.cumaru/notes/leaf.md" <<'EOF'
<!-- cumaru:custom-local -->
| Link | Description |
|---|---|
| [ghost](missing/ghost.md) | Must remain opaque. |
<!-- /cumaru:custom-local -->
EOF
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'body kept opaque and not path-resolved'
    The output should not include 'missing/ghost.md - target not found'
  End

  It 'keeps a retired absorptions tag visible and opaque'
    cat >> "$DOCTOR_PROJECT/.cumaru/notes/index.md" <<'EOF'
<!-- cumaru:absorptions -->
| Link | Description |
|---|---|
<!-- /cumaru:absorptions -->
EOF
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'body kept opaque and not path-resolved'
  End

  It 'accepts touched removals and rejects escaping references as warning-only'
    mkdir -p "$DOCTOR_PROJECT/src"; printf 'live\n' > "$DOCTOR_PROJECT/src/live.txt"
    cat >> "$DOCTOR_PROJECT/.cumaru/notes/leaf.md" <<'EOF'
<!-- cumaru:touched -->
| Link | Description |
|---|---|
| [live](src/live.txt) | modified - still present |
| [gone](src/gone.txt) | removed - intentionally absent |
<!-- /cumaru:touched -->
<!-- cumaru:reference -->
| Link | Description |
|---|---|
| [escape](../outside.txt) | Invalid traversal must not become stale. |
<!-- /cumaru:reference -->
EOF
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'invalid path, file type, containment, or final symlink target'
    The output should not include '../outside.txt - target not found'
  End

  It 'classifies a final symlink escape as invalid rather than missing'
    outside="$DOCTOR_TMP/outside.txt"; printf 'outside\n' > "$outside"; ln -s "$outside" "$DOCTOR_PROJECT/escape.txt"
    cat >> "$DOCTOR_PROJECT/.cumaru/notes/leaf.md" <<'EOF'
<!-- cumaru:reference -->
| Link | Description |
|---|---|
| [escape](escape.txt) | Final symlink must remain invalid. |
<!-- /cumaru:reference -->
EOF
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include 'escape.txt - invalid path, file type, containment, or final symlink target'
    The output should not include 'escape.txt - target not found'
  End

  It 'classifies touched present and explicitly removed paths as valid'
    mkdir -p "$DOCTOR_PROJECT/src"; printf 'live\n' > "$DOCTOR_PROJECT/src/live.txt"
    cat >> "$DOCTOR_PROJECT/.cumaru/notes/leaf.md" <<'EOF'
<!-- cumaru:touched -->
| Link | Description |
|---|---|
| [live](src/live.txt) | modified - still present |
| [gone](src/gone.txt) | removed - intentionally absent |
<!-- /cumaru:touched -->
EOF
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should not include 'src/live.txt - target not found'
    The output should not include 'src/gone.txt - target not found'
  End

  It 'accepts a knowledge-only handoff with an empty touched table'
    write_doctor_md "$DOCTOR_PROJECT/.cumaru/research/index.md" 'Research evidence remains available outside retained project-file tags.'
    write_doctor_md "$DOCTOR_PROJECT/.cumaru/research/usability/index.md" 'Usability evidence records the inspected design behavior and revision.'
    cat >> "$DOCTOR_PROJECT/.cumaru/notes/leaf.md" <<'EOF'
<!-- cumaru:touched -->
| Link | Description |
|---|---|
<!-- /cumaru:touched -->

## Delivered artifacts

[Research evidence](../research/usability/index.md), revision 2.
[Prototype](https://example.com/prototype), inspected at revision 3.
EOF
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should not include 'Retained project file references need review'
  End

  It 'keeps Cumaru and parent-relative paths invalid inside touched'
    cat >> "$DOCTOR_PROJECT/.cumaru/notes/leaf.md" <<'EOF'
<!-- cumaru:touched -->
| Link | Description |
|---|---|
| [knowledge](.cumaru/research/usability/index.md) | Knowledge artifacts do not belong here. |
| [parent](../outside.txt) | Parent-relative paths do not belong here. |
<!-- /cumaru:touched -->
EOF
    When call cli_in "$DOCTOR_PROJECT" doctor --quiet
    The status should be success
    The output should include '.cumaru/research/usability/index.md - invalid path, file type, containment, or final symlink target'
    The output should include '../outside.txt - invalid path, file type, containment, or final symlink target'
  End

  It 'documents touched and removed status in tag help'
    When call cli_in "$DOCTOR_PROJECT" tag all --help
    The status should be success
    The output should include 'touched'
    The output should include 'removed'
  End
End
