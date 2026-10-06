//! Ownership-aware remote refresh with read-only planning and conditional Git recovery.

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;
use std::process::{Command, ExitCode};

use clap::{Args, ValueEnum};

use crate::artifacts::{self, Change, Surface, add, merge_json, prune_namespace, publish, read};

use crate::{
    adapter::{self, Adapter},
    config, config_tree,
    distribution::{self, DomainSource},
    paths, tags,
    walk::Walk,
};

#[derive(Args)]
#[command(
    override_usage = "cumaru update [<path>|config|skills <agent>|commands <agent>|agent <agent>] [--apply|--clear] [--with <skill>...]"
)]
pub struct UpdateArgs {
    /// Optional content scope or named mode followed by an explicit adapter.
    #[arg(num_args = 0..=2)]
    target: Vec<String>,
    /// Publishes the displayed refresh; preview is the default.
    #[arg(long, conflicts_with = "clear")]
    apply: bool,
    /// Immediately removes the selected owned adapter surface, without remote access.
    #[arg(long, conflicts_with = "with")]
    clear: bool,
    /// Adds or refreshes only these top-level opt-in skills; repeatable in skills mode.
    #[arg(long = "with")]
    with: Vec<String>,
}

#[derive(Debug, PartialEq)]
enum Mode {
    Content(String),
    Config,
    Skills,
    Commands,
    Agent,
}

/// Validates modes, explicit adapters, and opt-in names before any source or filesystem operation.
fn arguments(args: &UpdateArgs) -> Result<(Mode, Option<Adapter>), String> {
    let (mode, name) = match args.target.as_slice() {
        [] => (Mode::Content(".".into()), None),
        [mode] if mode == "config" => (Mode::Config, None),
        [mode] if ["skills", "commands", "agent"].contains(&mode.as_str()) => (
            match mode.as_str() {
                "skills" => Mode::Skills,
                "commands" => Mode::Commands,
                _ => Mode::Agent,
            },
            None,
        ),
        [mode, name] if ["skills", "commands", "agent"].contains(&mode.as_str()) => (
            match mode.as_str() {
                "skills" => Mode::Skills,
                "commands" => Mode::Commands,
                _ => Mode::Agent,
            },
            Some(name),
        ),
        [path] => {
            paths::validate_target_syntax(path)?;
            (Mode::Content(paths::normalize_target(Some(path))), None)
        }
        _ => return Err("expected one content path or a named mode and adapter".into()),
    };
    let adapter = name
        .map(|name| {
            Adapter::from_str(name, false).map_err(|_| {
                "unknown adapter: expected none, claude, codex, or opencode".to_string()
            })
        })
        .transpose()?;
    if matches!(mode, Mode::Content(_) | Mode::Config) && args.clear {
        return Err("--clear requires skills, commands, or agent mode".into());
    }
    if mode == Mode::Config && args.apply {
        return Err(
            "config reconciliation is read-only; edit the reported candidate deliberately".into(),
        );
    }
    if !matches!(mode, Mode::Content(_) | Mode::Config) && !args.clear && adapter.is_none() {
        return Err("refresh requires an explicit adapter".into());
    }
    if !args.with.is_empty() && mode != Mode::Skills {
        return Err("--with is supported only in skills mode".into());
    }
    for skill in &args.with {
        if skill.starts_with("cumaru-")
            || skill.is_empty()
            || !skill
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
        {
            return Err(format!("invalid opt-in skill name: {skill}"));
        }
    }
    Ok((mode, adapter))
}

/// Executes native refresh, preserving classified usage failures and runtime diagnostics.
pub fn run(args: UpdateArgs) -> ExitCode {
    let (mode, adapter) = match arguments(&args) {
        Ok(value) => value,
        Err(error) => {
            eprintln!("cumaru update: {error}");
            return ExitCode::from(2);
        }
    };
    match execute(&args, mode, adapter) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("cumaru update: {error}");
            ExitCode::from(1)
        }
    }
}

