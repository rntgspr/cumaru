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
use crate::markdown::{markdown_escape, read_frontmatter, validate_summary};
use crate::paths::{
    canonical_inside, file_name, has_symlink_component, is_symlink, normalize_target,
    resolve_target, validate_target_syntax,
};
use crate::text::shell_quote;
use crate::walk::{Entry, Walk};

/// Arguments for `cumaru tree`.
#[derive(Args)]
#[command(
    override_usage = "cumaru tree [<directory-or-md>...] [--deep] [--rows|--markdown]",
    args_override_self = true
)]
pub struct TreeArgs {
    /// Directories or Markdown files relative to .cumaru/; each Markdown file resolves to its parent.
    #[arg(value_name = "directory-or-md")]
    targets: Vec<String>,

    /// Recursively inspect all non-hidden descendants and report every defect.
    #[arg(long)]
    deep: bool,

    /// Emit path<TAB>summary TSV (the default).
    #[arg(long, conflicts_with = "markdown")]
    rows: bool,

    /// Emit an escaped Markdown table instead of TSV.
    #[arg(long)]
    markdown: bool,
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
        let resolved = resolve_target(&root, target)?;
        let dir = if resolved.is_file() {
            resolved.parent().unwrap_or(&root).to_path_buf()
        } else {
            resolved
        };
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
    emit(&mut parser.records, args.rows || !args.markdown);

    parser.diagnostics.sort();
    parser.diagnostics.dedup();
    for line in &parser.diagnostics {
        eprintln!("{line}");
    }

    Ok(parser.diagnostics.is_empty())
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

        if let Err(message) = validate_summary(&Yaml::String(summary.clone())) {
            self.diag(rel, &message);
            None
        } else {
            Some(summary)
        }
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
