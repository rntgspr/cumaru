# schema.sh — strict configuration validation, typed reads, and reconciliation.

CUMARU_SCHEMA_METAMODEL="$SCRIPT_DIR/schemas/config.schema.json"
CUMARU_SCHEMA_VALIDATOR="$SCRIPT_DIR/schemas/schema-validate.jq"
CUMARU_SCHEMA_V9_VALIDATOR="$SCRIPT_DIR/schemas/schema-validate-v9.jq"
CUMARU_SCHEMA_V8_METAMODEL="$SCRIPT_DIR/schemas/config.schema.off-9.json"
CUMARU_CONFIG_RECONCILER="$SCRIPT_DIR/schemas/config-reconcile.jq"
SCHEMA_STATUS_INVALID=1
SCHEMA_STATUS_RUNTIME=4

_schema_require_runtime() {
  local tool
  for tool in yq jq; do
    command -v "$tool" >/dev/null 2>&1 || {
      red "✗ $tool is required for schema validation"
      return "$SCHEMA_STATUS_RUNTIME"
    }
  done
  yq --version 2>/dev/null | grep -qi 'mikefarah/yq.*version v4' || {
    red "✗ schema validation requires Mike Farah yq v4"
    return "$SCHEMA_STATUS_RUNTIME"
  }
}

_schema_json() {
  local json
  json=$(yq -o=json -I=0 '.' "$1" 2>/dev/null) || return 1
  jq -S -c '.' <<< "$json"
}

_schema_validate_shape() {
  local schema_file="$1" json output status validator
  [[ -f "$schema_file" && ! -L "$schema_file" ]] || {
    red "✗ config not found or not a regular file: $schema_file"
    return "$SCHEMA_STATUS_INVALID"
  }
  json=$(_schema_json "$schema_file") || {
    red "✗ cannot parse config: $schema_file"
    return "$SCHEMA_STATUS_INVALID"
  }
  if [[ $(jq -r '.version // ""' <<< "$json") == 9 ]]; then
    validator="$CUMARU_SCHEMA_V9_VALIDATOR"
  else
    validator="$CUMARU_SCHEMA_VALIDATOR"
  fi
  output=$(jq -r -f "$validator" <<< "$json" 2>&1)
  status=$?
  if [[ $status -ne 0 ]]; then
    red "✗ config validator execution failed: $validator"
    printf '%s\n' "$output" >&2
    return "$SCHEMA_STATUS_RUNTIME"
  fi
  if [[ -n "$output" ]]; then
    red "✗ invalid config: $schema_file"
    printf '%s\n' "$output" >&2
    return "$SCHEMA_STATUS_INVALID"
  fi
}

_schema_validate_semantics() {
  local schema_file="$1" json errors
  json=$(_schema_json "$schema_file") || {
    red "✗ cannot parse config as YAML: $schema_file"
    return "$SCHEMA_STATUS_INVALID"
  }
  if [[ $(jq -r '.version // ""' <<< "$json") == 9 ]]; then
    return 0
  fi
  errors=$(jq -r '
    def err($p; $m): "  \($p): \($m)";
    . as $schema |
    [
      ($schema.root.entities as $entities
        | if ($schema.meta.specification_dir? != null and ($entities | has($schema.meta.specification_dir) | not))
          then err("/meta/specification_dir"; "must name a key under /root/entities") else empty end),
      (paths(arrays) as $p
        | select(all($p[]; (tostring | startswith("x-") | not)))
        | select(($p[-1] == "frontmatter"))
        | getpath($p) as $fields
        | [$fields[] | sub("!$"; "")] as $logical
        | select(($logical | length) != ($logical | unique | length))
        | err("/" + ($p | map(tostring) | join("/")); "declares the same field as optional and required")),
      (paths(strings) as $p
        | select(all($p[]; (tostring | startswith("x-") | not)))
        | select($p[-1] == "path")
        | getpath($p) as $value
        | select($value | startswith("/") or test("(^|/)\\.\\.?(/|$)") or test("(^|/)\\.[^/]+"))
        | err("/" + ($p | map(tostring) | join("/")); "must be relative and contain no hidden or parent segments"))
    ] | .[]
  ' <<< "$json") || {
    red "✗ config semantic validator execution failed"
    return "$SCHEMA_STATUS_RUNTIME"
  }
  if [[ -n "$errors" ]]; then
    red "✗ invalid config semantics: $schema_file"
    printf '%s\n' "$errors" >&2
    return "$SCHEMA_STATUS_INVALID"
  fi

  local pattern
  while IFS= read -r pattern; do
    awk -v re="$pattern" 'BEGIN { "" ~ re; exit 0 }' 2>/dev/null || {
      red "✗ invalid POSIX ERE in $schema_file: $pattern"
      return "$SCHEMA_STATUS_INVALID"
    }
  done < <(jq -r '.rules | to_entries[] | select(.value.pattern? != null) | .value.pattern' <<< "$json")
}