/// Resolves all expected bytes before preview or direct publication and runs native postchecks.
fn execute(args: &UpdateArgs, mode: Mode, adapter: Option<Adapter>) -> Result<(), String> {
    let project = fs::canonicalize(std::env::current_dir().map_err(|e| e.to_string())?)
        .map_err(|e| e.to_string())?;
    let root = paths::project_destination(&project, ".cumaru")?;
    if !root.is_dir() {
        return Err("missing regular .cumaru/ installation".into());
    }
    let config_path = paths::project_destination(&project, ".cumaru/config.yaml")?;
    if !config_path.is_file() {
        return Err("missing regular .cumaru/config.yaml".into());
    }
    let original_config = fs::read_to_string(&config_path).map_err(|e| e.to_string())?;
    let index = paths::project_destination(&project, ".cumaru/index.md")?;
    if !index.is_file() {
        return Err("missing regular .cumaru/index.md".into());
    }
    let local = if mode == Mode::Config {
        let mut docs =
            yaml_rust2::YamlLoader::load_from_str(&original_config).map_err(|e| e.to_string())?;
        if docs.len() != 1 {
            return Err("config must contain exactly one YAML document".into());
        }
        docs.remove(0)
    } else {
        config::load(&root)?
    };
    if local["version"].as_i64() != Some(9) {
        return Err("native update requires config version 9; use cumaru migrate".into());
    }
    let domain = local["domain"]
        .as_str()
        .ok_or("config domain must be a string")?;
    if domain.is_empty()
        || !domain
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-' || b == b'_')
    {
        return Err("unsafe installed domain".into());
    }
    let domain = if domain == "base" { "__base" } else { domain };
    let mut changes = BTreeMap::new();
    if args.clear {
        for target in adapter.map(|a| vec![a]).unwrap_or_else(|| {
            vec![
                Adapter::None,
                Adapter::Claude,
                Adapter::Codex,
                Adapter::Opencode,
            ]
        }) {
            clear_plan(&project, &mode, target, &mut changes)?;
        }
    } else {
        let source = distribution::domain_source(domain)?;
        let bytes = source.read("config.yaml")?;
        let canonical = config::parse(std::str::from_utf8(&bytes).map_err(|e| e.to_string())?)?;
        if canonical["domain"] != local["domain"] {
            return Err("main domain differs from installed domain".into());
        }
        if canonical["version"] != local["version"] {
            return Err("main config version differs; use cumaru migrate".into());
        }
        config_tree::install_files(&canonical, &source.files.keys().cloned().collect())?;
        println!("source: main ({})", source.revision);
        match &mode {
            Mode::Config => {
                let (candidate, removed) = config::reconcile(&original_config, &canonical)?;
                for pointer in removed {
                    println!("removed: {pointer} (property is not allowed by the global model)");
                }
                println!(
                    "schema: embedded schemas/config.schema.json\ndefaults: domains/{domain}/config.yaml\n--- current config.yaml\n{original_config}\n+++ complete candidate (JSON is valid YAML)\n{candidate}"
                );
                return Ok(());
            }
            Mode::Content(scope) => {
                config_tree::tag_contracts(&root, &local)?;
                let local_files = inventory(&root)?;
                let source_files = source.files.keys().cloned().collect();
                let pairs =
                    config_tree::update_pairs(&local, &canonical, &local_files, &source_files)?;
                let mut matched = false;
                for (host, origin) in pairs {
                    if scope != "." && host != *scope && !host.starts_with(&format!("{scope}/")) {
                        continue;
                    }
                    matched = true;
                    let path = format!(".cumaru/{host}");
                    let before = read(&project, &path)?
                        .ok_or_else(|| format!("missing update target: {host}"))?;
                    let source_bytes = source.read(&origin)?;
                    let expected = tags::merge(
                        std::str::from_utf8(&source_bytes).map_err(|e| e.to_string())?,
                        std::str::from_utf8(&before).map_err(|e| e.to_string())?,
                    )?;
                    add(
                        &project,
                        &mut changes,
                        path,
                        Some(expected.into_bytes()),
                        false,
                    )?;
                    if host != origin && local_files.contains(&origin) {
                        eprintln!(
                            "review: former canonical path remains unchanged: .cumaru/{origin}"
                        );
                    }
                }
                if !matched && scope != "." {
                    return Err(
                        "scope does not select an explicitly framework-owned source/local entry"
                            .into(),
                    );
                }
                if root.join("archive").exists() {
                    eprintln!("review: deprecated .cumaru/archive remains unchanged");
                }
            }
            _ => artifact_plan(
                &project,
                &root,
                &source,
                &mode,
                adapter.unwrap(),
                &args.with,
                &mut changes,
            )?,
        }
    }
    changes.retain(|_, change| change.content != change.original);
    for change in changes.values() {
        println!(
            "{}: {}",
            if change.content.is_none() {
                "remove"
            } else if change.original.is_none() {
                "add"
            } else {
                "replace"
            },
            change.path
        );
        if matches!(mode, Mode::Content(_)) {
            println!(
                "--- current: {}\n{}\n+++ expected: {}\n{}",
                change.path,
                String::from_utf8_lossy(change.original.as_deref().unwrap_or_default()),
                change.path,
                String::from_utf8_lossy(change.content.as_deref().unwrap_or_default())
            );
        }
    }
    if !args.apply && !args.clear {
        println!(
            "preview: {} change(s); use --apply to publish",
            changes.len()
        );
        return Ok(());
    }
    if changes.is_empty() {
        println!("up to date");
        return Ok(());
    }
    recovery(&project)?;
    if fs::read_to_string(config_path).map_err(|e| e.to_string())? != original_config {
        return Err("config changed while planning".into());
    }
    for change in changes.values() {
        if read(&project, &change.path)? != change.original {
            return Err(format!("file changed while planning: {}", change.path));
        }
    }
    for change in changes.values() {
        publish(&project, change)?;
    }
    let report = super::doctor::inspect(&root)?;
    print!("{}", report.render(true));
    if report.failed() {
        return Err("doctor postcheck failed; published changes remain for review/recovery".into());
    }
    println!("updated: {} change(s); doctor checks passed", changes.len());
    Ok(())
}

