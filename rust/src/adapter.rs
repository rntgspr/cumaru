//! Native adapter instruction and session-hook planning without filesystem writes.

use std::collections::BTreeMap;

use clap::ValueEnum;
use serde_json::{Value, json};

#[derive(Clone, Copy, Debug, PartialEq, Eq, ValueEnum)]
pub(crate) enum Adapter {
    None,
    Claude,
    Codex,
    Opencode,
}

const HOOK: &str = "index=.cumaru/disciplines/index.md; [ -f \"$index\" ] && { printf \"\\n## Discipline: %s\\n\\n\" \"$index\"; cat \"$index\"; }; for file in .cumaru/disciplines/*.md; do [ \"$file\" = \"$index\" ] && continue; [ -f \"$file\" ] && { printf \"\\n## Discipline: %s\\n\\n\" \"$file\"; cat \"$file\"; }; done; cumaru tree . 2>/dev/null || true";
const INSTRUCTIONS: [&str; 3] = [
    ".cumaru/index.md",
    ".cumaru/domain.md",
    ".cumaru/disciplines/*.md",
];

impl Adapter {
    /// Returns the selected client's native skill directory.
    pub(crate) fn skills(self) -> &'static str {
        if self == Self::Claude {
            ".claude/skills"
        } else {
            ".agents/skills"
        }
    }

    /// Returns a supported launcher directory; Claude and Codex use skills directly.
    pub(crate) fn commands(self) -> Option<&'static str> {
        match self {
            Self::None => Some(".agents/commands"),
            Self::Opencode => Some(".opencode/commands"),
            _ => None,
        }
    }

    /// Returns a native Markdown instruction path when the client supports it.
    pub(crate) fn instructions(self) -> Option<&'static str> {
        match self {
            Self::None => Some(".agents/AGENTS.md"),
            Self::Claude => Some("CLAUDE.md"),
            Self::Codex => Some("AGENTS.md"),
            Self::Opencode => None,
        }
    }

    /// Returns a supported session-start JSON path.
    pub(crate) fn hooks(self) -> Option<&'static str> {
        match self {
            Self::Claude => Some(".claude/settings.json"),
            Self::Codex => Some(".codex/hooks.json"),
            _ => None,
        }
    }
}

/// Produces ordered bootstrap instructions, importing or embedding the installed discipline bodies.
fn block(
    adapter: Adapter,
    created: bool,
    files: &BTreeMap<String, Vec<u8>>,
) -> Result<String, String> {
    let begin = if created {
        "<!-- BEGIN CUMARU-HOOK created -->"
    } else {
        "<!-- BEGIN CUMARU-HOOK -->"
    };
    let mut output = format!(
        "{begin}\n## `.cumaru/` framework\n\nAt every session start, read `.cumaru/index.md`, `.cumaru/domain.md`, `.cumaru/disciplines/index.md`, and every other installed discipline in path order, then run `cumaru tree .`. Load every discipline; strictness controls consideration and applies-when controls application. Prune tree candidates by relevance.\n\n@.cumaru/index.md\n@.cumaru/domain.md\n"
    );
    let mut disciplines: Vec<_> = files
        .keys()
        .filter(|path| {
            path.starts_with("disciplines/")
                && path.ends_with(".md")
                && path[12..].find('/').is_none()
        })
        .collect();
    disciplines.sort_by_key(|path| (path.as_str() != "disciplines/index.md", path.as_str()));
    for path in disciplines {
        if adapter == Adapter::Claude {
            output.push_str(&format!("@.cumaru/{path}\n"));
        } else {
            let text = std::str::from_utf8(&files[path]).map_err(|e| e.to_string())?;
            output.push_str(&format!("\n<!-- BEGIN CUMARU-DISCIPLINE .cumaru/{path} -->\nSource: `.cumaru/{path}`\n\n{text}\n<!-- END CUMARU-DISCIPLINE .cumaru/{path} -->\n"));
        }
    }
    output.push_str("<!-- END CUMARU-HOOK -->\n");
    Ok(output)
}

