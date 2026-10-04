use std::collections::BTreeMap;
use std::fs;
use std::io::{self, IsTerminal, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use clap::Args;

use crate::adapter::Adapter;
use crate::artifacts::{self, Change, Surface};
use crate::{config, paths};

#[derive(Args)]
pub struct UninstallArgs {
    /// Confirm removal without prompting; required outside an interactive terminal.
    #[arg(short = 'y', long)]
    yes: bool,
}

struct Plan {
    project: PathBuf,
    tree: Option<BTreeMap<String, Vec<u8>>>,
    changes: BTreeMap<String, Change>,
}

/// Preflights the entire owned footprint, obtains confirmation, and removes adapter files before the install tree.
pub fn run(args: UninstallArgs) -> ExitCode {
    let result: Result<(), String> = (|| {
        let project = std::env::current_dir().map_err(|error| error.to_string())?;
        let plan = plan(&project)?;
        if plan.tree.is_none() && plan.changes.is_empty() {
            println!("Nothing to uninstall.");
            return Ok(());
        }
        if !args.yes && !io::stdin().is_terminal() {
            return Err("refusing to uninstall non-interactively; pass --yes to confirm".into());
        }
        println!("cumaru uninstall will remove:");
        if plan.tree.is_some() {
            println!("  .cumaru/ and all of its contents");
        }
        for change in plan.changes.values() {
            println!(
                "  {}: {}",
                if change.content.is_some() {
                    "strip owned entries"
                } else {
                    "remove"
                },
                change.path
            );
        }
        if !args.yes {
            print!("Proceed? [y/N] ");
            io::stdout().flush().map_err(|error| error.to_string())?;
            let mut answer = String::new();
            io::stdin()
                .read_line(&mut answer)
                .map_err(|error| error.to_string())?;
            if !confirmed(&answer) {
                return Err("aborted; nothing was removed".into());
            }
        }
        apply(&plan)?;
        println!("uninstalled");
        Ok(())
    })();
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("cumaru uninstall: {error}");
            ExitCode::FAILURE
        }
    }
}

/// Accepts only an explicit affirmative response at the interactive confirmation boundary.
fn confirmed(answer: &str) -> bool {
    matches!(answer.trim().to_ascii_lowercase().as_str(), "y" | "yes")
}

/// Validates a real install tree and captures every regular byte without requiring valid configuration contents.
fn tree_snapshot(project: &Path) -> Result<Option<BTreeMap<String, Vec<u8>>>, String> {
    let root = paths::project_destination(project, config::CUMARU_DIR)?;
    match fs::symlink_metadata(&root) {
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(error.to_string()),
        Ok(metadata) if !metadata.is_dir() => {
            return Err("refusing to uninstall: .cumaru must be a real directory".into());
        }
        Ok(_) => {}
    }
    for marker in ["index.md", config::CONFIG_FILE] {
        if artifacts::read(project, &format!(".cumaru/{marker}"))?.is_none() {
            return Err(
                "refusing to uninstall: expected regular index.md + config.yaml in .cumaru/".into(),
            );
        }
    }
    let mut files = BTreeMap::new();
    for path in artifacts::managed_inventory(&root, false)? {
        let bytes = artifacts::read(project, &format!(".cumaru/{path}"))?
            .ok_or_else(|| format!("install file disappeared during preflight: {path}"))?;
        files.insert(path, bytes);
    }
    Ok(Some(files))
}

