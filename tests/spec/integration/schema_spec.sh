Include tests/spec/integration/support/integration_helpers.sh

Describe 'configuration schema integration'
  setup_schema() {
    integration_tmp_create
    SCRIPT_DIR="$INTEGRATION_ROOT"
    . "$INTEGRATION_ROOT/src/common.sh"
    . "$INTEGRATION_ROOT/src/agent_adapter.sh"
    . "$INTEGRATION_ROOT/src/schema.sh"
  }

  Before 'setup_schema'
  After 'integration_tmp_remove'

  validate_config() { schema_validate_file "$1" "$2"; }

  It 'validates every canonical domain configuration'
    When run bash -c '
      set -u
      root=$1
      . "$root/src/common.sh"; SCRIPT_DIR=$root
      . "$root/src/agent_adapter.sh"; . "$root/src/schema.sh"
      for file in "$root"/domains/*/config.yaml; do
        domain=$(basename "$(dirname "$file")"); [ "$domain" = __base ] && domain=base
        schema_validate_file "$file" "$domain" || exit
      done
    ' _ "$INTEGRATION_ROOT"
    The status should be success
  End

  It 'ships one active model and no legacy schema artifacts'
    When run bash -c 'test -f "$1/schemas/config.schema.json" && ! compgen -G "$1/domains/*/schema.yaml" >/dev/null && test ! -f "$1/schemas/cumaru-domain-schema-v1.json" && test ! -f "$1/schemas/schema-merge.jq"' _ "$INTEGRATION_ROOT"
    The status should be success
  End

  It 'rejects unknown properties and x-* extensions with status 1'
    When run bash -c '
      root=$1; tmp=$2; . "$root/src/common.sh"; SCRIPT_DIR=$root; . "$root/src/agent_adapter.sh"; . "$root/src/schema.sh"
      n=0
      while IFS="|" read -r expression expected; do
        n=$((n+1)); file="$tmp/reject-$n.yaml"; cp "$root/domains/__base/config.yaml" "$file"; yq -i "$expression" "$file"
        output=$(schema_validate_file "$file" base 2>&1); test $? -eq 1 || exit 1
        case "$output" in *"$expected"*) ;; *) exit 1;; esac
      done <<EOF
