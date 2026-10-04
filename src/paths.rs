//! Path normalization and filesystem inspection for CLI commands.

use std::fs;
use std::path::{Path, PathBuf};

use crate::text::{has_control, shell_quote};

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

/// Guards project-relative managed destinations, allowing native hidden directories but no symlinks.
pub(crate) fn project_destination(project: &Path, rel: &str) -> Result<PathBuf, String> {
    if rel.is_empty()
        || rel.starts_with('/')
        || rel
            .split('/')
            .any(|s| s.is_empty() || s == "." || s == "..")
        || has_control(rel)
    {
        return Err(format!("unsafe project destination: {rel}"));
    }
    let path = project.join(rel);
    if has_symlink_component(project, &path) {
        return Err(format!("symlinked project destination: {rel}"));
    }
    for parent in path.ancestors().skip(1).take_while(|p| *p != project) {
        if parent.exists() && !parent.is_dir() {
            return Err(format!(
                "project parent is not a directory: {}",
                parent.display()
            ));
        }
    }
    Ok(path)
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

/// Rejects absolute, control-character, `..`, and hidden target paths before any filesystem access.
pub(crate) fn validate_target_syntax(target: &str) -> Result<(), String> {
    if target.starts_with('/') {
        return Err(format!(
            "target must be relative to .cumaru/: {}",
            shell_quote(target)
        ));
    }
    if has_control(target) {
        return Err(format!(
            "target path contains a control character: {}",
            shell_quote(target)
        ));
    }

    for segment in target.split('/') {
        if segment == ".." {
            return Err(format!(
                "`..` path segments are not allowed: {}",
                shell_quote(target)
            ));
        }
        if segment.starts_with('.') && segment != "." {
            return Err(format!(
                "hidden target paths are not allowed: {}",
                shell_quote(target)
            ));
        }
    }

    Ok(())
}

/// Resolves a safe directory or exact Markdown file inside the framework root.
pub(crate) fn resolve_target(root: &Path, target: &str) -> Result<PathBuf, String> {
    let candidate = if target == "." {
        root.to_path_buf()
    } else {
        root.join(target)
    };
    if has_symlink_component(root, &candidate) {
        return Err(format!(
            "target contains a symlink: {}",
            shell_quote(target)
        ));
    }

    let unsafe_target = || {
        format!(
            "target does not resolve safely inside .cumaru/: {}",
            shell_quote(target)
        )
    };
    if candidate.is_dir() {
        return canonical_inside(root, &candidate).ok_or_else(unsafe_target);
    }
    if candidate.is_file() {
        if !target.ends_with(".md") {
            return Err(format!(
                "file target must end in .md: {}",
                shell_quote(target)
            ));
        }
        let canonical = canonical_inside(root, &candidate).ok_or_else(unsafe_target)?;
        return Ok(canonical);
    }

    if candidate.exists() {
        return Err(format!(
            "target must be a directory or Markdown file: {}",
            shell_quote(target)
        ));
    }
    Err(format!("target not found: {}", shell_quote(target)))
}