schema_validate_file() {
  local schema_file="$1" expected_domain="${2:-}" actual
  _schema_require_runtime || return $?
  _schema_validate_shape "$schema_file" || return $?
  _schema_validate_semantics "$schema_file" || return $?
  actual=$(schema_get_domain "$schema_file") || return "$SCHEMA_STATUS_INVALID"
  if [[ -n "$expected_domain" ]]; then
    [[ "$actual" == "$expected_domain" ]] || {
      red "✗ source domain disagreement: selected $expected_domain, schema declares $actual"
      return "$SCHEMA_STATUS_INVALID"
    }
  fi
  schema_validate_workflow_skills "$schema_file" "$actual"
}

# Return success when a workflow skill exists in its shipped source or adapter tree.
_schema_workflow_skill_available() {
  local schema_file="$1" domain="$2" skill="$3" source_dir parent agent skills_dir
  source_dir="$SCRIPT_DIR/domains/$domain"
  [[ "$domain" != base ]] || source_dir="$SCRIPT_DIR/domains/__base"

  if [[ -f "$source_dir/config.yaml" && ! -L "$source_dir/config.yaml" ]]; then
    [[ -f "$source_dir/skills/$skill/SKILL.md" && ! -L "$source_dir/skills/$skill/SKILL.md" ]]
    return
  fi

  parent=$(dirname "$(dirname "$schema_file")")
  for agent in generic claude codex opencode; do
    skills_dir=$(_agent_skills_dir "$parent" "$agent")
    [[ -f "$skills_dir/$skill/SKILL.md" && ! -L "$skills_dir/$skill/SKILL.md" ]] && return 0
  done
  return 1
}

# Require every v9 workflow skill from its shipped source or installed custom tree.
schema_validate_workflow_skills() {
  local schema_file="$1" domain="$2" json skill
  json=$(_schema_json "$schema_file") || return "$SCHEMA_STATUS_INVALID"
  [[ $(jq -r '.version // ""' <<< "$json") == 9 ]] || return 0
  [[ $(jq -r '.workflows? != null' <<< "$json") == true ]] || return 0

  while IFS= read -r skill; do
    _schema_workflow_skill_available "$schema_file" "$domain" "$skill" || {
      red "✗ workflow references unavailable domain skill: $skill"
      return "$SCHEMA_STATUS_INVALID"
    }
  done < <(jq -r '.workflows | to_entries[] | .value.steps | to_entries[] | .value.skill' <<< "$json" | LC_ALL=C sort -u)
}

