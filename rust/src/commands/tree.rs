//! `cumaru tree`: filesystem-backed navigation for `.cumaru/`.
//!
//! The filesystem supplies structural candidates and Markdown frontmatter
//! supplies summaries. Symlinks are never followed and Markdown bodies are
//! never read: frontmatter extraction stops at the closing `---` fence.
//!
//! Accepts multiple filesystem targets without schema-declared pillar filters.

use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use clap::Args;
use yaml_rust2::{Yaml, YamlLoader};

use crate::config::CUMARU_DIR;
use crate::markdown::{SUMMARY_MAX, SUMMARY_MIN, markdown_escape, read_frontmatter};
use crate::paths::{
    canonical_inside, file_name, has_symlink_component, is_symlink, normalize_target,
};
use crate::text::{has_control, shell_quote};
use crate::walk::{Entry, Walk};

/// Arguments for `cumaru tree`.
#[derive(Args)]
#[command(
    override_usage = "cumaru tree [<directory-or-md>...] [--deep] [--rows]",
    args_override_self = true
)]
pub struct TreeArgs {
    /// Directories or Markdown files relative to .cumaru/; each Markdown file resolves to its parent.
    #[arg(value_name = "directory-or-md")]
    targets: Vec<String>,

    /// Recursively inspect all non-hidden descendants and report every defect.
    #[arg(long)]
    deep: bool,

    /// Emit path<TAB>summary TSV instead of a Markdown table.
    #[arg(long)]
    rows: bool,
}

/// Tree-specific parsing results and diagnostics.
struct TreeParser {
    root: PathBuf,
    records: Vec<String>,
    diagnostics: Vec<String>,
}

