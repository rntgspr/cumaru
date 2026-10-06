use std::collections::{BTreeMap, BTreeSet};
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::Path;

use crate::{
    adapter::{self, Adapter},
    paths,
};

#[derive(PartialEq)]
pub(crate) enum Surface {
    Skills,
    Commands,
    Agent,
}

pub(crate) struct Change {
    pub(crate) path: String,
    pub(crate) original: Option<Vec<u8>>,
    pub(crate) content: Option<Vec<u8>>,
    pub(crate) executable: bool,
}

/// Reads a safe regular managed file without following symlinks or accepting special files.
pub(crate) fn read(project: &Path, rel: &str) -> Result<Option<Vec<u8>>, String> {
    let path = paths::project_destination(project, rel)?;
    match fs::symlink_metadata(&path) {
        Ok(meta) if meta.is_file() => fs::read(path).map(Some).map_err(|e| e.to_string()),
        Ok(_) => Err(format!("managed target is not a regular file: {rel}")),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(e.to_string()),
    }
}

/// Captures original bytes once and refuses overlapping publication ownership.
pub(crate) fn add(
    project: &Path,
    changes: &mut BTreeMap<String, Change>,
    path: String,
    content: Option<Vec<u8>>,
    executable: bool,
) -> Result<(), String> {
    let original = read(project, &path)?;
    if let Some(previous) = changes.get(&path) {
        if previous.content != content {
            return Err(format!("conflicting planned changes: {path}"));
        }
        return Ok(());
    }
    changes.insert(
        path.clone(),
        Change {
            path,
            original,
            content,
            executable,
        },
    );
    Ok(())
}

/// Enumerates owned files under a namespace and schedules removals without deleting adopter parents.
pub(crate) fn prune_namespace(
    project: &Path,
    namespace: &str,
    skills: bool,
    expected: &BTreeSet<String>,
    changes: &mut BTreeMap<String, Change>,
) -> Result<(), String> {
    let path = paths::project_destination(project, namespace)?;
    if !path.exists() {
        return Ok(());
    }
    if !path.is_dir() {
        return Err(format!("managed namespace is not a directory: {namespace}"));
    }
    for host in managed_inventory(&path, skills)? {
        let rel = format!("{namespace}/{host}");
        if !expected.contains(&rel) {
            add(project, changes, rel, None, false)?;
        }
    }
    Ok(())
}

/// Inventories a complete owned artifact tree, including hidden resources, without following links.
pub(crate) fn managed_inventory(root: &Path, skills: bool) -> Result<BTreeSet<String>, String> {
    let mut files = BTreeSet::new();
    let mut pending = vec![root.to_path_buf()];
    while let Some(directory) = pending.pop() {
        for entry in fs::read_dir(&directory).map_err(|e| e.to_string())? {
            let entry = entry.map_err(|e| e.to_string())?;
            if skills
                && directory == root
                && !entry.file_name().to_string_lossy().starts_with("cumaru-")
            {
                continue;
            }
            let path = entry.path();
            let relative = path
                .strip_prefix(root)
                .unwrap()
                .to_string_lossy()
                .into_owned();
            let kind = entry.file_type().map_err(|e| e.to_string())?;
            if crate::text::has_control(&relative) || kind.is_symlink() {
                return Err(format!("unsafe managed artifact: {}", path.display()));
            }
            if kind.is_dir() {
                pending.push(path);
            } else if kind.is_file() {
                files.insert(relative);
            } else {
                return Err(format!("unsupported managed artifact: {}", path.display()));
            }
        }
    }
    Ok(files)
}

/// Plans exact managed JSON merges or removals while preserving unrelated native keys and entries.
pub(crate) fn merge_json(
    project: &Path,
    path: &str,
    kind: &str,
    clear: bool,
    changes: &mut BTreeMap<String, Change>,
) -> Result<(), String> {
    let before = read(project, path)?;
    if clear && before.is_none() {
        return Ok(());
    }
    let existing = before
        .as_deref()
        .map(std::str::from_utf8)
        .transpose()
        .map_err(|e| e.to_string())?;
    let output = if clear {
        adapter::clear(existing.unwrap(), kind)?
    } else if kind == "opencode" {
        adapter::opencode(existing)?
    } else {
        adapter::hooks(existing)?
    };
    add(
        project,
        changes,
        path.into(),
        Some(output.into_bytes()),
        false,
    )
}

/// Clears one adapter footprint or selected artifact surface without resolving a remote release.
pub(crate) fn clear_plan(
    project: &Path,
    mode: &Surface,
    target: Adapter,
    changes: &mut BTreeMap<String, Change>,
) -> Result<(), String> {
    if matches!(mode, Surface::Skills | Surface::Agent) {
        prune_namespace(project, target.skills(), true, &BTreeSet::new(), changes)?;
    }
    if matches!(mode, Surface::Commands | Surface::Agent)
        && let Some(commands) = target.commands().or(if target == Adapter::Claude {
            Some(".claude/commands")
        } else {
            None
        })
    {
        prune_namespace(
            project,
            &format!("{commands}/cumaru"),
            false,
            &BTreeSet::new(),
            changes,
        )?;
    }
    if *mode == Surface::Agent {
        if let Some(path) = target.instructions() {
            if let Some(before) = read(project, path)? {
                add(
                    project,
                    changes,
                    path.into(),
                    Some(
                        adapter::clear(
                            std::str::from_utf8(&before).map_err(|e| e.to_string())?,
                            "markdown",
                        )?
                        .into_bytes(),
                    ),
                    false,
                )?;
            }
        } else {
            merge_json(project, "opencode.json", "opencode", true, changes)?;
        }
        if let Some(path) = target.hooks() {
            merge_json(project, path, "hooks", true, changes)?;
        }
    }
    Ok(())
}

/// Writes or removes one preflighted file directly, preserving existing permissions and detecting edits.
pub(crate) fn publish(project: &Path, change: &Change) -> Result<(), String> {
    if read(project, &change.path)? != change.original {
        return Err(format!("file changed before publication: {}", change.path));
    }
    let path = paths::project_destination(project, &change.path)?;
    if let Some(content) = &change.content {
        fs::create_dir_all(path.parent().unwrap()).map_err(|e| e.to_string())?;
        let mut options = OpenOptions::new();
        options.write(true);
        if change.original.is_some() {
            options.truncate(true);
        } else {
            options.create_new(true);
        }
        let mut file = options
            .open(&path)
            .map_err(|e| format!("{}: {e}", change.path))?;
        file.write_all(content)
            .and_then(|_| file.sync_all())
            .map_err(|e| e.to_string())?;
        #[cfg(unix)]
        if change.original.is_none() && change.executable {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(path, fs::Permissions::from_mode(0o755))
                .map_err(|e| e.to_string())?;
        }
    } else {
        fs::remove_file(path).map_err(|e| e.to_string())?;
    }
    Ok(())
}