/// Inventories safe visible regular files and rejects incomplete traversal before planning.
fn inventory(root: &Path) -> Result<BTreeSet<String>, String> {
    let mut files = BTreeSet::new();
    let diagnostics = Walk { root, deep: true }.run(
        &[root.to_path_buf()],
        |_| true,
        |entry| {
            if !entry.is_dir {
                files.insert(
                    entry
                        .path
                        .strip_prefix(root)
                        .unwrap()
                        .to_string_lossy()
                        .into_owned(),
                );
            }
            Ok(())
        },
    )?;
    if let Some(issue) = diagnostics.first() {
        return Err(format!("{}: {}", issue.path.display(), issue.message));
    }
    Ok(files)
}

/// Plans complete framework skill or command replacement, pruning only the selected owned namespace.
fn artifact_plan(
    project: &Path,
    root: &Path,
    source: &DomainSource,
    mode: &Mode,
    target: Adapter,
    optins: &[String],
    changes: &mut BTreeMap<String, Change>,
) -> Result<(), String> {
    if matches!(mode, Mode::Skills | Mode::Agent) {
        let skill_dir = target.skills();
        let mut expected = BTreeSet::new();
        if optins.is_empty() {
            for (origin, mode) in source
                .files
                .iter()
                .filter(|(path, _)| path.starts_with("skills/cumaru-"))
            {
                let relative = origin.strip_prefix("skills/").unwrap();
                let name = relative.split('/').next().unwrap();
                if !source
                    .files
                    .contains_key(&format!("skills/{name}/SKILL.md"))
                {
                    return Err(format!("source skill has no SKILL.md: {name}"));
                }
                let path = format!("{skill_dir}/{relative}");
                expected.insert(path.clone());
                add(
                    project,
                    changes,
                    path,
                    Some(source.read(origin)?),
                    mode == "100755",
                )?;
            }
            prune_namespace(project, skill_dir, true, &expected, changes)?;
        } else {
            for name in optins.iter().collect::<BTreeSet<_>>() {
                let prefix = format!("skills/{name}/");
                if !source
                    .repository_files
                    .contains_key(&format!("{prefix}SKILL.md"))
                {
                    return Err(format!("main has no opt-in skill: {name}"));
                }
                for (origin, mode) in source
                    .repository_files
                    .iter()
                    .filter(|(path, _)| path.starts_with(&prefix))
                {
                    let path = format!("{skill_dir}/{name}/{}", &origin[prefix.len()..]);
                    expected.insert(path.clone());
                    add(
                        project,
                        changes,
                        path,
                        Some(source.read_repository(origin)?),
                        mode == "100755",
                    )?;
                }
                prune_namespace(
                    project,
                    &format!("{skill_dir}/{name}"),
                    false,
                    &expected,
                    changes,
                )?;
            }
        }
    }
    if matches!(mode, Mode::Commands | Mode::Agent) {
        if let Some(commands) = target.commands() {
            let namespace = format!("{commands}/cumaru");
            let mut expected = BTreeSet::new();
            for (origin, mode) in source
                .files
                .iter()
                .filter(|(path, _)| path.starts_with("commands/cumaru/") && path.ends_with(".md"))
            {
                let relative = origin.strip_prefix("commands/cumaru/").unwrap();
                let skill = Path::new(relative)
                    .file_stem()
                    .and_then(|name| name.to_str())
                    .ok_or("invalid command name")?;
                if !source
                    .files
                    .contains_key(&format!("skills/cumaru-{skill}/SKILL.md"))
                {
                    return Err(format!("command has no namesake skill: {relative}"));
                }
                let path = format!("{namespace}/{relative}");
                expected.insert(path.clone());
                add(
                    project,
                    changes,
                    path,
                    Some(source.read(origin)?),
                    mode == "100755",
                )?;
            }
            prune_namespace(project, &namespace, false, &expected, changes)?;
        } else if *mode == Mode::Commands {
            return Err("this adapter uses skills directly and has no separate commands".into());
        }
    }
    if *mode == Mode::Agent {
        let mut files = BTreeMap::new();
        for host in inventory(root)?
            .into_iter()
            .filter(|path| path.starts_with("disciplines/") && path.ends_with(".md"))
        {
            files.insert(
                host.clone(),
                fs::read(root.join(host)).map_err(|e| e.to_string())?,
            );
        }
        if !files.contains_key("disciplines/index.md") {
            return Err("missing installed discipline index".into());
        }
        if let Some(path) = target.instructions() {
            let before = read(project, path)?;
            let existing = before
                .as_deref()
                .map(std::str::from_utf8)
                .transpose()
                .map_err(|e| e.to_string())?;
            add(
                project,
                changes,
                path.into(),
                Some(adapter::markdown(target, existing, &files)?.into_bytes()),
                false,
            )?;
        } else {
            merge_json(project, "opencode.json", "opencode", false, changes)?;
        }
        if let Some(path) = target.hooks() {
            merge_json(project, path, "hooks", false, changes)?;
        }
    }
    Ok(())
}

