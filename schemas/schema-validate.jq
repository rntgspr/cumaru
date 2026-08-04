def path($p): "/" + ($p | map(tostring) | join("/"));
def err($p; $m): "  \(path($p)): \($m)";
def name: test("^[a-z][a-z0-9_-]*$");
def tagname: test("^[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*$");
def unknown($value; $allowed; $p):
  $value | keys_unsorted[] | select((. as $key | $allowed | index($key)) == null) |
  err($p + [.]; "unknown property");
def strings($value): ($value | type) == "array" and all($value[]; type == "string");
def frontmatter:
  . as $value |
  strings($value) and all($value[]; test("^[a-z][a-z0-9_-]*!?$")) and (($value | unique | length) == ($value | length));
def tagtype:
  . as $value |
  ($value == "default" or $value == "prose" or $value == "mixed" or $value == "other") or
  (strings($value) and ($value | length) > 0 and all($value[]; length > 0) and (($value | unique | length) == ($value | length)));

def validate_tags($tags; $p):
  if ($tags | type) != "object" then err($p; "must be an object")
  else
    ($tags | to_entries[] |
      if (.key | tagname | not) then err($p + [.key]; "invalid tag name")
      elif (.value | tagtype | not) then err($p + [.key]; "invalid tag body type")
      else empty end)
  end;

def validate_node($node; $p):
  if ($node | type) != "object" then err($p; "must be an object")
  else
    unknown($node; ["path", "frontmatter", "tags", "entities"]; $p),
    (if $node.path? != null and (($node.path | type) != "string" or ($node.path | length) == 0)
      then err($p + ["path"]; "must be a non-empty string") else empty end),
    (if $node.frontmatter? != null and ($node.frontmatter | frontmatter | not)
      then err($p + ["frontmatter"]; "must contain unique valid field names") else empty end),
    (if $node.tags? != null then validate_tags($node.tags; $p + ["tags"]) else empty end),
    (if $node.entities? != null then
      if ($node.entities | type) != "object" then err($p + ["entities"]; "must be an object")
      else $node.entities | to_entries[] |
        if (.key | name | not) then err($p + ["entities", .key]; "invalid entity name")
        else validate_node(.value; $p + ["entities", .key]) end
      end
    else empty end)
  end;

def validate_file_rule($rule; $p; $markdown):
  if ($rule | type) != "object" then err($p; "must be an object")
  else
    unknown($rule; (if $markdown then ["required_heading", "frontmatter"] else ["frontmatter"] end); $p),
    (if ($rule.frontmatter? | frontmatter | not) then err($p + ["frontmatter"]; "must contain unique valid field names") else empty end),
    (if $markdown and (($rule.required_heading? | type) != "string" or ($rule.required_heading | length) == 0)
      then err($p + ["required_heading"]; "must be a non-empty string") else empty end)
  end;

def validate_pattern_rule($rule; $p):
  if ($rule | type) != "object" then err($p; "must be an object")
  else
    unknown($rule; ["severity", "pattern", "applies_to"]; $p),
    (if (["warning", "error"] | index($rule.severity?)) == null then err($p + ["severity"]; "must be warning or error") else empty end),
    (if (($rule.pattern? | type) != "string" or ($rule.pattern | length) == 0) then err($p + ["pattern"]; "must be a non-empty string") else empty end),
    (if (strings($rule.applies_to?) | not) then err($p + ["applies_to"]; "must be an array of strings") else empty end)
  end;

def validate_meta_tag($spec; $p):
  if ($spec | type) != "object" then err($p; "must be an object")
  else
    unknown($spec; ["host_file", "type"]; $p),
    (if (($spec.host_file? | type) != "string" or ($spec.host_file | length) == 0) then err($p + ["host_file"]; "must be a non-empty string") else empty end),
    (if ($spec.type? | tagtype | not) then err($p + ["type"]; "invalid tag body type") else empty end)
  end;

def validate_meta($meta):
  if ($meta | type) != "object" then err(["meta"]; "must be an object")
  else
    unknown($meta; ["apps", "tags", "specification_dir", "coverage", "compatibility"]; ["meta"]),
    (if ($meta.apps? | type) != "object" or (strings($meta.apps.values?) | not) or ($meta.apps.values | length) == 0 or (($meta.apps.values | unique | length) != ($meta.apps.values | length))
      then err(["meta", "apps", "values"]; "must be a non-empty array of unique strings") else unknown($meta.apps; ["values"]; ["meta", "apps"]) end),
    (if ($meta.tags? | type) != "object" then err(["meta", "tags"]; "must be an object")
      else $meta.tags | to_entries[] | if (.key | tagname | not) then err(["meta", "tags", .key]; "invalid tag name") else validate_meta_tag(.value; ["meta", "tags", .key]) end end),
    (if $meta.specification_dir? != null and ($meta.specification_dir | name | not) then err(["meta", "specification_dir"]; "invalid entity name") else empty end),
    (if $meta.coverage? != null then
      if ($meta.coverage | type) != "object" or (strings($meta.coverage.source?) | not) then err(["meta", "coverage", "source"]; "must be an array of strings")
      else unknown($meta.coverage; ["source"]; ["meta", "coverage"]) end
    else empty end),
    (if ($meta.compatibility? | type) != "object" then err(["meta", "compatibility"]; "must be an object")
      else
        unknown($meta.compatibility; ["framework_version_field", "framework_version_location", "rule"]; ["meta", "compatibility"]),
        (if (($meta.compatibility.framework_version_field? | type) != "string") then err(["meta", "compatibility", "framework_version_field"]; "must be a string") else empty end),
        (if (($meta.compatibility.framework_version_location? | type) != "string") then err(["meta", "compatibility", "framework_version_location"]; "must be a string") else empty end),
        (if (strings($meta.compatibility.rule?) | not) or ($meta.compatibility.rule | length) == 0 then err(["meta", "compatibility", "rule"]; "must be a non-empty array of strings") else empty end)
      end)
  end;

. as $schema |
[
  (if ($schema | type) != "object" then err([]; "schema must be an object") else
    unknown($schema; ["version", "domain", "agent", "rules", "root", "meta"]; []),
    (if ($schema.version | type) != "number" or ($schema.version | floor) != $schema.version or $schema.version < 1 then err(["version"]; "must be a positive integer") else empty end),
    (if ($schema.domain | type) != "string" or ($schema.domain | name | not) then err(["domain"]; "invalid domain name") else empty end),
    (if ($schema.rules | type) != "object" then err(["rules"]; "must be an object")
      else
        (if (($schema.rules | has("markdown")) and ($schema.rules | has("index_md")) and ($schema.rules | has("pillar_index")) | not) then err(["rules"]; "missing required file rules") else empty end),
        validate_file_rule($schema.rules.markdown; ["rules", "markdown"]; true),
        validate_file_rule($schema.rules.index_md; ["rules", "index_md"]; false),
        validate_file_rule($schema.rules.pillar_index; ["rules", "pillar_index"]; false),
        ($schema.rules | to_entries[] | . as $entry | select(["markdown", "index_md", "pillar_index"] | index($entry.key) == null) |
          if ($entry.key | name | not) then err(["rules", $entry.key]; "invalid rule name") else validate_pattern_rule($entry.value; ["rules", $entry.key]) end)
      end),
    validate_node($schema.root; ["root"]),
    validate_meta($schema.meta)
  end)
] | .[]