# Emit one lexically stable topological order for a named validated workflow.
schema_workflow_order() {
  local schema_file="$1" workflow="$2" json
  json=$(_schema_json "$schema_file") || return "$SCHEMA_STATUS_INVALID"
  jq -er --arg workflow "$workflow" '
    .workflows[$workflow].steps as $steps |
    ($steps | keys_unsorted) as $ids |
    def visit($done):
      [$ids[] | select(. as $id | (($done | index($id)) == null) and (($steps[$id].needs // []) as $needs | all($needs[]; . as $need | ($done | index($need)) != null)))] | sort as $ready |
      if ($ready | length) == 0 then $done else visit($done + $ready) end;
    visit([])[]
  ' <<< "$json"
}

schema_validate_installed() {
  local schema_file="$1" index_file="$2"
  schema_validate_file "$schema_file" || return $?
  [[ -f "$index_file" && ! -L "$index_file" ]] || {
    red "✗ root index not found or not a regular file: $index_file"
    return 1
  }
}

schema_validate_domain() {
  local domain_dir="$1" expected_domain="$2"
  schema_validate_file "$domain_dir/config.yaml" "$expected_domain" || return $?
  schema_validate_installed "$domain_dir/config.yaml" "$domain_dir/index.md" || return $?
  schema_validate_disciplines "$domain_dir" || return $?
  schema_validate_command_skills "$domain_dir"
}

# Emit invalid discipline metadata relative to one source or installed domain.
# The index explains the contract and is not itself an execution discipline.
discipline_metadata_issues() {
  local domain_dir="$1" file rel strictness
  [[ -d "$domain_dir/disciplines" ]] || return 0

  while IFS= read -r -d '' file; do
    [[ "$(basename "$file")" == "index.md" ]] && continue
    rel="${file#"$domain_dir"/}"
    strictness=$(yq --front-matter=extract -r '.strictness // ""' "$file" 2>/dev/null) || {
      printf '%s: cannot read discipline frontmatter\n' "$rel"
      continue
    }
    if [[ -z "$strictness" ]]; then
      printf '%s: strictness is required; missing values are treated as 0/10\n' "$rel"
    elif [[ ! "$strictness" =~ ^(10|[0-9])/10$ ]]; then
      printf '%s: strictness must be 0/10 through 10/10; saw %s\n' "$rel" "$strictness"
    fi
  done < <(find "$domain_dir/disciplines" -type f -name '*.md' -print0 | LC_ALL=C sort -z)
}

schema_validate_disciplines() {
  local domain_dir="$1" issues
  issues=$(discipline_metadata_issues "$domain_dir") || return 1
  [[ -z "$issues" ]] && return 0
  red "✗ invalid discipline metadata"
  printf '%s\n' "$issues"
  return 1
}

# Every shipped slash command is only a launcher for its namesake skill.
# Validate this at the source-domain boundary before install or update writes.
schema_validate_command_skills() {
  local domain_dir="$1" commands_dir
  commands_dir="$domain_dir/commands/cumaru"
  [[ -d "$commands_dir" ]] || return 0

  local command_file name skill_file
  while IFS= read -r -d '' command_file; do
    name=$(basename "$command_file" .md)
    skill_file="$domain_dir/skills/cumaru-$name/SKILL.md"
    if [[ ! -f "$skill_file" || -L "$skill_file" ]]; then
      red "✗ slash command requires its namesake skill: commands/cumaru/$name.md → skills/cumaru-$name/SKILL.md"
      return 1
    fi
  done < <(find "$commands_dir" -type f -name '*.md' -print0)
}

schema_get_domain() { yq -er '.domain | select(type == "!!str")' "$1"; }
schema_get_version() { yq -er '.version | select(type == "!!int")' "$1"; }
schema_canonical_json() { _schema_json "$1"; }

config_reconcile_plan() {
  local source_yaml="$1" local_yaml="$2" output="$3" source_json local_json planner_output status model
  _schema_require_runtime || return $?
  source_json=$(schema_canonical_json "$source_yaml") || {
    red "✗ cannot parse source config for reconciliation: $source_yaml"
    return "$SCHEMA_STATUS_INVALID"
  }
  local_json=$(schema_canonical_json "$local_yaml") || {
    red "✗ cannot parse local config for reconciliation: $local_yaml"
    return "$SCHEMA_STATUS_INVALID"
  }
  if [[ $(jq -r '.version // ""' <<< "$source_json") == 8 ]]; then
    model="$CUMARU_SCHEMA_V8_METAMODEL"
  else
    model="$CUMARU_SCHEMA_METAMODEL"
  fi
  planner_output=$(jq -n -S --slurpfile model "$model" \
    --argjson source "$source_json" --argjson local "$local_json" \
    -f "$CUMARU_CONFIG_RECONCILER" 2>&1)
  status=$?
  if [[ $status -ne 0 ]]; then
    red "✗ config reconciliation planner execution failed: $CUMARU_CONFIG_RECONCILER"
    printf '%s\n' "$planner_output" >&2
    return "$SCHEMA_STATUS_RUNTIME"
  fi
  printf '%s\n' "$planner_output" > "$output"
}