/// Requires a clean committed tracked Cumaru baseline inside Git, otherwise reports absent recovery.
fn recovery(project: &Path) -> Result<(), String> {
    let probe = Command::new("git")
        .current_dir(project)
        .args(["rev-parse", "--is-inside-work-tree"])
        .output();
    let probe = match probe {
        Ok(probe) => probe,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            eprintln!("warning: Git unavailable; proceeding without a Git recovery point");
            return Ok(());
        }
        Err(e) => return Err(e.to_string()),
    };
    if !probe.status.success() {
        eprintln!("warning: non-Git project; proceeding without a Git recovery point");
        return Ok(());
    }
    if probe.stdout != b"true\n" {
        return Err("project is not a Git work tree".into());
    }
    let status = Command::new("git")
        .current_dir(project)
        .args(["status", "--porcelain", "--untracked-files=all"])
        .output()
        .map_err(|e| e.to_string())?;
    if !status.status.success() || !status.stdout.is_empty() {
        return Err("Git work tree must be clean before update mutation".into());
    }
    for args in [
        vec!["rev-parse", "--verify", "HEAD"],
        vec![
            "ls-files",
            "--error-unmatch",
            ".cumaru/config.yaml",
            ".cumaru/index.md",
        ],
    ] {
        if !Command::new("git")
            .current_dir(project)
            .args(args)
            .output()
            .map_err(|e| e.to_string())?
            .status
            .success()
        {
            return Err("update requires a committed tracked Cumaru baseline".into());
        }
    }
    Ok(())
}

