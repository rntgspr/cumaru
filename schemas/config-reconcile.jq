def resolve($model; $schema):
  if ($schema["$ref"]? | type) == "string" and ($schema["$ref"] | startswith("#/$defs/"))
  then $model["$defs"][($schema["$ref"] | sub("^#/\\$defs/"; ""))]
  else $schema
  end;

def property_schema($model; $schema; $key):
  resolve($model; $schema) as $resolved
  | if $resolved.properties[$key]? != null then
      {allowed: true, schema: $resolved.properties[$key]}
    else
      if ($resolved.additionalProperties | type) == "object" then
          {allowed: true, schema: $resolved.additionalProperties}
        elif $resolved.additionalProperties == true then
          {allowed: true, schema: {}}
        else
          {allowed: false}
        end
    end;

def reconcile_local($model; $value; $schema; $path):
  resolve($model; $schema) as $resolved
  | if ($value | type) == "object" and
       ($resolved.properties? != null or $resolved.additionalProperties? != null) then
      reduce ($value | to_entries[]) as $entry ({value: {}, removed: []};
        property_schema($model; $resolved; $entry.key) as $property
        | if $property.allowed then
            reconcile_local($model; $entry.value; $property.schema; $path + [$entry.key]) as $child
            | .value[$entry.key] = $child.value
            | .removed += $child.removed
          else
            .removed += [{path: ("/" + (($path + [$entry.key]) | map(tostring) | join("/"))), reason: "property is not allowed by the global model"}]
          end)
    elif ($value | type) == "array" and $resolved.items? != null then
      reduce range(0; $value | length) as $index ({value: [], removed: []};
        reconcile_local($model; $value[$index]; $resolved.items; $path + [$index]) as $child
        | .value += [$child.value]
        | .removed += $child.removed)
    else
      {value: $value, removed: []}
    end;

def reserved: ["path", "optional", "framework", "frontmatter", "tags"];

# Translate one structural glob selector into an anchored regular expression.
# Only "*" and "?" are wildcards, and neither crosses a path separator.
def glob_regex:
  def escape: gsub("(?<c>[^A-Za-z0-9_/-])"; "\\\(.c)");
  "^" + (split("*") | map(split("?") | map(escape) | join("[^/]")) | join("[^/]*")) + "$";

# Return true when the local object already declares a more specific selector
# in place of one glob selector the source ships. Replacing a shipped wildcard
# with named keys that the wildcard itself would have matched is a structural
# refinement, not drift, so the candidate must not restore the wildcard.
def stands_in($local; $key):
  if ($key | test("[*?]")) and (($key | contains("[")) | not) then
    ($key | glob_regex) as $pattern
    | any($local | keys_unsorted[];
        . as $candidate
        | ((reserved | index($candidate)) == null) and ($candidate | test($pattern)))
  else false
  end;

def fill($source; $local):
  if ($source | type) == "object" and ($local | type) == "object" then
    reduce ($source | keys_unsorted[]) as $key ($local;
      if has($key) then .[$key] = fill($source[$key]; .[$key])
      elif stands_in(.; $key) then .
      else .[$key] = $source[$key]
      end)
  else $local
  end;

$model[0] as $contract
| reconcile_local($contract; $local; $contract; [])
| .value = fill($source; .value)
