def path($p): "/" + ($p | map(tostring) | join("/"));
def err($p; $m): "  \(path($p)): \($m)";
def name: test("^[a-z][a-z0-9_-]*$");
def fieldname: test("^[a-z][a-z0-9_-]*$");
def tagname: test("^[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*$");
def reserved: ["path", "optional", "framework", "frontmatter", "tags"];
def strings: type == "array" and all(.[]; type == "string");
def glob: test("[*?[]");
def safe_path:
  type == "string" and length > 0 and
  ([startswith("/"), test("(^|/)\\.\\.?(/|$)"), test("(^|/)\\.[^/]+"), contains("**")] | any | not);
def unknown($value; $allowed; $p): $value | keys_unsorted[] | select((. as $key | $allowed | index($key)) == null) | err($p + [.]; "unknown property");

def validate_frontmatter($value; $p):
  if ($value | type) != "object" then err($p; "must be an object")
  else $value | to_entries[] |
    if (.key | fieldname | not) then err($p + [.key]; "invalid frontmatter field")
    elif (.value | type) != "object" then err($p + [.key]; "must be an object")
    else unknown(.value; ["optional"]; $p + [.key]),
      if .value.optional? != null and (.value.optional | type) != "boolean" then err($p + [.key, "optional"]; "must be a boolean") else empty end
    end
  end;
def validate_tags($value; $p):
  if ($value | strings | not) or (($value | unique | length) != ($value | length)) then err($p; "must be an array of unique tag names")
  else $value[] | select(tagname | not) | err($p; "contains an invalid tag name") end;
def validate_file_rule($value; $p; $markdown):
  if ($value | type) != "object" then err($p; "must be an object")
  else unknown($value; if $markdown then ["required_heading", "frontmatter"] else ["frontmatter"] end; $p),
    if $value.frontmatter? == null then err($p + ["frontmatter"]; "is required") else validate_frontmatter($value.frontmatter; $p + ["frontmatter"]) end,
    if $markdown and (($value.required_heading? | type) != "string" or ($value.required_heading | length) == 0) then err($p + ["required_heading"]; "must be a non-empty string") else empty end
  end;
def validate_pattern_rule($value; $p):
  if ($value | type) != "object" then err($p; "must be an object")
  else unknown($value; ["severity", "pattern", "applies_to"]; $p),
    if (["warning", "error"] | index($value.severity?)) == null then err($p + ["severity"]; "must be warning or error") else empty end,
    if (($value.pattern? | type) != "string" or ($value.pattern | length) == 0) then err($p + ["pattern"]; "must be a non-empty string") else empty end,
    if ($value.applies_to? | strings | not) then err($p + ["applies_to"]; "must be an array of strings") else empty end
  end;
def validate_rules($value):
  if ($value | type) != "object" then err(["rules"]; "must be an object")
  else
    if ["markdown", "index_md", "pillar_index"] | all(. as $key | $value | has($key)) then empty else err(["rules"]; "missing required file rules") end,
    validate_file_rule($value.markdown; ["rules", "markdown"]; true),
    validate_file_rule($value.index_md; ["rules", "index_md"]; false),
    validate_file_rule($value.pillar_index; ["rules", "pillar_index"]; false),
    ($value | to_entries[] | . as $entry | select(["markdown", "index_md", "pillar_index"] | index($entry.key) | not) | if (.key | name | not) then err(["rules", .key]; "invalid rule name") else validate_pattern_rule(.value; ["rules", .key]) end)
  end;
def child_entries($node): $node | to_entries | map(. as $entry | select(reserved | index($entry.key) | not));
def wildcard_conflicts($entries; $p):
  [$entries[] | select(.key | glob)] as $wildcards |
  range(0; $wildcards | length) as $left |
  range($left + 1; $wildcards | length) as $right |
  $wildcards[$left] as $first | $wildcards[$right] as $second |
  ["path", "optional", "framework", "tags"][] as $attribute |
  select($first.value[$attribute]? != null and $second.value[$attribute]? != null and $first.value[$attribute] != $second.value[$attribute]) |
  err($p; "wildcard selectors declare conflicting \($attribute) attributes");
