//! Remote domain materialization and native adapter installation into a fresh project.

use std::collections::{BTreeMap, BTreeSet};
use std::fs::{self, OpenOptions};
use std::io::Write as _;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use clap::Args;

use crate::{
    adapter::{self, Adapter},
    config, config_tree, distribution, paths,
};

#[derive(Args)]
#[command(override_usage = "cumaru install [agent <none|claude|codex|opencode>] [--domain <name>]")]
pub struct InstallArgs {
    /// Selects a release domain; base is an alias for __base.
    #[arg(long, default_value = "__base")]
    domain: String,
    /// Optional literal 'agent' followed by its native adapter name.
    #[arg(num_args = 0..=2)]
    adapter: Vec<String>,
}

struct Write {
    path: String,
    content: Vec<u8>,
    original: Option<Vec<u8>>,
    executable: bool,
}

/// Validates domain/adapter arguments before repository access or project mutation.
fn arguments(args: &InstallArgs) -> Result<(String, Adapter), String> {
    let domain = if args.domain == "base" {
        "__base"
    } else {
        &args.domain
    };
    if domain != "__base"
        && (!domain.starts_with(|c: char| c.is_ascii_lowercase())
            || !domain
                .bytes()
                .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'_' || c == b'-'))
    {
        return Err("domain must be __base or a lowercase domain name".into());
    }
    let adapter = match args.adapter.as_slice() {
        [] => Adapter::None,
        [keyword, name] if keyword == "agent" => match name.as_str() {
            "none" => Adapter::None,
            "claude" => Adapter::Claude,
            "codex" => Adapter::Codex,
            "opencode" => Adapter::Opencode,
            _ => return Err("unknown adapter: expected none, claude, codex, or opencode".into()),
        },
        _ => {
            return Err(
                "usage: install [agent <none|claude|codex|opencode>] [--domain <name>]".into(),
            );
        }
    };
    Ok((domain.into(), adapter))
}

/// Installs the latest remote domain with classified usage and runtime failures.
pub fn run(args: InstallArgs) -> ExitCode {
    let (domain, adapter) = match arguments(&args) {
        Ok(args) => args,
        Err(error) => {
            eprintln!("cumaru install: {error}");
            return ExitCode::from(2);
        }
    };
    let result = (|| {
        let project = fs::canonicalize(std::env::current_dir().map_err(|e| e.to_string())?)
            .map_err(|e| e.to_string())?;
        refuse_existing(&project)?;
        let release = distribution::latest_release()?;
        println!("Fetching domain '{domain}' from release {release}...");
        let source = distribution::domain_release(&release, &domain)?;
        let config_bytes = source.read(config::CONFIG_FILE)?;
        let doc = config::parse(std::str::from_utf8(&config_bytes).map_err(|e| e.to_string())?)?;
        let expected = if domain == "__base" { "base" } else { &domain };
        if doc["version"].as_i64() != Some(9) || doc["domain"].as_str() != Some(expected) {
            return Err("release config must declare v9 and the selected domain".into());
        }
        let inventory = source.files.keys().cloned().collect();
        let selected = config_tree::install_files(&doc, &inventory)?;
        let mut domain_files = BTreeMap::new();
        for path in selected {
            let bytes = if path == config::CONFIG_FILE {
                config_bytes.clone()
            } else {
                source.read(&path)?
            };
            domain_files.insert(path, bytes);
        }
        validate_disciplines(&domain_files)?;
        if !domain_files.contains_key("domain.md") {
            return Err("config must select domain.md for adapter bootstrap".into());
        }
        let mut writes = Vec::new();
        for (path, bytes) in &domain_files {
            writes.push(Write {
                path: format!(".cumaru/{path}"),
                content: bytes.clone(),
                original: None,
                executable: source.files[path] == "100755",
            });
        }
        add_skills(&project, adapter, &source, &mut writes)?;
        if let Some(commands) = adapter.commands() {
            for path in source
                .files
                .keys()
                .filter(|path| path.starts_with("commands/") && path.ends_with(".md"))
            {
                let rel = path.strip_prefix("commands/").unwrap();
                let name = Path::new(rel)
                    .file_stem()
                    .and_then(|name| name.to_str())
                    .ok_or("invalid command name")?;
                if !source
                    .files
                    .contains_key(&format!("skills/cumaru-{name}/SKILL.md"))
                {
                    return Err(format!("command has no namesake domain skill: {rel}"));
                }
                let dest = format!("{commands}/{rel}");
                if existing(&project, &dest)?.is_none() {
                    writes.push(Write {
                        path: dest,
                        content: source.read(path)?,
                        original: None,
                        executable: false,
                    });
                }
            }
        }
        if let Some(path) = adapter.instructions() {
            let original = existing(&project, path)?;
            let text = original
                .as_deref()
                .map(std::str::from_utf8)
                .transpose()
                .map_err(|e| e.to_string())?;
            writes.push(Write {
                path: path.into(),
                content: adapter::markdown(adapter, text, &domain_files)?.into_bytes(),
                original,
                executable: false,
            });
        } else {
            let path = "opencode.json";
            let original = existing(&project, path)?;
            let text = original
                .as_deref()
                .map(std::str::from_utf8)
                .transpose()
                .map_err(|e| e.to_string())?;
            writes.push(Write {
                path: path.into(),
                content: adapter::opencode(text)?.into_bytes(),
                original,
                executable: false,
            });
        }
        if let Some(path) = adapter.hooks() {
            let original = existing(&project, path)?;
            let text = original
                .as_deref()
                .map(std::str::from_utf8)
                .transpose()
                .map_err(|e| e.to_string())?;
            writes.push(Write {
                path: path.into(),
                content: adapter::hooks(text)?.into_bytes(),
                original,
                executable: false,
            });
        }
        preflight(&project, &writes)?;
        apply(&project, &writes)?;
        println!(
            "Installed domain '{domain}' from release {release} into .cumaru/.\n\nNext steps:\n  1. Read .cumaru/domain.md.\n  2. Review .cumaru/config.yaml and its target values.\n  3. Run cumaru doctor.\n\nAdapter selection is stateless. Optional skills belong to update."
        );
        Ok(())
    })();
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("cumaru install: {error}");
            ExitCode::FAILURE
        }
    }
}

