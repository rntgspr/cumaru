Include tests/spec/integration/support/integration_helpers.sh

Describe 'workflow graph configuration'
  # Load schema helpers against an isolated temporary configuration directory.
  setup_workflow_graph() {
    integration_tmp_create
    SCRIPT_DIR="$INTEGRATION_ROOT"
    . "$INTEGRATION_ROOT/src/common.sh"
    . "$INTEGRATION_ROOT/src/agent_adapter.sh"
    . "$INTEGRATION_ROOT/src/schema.sh"
  }

  # Create the smallest valid v9 configuration before workflow cases add steps.
  workflow_config() {
    local file="$1"
    yq -n -P '.version = 9 | .domain = "base" | .rules = {"markdown": {"required_heading": "h1", "frontmatter": {}}, "index_md": {"frontmatter": {}}, "pillar_index": {"frontmatter": {}}} | .root = {} | .meta = {"targets": {"values": ["all"]}}' >"$file"
  }

  # Validate a workflow and emit its stable order in one ShellSpec evaluation.
  workflow_validate_and_order() {
    schema_validate_file "$1" base && schema_workflow_order "$1" "$2"
  }

  Before 'setup_workflow_graph'
  After 'integration_tmp_remove'

  It 'accepts a chain, independent entries, branches, and joins in lexical ready order'
    file="$INTEGRATION_TMP/valid.yaml"
    workflow_config "$file"
    yq -i '.workflows = {"delivery": {"steps": {"alpha": {"skill": "cumaru-role"}, "beta": {"skill": "cumaru-refs"}, "build": {"skill": "cumaru-summarize", "needs": ["alpha"]}, "check": {"skill": "cumaru-doctor", "needs": ["alpha"]}, "join": {"skill": "cumaru-update", "needs": ["beta", "build", "check"]}}}}' "$file"
    When call workflow_validate_and_order "$file" delivery
    The status should be success
    The output should equal 'alpha
beta
build
check
join'
    The error should be blank
  End

  It 'keeps workflows optional'
    file="$INTEGRATION_TMP/optional.yaml"
    workflow_config "$file"
    When call schema_validate_file "$file" base
    The status should be success
  End

  Context 'with an invalid graph or reference'
    Parameters
      '.workflows = {"flow": {"steps": {}}}' 'must be a non-empty object'
      '.workflows = {"flow": {"steps": {"first": {"skill": "cumaru-role", "needs": ["missing"]}}}}' 'references an unknown step'
      '.workflows = {"flow": {"steps": {"first": {"skill": "cumaru-role", "needs": ["other", "other"]}, "other": {"skill": "cumaru-refs"}}}}' 'must be an array of unique step names'
      '.workflows = {"flow": {"steps": {"first": {"skill": "cumaru-role", "needs": ["first"]}}}}' 'must not depend on itself'
      '.workflows = {"flow": {"steps": {"first": {"skill": "cumaru-role", "needs": ["second"]}, "second": {"skill": "cumaru-refs", "needs": ["third"]}, "third": {"skill": "cumaru-doctor", "needs": ["first"]}}}}' 'contains a dependency cycle'
      '.workflows = {"flow": {"steps": {"first": {"skill": "cumaru-role", "unexpected": true}}}}' 'unknown property'
    End
    It 'rejects it before execution'
      file="$INTEGRATION_TMP/invalid.yaml"
      workflow_config "$file"
      yq -i "$1" "$file"
      When call schema_validate_file "$file" base
      The status should eq 1
      The output should include 'invalid config'
      The error should include "$2"
    End
  End

  It 'rejects a skill absent from the selected domain'
    file="$INTEGRATION_TMP/unknown-skill.yaml"
    workflow_config "$file"
    yq -i '.workflows = {"flow": {"steps": {"first": {"skill": "cumaru-not-real"}}}}' "$file"
    When call schema_validate_file "$file" base
    The status should eq 1
    The output should include 'workflow references unavailable domain skill: cumaru-not-real'
  End

  It 'validates custom workflow skills from the installed adopter tree'
    project="$INTEGRATION_TMP/custom-project"
    file="$project/.cumaru/config.yaml"
    mkdir -p "$project/.cumaru" "$project/.agents/skills/cumaru-role"
    workflow_config "$file"
    yq -i '.domain = "edm-music" | .workflows = {"flow": {"steps": {"first": {"skill": "cumaru-role"}}}}' "$file"
    : > "$project/.agents/skills/cumaru-role/SKILL.md"
    When call schema_validate_file "$file"
    The status should be success
  End

  It 'finds custom workflow skills in a Claude adapter tree'
    project="$INTEGRATION_TMP/claude-project"
    file="$project/.cumaru/config.yaml"
    mkdir -p "$project/.cumaru" "$project/.claude/skills/cumaru-role"
    workflow_config "$file"
    yq -i '.domain = "edm-music" | .workflows = {"flow": {"steps": {"first": {"skill": "cumaru-role"}}}}' "$file"
    : > "$project/.claude/skills/cumaru-role/SKILL.md"
    When call schema_validate_file "$file"
    The status should be success
  End

  It 'rejects a custom workflow skill absent from the installed adopter tree'
    project="$INTEGRATION_TMP/custom-project"
    file="$project/.cumaru/config.yaml"
    mkdir -p "$project/.cumaru"
    workflow_config "$file"
    yq -i '.domain = "edm-music" | .workflows = {"flow": {"steps": {"first": {"skill": "cumaru-role"}}}}' "$file"
    When call schema_validate_file "$file"
    The status should eq 1
    The output should include 'workflow references unavailable domain skill: cumaru-role'
  End

  It 'rejects a malformed custom domain before checking workflow artifacts'
    file="$INTEGRATION_TMP/malformed-domain.yaml"
    workflow_config "$file"
    yq -i '.domain = "EDM Music" | .workflows = {"flow": {"steps": {"first": {"skill": "cumaru-role"}}}}' "$file"
    cp "$file" "$INTEGRATION_TMP/malformed-domain.before.yaml"
    When call schema_validate_file "$file"
    The status should eq 1
    The output should include 'invalid config'
    The error should include '/domain: invalid domain name'
    The contents of file "$file" should equal "$(cat "$INTEGRATION_TMP/malformed-domain.before.yaml")"
  End
End
