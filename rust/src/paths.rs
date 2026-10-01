//! Path normalization and filesystem inspection for CLI commands.

use std::fs;
use std::path::{Path, PathBuf};

/// Defaults an omitted target to the root and strips trailing slashes.
pub(crate) fn normalize_target(target: Option<&str>) -> String {
    let mut target = target.unwrap_or(".").to_string();
    while target != "/" && target.ends_with('/') {
        target.pop();
    }

    if target.is_empty() {
        ".".to_string()
    } else {
        target
    }
}

/// True when the path itself is a symlink (the link is inspected, not its target).
pub(crate) fn is_symlink(path: &Path) -> bool {
    fs::symlink_metadata(path).is_ok_and(|meta| meta.file_type().is_symlink())
}

/// True when any component below the root is a symlink, or when the path is outside the root.
pub(crate) fn has_symlink_component(root: &Path, path: &Path) -> bool {
    let Ok(rel) = path.strip_prefix(root) else {
        return true;
    };

    let mut probe = root.to_path_buf();
    for component in rel.components() {
        probe.push(component);
        if is_symlink(&probe) {
            return true;
        }
    }

    false
}

/// Returns the canonical path when it exists and stays inside the root.
pub(crate) fn canonical_inside(root: &Path, path: &Path) -> Option<PathBuf> {
    fs::canonicalize(path)
        .ok()
        .filter(|canonical| canonical.starts_with(root))
}

/// Returns the final path component as text.
pub(crate) fn file_name(path: &Path) -> String {
    path.file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default()
}