.meta.retention = {"years": 7}|/meta/retention: unknown property
."x-project" = {}|/x-project: unknown property
.root."x-provider" = {}|/root/x-provider: unknown property
.root.entities.custom."x-node" = {}|/root/entities/custom/x-node: unknown property
.meta."x-legal" = {}|/meta/x-legal: unknown property
.meta.apps."x-label" = {}|/meta/apps/x-label: unknown property
EOF
    ' _ "$INTEGRATION_ROOT" "$INTEGRATION_TMP"
    The status should be success
  End

  It 'classifies malformed YAML as invalid rather than runtime failure'
    file="$INTEGRATION_TMP/malformed.yaml"
    printf '%s\n' 'version: [unterminated' >"$file"
    When call validate_config "$file" base
    The status should eq 1
    The output should include 'cannot parse config'
  End

  It 'rejects a selected/source domain disagreement'
    When call validate_config "$INTEGRATION_ROOT/domains/__base/config.yaml" sdlc-full
    The status should eq 1
    The output should include 'source domain disagreement'
  End

  It 'uses runtime status 4 when schema dependencies are unavailable'
    no_tools="$INTEGRATION_TMP/no-tools"; mkdir -p "$no_tools"
    When run bash -c '. "$1/src/common.sh"; SCRIPT_DIR=$1; . "$1/src/agent_adapter.sh"; . "$1/src/schema.sh"; PATH=$2; _schema_require_runtime' _ "$INTEGRATION_ROOT" "$no_tools"
    The status should eq 4
    The output should include 'yq is required'
  End

  It 'uses runtime status 4 for a broken validator program'
    validator="$INTEGRATION_TMP/broken-validator.jq"
    printf '%s\n' 'this is not jq syntax {' >"$validator"
    CUMARU_SCHEMA_VALIDATOR="$validator"
    When call validate_config "$INTEGRATION_ROOT/domains/__base/config.yaml" base
    The status should eq 4
    The output should include 'validator execution failed'
    The stderr should include 'compile error'
    CUMARU_SCHEMA_VALIDATOR="$INTEGRATION_ROOT/schemas/schema-validate.jq"
  End

  It 'accepts recursive custom entities'
    file="$INTEGRATION_TMP/custom.yaml"; cp "$INTEGRATION_ROOT/domains/__base/config.yaml" "$file"
    yq -i '.root.entities.contracts = {"entities": {"contract": {"path": "<contract-id>", "frontmatter": ["status!", "summary!", "apps!"]}}} | .meta.specification_dir = "contracts"' "$file"
    When call validate_config "$file" base
    The status should be success
  End

  It 'rejects optional and required forms of one frontmatter field'
    file="$INTEGRATION_TMP/frontmatter.yaml"; cp "$INTEGRATION_ROOT/domains/__base/config.yaml" "$file"
    yq -i '.root.entities.contracts = {"frontmatter": ["status", "status!"]}' "$file"
    When call validate_config "$file" base
    The status should eq 1
    The output should include 'invalid config semantics'
    The stderr should include '/root/entities/contracts/frontmatter: declares the same field'
  End

  It 'rejects absolute, parent, and hidden entity paths'
    When run bash -c '
      root=$1; tmp=$2; . "$root/src/common.sh"; SCRIPT_DIR=$root; . "$root/src/agent_adapter.sh"; . "$root/src/schema.sh"
      for path in /absolute ../escape .hidden/item nested/.hidden; do file="$tmp/path.yaml"; cp "$root/domains/__base/config.yaml" "$file"; INVALID_PATH="$path" yq -i '\'' .root.entities.contracts = {"entities": {"contract": {"path": strenv(INVALID_PATH)}}} | .meta.specification_dir = "contracts" '\'' "$file"; output=$(schema_validate_file "$file" base 2>&1); test $? -eq 1 && case "$output" in *"must be relative"*) ;; *) exit 1;; esac || exit 1; done
    ' _ "$INTEGRATION_ROOT" "$INTEGRATION_TMP"
    The status should be success
  End

  It 'requires specification_dir to name a root entity'
    file="$INTEGRATION_TMP/spec-dir.yaml"; cp "$INTEGRATION_ROOT/domains/__base/config.yaml" "$file"
    yq -i '.meta.specification_dir = "contracts"' "$file"
    When call validate_config "$file" base
    The status should eq 1
    The output should include 'invalid config semantics'
    The stderr should include '/meta/specification_dir: must name a key'
  End

  It 'accepts the ignored legacy agent property for no-migration compatibility'
    file="$INTEGRATION_TMP/legacy-agent.yaml"; cp "$INTEGRATION_ROOT/domains/__base/config.yaml" "$file"; yq -i '.agent = "legacy-client"' "$file"
    When call validate_config "$file" base
    The status should be success
  End

  It 'validates config and root framework versions together'
    dir="$INTEGRATION_TMP/installed"; mkdir -p "$dir"
    cp "$INTEGRATION_ROOT/domains/__base/config.yaml" "$dir/config.yaml"; cp "$INTEGRATION_ROOT/domains/__base/index.md" "$dir/index.md"
    When call schema_validate_installed "$dir/config.yaml" "$dir/index.md"
    The status should be success
  End

  It 'rejects config and root version disagreement'
    dir="$INTEGRATION_TMP/disagreement"; mkdir -p "$dir"
    cp "$INTEGRATION_ROOT/domains/__base/config.yaml" "$dir/config.yaml"; cp "$INTEGRATION_ROOT/domains/__base/index.md" "$dir/index.md"
    yq --front-matter=process -i '."framework-version" = 5' "$dir/index.md"
    When call schema_validate_installed "$dir/config.yaml" "$dir/index.md"
    The status should eq 1
    The output should include 'version disagreement'
  End

  It 'preserves valid adopter values and removes incompatible properties'
    local="$INTEGRATION_TMP/local.yaml"; plan="$INTEGRATION_TMP/plan.json"
    cp "$INTEGRATION_ROOT/domains/sdlc-full/config.yaml" "$local"
    yq -i '.agent = "opencode" | .meta.apps.values = ["web", "platform", "meta"] | .root.entities.contracts = {"entities": {"contract": {"path": "<contract-id>"}}} | .root.obsolete = true' "$local"
    When run bash -c '. "$1/src/common.sh"; SCRIPT_DIR=$1; . "$1/src/agent_adapter.sh"; . "$1/src/schema.sh"; config_reconcile_plan "$1/domains/sdlc-full/config.yaml" "$2" "$3" && jq -e '\'' .value.agent == "opencode" and .value.meta.apps.values[0] == "web" and (.value.root.entities | has("contracts")) and (.value.root | has("obsolete") | not) and (.removed | any(.path == "/root/obsolete")) '\'' "$3" >/dev/null' _ "$INTEGRATION_ROOT" "$local" "$plan"
    The status should be success
  End

  It 'adds missing source defaults recursively'
    source="$INTEGRATION_TMP/source.yaml"; plan="$INTEGRATION_TMP/addition.json"
    cp "$INTEGRATION_ROOT/domains/sdlc-full/config.yaml" "$source"
    yq -i '.root.entities.reviews = {"entities": {"review": {"path": "<review-id>"}}}' "$source"
    config_reconcile_plan "$source" "$INTEGRATION_ROOT/domains/sdlc-full/config.yaml" "$plan"
    When run bash -c 'jq -e '\'' .value.root.entities | has("reviews") '\'' "$1" >/dev/null' _ "$plan"
    The status should be success
  End

  It 'removes unsupported x-* properties during reconciliation'
    local="$INTEGRATION_TMP/x-local.yaml"; plan="$INTEGRATION_TMP/x-plan.json"
    result="$INTEGRATION_TMP/x-result.yaml"
    cp "$INTEGRATION_ROOT/domains/sdlc-full/config.yaml" "$local"; yq -i '."x-project" = {} | .root."x-provider" = {}' "$local"
    config_reconcile_plan "$INTEGRATION_ROOT/domains/sdlc-full/config.yaml" "$local" "$plan"
    jq '.value' "$plan" | yq -P >"$result"
    When run bash -c '. "$1/src/common.sh"; SCRIPT_DIR=$1; . "$1/src/agent_adapter.sh"; . "$1/src/schema.sh"; jq -e '\''(.value | has("x-project") | not) and (.value.root | has("x-provider") | not) and (.removed | any(.path == "/x-project")) and (.removed | any(.path == "/root/x-provider"))'\'' "$2" >/dev/null && schema_validate_file "$3" sdlc-full' _ "$INTEGRATION_ROOT" "$plan" "$result"
    The status should be success
  End

  It 'preserves permitted invalid values for validation to reject'
    local="$INTEGRATION_TMP/invalid-value.yaml"; plan="$INTEGRATION_TMP/invalid-value.json"; result="$INTEGRATION_TMP/invalid-result.yaml"
    cp "$INTEGRATION_ROOT/domains/sdlc-full/config.yaml" "$local"; yq -i '.rules.markdown.required_heading = 42' "$local"
    config_reconcile_plan "$INTEGRATION_ROOT/domains/sdlc-full/config.yaml" "$local" "$plan"; jq '.value' "$plan" | yq -P >"$result"
    When call validate_config "$result" sdlc-full
    The status should eq 1
    The output should include 'invalid config'
    The stderr should include '/rules/markdown/required_heading: must be a non-empty string'
  End

  It 'classifies malformed reconciliation input as invalid'
    file="$INTEGRATION_TMP/malformed-local.yaml"; printf '%s\n' 'version: [unterminated' >"$file"
    When call config_reconcile_plan "$INTEGRATION_ROOT/domains/sdlc-full/config.yaml" "$file" "$INTEGRATION_TMP/no-plan.json"
    The status should eq 1
    The output should include 'cannot parse local config'
  End

  It 'classifies a broken planner as runtime failure and preserves prior output'
    reconciler="$INTEGRATION_TMP/broken-reconciler.jq"; output="$INTEGRATION_TMP/sentinel.json"
    printf '%s\n' 'this is not jq syntax {' >"$reconciler"; printf '%s\n' sentinel >"$output"
    CUMARU_CONFIG_RECONCILER="$reconciler"
    When call config_reconcile_plan "$INTEGRATION_ROOT/domains/sdlc-full/config.yaml" "$INTEGRATION_ROOT/domains/sdlc-full/config.yaml" "$output"
    The status should eq 4
    The output should include 'planner execution failed'
    The stderr should include 'compile error'
    The contents of file "$output" should eq 'sentinel'
    CUMARU_CONFIG_RECONCILER="$INTEGRATION_ROOT/schemas/config-reconcile.jq"
  End
End
