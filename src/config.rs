//! Fixed project configuration shared by CLI commands.
//!
//! Mirrors the retired Bash `src/common.sh` (tag 0.10.0): the framework tree has one fixed location and is
//! never read from the environment, so write-capable commands cannot be
//! redirected by an inherited variable.

use std::fs;
use std::path::Path;

use serde_json::{Map, Value};
use yaml_rust2::{Yaml, YamlLoader};

use crate::paths::is_symlink;

/// The framework tree, relative to the project directory.
pub const CUMARU_DIR: &str = ".cumaru";

/// The installed configuration file name inside `CUMARU_DIR`.
pub const CONFIG_FILE: &str = "config.yaml";

/// Loads and validates the adopter's single-document regular configuration file.
pub(crate) fn load(root: &Path) -> Result<Yaml, String> {
    let config = root.join(CONFIG_FILE);
    if is_symlink(&config) || !config.is_file() {
        return Err("filters require a regular .cumaru/config.yaml".into());
    }

    let text = fs::read_to_string(&config)
        .map_err(|error| format!("cannot read .cumaru/config.yaml: {error}"))?;
    parse(&text)
}

/// Parses one configuration document and applies the private embedded-schema validation gate.
pub(crate) fn parse(text: &str) -> Result<Yaml, String> {
    let mut docs = YamlLoader::load_from_str(text)
        .map_err(|error| format!("cannot parse .cumaru/config.yaml: {error}"))?;
    if docs.len() != 1 {
        return Err("config must contain exactly one YAML document".into());
    }

    let doc = docs.remove(0);
    validate(&doc)?;

    Ok(doc)
}

/// Validates the configuration against the embedded schema for its version.
fn validate(doc: &Yaml) -> Result<(), String> {
    let schema = if doc["version"].as_i64() == Some(8) {
        include_str!("../schemas/config.schema.off-9.json")
    } else {
        include_str!("../schemas/config.schema.json")
    };
    let schema: Value = serde_json::from_str(schema)
        .map_err(|error| format!("cannot parse embedded config schema: {error}"))?;
    let validator = jsonschema::validator_for(&schema)
        .map_err(|error| format!("cannot compile config schema: {error}"))?;
    let instance = yaml_to_json(doc)?;
    let errors: Vec<String> = validator
        .iter_errors(&instance)
        .map(|error| {
            let path = error.instance_path().to_string();

            format!("  {}: {error}", if path.is_empty() { "/" } else { &path })
        })
        .collect();

    if errors.is_empty() {
        Ok(())
    } else {
        Err(format!(
            "invalid .cumaru/config.yaml:\n{}",
            errors.join("\n")
        ))
    }
}

/// Converts YAML values to JSON without coercing non-string mapping keys.
pub(crate) fn yaml_to_json(value: &Yaml) -> Result<Value, String> {
    match value {
        Yaml::Null => Ok(Value::Null),
        Yaml::Boolean(value) => Ok(Value::Bool(*value)),
        Yaml::Integer(value) => Ok(Value::from(*value)),
        Yaml::Real(value) => value
            .parse::<f64>()
            .ok()
            .and_then(serde_json::Number::from_f64)
            .map(Value::Number)
            .ok_or_else(|| "config numbers must be finite JSON numbers".into()),
        Yaml::String(value) => Ok(Value::String(value.clone())),
        Yaml::Array(values) => values
            .iter()
            .map(yaml_to_json)
            .collect::<Result<Vec<_>, _>>()
            .map(Value::Array),
        Yaml::Hash(values) => {
            let mut object = Map::new();
            for (key, value) in values {
                let key = key.as_str().ok_or("config mapping keys must be strings")?;
                object.insert(key.to_string(), yaml_to_json(value)?);
            }

            Ok(Value::Object(object))
        }
        _ => Err("config contains an unsupported YAML value".into()),
    }
}

/// Reports a schema-pruned, default-filled v9 candidate without replacing permitted local values.
pub(crate) fn reconcile(text: &str, source: &Yaml) -> Result<(String, Vec<String>), String> {
    let docs = YamlLoader::load_from_str(text).map_err(|e| e.to_string())?;
    if docs.len() != 1 {
        return Err("config must contain exactly one YAML document".into());
    }
    if docs[0]["version"].as_i64() != source["version"].as_i64() {
        return Err("config reconciliation cannot cross versions; use cumaru migrate".into());
    }
    let model: Value = serde_json::from_str(include_str!("../schemas/config.schema.json"))
        .map_err(|e| e.to_string())?;
    let mut candidate = yaml_to_json(&docs[0])?;
    let mut removed = Vec::new();
    prune(&mut candidate, &model, &model, "", &mut removed);
    fill(&mut candidate, &yaml_to_json(source)?);

    let output = serde_json::to_string_pretty(&candidate).map_err(|e| e.to_string())?;
    parse(&output)?;
    Ok((format!("{output}\n"), removed))
}