/// Replaces only complete owned bootstrap blocks while retaining adopter prose and creation provenance.
pub(crate) fn markdown(
    adapter: Adapter,
    existing: Option<&str>,
    files: &BTreeMap<String, Vec<u8>>,
) -> Result<String, String> {
    let new_file = existing.is_none();
    let existing = existing.unwrap_or("# Project instructions\n");
    let mut output = String::new();
    let mut inside = false;
    let mut created = new_file;
    for line in existing.split_inclusive('\n') {
        if line.starts_with("<!-- BEGIN CUMARU-HOOK") {
            if inside {
                return Err("nested Cumaru instruction blocks".into());
            }
            inside = true;
            created |= line.contains("created");
        } else if line.trim_end() == "<!-- END CUMARU-HOOK -->" {
            if !inside {
                return Err("unmatched Cumaru instruction closer".into());
            }
            inside = false;
        } else if !inside {
            output.push_str(line);
        }
    }
    if inside {
        return Err("unclosed Cumaru instruction block".into());
    }
    if !output.ends_with('\n') {
        output.push('\n');
    }
    while output.ends_with("\n\n") {
        output.pop();
    }
    output.push('\n');
    output.push_str(&block(adapter, created, files)?);
    Ok(output)
}

/// Loads an existing JSON object without coercing malformed adopter state.
fn object(existing: Option<&str>) -> Result<Value, String> {
    let value = existing
        .map(serde_json::from_str)
        .transpose()
        .map_err(|e| e.to_string())?
        .unwrap_or_else(|| json!({}));
    if !value.is_object() {
        return Err("adapter config must be a JSON object".into());
    }
    Ok(value)
}

/// Merges the exact OpenCode instruction entries while retaining unrelated values and their order.
pub(crate) fn opencode(existing: Option<&str>) -> Result<String, String> {
    let mut value = object(existing)?;
    if value["instructions"].is_null() {
        value["instructions"] = json!([]);
    }
    let instructions = value["instructions"]
        .as_array_mut()
        .ok_or("OpenCode instructions must be an array")?;
    instructions.retain(|entry| !entry.as_str().is_some_and(|s| INSTRUCTIONS.contains(&s)));
    instructions.extend(INSTRUCTIONS.map(|entry| Value::String(entry.into())));
    serde_json::to_string_pretty(&value)
        .map(|text| format!("{text}\n"))
        .map_err(|e| e.to_string())
}

/// Merges one Cumaru hook and preserves other entries, including unrelated hooks sharing an entry.
pub(crate) fn hooks(existing: Option<&str>) -> Result<String, String> {
    let mut value = object(existing)?;
    if value["hooks"].is_null() {
        value["hooks"] = json!({});
    }
    if !value["hooks"].is_object() {
        return Err("hooks must be a JSON object".into());
    }
    if value["hooks"]["SessionStart"].is_null() {
        value["hooks"]["SessionStart"] = json!([]);
    }
    let entries = value["hooks"]["SessionStart"]
        .as_array_mut()
        .ok_or("SessionStart must be an array")?;
    for entry in entries.iter_mut() {
        if !entry.is_object() {
            return Err("SessionStart entries must be objects".into());
        }
        let hooks = entry["hooks"]
            .as_array_mut()
            .ok_or("SessionStart entry hooks must be an array")?;
        hooks.retain(|hook| {
            !hook["command"].as_str().is_some_and(|command| {
                command == HOOK
                    || command == HOOK.replace("cumaru tree", "cuma tree")
                    || command == "cumaru tree . 2>/dev/null || true"
            })
        });
    }
    entries.retain(|entry| !entry["hooks"].as_array().unwrap().is_empty());
    entries.push(json!({"matcher": "startup|resume|clear|compact|fork", "hooks": [{"type": "command", "command": HOOK}]}));
    serde_json::to_string_pretty(&value)
        .map(|text| format!("{text}\n"))
        .map_err(|e| e.to_string())
}