def validate_node($value; $p):
  if ($value | type) != "object" then err($p; "must be an object")
  else
    if $value.path? != null and ($value.path | safe_path | not) then err($p + ["path"]; "must be a relative non-recursive path without hidden or parent segments") else empty end,
    if $value.optional? != null and ($value.optional | type) != "boolean" then err($p + ["optional"]; "must be a boolean") else empty end,
    if $value.framework? != null and ($value.framework | type) != "boolean" then err($p + ["framework"]; "must be a boolean") else empty end,
    if $value.frontmatter? != null then validate_frontmatter($value.frontmatter; $p + ["frontmatter"]) else empty end,
    if $value.tags? != null then validate_tags($value.tags; $p + ["tags"]) else empty end,
    (child_entries($value) as $children |
      $children[] | select((.key | safe_path) | not) | err($p + [.key]; "selector must be a relative non-recursive path without hidden or parent segments")),
    (child_entries($value) as $children | wildcard_conflicts($children; $p)),
    (child_entries($value)[] | validate_node(.value; $p + [.key]))
  end;
def validate_meta($value):
  if ($value | type) != "object" then err(["meta"]; "must be an object")
  else unknown($value; ["targets", "specification_dir", "coverage"]; ["meta"]),
    if ($value.targets? | type) != "object" or ($value.targets.values? | strings | not) or ($value.targets.values | length) == 0 or (($value.targets.values | unique | length) != ($value.targets.values | length)) then err(["meta", "targets", "values"]; "must be a non-empty array of unique strings") else unknown($value.targets; ["values"]; ["meta", "targets"]) end,
    if $value.specification_dir? != null and ($value.specification_dir | name | not) then err(["meta", "specification_dir"]; "invalid entity name") else empty end,
    if $value.coverage? != null then if ($value.coverage | type) != "object" or ($value.coverage.source? | strings | not) then err(["meta", "coverage", "source"]; "must be an array of strings") else unknown($value.coverage; ["source"]; ["meta", "coverage"]) end else empty end
  end;
def validate_workflow_step($value; $p):
  if ($value | type) != "object" then err($p; "must be an object")
  else
    unknown($value; ["skill", "needs"]; $p),
    if ($value.skill? | type) != "string" or ($value.skill | name | not) then err($p + ["skill"]; "must be a valid skill name") else empty end,
    if $value.needs? != null and (($value.needs | strings | not) or (($value.needs | unique | length) != ($value.needs | length)) or any($value.needs[]; name | not)) then err($p + ["needs"]; "must be an array of unique step names") else empty end
  end;
def workflow_acyclic($steps):
  ($steps | keys_unsorted) as $ids |
  def visit($done):
    [ $ids[] | select(. as $id | (($done | index($id)) == null) and (($steps[$id].needs // []) as $needs | all($needs[]; . as $need | ($done | index($need)) != null))) ] | sort as $ready |
    if ($ready | length) == 0 then $done else visit($done + $ready) end;
  (visit([]) | length) == ($ids | length);
def validate_workflow($value; $p):
  if ($value | type) != "object" then err($p; "must be an object")
  else
    unknown($value; ["steps"]; $p),
    if ($value.steps? | type) != "object" or ($value.steps | length) == 0 then err($p + ["steps"]; "must be a non-empty object")
    else
      ($value.steps | keys_unsorted[] | select(name | not) | err($p + ["steps", .]; "invalid step name")),
      ($value.steps | to_entries[] | validate_workflow_step(.value; $p + ["steps", .key])),
      ($value.steps | to_entries[] | .key as $step | (.value.needs // [])[] | select(. == $step) | err($p + ["steps", $step, "needs"]; "must not depend on itself")),
      ($value.steps | keys_unsorted) as $ids |
      ($value.steps | to_entries[] | .key as $step | (.value.needs // [])[] | . as $need | select($ids | index($need) | not) | err($p + ["steps", $step, "needs"]; "references an unknown step")),
      if ([ $value.steps | to_entries[] | .key as $step | (.value.needs // [])[] | . as $need | select($need == $step or ($ids | index($need) | not)) ] | length) == 0 and (workflow_acyclic($value.steps) | not) then err($p + ["steps"]; "contains a dependency cycle") else empty end
    end
  end;
def validate_workflows($value):
  if ($value | type) != "object" then err(["workflows"]; "must be an object")
  else
    ($value | keys_unsorted[] | select(name | not) | err(["workflows", .]; "invalid workflow name")),
    ($value | to_entries[] | validate_workflow(.value; ["workflows", .key]))
  end;
. as $config | [
  if ($config | type) != "object" then err([]; "config must be an object") else
    unknown($config; ["version", "domain", "rules", "root", "meta", "workflows"]; []),
    if $config.version != 9 then err(["version"]; "must equal 9") else empty end,
    if ($config.domain | type) != "string" or ($config.domain | name | not) then err(["domain"]; "invalid domain name") else empty end,
    validate_rules($config.rules), validate_node($config.root; ["root"]), validate_meta($config.meta),
    if $config.workflows? != null then validate_workflows($config.workflows) else empty end
  end
] | .[]