/// Plans cleanup across all stateless adapters, preserving opt-ins and native content outside exact owned entries.
fn plan(project: &Path) -> Result<Plan, String> {
    let project = fs::canonicalize(project).map_err(|error| error.to_string())?;
    let tree = tree_snapshot(&project)?;
    let mut changes = BTreeMap::new();
    for adapter in [
        Adapter::None,
        Adapter::Claude,
        Adapter::Codex,
        Adapter::Opencode,
    ] {
        artifacts::clear_plan(&project, &Surface::Agent, adapter, &mut changes)?;
    }
    for change in changes.values_mut() {
        let (Some(original), Some(content)) = (&change.original, &change.content) else {
            continue;
        };
        if content == original {
            continue;
        }
        let before = std::str::from_utf8(original).map_err(|error| error.to_string())?;
        let after = std::str::from_utf8(content).map_err(|error| error.to_string())?;
        if change.path.ends_with(".md") {
            let created = before.lines().any(|line| {
                line == "<!-- BEGIN CUMARU-HOOK created -->"
                    || line == "<!-- BEGIN DOT-LLM-HOOK created -->"
            });
            if created && (after.trim().is_empty() || after.trim() == "# Project instructions") {
                change.content = None;
            }
        } else {
            let mut value: serde_json::Value =
                serde_json::from_str(after).map_err(|error| error.to_string())?;
            if change.path == "opencode.json"
                && value["instructions"].as_array().is_some_and(Vec::is_empty)
            {
                value.as_object_mut().unwrap().remove("instructions");
            }
            if value.as_object().is_some_and(|object| object.is_empty()) {
                change.content = None;
            } else if change.path == "opencode.json" {
                change.content = Some(
                    format!(
                        "{}\n",
                        serde_json::to_string_pretty(&value).map_err(|error| error.to_string())?
                    )
                    .into_bytes(),
                );
            }
        }
    }
    changes.retain(|_, change| change.original != change.content);
    Ok(Plan {
        project,
        tree,
        changes,
    })
}