/// Strips only owned instruction blocks or exact JSON entries, rejecting malformed native state.
pub(crate) fn clear(existing: &str, kind: &str) -> Result<String, String> {
    if kind == "markdown" {
        let mut output = String::new();
        let mut inside = None;
        for line in existing.split_inclusive('\n') {
            if line.starts_with("<!-- BEGIN CUMARU-HOOK")
                || line.starts_with("<!-- BEGIN DOT-LLM-HOOK")
            {
                if inside.is_some() {
                    return Err("nested Cumaru instruction blocks".into());
                }
                inside = Some(if line.starts_with("<!-- BEGIN CUMARU-HOOK") {
                    "CUMARU"
                } else {
                    "DOT-LLM"
                });
            } else if ["<!-- END CUMARU-HOOK -->", "<!-- END DOT-LLM-HOOK -->"]
                .contains(&line.trim_end())
            {
                let closer = if line.trim_end() == "<!-- END CUMARU-HOOK -->" {
                    "CUMARU"
                } else {
                    "DOT-LLM"
                };
                if inside != Some(closer) {
                    return Err("unmatched Cumaru instruction closer".into());
                }
                inside = None;
            } else if inside.is_none() {
                output.push_str(line);
            }
        }
        if inside.is_some() {
            return Err("unclosed Cumaru instruction block".into());
        }
        return Ok(output);
    }
    let mut value = object(Some(existing))?;
    let original = value.clone();
    if kind == "opencode" {
        if let Some(instructions) = value.get_mut("instructions") {
            let instructions = instructions
                .as_array_mut()
                .ok_or("OpenCode instructions must be an array")?;
            instructions.retain(|entry| !entry.as_str().is_some_and(|s| INSTRUCTIONS.contains(&s)));
        }
    } else if let Some(hooks) = value.get_mut("hooks") {
        let hooks = hooks.as_object_mut().ok_or("hooks must be a JSON object")?;
        if let Some(entries) = hooks.get_mut("SessionStart") {
            let entries = entries
                .as_array_mut()
                .ok_or("SessionStart must be an array")?;
            for entry in entries.iter_mut() {
                let hooks = entry["hooks"]
                    .as_array_mut()
                    .ok_or("SessionStart entry hooks must be an array")?;
                hooks.retain(|hook| {
                    !hook["command"].as_str().is_some_and(|command| {
                        command == HOOK
                            || command == HOOK.replace("cumaru tree", "cuma tree")
                            || command == "cumaru tree . 2>/dev/null || true"
                    })
                });
            }
            entries.retain(|entry| !entry["hooks"].as_array().unwrap().is_empty());
            if entries.is_empty() {
                hooks.remove("SessionStart");
            }
        }
        if hooks.is_empty() {
            value.as_object_mut().unwrap().remove("hooks");
        }
    }
    if value == original {
        return Ok(existing.into());
    }
    serde_json::to_string_pretty(&value)
        .map(|s| format!("{s}\n"))
        .map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Removes owned entries without touching adopter content and keeps refresh byte-idempotent.
    #[test]
    fn clears_exact_owned_artifacts() {
        let files = BTreeMap::new();
        let instructions = markdown(Adapter::Codex, Some("mine\n"), &files).unwrap();
        assert_eq!(
            markdown(Adapter::Codex, Some(&instructions), &files).unwrap(),
            instructions
        );
        assert!(clear(&instructions, "markdown").unwrap().contains("mine"));
        let legacy = instructions.replace("CUMARU-HOOK", "DOT-LLM-HOOK");
        assert_eq!(
            clear(&legacy, "markdown").unwrap(),
            clear(&instructions, "markdown").unwrap()
        );
        assert!(
            clear(
                "<!-- BEGIN CUMARU-HOOK -->\n<!-- END DOT-LLM-HOOK -->\n",
                "markdown"
            )
            .is_err()
        );
        assert!(
            !clear(&instructions, "markdown")
                .unwrap()
                .contains("CUMARU-HOOK")
        );
        let existing = r#"{"permissions":true,"hooks":{"Stop":[1],"SessionStart":[{"hooks":[{"command":"mine"},{"command":"cumaru tree . 2>/dev/null || true"}]}]}}"#;
        let output = clear(existing, "hooks").unwrap();
        let value: Value = serde_json::from_str(&output).unwrap();
        assert_eq!(value["permissions"], true);
        assert_eq!(value["hooks"]["Stop"], json!([1]));
        assert_eq!(
            value["hooks"]["SessionStart"][0]["hooks"],
            json!([{"command":"mine"}])
        );
        assert_eq!(
            clear("{ \"mine\": true }", "hooks").unwrap(),
            "{ \"mine\": true }"
        );
    }

    /// Protects unrelated instruction/config content and rejects malformed adapter state.
    #[test]
    fn preserves_adopter_surfaces() {
        let files = BTreeMap::from([
            ("disciplines/index.md".into(), b"discipline index".to_vec()),
            ("disciplines/a.md".into(), b"discipline body".to_vec()),
        ]);
        let output = markdown(Adapter::Codex, Some("My rules\n"), &files).unwrap();
        assert!(output.starts_with("My rules\n"));
        assert!(output.find("discipline index").unwrap() < output.find("discipline body").unwrap());
        assert_eq!(
            markdown(Adapter::Codex, Some(&output), &files)
                .unwrap()
                .matches("BEGIN CUMARU-HOOK")
                .count(),
            1
        );
        assert!(
            markdown(
                Adapter::Claude,
                Some("<!-- BEGIN CUMARU-HOOK -->\n"),
                &files
            )
            .is_err()
        );
        let value: Value = serde_json::from_str(
            &opencode(Some(
                r#"{"instructions":["mine",".cumaru/domain.md"],"other":true}"#,
            ))
            .unwrap(),
        )
        .unwrap();
        assert_eq!(value["instructions"][0], "mine");
        assert_eq!(value["other"], true);
        assert!(opencode(Some(r#"{"instructions":"bad"}"#)).is_err());
    }

    /// Keeps unrelated hooks while consolidating the owned hook on repeated merges.
    #[test]
    fn merges_session_hooks() {
        let existing = r#"{"permissions":{"allow":["mine"]},"hooks":{"Stop":[1],"SessionStart":[{"matcher":"startup","hooks":[{"type":"command","command":"mine"},{"type":"command","command":"cumaru tree . 2>/dev/null || true"}]}]}}"#;
        let output = hooks(Some(existing)).unwrap();
        let output = hooks(Some(&output)).unwrap();
        let value: Value = serde_json::from_str(&output).unwrap();
        assert_eq!(value["hooks"]["SessionStart"].as_array().unwrap().len(), 2);
        assert_eq!(
            value["hooks"]["SessionStart"][0]["hooks"][0]["command"],
            "mine"
        );
        assert_eq!(value["hooks"]["Stop"], json!([1]));
        assert!(hooks(Some(r#"{"hooks":{"SessionStart":"bad"}}"#)).is_err());

        let legacy = json!({"hooks":{"SessionStart":[{"hooks":[{"command":HOOK.replace("cumaru tree", "cuma tree")}]}]}}).to_string();
        let refreshed = hooks(Some(&legacy)).unwrap();
        let value: Value = serde_json::from_str(&refreshed).unwrap();
        assert_eq!(value["hooks"]["SessionStart"].as_array().unwrap().len(), 1);
        assert_eq!(
            value["hooks"]["SessionStart"][0]["hooks"][0]["command"],
            HOOK
        );
        let cleared: Value = serde_json::from_str(&clear(&legacy, "hooks").unwrap()).unwrap();
        assert!(cleared.get("hooks").is_none());
    }
}
