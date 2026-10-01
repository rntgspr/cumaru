//! Fixed project configuration shared by CLI commands.
//!
//! Mirrors `src/common.sh`: the framework tree has one fixed location and is
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
    let mut docs = YamlLoader::load_from_str(&text)
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
        include_str!("../../schemas/config.schema.off-9.json")
    } else {
        include_str!("../../schemas/config.schema.json")
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
fn yaml_to_json(value: &Yaml) -> Result<Value, String> {
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

#[cfg(test)]
mod tests {
    use super::*;

    /// Accepts the shipped v9 base configuration against the active schema.
    #[test]
    fn accepts_shipped_config() {
        let docs =
            YamlLoader::load_from_str(include_str!("../../domains/__base/config.yaml")).unwrap();

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
            YamlLoader::load_from_str(include_str!("../../domains/__base/config.yaml")).unwrap();
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
            YamlLoader::load_from_str(include_str!("../../domains/__base/config.yaml")).unwrap();
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