/// Refuses existing installations, including files and broken symlinks, before network or writes.
fn refuse_existing(project: &Path) -> Result<(), String> {
    let path = project.join(config::CUMARU_DIR);
    match fs::symlink_metadata(path) {
        Ok(_) => Err(".cumaru/ already exists; use update for refresh".into()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.to_string()),
    }
}

/// Validates all selected discipline strictness metadata before adopter writes.
fn validate_disciplines(files: &BTreeMap<String, Vec<u8>>) -> Result<(), String> {
    if !files.contains_key("disciplines/index.md") {
        return Err("config must select disciplines/index.md".into());
    }
    for (path, bytes) in files.iter().filter(|(path, _)| {
        path.starts_with("disciplines/")
            && path.ends_with(".md")
            && path.as_str() != "disciplines/index.md"
    }) {
        let text = std::str::from_utf8(bytes).map_err(|e| e.to_string())?;
        let frontmatter =
            crate::markdown::frontmatter(text).map_err(|error| format!("{path}: {error}"))?;
        crate::markdown::validate_strictness(&frontmatter["strictness"])
            .map_err(|error| format!("{path}: {error}"))?;
    }
    Ok(())
}

/// Plans complete domain skill directories while skipping adopter-owned names already installed.
fn add_skills(
    project: &Path,
    adapter: Adapter,
    source: &distribution::DomainRelease,
    writes: &mut Vec<Write>,
) -> Result<(), String> {
    let mut skipped = BTreeSet::new();
    for path in source
        .files
        .keys()
        .filter(|path| path.starts_with("skills/"))
    {
        let Some((name, _)) = path[7..].split_once('/') else {
            return Err("skill source must have a named directory".into());
        };
        if !name.starts_with("cumaru-") {
            continue;
        }
        if !source
            .files
            .contains_key(&format!("skills/{name}/SKILL.md"))
        {
            return Err(format!("domain skill has no SKILL.md: {name}"));
        }
        let dest_root = format!("{}/{name}", adapter.skills());
        safe_destination(project, &dest_root)?;
        if project.join(&dest_root).exists() {
            if !project.join(&dest_root).is_dir() {
                return Err(format!("skill destination is not a directory: {dest_root}"));
            }
            skipped.insert(name.to_string());
            continue;
        }
        writes.push(Write {
            path: format!("{}/{}", adapter.skills(), &path[7..]),
            content: source.read(path)?,
            original: None,
            executable: source.files[path] == "100755",
        });
    }
    for name in skipped {
        println!("Skill '{name}' already exists; preserved.");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Rejects invalid command arguments and resolves the base alias and explicit adapter.
    #[test]
    fn validates_install_arguments() {
        let args = InstallArgs {
            domain: "base".into(),
            adapter: vec!["agent".into(), "claude".into()],
        };
        assert_eq!(
            arguments(&args).unwrap(),
            ("__base".into(), Adapter::Claude)
        );
        for domain in ["../outside", "", "UPPER"] {
            assert!(
                arguments(&InstallArgs {
                    domain: domain.into(),
                    adapter: Vec::new()
                })
                .is_err()
            );
        }
        assert!(
            arguments(&InstallArgs {
                domain: "__base".into(),
                adapter: vec!["codex".into()]
            })
            .is_err()
        );
    }

    /// Enforces discipline metadata without interpreting unrelated Markdown content.
    #[test]
    fn validates_source_disciplines() {
        let mut files = BTreeMap::from([
            ("disciplines/index.md".into(), Vec::new()),
            (
                "disciplines/a.md".into(),
                b"---\nstrictness: 9/10\n---\nbody".to_vec(),
            ),
        ]);
        assert!(validate_disciplines(&files).is_ok());
        files.insert(
            "disciplines/a.md".into(),
            b"---\nstrictness: 11/10\n---\nbody".to_vec(),
        );
        assert!(validate_disciplines(&files).is_err());
    }

    /// Refuses existing installations and unsafe destinations before creating any planned file.
    #[test]
    fn protects_project_preflight() {
        let nonce = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let project =
            std::env::temp_dir().join(format!("cumaru-install-{}-{nonce}", std::process::id()));
        fs::create_dir(&project).unwrap();
        let project = fs::canonicalize(project).unwrap();
        fs::write(project.join("AGENTS.md"), "mine").unwrap();
        let writes = [Write {
            path: "AGENTS.md".into(),
            content: b"new".to_vec(),
            original: Some(b"stale".to_vec()),
            executable: false,
        }];
        assert!(preflight(&project, &writes).is_err());
        assert!(!project.join(".cumaru").exists());
        assert_eq!(fs::read(project.join("AGENTS.md")).unwrap(), b"mine");
        assert!(safe_destination(&project, "../escape").is_err());
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink("missing", project.join(".cumaru")).unwrap();
            assert!(refuse_existing(&project).is_err());
        }
        fs::remove_dir_all(project).unwrap();
    }
}

