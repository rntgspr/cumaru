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

def fill($source; $local):
  if ($source | type) == "object" and ($local | type) == "object" then
    reduce ($source | keys_unsorted[]) as $key ($local;
      if has($key) then .[$key] = fill($source[$key]; .[$key])
      else .[$key] = $source[$key]
      end)
  else $local
  end;

$model[0] as $contract
| reconcile_local($contract; $local; $contract; [])
| .value = fill($source; .value)