/// Maps the selected update mode to the shared owned-artifact cleanup planner.
fn clear_plan(
    project: &Path,
    mode: &Mode,
    target: Adapter,
    changes: &mut BTreeMap<String, Change>,
) -> Result<(), String> {
    let surface = match mode {
        Mode::Skills => Surface::Skills,
        Mode::Commands => Surface::Commands,
        Mode::Agent => Surface::Agent,
        _ => return Err("clear requires an artifact mode".into()),
    };
    artifacts::clear_plan(project, &surface, target, changes)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Protects mode boundaries and explicit adapter/opt-in ownership before any I/O.
    #[test]
    fn validates_modes_and_targets() {
        let mut args = UpdateArgs {
            target: vec![],
            apply: false,
            clear: false,
            with: vec![],
        };
        assert_eq!(arguments(&args).unwrap(), (Mode::Content(".".into()), None));
        args.target = vec!["skills".into()];
        assert!(arguments(&args).is_err());
        args.clear = true;
        assert_eq!(arguments(&args).unwrap(), (Mode::Skills, None));
        args.clear = false;
        args.target.push("codex".into());
        args.with.push("git".into());
        assert_eq!(
            arguments(&args).unwrap(),
            (Mode::Skills, Some(Adapter::Codex))
        );
        args.with[0] = "../outside".into();
        assert!(arguments(&args).is_err());
        args.with.clear();
        args.target = vec!["config".into()];
        args.apply = true;
        assert!(arguments(&args).is_err());
    }

    /// Rejects detected edits before publication and clears only owned skill files, including resources.
    #[test]
    fn preserves_adopter_files_and_concurrent_changes() {
        let nonce = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let project =
            std::env::temp_dir().join(format!("cumaru-update-{}-{nonce}", std::process::id()));
        fs::create_dir_all(project.join(".agents/skills/cumaru-old/.resources")).unwrap();
        fs::create_dir_all(project.join(".agents/skills/mine")).unwrap();
        fs::write(
            project.join(".agents/skills/cumaru-old/SKILL.md"),
            "original",
        )
        .unwrap();
        fs::write(
            project.join(".agents/skills/cumaru-old/.resources/data"),
            "resource",
        )
        .unwrap();
        fs::write(project.join(".agents/skills/mine/SKILL.md"), "mine").unwrap();
        let mut changes = BTreeMap::new();
        clear_plan(&project, &Mode::Skills, Adapter::Codex, &mut changes).unwrap();
        assert_eq!(changes.len(), 2);
        fs::write(
            project.join(".agents/skills/cumaru-old/SKILL.md"),
            "concurrent",
        )
        .unwrap();
        assert!(publish(&project, &changes[".agents/skills/cumaru-old/SKILL.md"]).is_err());
        assert_eq!(
            fs::read_to_string(project.join(".agents/skills/cumaru-old/SKILL.md")).unwrap(),
            "concurrent"
        );
        assert_eq!(
            fs::read_to_string(project.join(".agents/skills/mine/SKILL.md")).unwrap(),
            "mine"
        );
        fs::remove_dir_all(project).unwrap();
    }
}
