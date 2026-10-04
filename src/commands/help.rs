use std::collections::BTreeMap;
use std::process::ExitCode;

use clap::{Args, CommandFactory};

use crate::distribution::{self, DomainSource};

#[derive(Args)]
pub struct HelpArgs {
    /// Show domains from the main HEAD, or help for a CLI command.
    #[arg(value_name = "TOPIC")]
    topic: Option<String>,
}

/// Renders local Clap help or assembles the complete pinned-main domain catalog before emitting it.
pub fn run(args: HelpArgs) -> ExitCode {
    if !matches!(args.topic.as_deref(), Some("domains" | "domain")) {
        let mut cli = crate::Cli::command();
        let help = match args.topic.as_deref() {
            None => cli.render_long_help(),
            Some(name) => match cli.find_subcommand_mut(name) {
                Some(command) => command.render_long_help(),
                None => {
                    eprintln!(
                        "cumaru help: unknown topic '{name}'; use domains or a CLI command name"
                    );
                    return ExitCode::from(2);
                }
            },
        };
        print!("{help}");
        return ExitCode::SUCCESS;
    }
    let result = (|| {
        let release = distribution::domain_source("__base")?;
        render_domains(&release, |path| release.read_repository(path))
    })();
    match result {
        Ok(output) => {
            print!("{output}");
            ExitCode::SUCCESS
        }
        Err(error) => {
            eprintln!("cumaru help: {error}");
            ExitCode::FAILURE
        }
    }
}

/// Discovers immediate public domain configs and validates catalog names and metadata modes before downloads.
fn domain_names(inventory: &BTreeMap<String, String>) -> Result<Vec<String>, String> {
    let mut names = Vec::new();
    for (path, mode) in inventory {
        let Some((name, relative)) = path
            .strip_prefix("domains/")
            .and_then(|path| path.split_once('/'))
        else {
            continue;
        };
        if relative != "config.yaml"
            || (name.starts_with("__") && name != "__base")
            || name.starts_with('.')
        {
            continue;
        }
        if name.is_empty()
            || !name
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
        {
            return Err(format!(
                "main catalog contains an invalid domain name: {}",
                crate::text::shell_quote(name)
            ));
        }
        if name == "base" {
            return Err("main domain 'base' conflicts with the reserved __base alias".into());
        }
        if !matches!(mode.as_str(), "100644" | "100755") {
            return Err(format!("main domain config is not a regular file: {path}"));
        }
        let metadata = format!("domains/{name}/domain.md");
        if inventory
            .get(&metadata)
            .is_some_and(|mode| !matches!(mode.as_str(), "100644" | "100755"))
        {
            return Err(format!(
                "main domain metadata is not a regular file: {metadata}"
            ));
        }
        names.push(name.to_string());
    }
    names.sort_by_key(|name| (name != "__base", name.clone()));
    if !names.iter().any(|name| name == "__base") {
        return Err("main catalog has no base domain".into());
    }
    Ok(names)
}

/// Reads the first literal H1 title, rejecting terminal controls and truncating long Unicode titles safely.
fn title(bytes: &[u8]) -> Result<String, String> {
    let text = std::str::from_utf8(bytes)
        .map_err(|error| format!("invalid domain metadata UTF-8: {error}"))?;
    let title = text
        .lines()
        .find_map(|line| line.strip_prefix("# "))
        .filter(|title| !title.is_empty())
        .unwrap_or("domain");
    if crate::text::has_control(title) {
        return Err("domain title contains a control character".into());
    }
    if title.chars().count() > 70 {
        Ok(format!("{}...", title.chars().take(67).collect::<String>()))
    } else {
        Ok(title.to_string())
    }
}

