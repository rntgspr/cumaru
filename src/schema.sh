# schema.sh — strict configuration validation, typed reads, and reconciliation.

CUMARU_SCHEMA_METAMODEL="$SCRIPT_DIR/schemas/config.schema.json"
CUMARU_SCHEMA_VALIDATOR="$SCRIPT_DIR/schemas/schema-validate.jq"
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
  local schema_file="$1" json output status
  [[ -f "$schema_file" && ! -L "$schema_file" ]] || {
    red "✗ config not found or not a regular file: $schema_file"
    return "$SCHEMA_STATUS_INVALID"
  }
  json=$(_schema_json "$schema_file") || {
    red "✗ cannot parse config: $schema_file"
    return "$SCHEMA_STATUS_INVALID"
  }
  output=$(jq -r -f "$CUMARU_SCHEMA_VALIDATOR" <<< "$json" 2>&1)
  status=$?
  if [[ $status -ne 0 ]]; then
    red "✗ config validator execution failed: $CUMARU_SCHEMA_VALIDATOR"
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
  local schema_file="$1" expected_domain="${2:-}"
  _schema_require_runtime || return $?
  _schema_validate_shape "$schema_file" || return $?
  _schema_validate_semantics "$schema_file" || return $?
  if [[ -n "$expected_domain" ]]; then
    local actual
    actual=$(schema_get_domain "$schema_file") || return "$SCHEMA_STATUS_INVALID"
    [[ "$actual" == "$expected_domain" ]] || {
      red "✗ source domain disagreement: selected $expected_domain, schema declares $actual"
      return "$SCHEMA_STATUS_INVALID"
    }
  fi
}

schema_validate_installed() {
  local schema_file="$1" index_file="$2" schema_version index_version
  schema_validate_file "$schema_file" || return $?
  [[ -f "$index_file" && ! -L "$index_file" ]] || {
    red "✗ root index not found or not a regular file: $index_file"
    return 1
  }
  schema_version=$(schema_get_version "$schema_file") || return 1
  index_version=$(yq --front-matter=extract -r '."framework-version" // ""' "$index_file" 2>/dev/null) || return 1
  [[ -n "$index_version" && "$schema_version" == "$index_version" ]] || {
    red "✗ version disagreement: config is ${schema_version:-<unset>}, framework-version is ${index_version:-<unset>}"
    return 1
  }
}

schema_validate_domain() {
  local domain_dir="$1" expected_domain="$2"
  schema_validate_file "$domain_dir/config.yaml" "$expected_domain" || return $?
  schema_validate_installed "$domain_dir/config.yaml" "$domain_dir/index.md"
}

schema_get_domain() { yq -er '.domain | select(type == "!!str")' "$1"; }
schema_get_version() { yq -er '.version | select(type == "!!int")' "$1"; }
schema_canonical_json() { _schema_json "$1"; }

config_reconcile_plan() {
  local source_yaml="$1" local_yaml="$2" output="$3" source_json local_json planner_output status
  _schema_require_runtime || return $?
  source_json=$(schema_canonical_json "$source_yaml") || {
    red "✗ cannot parse source config for reconciliation: $source_yaml"
    return "$SCHEMA_STATUS_INVALID"
  }
  local_json=$(schema_canonical_json "$local_yaml") || {
    red "✗ cannot parse local config for reconciliation: $local_yaml"
    return "$SCHEMA_STATUS_INVALID"
  }
  planner_output=$(jq -n -S --slurpfile model "$CUMARU_SCHEMA_METAMODEL" \
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