/// Removes only model-incompatible properties, following local schema references recursively.
fn prune(value: &mut Value, schema: &Value, model: &Value, path: &str, removed: &mut Vec<String>) {
    let schema = schema["$ref"]
        .as_str()
        .and_then(|reference| reference.strip_prefix('#'))
        .and_then(|pointer| model.pointer(pointer))
        .unwrap_or(schema);
    if let Some(object) = value.as_object_mut() {
        if schema.get("properties").is_none() && schema.get("additionalProperties").is_none() {
            return;
        }
        let keys: Vec<_> = object.keys().cloned().collect();
        for key in keys {
            let pointer = format!("{path}/{}", key.replace('~', "~0").replace('/', "~1"));
            let contract = schema["properties"]
                .get(&key)
                .or_else(|| schema.get("additionalProperties").filter(|s| s.is_object()));
            if let Some(contract) = contract {
                prune(
                    object.get_mut(&key).unwrap(),
                    contract,
                    model,
                    &pointer,
                    removed,
                );
            } else if schema["additionalProperties"] != true {
                object.remove(&key);
                removed.push(pointer);
            }
        }
    } else if let Some(array) = value.as_array_mut() {
        if let Some(items) = schema.get("items") {
            for (index, child) in array.iter_mut().enumerate() {
                prune(child, items, model, &format!("{path}/{index}"), removed);
            }
        }
    }
}

/// Fills missing defaults while preserving scalar/array choices and refined wildcard selectors.
fn fill(local: &mut Value, source: &Value) {
    let (Some(local), Some(source)) = (local.as_object_mut(), source.as_object()) else {
        return;
    };
    for (key, default) in source {
        if let Some(value) = local.get_mut(key) {
            fill(value, default);
        } else {
            let refined = key.contains(['*', '?'])
                && !key.contains('[')
                && glob::Pattern::new(key).is_ok_and(|pattern| {
                    local.keys().any(|candidate| {
                        !["path", "optional", "framework", "frontmatter", "tags"]
                            .contains(&candidate.as_str())
                            && pattern.matches_with(
                                candidate,
                                glob::MatchOptions {
                                    case_sensitive: true,
                                    require_literal_separator: true,
                                    require_literal_leading_dot: true,
                                },
                            )
                    })
                });
            if !refined {
                local.insert(key.clone(), default.clone());
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Prunes unknown properties, fills missing defaults, and blocks invalid permitted local values.
    #[test]
    fn reconciles_without_overwriting_local_choices() {
        let source = parse(include_str!("../domains/__base/config.yaml")).unwrap();
        let mut local = yaml_to_json(&source).unwrap();
        local["extra"] = Value::Bool(true);
        local["meta"]["targets"]["values"] = serde_json::json!(["mine"]);
        local.as_object_mut().unwrap().remove("rules");
        let (candidate, removed) = reconcile(&local.to_string(), &source).unwrap();
        assert_eq!(removed, vec!["/extra"]);
        let candidate = parse(&candidate).unwrap();
        assert_eq!(
            candidate["meta"]["targets"]["values"][0].as_str(),
            Some("mine")
        );
        assert!(candidate["rules"].as_hash().is_some());
        local["meta"]["targets"]["values"] = serde_json::json!("bad");
        assert!(reconcile(&local.to_string(), &source).is_err());
    }

    /// Accepts the shipped v9 base configuration against the active schema.
    #[test]
    fn accepts_shipped_config() {
        let docs =
            YamlLoader::load_from_str(include_str!("../domains/__base/config.yaml")).unwrap();

        assert!(validate(&docs[0]).is_ok());
    }

    /// Keeps installed v8 configurations valid against their migration schema.
    #[test]
    fn accepts_legacy_config() {
        let docs = YamlLoader::load_from_str(
            "version: 8\ndomain: legacy\nrules:\n  markdown: {required_heading: h1, frontmatter: []}\n  index_md: {frontmatter: []}\n  pillar_index: {frontmatter: []}\nroot: {entities: {}}\nmeta:\n  targets: {values: [platform]}\n  tags: {}\n  compatibility: {framework_version_field: version, framework_version_location: index.md, rule: [match]}\n",
        )
        .unwrap();

        assert!(validate(&docs[0]).is_ok());
    }

    /// Reports all schema violations rather than stopping at the first one.
    #[test]
    fn reports_multiple_schema_errors() {
        let mut docs =
            YamlLoader::load_from_str(include_str!("../domains/__base/config.yaml")).unwrap();
        let Yaml::Hash(config) = &mut docs[0] else {
            panic!("the shipped config must be a mapping");
        };
        config.remove(&Yaml::String("meta".into()));
        config.insert(Yaml::String("domain".into()), Yaml::Integer(42));
        config.insert(Yaml::String("unknown".into()), Yaml::Boolean(true));

        let error = validate(&docs[0]).unwrap_err();

        assert!(error.contains("meta"), "{error}");
        assert!(error.contains("/domain"), "{error}");
        assert!(error.contains("unknown"), "{error}");
    }

    /// Rejects invalid nested properties and unsupported configuration versions.
    #[test]
    fn rejects_nested_type_and_unsupported_version() {
        let mut docs =
            YamlLoader::load_from_str(include_str!("../domains/__base/config.yaml")).unwrap();
        let Yaml::Hash(config) = &mut docs[0] else {
            panic!("the shipped config must be a mapping");
        };
        config.insert(Yaml::String("version".into()), Yaml::Integer(10));
        config.insert(Yaml::String("root".into()), Yaml::String("invalid".into()));

        let error = validate(&docs[0]).unwrap_err();

        assert!(error.contains("/version"), "{error}");
        assert!(error.contains("/root"), "{error}");
    }
}