/// Rechecks all planned bytes before any removal, then publishes adapter cleanup and deletes the validated tree last.
fn apply(plan: &Plan) -> Result<(), String> {
    if tree_snapshot(&plan.project)? != plan.tree {
        return Err("install tree changed after preflight; nothing was removed".into());
    }
    for change in plan.changes.values() {
        if artifacts::read(&plan.project, &change.path)? != change.original {
            return Err(format!(
                "adapter file changed after preflight: {}",
                change.path
            ));
        }
    }
    for change in plan.changes.values() {
        artifacts::publish(&plan.project, change).map_err(|error| {
            format!("{error}; adapter cleanup may be partial; .cumaru was preserved")
        })?;
    }
    if plan.tree.is_some() {
        if tree_snapshot(&plan.project)? != plan.tree {
            return Err(
                "install tree changed during adapter cleanup; .cumaru was preserved".into(),
            );
        }
        fs::remove_dir_all(paths::project_destination(
            &plan.project,
            config::CUMARU_DIR,
        )?)
        .map_err(|error| {
            format!("cannot completely remove .cumaru/: {error}; removal may be partial")
        })?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::adapter;
    use std::time::{SystemTime, UNIX_EPOCH};

    struct Fixture(PathBuf);

    impl Fixture {
        /// Creates a disposable install whose invalid config proves uninstall does not require schema validation.
        fn new() -> Self {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let project = std::env::temp_dir()
                .join(format!("cumaru-uninstall-{}-{nonce}", std::process::id()));
            fs::create_dir_all(project.join(".cumaru/.hidden")).unwrap();
            fs::write(project.join(".cumaru/index.md"), "# Cumaru").unwrap();
            fs::write(project.join(".cumaru/config.yaml"), "malformed: [").unwrap();
            fs::write(
                project.join(".cumaru/.hidden/evidence"),
                "adopter evidence removed with the whole tree",
            )
            .unwrap();
            Self(project)
        }

        /// Adds an owned resource or preserved adopter file below a native surface.
        fn write(&self, path: &str, content: &str) {
            let file = self.0.join(path);
            fs::create_dir_all(file.parent().unwrap()).unwrap();
            fs::write(file, content).unwrap();
        }

        /// Captures regular bytes and symlink targets for non-mutation assertions.
        fn snapshot(&self) -> BTreeMap<PathBuf, Vec<u8>> {
            let mut pending = vec![self.0.clone()];
            let mut files = BTreeMap::new();
            while let Some(path) = pending.pop() {
                let metadata = fs::symlink_metadata(&path).unwrap();
                if metadata.is_dir() {
                    pending.extend(
                        fs::read_dir(path)
                            .unwrap()
                            .map(|entry| entry.unwrap().path()),
                    );
                } else {
                    let bytes = if metadata.file_type().is_symlink() {
                        fs::read_link(&path)
                            .unwrap()
                            .to_string_lossy()
                            .as_bytes()
                            .to_vec()
                    } else {
                        fs::read(&path).unwrap()
                    };
                    files.insert(path.strip_prefix(&self.0).unwrap().to_path_buf(), bytes);
                }
            }
            files
        }
    }

    impl Drop for Fixture {
        /// Removes only this fixture's scratch project.
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    /// Removes every owned adapter surface while keeping unrelated hooks, skills, commands, instructions, and permissions.
    #[test]
    fn removes_all_adapters_and_preserves_adopter_state() {
        let fixture = Fixture::new();
        for target in [Adapter::None, Adapter::Claude, Adapter::Codex] {
            let path = target.instructions().unwrap();
            fixture.write(
                path,
                &adapter::markdown(target, Some("# Adopter instructions\n"), &BTreeMap::new())
                    .unwrap(),
            );
        }
        for path in [".claude/settings.json", ".codex/hooks.json"] {
            let original = r#"{"permissions":{"allow":["mine"]},"hooks":{"Other":[],"SessionStart":[{"hooks":[{"type":"command","command":"mine"}]}]}}"#;
            fixture.write(path, &adapter::hooks(Some(original)).unwrap());
        }
        fixture.write(
            "opencode.json",
            &adapter::opencode(Some(r#"{"instructions":["mine.md"],"other":true}"#)).unwrap(),
        );
        for path in [
            ".agents/skills/cumaru-test/.resources/data",
            ".claude/skills/cumaru-test/SKILL.md",
            ".agents/commands/cumaru/deep/test.md",
            ".claude/commands/cumaru/test.md",
            ".opencode/commands/cumaru/test.md",
        ] {
            fixture.write(path, "owned");
        }
        for path in [
            ".agents/skills/git/SKILL.md",
            ".claude/skills/mine/SKILL.md",
            ".agents/commands/mine.md",
            ".opencode/commands/mine.md",
        ] {
            fixture.write(path, "adopter");
        }
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(
                fixture.0.join("AGENTS.md"),
                fs::Permissions::from_mode(0o640),
            )
            .unwrap();
        }
        let before = fixture.snapshot();
        let prepared = plan(&fixture.0).unwrap();
        assert_eq!(before, fixture.snapshot());
        apply(&prepared).unwrap();
        assert!(!fixture.0.join(".cumaru").exists());
        assert!(
            !fixture
                .0
                .join(".agents/skills/cumaru-test/.resources/data")
                .exists()
        );
        assert_eq!(
            fs::read_to_string(fixture.0.join(".agents/skills/git/SKILL.md")).unwrap(),
            "adopter"
        );
        assert_eq!(
            fs::read_to_string(fixture.0.join(".claude/skills/mine/SKILL.md")).unwrap(),
            "adopter"
        );
        for path in [".agents/AGENTS.md", "AGENTS.md", "CLAUDE.md"] {
            assert_eq!(
                fs::read_to_string(fixture.0.join(path)).unwrap().trim(),
                "# Adopter instructions"
            );
        }
        for path in [".claude/settings.json", ".codex/hooks.json"] {
            let value: serde_json::Value =
                serde_json::from_slice(&fs::read(fixture.0.join(path)).unwrap()).unwrap();
            assert_eq!(value["permissions"]["allow"][0], "mine");
            assert_eq!(
                value["hooks"]["SessionStart"][0]["hooks"][0]["command"],
                "mine"
            );
            assert!(value["hooks"].get("Other").is_some());
        }
        let value: serde_json::Value =
            serde_json::from_slice(&fs::read(fixture.0.join("opencode.json")).unwrap()).unwrap();
        assert_eq!(value["instructions"], serde_json::json!(["mine.md"]));
        assert_eq!(value["other"], true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(
                fs::metadata(fixture.0.join("AGENTS.md"))
                    .unwrap()
                    .permissions()
                    .mode()
                    & 0o777,
                0o640
            );
        }
        let second = plan(&fixture.0).unwrap();
        assert!(second.tree.is_none() && second.changes.is_empty());
    }

    /// Cleans a partial install with no framework tree and deletes only proven install-created empty native files.
    #[test]
    fn cleans_partial_install_and_created_files() {
        let fixture = Fixture::new();
        fs::remove_dir_all(fixture.0.join(".cumaru")).unwrap();
        fixture.write(
            "AGENTS.md",
            &adapter::markdown(Adapter::Codex, None, &BTreeMap::new()).unwrap(),
        );
        fixture.write("CLAUDE.md", "# Project instructions\n");
        fixture.write(".codex/hooks.json", &adapter::hooks(None).unwrap());
        fixture.write("opencode.json", &adapter::opencode(None).unwrap());
        fixture.write(".agents/skills/cumaru-leftover/SKILL.md", "owned");
        apply(&plan(&fixture.0).unwrap()).unwrap();
        for path in [
            "AGENTS.md",
            ".codex/hooks.json",
            "opencode.json",
            ".agents/skills/cumaru-leftover/SKILL.md",
        ] {
            assert!(!fixture.0.join(path).exists(), "{path}");
        }
        assert_eq!(
            fs::read_to_string(fixture.0.join("CLAUDE.md")).unwrap(),
            "# Project instructions\n"
        );
        assert!(fixture.0.join(".agents/skills").is_dir());
    }

    /// Refuses malformed instructions/JSON and missing install markers before touching any owned resource.
    #[test]
    fn preflight_failures_preserve_every_file() {
        for (path, content) in [
            ("AGENTS.md", "<!-- BEGIN CUMARU-HOOK -->\nunclosed"),
            (".codex/hooks.json", "{bad"),
            ("opencode.json", r#"{"instructions":"bad"}"#),
        ] {
            let fixture = Fixture::new();
            fixture.write(".agents/skills/cumaru-old/SKILL.md", "owned");
            fixture.write(path, content);
            let before = fixture.snapshot();
            assert!(plan(&fixture.0).is_err());
            assert_eq!(fixture.snapshot(), before);
        }
        let fixture = Fixture::new();
        fs::remove_file(fixture.0.join(".cumaru/index.md")).unwrap();
        let before = fixture.snapshot();
        assert!(plan(&fixture.0).is_err());
        assert_eq!(fixture.snapshot(), before);
    }

    /// Rejects root, adapter, and nested managed symlinks without following or deleting their targets.
    #[cfg(unix)]
    #[test]
    fn rejects_symlinks_without_mutation() {
        for path in [".cumaru", ".agents", ".cumaru/link", ".cumaru/config.yaml"] {
            let fixture = Fixture::new();
            let target = fixture.0.join("outside");
            fixture.write("outside/sentinel", "preserve");
            let link = fixture.0.join(path);
            if link.is_dir() {
                fs::rename(&link, fixture.0.join("saved")).unwrap();
            } else if link.is_file() {
                fs::remove_file(&link).unwrap();
            }
            std::os::unix::fs::symlink(&target, &link).unwrap();
            let before = fixture.snapshot();
            assert!(plan(&fixture.0).is_err());
            assert_eq!(fixture.snapshot(), before);
            assert_eq!(
                fs::read_to_string(target.join("sentinel")).unwrap(),
                "preserve"
            );
        }
    }

    /// Blocks all removals after observed tree or adapter edits made while confirmation was pending.
    #[test]
    fn detects_concurrent_edits_before_removal() {
        for path in [".cumaru/new.md", "AGENTS.md"] {
            let fixture = Fixture::new();
            fixture.write(
                "AGENTS.md",
                &adapter::markdown(Adapter::Codex, None, &BTreeMap::new()).unwrap(),
            );
            fixture.write(".agents/skills/cumaru-test/SKILL.md", "owned");
            let prepared = plan(&fixture.0).unwrap();
            fixture.write(path, "concurrent");
            let before = fixture.snapshot();
            assert!(apply(&prepared).is_err());
            assert_eq!(fixture.snapshot(), before);
        }
        assert!(confirmed("y\n") && confirmed("YES\n"));
        for answer in ["", "\n", "n", "yesterday"] {
            assert!(!confirmed(answer));
        }
    }
}