/// Assembles a deterministic base-first catalog using only regular metadata files in the pinned inventory.
fn render_domains(
    release: &DomainSource,
    mut read: impl FnMut(&str) -> Result<Vec<u8>, String>,
) -> Result<String, String> {
    let names = domain_names(&release.repository_files)?;
    let mut output =
        "Available domains (install one with `cumaru install --domain <name>`):\n\n".to_string();
    for name in names {
        let (name, summary) = if name == "__base" {
            (
                "base".to_string(),
                "minimal kernel - rules + meta, no pillars.".to_string(),
            )
        } else {
            let path = format!("domains/{name}/domain.md");
            let summary = if release.repository_files.contains_key(&path) {
                title(&read(&path)?)?
            } else {
                "domain".into()
            };
            (name, summary)
        };
        output.push_str(&format!("  {name:<22} {summary}\n"));
    }
    Ok(output)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Discovers only configured immediate public domains and renders sorted titles without requiring an adopter.
    #[test]
    fn renders_catalog_and_metadata_fallback() {
        let release = DomainSource {
            revision: "a".repeat(40),
            domain: "__base".into(),
            files: BTreeMap::new(),
            repository_files: [
                "domains/__base/config.yaml",
                "domains/zeta/config.yaml",
                "domains/zeta/domain.md",
                "domains/alpha/config.yaml",
                "domains/__private/config.yaml",
                "domains/.hidden/config.yaml",
                "domains/not-domain/nested/config.yaml",
                "domains/unconfigured/domain.md",
            ]
            .into_iter()
            .map(|path| (path.into(), "100644".into()))
            .collect(),
        };
        let mut fetched = Vec::new();
        let output = render_domains(&release, |path| {
            fetched.push(path.to_string());
            Ok(b"---\nsummary: Metadata\n---\n# Zeta title\r\n# Other\n".to_vec())
        })
        .unwrap();
        assert_eq!(fetched, ["domains/zeta/domain.md"]);
        assert_eq!(
            output,
            "Available domains (install one with `cumaru install --domain <name>`):\n\n  base                   minimal kernel - rules + meta, no pillars.\n  alpha                  domain\n  zeta                   Zeta title\n"
        );
    }

    /// Refuses unsafe names/metadata before fetching and propagates download failures without a partial catalog.
    #[test]
    fn rejects_invalid_catalog_and_failed_downloads() {
        for (path, mode) in [
            ("domains/bad name/config.yaml", "100644"),
            ("domains/base/config.yaml", "100644"),
            ("domains/alpha/config.yaml", "120000"),
            ("domains/alpha/domain.md", "120000"),
        ] {
            let mut inventory: BTreeMap<_, _> = [
                "domains/__base/config.yaml",
                "domains/alpha/config.yaml",
                "domains/alpha/domain.md",
            ]
            .into_iter()
            .map(|path| (path.into(), "100644".into()))
            .collect();
            inventory.insert(path.into(), mode.into());
            assert!(domain_names(&inventory).is_err());
        }
        assert!(domain_names(&BTreeMap::new()).is_err());
        let release = DomainSource {
            revision: "a".repeat(40),
            domain: "__base".into(),
            files: BTreeMap::new(),
            repository_files: [
                "domains/__base/config.yaml",
                "domains/alpha/config.yaml",
                "domains/alpha/domain.md",
            ]
            .into_iter()
            .map(|path| (path.into(), "100644".into()))
            .collect(),
        };
        assert_eq!(
            render_domains(&release, |_| Err("HTTP 404".into())).unwrap_err(),
            "HTTP 404"
        );
    }

    /// Preserves literal-heading behavior, Unicode boundaries, missing-title fallback, and control/UTF-8 rejection.
    #[test]
    fn reads_safe_literal_titles() {
        assert_eq!(title(b"# First\r\n# Second").unwrap(), "First");
        assert_eq!(title(b"## Not H1\n").unwrap(), "domain");
        assert_eq!(title(b"# \n").unwrap(), "domain");
        let long = format!("# {}", "a".repeat(66) + "ééééé");
        let shortened = title(long.as_bytes()).unwrap();
        assert_eq!(shortened.chars().count(), 70);
        assert!(shortened.ends_with("é..."));
        assert!(title(b"# Bad\tTitle").is_err());
        assert!(title(&[255]).is_err());
    }
}
