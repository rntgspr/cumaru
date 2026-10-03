//! CLI coordination for semantic tag audits, extraction, and opaque body replacement.

use std::collections::BTreeSet;
use std::fs::{self, OpenOptions};
use std::io::{self, IsTerminal, Read, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::sync::atomic::{AtomicU64, Ordering};

use clap::Args;

use crate::walk::Walk;
use crate::{config, config_tree, paths, tags};

#[derive(Args)]
#[command(
    override_usage = "cumaru tag [<file>] [get|set <tag> [<content>]]\n       cumaru tag get|set [<file>] <tag> [<content>]\n       cumaru tag all [--body]"
)]
pub struct TagArgs {
    /// File, operation, tag name, and optional replacement content.
    #[arg(allow_hyphen_values = true)]
    arguments: Vec<String>,
}

enum Operation {
    All(&'static str),
    Audit(String),
    Get(String, String),
    Set(String, String, Option<String>),
}

/// Parses both supported positional orders without interpreting replacement text as options.
fn operation(arguments: &[String]) -> Result<Operation, String> {
    if arguments.is_empty() {
        return Ok(Operation::Audit("index.md".into()));
    }
    if arguments[0] == "all" {
        return match &arguments[1..] {
            [] => Ok(Operation::All("list")),
            [mode] if mode == "--body" => Ok(Operation::All("body")),
            _ => Err("usage: tag all [--body]".into()),
        };
    }
    let (file, verb, rest) = if arguments[0] == "get" || arguments[0] == "set" {
        if arguments.get(1).is_some_and(|s| s.ends_with(".md")) {
            (arguments[1].clone(), arguments[0].as_str(), &arguments[2..])
        } else {
            ("index.md".into(), arguments[0].as_str(), &arguments[1..])
        }
    } else {
        if !arguments[0].ends_with(".md") {
            return Err("file paths must end in .md".into());
        }
        if arguments.len() == 1 {
            return Ok(Operation::Audit(arguments[0].clone()));
        }
        (arguments[0].clone(), arguments[1].as_str(), &arguments[2..])
    };
    let name = rest
        .first()
        .ok_or("missing tag name")?
        .strip_prefix("cumaru:")
        .unwrap_or(&rest[0])
        .to_string();
    if !tags::valid_name(&name) {
        return Err(format!("invalid tag name: {name}"));
    }
    match (verb, rest.len()) {
        ("get", 1) => Ok(Operation::Get(file, name)),
        ("set", 1 | 2) => Ok(Operation::Set(file, name, rest.get(1).cloned())),
        _ => Err("usage: tag [<file>] get|set <tag> [<content>]".into()),
    }
}

/// Executes one operation and classifies usage separately from runtime failures.
pub fn run(args: TagArgs) -> ExitCode {
    if args.arguments.first().is_some_and(|s| s == "help")
        || (args.arguments.len() == 2
            && args.arguments[0] == "all"
            && ["help", "-h", "--help"].contains(&args.arguments[1].as_str()))
    {
        println!(
            "Usage: cumaru tag [<file>] [get|set <tag> [<content>]]\n       cumaru tag get|set [<file>] <tag> [<content>]\n       cumaru tag all [--body]"
        );
        return ExitCode::SUCCESS;
    }
    let operation = match operation(&args.arguments) {
        Ok(operation) => operation,
        Err(error) => {
            eprintln!("cumaru tag: {error}");
            return ExitCode::from(2);
        }
    };
    if matches!(&operation, Operation::Set(_, _, None)) && io::stdin().is_terminal() {
        eprintln!("cumaru tag: no content: pass an argument or pipe stdin");
        return ExitCode::from(2);
    }
    match execute(operation) {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(error) => {
            eprintln!("cumaru tag: {error}");
            ExitCode::FAILURE
        }
    }
}

/// Resolves a Markdown host, accepting contained absolute paths and rejecting every symlink component.
fn host_path(root: &Path, file: &str) -> Result<PathBuf, String> {
    if !file.ends_with(".md") || crate::text::has_control(file) {
        return Err("unsafe Markdown file path".into());
    }
    let path = Path::new(file);
    if path
        .components()
        .any(|c| matches!(c, std::path::Component::ParentDir))
    {
        return Err("parent path segments are not allowed".into());
    }
    let candidate = if path.is_absolute() {
        let lexical_root = path
            .ancestors()
            .find(|ancestor| fs::canonicalize(ancestor).is_ok_and(|canonical| canonical == root));
        let lexical_root = lexical_root.ok_or("absolute file path is outside .cumaru/")?;
        root.join(path.strip_prefix(lexical_root).map_err(|e| e.to_string())?)
    } else if path.starts_with(config::CUMARU_DIR) {
        std::env::current_dir()
            .map_err(|e| e.to_string())?
            .join(path)
    } else {
        root.join(path)
    };
    if paths::has_symlink_component(root, &candidate) {
        return Err(format!(
            "file contains a symlink or is outside .cumaru/: {file}"
        ));
    }
    let path = paths::canonical_inside(root, &candidate)
        .ok_or_else(|| format!("file not found or outside .cumaru/: {file}"))?;
    if !path.is_file() {
        return Err(format!("not a regular Markdown file: {file}"));
    }
    Ok(path)
}

/// Audits or edits one validated host, or walks the complete tree without requiring config for all modes.
fn execute(operation: Operation) -> Result<bool, String> {
    let root = Path::new(config::CUMARU_DIR);
    if paths::is_symlink(root) || !root.is_dir() {
        return Err(".cumaru/ must be a real directory".into());
    }
    let root = fs::canonicalize(root).map_err(|e| e.to_string())?;
    if let Operation::All(mode) = operation {
        return all(&root, mode);
    }
    let file = match &operation {
        Operation::Audit(file) | Operation::Get(file, _) | Operation::Set(file, _, _) => file,
        _ => unreachable!(),
    };
    let path = host_path(&root, file)?;
    let rel = path
        .strip_prefix(&root)
        .unwrap()
        .to_string_lossy()
        .into_owned();
    let text = fs::read_to_string(&path).map_err(|e| format!("{rel}: {e}"))?;
    let blocks = tags::parse(&text).map_err(|e| format!("{rel}: {e}"))?;
    let reference = matches!(&operation, Operation::Get(_, name) | Operation::Set(_, name, _) if name == "reference");
    let (expected, allowed) = if reference {
        (BTreeSet::new(), BTreeSet::from(["reference".into()]))
    } else {
        let config = config::load(&root)?;
        if config["version"].as_i64() == Some(9) {
            let contracts = config_tree::tag_contracts(&root, &config)?;
            let expected = contracts.get(&rel).cloned().unwrap_or_default();
            (expected.clone(), expected)
        } else {
            config_tree::legacy_tags(&config, &rel)
        }
    };

    match operation {
        Operation::Audit(_) => {
            let actual: BTreeSet<_> = blocks.iter().map(|block| block.name.clone()).collect();
            println!("File: {rel}\n\nSchema declares:");
            for name in &expected {
                println!("  {name}");
            }
            println!("\nFile contains:");
            for name in &actual {
                println!("  {name}");
            }
            let missing: Vec<_> = expected.difference(&actual).collect();
            let extra: Vec<_> = actual.difference(&allowed).collect();
            for name in &missing {
                println!("  [+] {name}: declared in config, absent in file");
            }
            for name in &extra {
                println!("  [!] {name}: present in file, not declared in config");
            }
            if missing.is_empty() && extra.is_empty() {
                println!("\naligned: every expected tag is present, no extras");
            }
            Ok(missing.is_empty() && extra.is_empty())
        }
        Operation::Get(_, name) => {
            if !allowed.contains(&name) {
                return Err(format!("tag '{name}' is not declared for {rel}"));
            }
            let body = tags::extract(&text, &blocks, &name)
                .ok_or_else(|| format!("block '{name}' not found in {rel}"))?;
            if body.trim().is_empty() {
                eprintln!("cumaru tag get: block '{name}' is present but empty in {rel}");
            }
            print!("{body}");
            Ok(true)
        }
        Operation::Set(_, name, content) => {
            if !allowed.contains(&name) {
                return Err(format!("tag '{name}' is not declared for {rel}"));
            }
            let content = if let Some(content) = content {
                content
            } else {
                if io::stdin().is_terminal() {
                    return Err("no content: pass an argument or pipe stdin".into());
                }
                let mut content = String::new();
                io::stdin()
                    .read_to_string(&mut content)
                    .map_err(|e| e.to_string())?;
                content
            };
            let output = tags::replace(&text, &name, &content)?;
            publish(&root, &path, &text, &output)?;
            Ok(true)
        }
        _ => unreachable!(),
    }
}

/// Stages beside the host and preserves its permissions; refuses detected concurrent edits before rename.
fn publish(root: &Path, path: &Path, original: &str, output: &str) -> Result<(), String> {
    static NEXT: AtomicU64 = AtomicU64::new(0);
    let temporary = path.with_file_name(format!(
        ".cumaru-tag-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    let mut created = false;
    let result = (|| {
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&temporary)
            .map_err(|e| e.to_string())?;
        created = true;
        file.set_permissions(fs::metadata(path).map_err(|e| e.to_string())?.permissions())
            .map_err(|e| e.to_string())?;
        file.write_all(output.as_bytes())
            .map_err(|e| e.to_string())?;
        file.sync_all().map_err(|e| e.to_string())?;
        if paths::has_symlink_component(root, path)
            || fs::read_to_string(path).map_err(|e| e.to_string())? != original
        {
            return Err("host changed during replacement; refusing to overwrite".into());
        }
        fs::rename(&temporary, path).map_err(|e| e.to_string())
    })();
    if created {
        let _ = fs::remove_file(&temporary);
    }
    result
}

/// Emits sorted tag inventories or opaque bodies while reporting malformed hosts and traversal defects.
fn all(root: &Path, mode: &str) -> Result<bool, String> {
    let mut files = Vec::new();
    let defects = Walk { root, deep: true }.run(
        &[root.to_path_buf()],
        |path| path.extension().is_some_and(|e| e == "md"),
        |entry| {
            if !entry.is_dir {
                files.push(entry.path.to_path_buf());
            }
            Ok(())
        },
    )?;
    files.sort();
    let mut errors = Vec::new();
    for path in files {
        let rel = path
            .strip_prefix(root)
            .unwrap()
            .to_string_lossy()
            .into_owned();
        let text = match fs::read_to_string(&path) {
            Ok(text) => text,
            Err(e) => {
                errors.push(format!("{rel}: {e}"));
                continue;
            }
        };
        let blocks = match tags::parse(&text) {
            Ok(blocks) => blocks,
            Err(e) => {
                errors.push(format!("{rel}: {e}"));
                continue;
            }
        };
        let names: BTreeSet<_> = blocks.iter().map(|b| b.name.as_str()).collect();
        if mode == "body" {
            for name in names {
                println!("File: {rel}\nTag: {name}\n\n<!-- cumaru:{name} -->");
                print!("{}", tags::extract(&text, &blocks, name).unwrap());
                println!("<!-- /cumaru:{name} -->\n");
            }
        } else if !names.is_empty() {
            println!("File: {rel}");
            for name in names {
                println!("  {name}");
            }
            println!();
        }
    }
    errors.extend(defects.into_iter().map(|d| {
        format!(
            "{}: {}",
            d.path.strip_prefix(root).unwrap_or(&d.path).display(),
            d.message
        )
    }));
    errors.sort();
    errors.dedup();
    for error in &errors {
        eprintln!("cumaru tag: {error}");
    }
    Ok(errors.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Covers both positional orders and rejects ambiguous or surplus operands.
    #[test]
    fn parses_operations() {
        for args in [
            vec!["get", "a.md", "cumaru:notes"],
            vec!["a.md", "get", "notes"],
        ] {
            assert!(
                matches!(operation(&args.into_iter().map(String::from).collect::<Vec<_>>()), Ok(Operation::Get(file, name)) if file == "a.md" && name == "notes")
            );
        }
        for args in [
            vec!["get"],
            vec!["get", "bad.txt"],
            vec!["all", "--rows"],
            vec!["get", "notes", "extra"],
        ] {
            assert!(operation(&args.into_iter().map(String::from).collect::<Vec<_>>()).is_err());
        }
    }

    /// Preserves host bytes on concurrent edits and preserves permissions on successful publication.
    #[test]
    fn publishes_without_clobbering_changes() {
        let nonce = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root =
            std::env::temp_dir().join(format!("cumaru-tag-publish-{}-{nonce}", std::process::id()));
        fs::create_dir(&root).unwrap();
        let path = root.join("index.md");
        fs::write(&path, "original").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&path, fs::Permissions::from_mode(0o640)).unwrap();
        }
        assert!(publish(&root, &path, "stale", "replacement").is_err());
        assert_eq!(fs::read_to_string(&path).unwrap(), "original");
        assert_eq!(fs::read_dir(&root).unwrap().count(), 1);
        publish(&root, &path, "original", "replacement").unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), "replacement");
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(
                fs::metadata(&path).unwrap().permissions().mode() & 0o777,
                0o640
            );
        }
        fs::remove_dir_all(root).unwrap();
    }
}