/// Rejects unsafe or symlinked destination paths and existing non-directory parents.
fn safe_destination(project: &Path, rel: &str) -> Result<PathBuf, String> {
    paths::project_destination(project, rel)
}

/// Reads a regular adopter file for a prospective merge without creating adapter directories.
fn existing(project: &Path, rel: &str) -> Result<Option<Vec<u8>>, String> {
    let path = safe_destination(project, rel)?;
    match fs::read(&path) {
        Ok(bytes) => Ok(Some(bytes)),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(format!("cannot read {rel}: {error}")),
    }
}

/// Validates the complete publication plan and original adopter bytes before the first project write.
fn preflight(project: &Path, writes: &[Write]) -> Result<(), String> {
    refuse_existing(project)?;
    let mut seen = BTreeSet::new();
    for write in writes {
        if !seen.insert(&write.path) {
            return Err(format!("duplicate install destination: {}", write.path));
        }
        if existing(project, &write.path)? != write.original {
            return Err(format!("install destination changed: {}", write.path));
        }
    }
    Ok(())
}

/// Publishes a validated initial install in order; reports partial I/O failures without claiming rollback.
fn apply(project: &Path, writes: &[Write]) -> Result<(), String> {
    refuse_existing(project)?;
    fs::create_dir(project.join(config::CUMARU_DIR)).map_err(|e| e.to_string())?;
    for (index, write) in writes.iter().enumerate() {
        let path = safe_destination(project, &write.path)?;
        if existing(project, &write.path)? != write.original {
            return Err(format!("install destination changed: {}", write.path));
        }
        fs::create_dir_all(path.parent().unwrap()).map_err(|e| e.to_string())?;
        if write.original.is_some() {
            let temporary =
                path.with_file_name(format!(".cumaru-install-{}-{index}", std::process::id()));
            let mut file = OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&temporary)
                .map_err(|e| e.to_string())?;
            let result = (|| {
                file.set_permissions(
                    fs::metadata(&path)
                        .map_err(|e| e.to_string())?
                        .permissions(),
                )
                .map_err(|e| e.to_string())?;
                file.write_all(&write.content).map_err(|e| e.to_string())?;
                file.sync_all().map_err(|e| e.to_string())?;
                if existing(project, &write.path)? != write.original {
                    return Err(format!("install destination changed: {}", write.path));
                }
                fs::rename(&temporary, &path).map_err(|e| e.to_string())
            })();
            let _ = fs::remove_file(&temporary);
            result?;
            continue;
        }
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
            .map_err(|e| format!("cannot write {}: {e}", write.path))?;
        file.write_all(&write.content)
            .map_err(|e| format!("cannot write {}: {e}", write.path))?;
        #[cfg(unix)]
        if write.executable {
            use std::os::unix::fs::PermissionsExt;
            file.set_permissions(fs::Permissions::from_mode(0o755))
                .map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}