/// Runs `cumaru tree` and maps the outcome to the documented exit codes.
pub fn run(args: TreeArgs) -> ExitCode {
    match execute(&args) {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(message) => {
            eprintln!("cumaru tree: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Validates all targets, walks each directory, and emits their combined unique results.
fn execute(args: &TreeArgs) -> Result<bool, String> {
    let targets: Vec<String> = if args.targets.is_empty() {
        vec![normalize_target(None)]
    } else {
        args.targets
            .iter()
            .map(|target| normalize_target(Some(target)))
            .collect()
    };
    for target in &targets {
        validate_target_syntax(target)?;
    }

    let cumaru = Path::new(CUMARU_DIR);
    if is_symlink(cumaru) {
        return Err(".cumaru/ must not be a symlink".into());
    }
    if !cumaru.is_dir() {
        return Err(".cumaru/ not found; run `cumaru install` first".into());
    }
    let root = fs::canonicalize(cumaru).map_err(|_| "cannot resolve .cumaru/".to_string())?;

    let mut target_dirs = Vec::new();
    for target in &targets {
        let dir = resolve_target(&root, target)?;
        if !target_dirs.contains(&dir) {
            target_dirs.push(dir);
        }
    }

    let mut parser = TreeParser {
        root: root.clone(),
        records: Vec::new(),
        diagnostics: Vec::new(),
    };
    let walk = Walk {
        root: &root,
        deep: args.deep,
    };
    let diagnostics = walk.run(
        &target_dirs,
        |path| file_name(path).ends_with(".md"),
        |entry| parser.parse(entry, args.deep),
    )?;
    for diagnostic in diagnostics {
        let rel = parser.rel(&diagnostic.path);
        parser.diag(&rel, diagnostic.message);
    }

    parser.records.sort();
    parser.records.dedup();
    emit(&mut parser.records, args.rows);

    parser.diagnostics.sort();
    parser.diagnostics.dedup();
    for line in &parser.diagnostics {
        eprintln!("{line}");
    }

    Ok(parser.diagnostics.is_empty())
}

/// Rejects absolute, control-character, `..`, and hidden target paths before any filesystem access.
fn validate_target_syntax(target: &str) -> Result<(), String> {
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

/// Resolves the target to the directory to walk; a Markdown file target becomes its parent.
fn resolve_target(root: &Path, target: &str) -> Result<PathBuf, String> {
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
        return Ok(canonical.parent().unwrap_or(root).to_path_buf());
    }

    if candidate.exists() {
        return Err(format!(
            "target must be a directory or Markdown file: {}",
            shell_quote(target)
        ));
    }
    Err(format!("target not found: {}", shell_quote(target)))
}

impl TreeParser {
    /// Parses directory indexes and Markdown candidates independently of filesystem traversal.
    fn parse(&mut self, entry: Entry<'_>, deep: bool) -> Result<(), String> {
        let rel = self.rel(entry.path);
        if !entry.is_dir {
            if file_name(entry.path) != "index.md" {
                if let Some(summary) = self.summary(entry.path, &rel) {
                    self.records.push(format!("{rel}\t{summary}"));
                }
            }
            return Ok(());
        }

        let index = entry.path.join("index.md");
        let index_rel = self.rel(&index);
        let target = entry.path == entry.target;
        if target && !deep {
            if is_symlink(&index) {
                return Err(format!(
                    "target index is a symlink: {}",
                    shell_quote(&index_rel)
                ));
            }
            if !index.is_file()
                || has_symlink_component(&self.root, &index)
                || canonical_inside(&self.root, &index).is_none()
            {
                return Err(format!(
                    "target requires a regular index.md: {}",
                    shell_quote(&index_rel)
                ));
            }
            return Ok(());
        }

        if is_symlink(&index) {
            self.diag(&index_rel, "symlinks are not supported");
        } else if index.is_file() {
            if has_symlink_component(&self.root, &index)
                || canonical_inside(&self.root, &index).is_none()
            {
                self.diag(&index_rel, "file does not resolve safely inside .cumaru/");
            } else if let Some(summary) = self.summary(&index, &index_rel) {
                if !target {
                    self.records.push(format!("{rel}/\t{summary}"));
                }
            }
        } else if deep {
            self.diag(&index_rel, "directory is missing a regular index.md");
        }

        Ok(())
    }

    /// Reads and validates the frontmatter `summary`, recording a diagnostic when it is unusable.
    fn summary(&mut self, file: &Path, rel: &str) -> Option<String> {
        let parsed = read_frontmatter(file)
            .ok()
            .and_then(|text| YamlLoader::load_from_str(&text).ok());
        let Some(docs) = parsed else {
            self.diag(rel, "cannot read YAML frontmatter");
            return None;
        };

        let summary = match docs.first().map(|doc| &doc["summary"]) {
            Some(Yaml::String(summary)) => summary.clone(),
            _ => {
                self.diag(rel, "summary must be a YAML string");
                return None;
            }
        };

        let length = summary.chars().count();
        if summary.trim() != summary {
            self.diag(rel, "summary must be trimmed");
        } else if has_control(&summary) {
            self.diag(rel, "summary must not contain C0 or DEL control characters");
        } else if !(SUMMARY_MIN..=SUMMARY_MAX).contains(&length) {
            self.diag(rel, "summary must contain 32 to 512 Unicode code points");
        } else {
            return Some(summary);
        }

        None
    }

    /// Records a diagnostic with the tree command's path formatting.
    fn diag(&mut self, rel: &str, message: &str) {
        self.diagnostics
            .push(format!("cumaru tree: {}: {message}", shell_quote(rel)));
    }

    /// Returns a path relative to the framework root, or dot for the root itself.
    fn rel(&self, path: &Path) -> String {
        match path.strip_prefix(&self.root) {
            Ok(rel) if rel.as_os_str().is_empty() => ".".to_string(),
            Ok(rel) => rel.to_string_lossy().into_owned(),
            Err(_) => path.to_string_lossy().into_owned(),
        }
    }
}

/// Prints sorted records as TSV rows or as an escaped Markdown table; stops quietly on a closed pipe.
fn emit(records: &mut [String], rows: bool) {
    records.sort();
    let mut out = io::stdout().lock();

    if rows {
        for record in records.iter() {
            let (path, summary) = record.split_once('\t').unwrap_or((record, ""));

            if crate::tsv::write_row(&mut out, [path, summary]).is_err() {
                return;
            }
        }
        return;
    }

    if writeln!(out, "| Path | Summary |\n|---|---|").is_err() {
        return;
    }
    for record in records.iter() {
        let (path, summary) = record.split_once('\t').unwrap_or((record, ""));
        if writeln!(
            out,
            "| {} | {} |",
            markdown_escape(path),
            markdown_escape(summary)
        )
        .is_err()
        {
            return;
        }
    }
}
