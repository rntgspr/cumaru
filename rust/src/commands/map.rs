//! Read-only projection of literal H1-H6 Markdown headings with their markers.

use std::fs;
use std::io::{self, Write};
use std::path::Path;
use std::process::ExitCode;

use clap::Args;

use crate::config::CUMARU_DIR;
use crate::markdown::{markdown_escape, read_headings};
use crate::paths::{
    file_name, is_symlink, normalize_target, resolve_target, validate_target_syntax,
};
use crate::text::shell_quote;
use crate::walk::Walk;

/// Arguments for `cumaru map`.
#[derive(Args)]
pub struct MapArgs {
    /// Directory to search recursively or exact Markdown file, relative to .cumaru/.
    #[arg(value_name = "directory-or-md")]
    target: Option<String>,

    /// Emit path<TAB>line<TAB>title TSV (the default).
    #[arg(long, conflicts_with = "markdown")]
    rows: bool,

    /// Emit an escaped Markdown table instead of TSV.
    #[arg(long)]
    markdown: bool,
}

/// Runs the heading projection and reports runtime failures on stderr.
pub fn run(args: MapArgs) -> ExitCode {
    match execute(&args) {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(message) => {
            eprintln!("cumaru map: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Resolves the scope, collects headings from safe files, and emits sorted results and diagnostics.
fn execute(args: &MapArgs) -> Result<bool, String> {
    let target = normalize_target(args.target.as_deref());
    validate_target_syntax(&target)?;

    let cumaru = Path::new(CUMARU_DIR);
    if is_symlink(cumaru) || !cumaru.is_dir() {
        return Err(".cumaru/ not found or is a symlink".into());
    }
    let root = fs::canonicalize(cumaru).map_err(|_| "cannot resolve .cumaru/".to_string())?;
    let scope = resolve_target(&root, &target)?;

    let mut records = Vec::new();
    let mut diagnostics = Vec::new();
    let walk = Walk {
        root: &root,
        deep: true,
    };
    let defects = walk.run(
        &[scope],
        |path| file_name(path).ends_with(".md"),
        |entry| {
            if entry.is_dir {
                return Ok(());
            }

            let rel = entry
                .path
                .strip_prefix(&root)
                .unwrap_or(entry.path)
                .to_string_lossy()
                .into_owned();
            match read_headings(entry.path) {
                Ok(headings) => {
                    records.extend(
                        headings
                            .into_iter()
                            .map(|(line, title)| (rel.clone(), line, title)),
                    );
                }
                Err(_) => diagnostics.push(format!(
                    "cumaru map: {}: cannot read Markdown headings",
                    shell_quote(&rel)
                )),
            }

            Ok(())
        },
    )?;
    for defect in defects {
        let rel = defect
            .path
            .strip_prefix(&root)
            .unwrap_or(&defect.path)
            .to_string_lossy();
        diagnostics.push(format!(
            "cumaru map: {}: {}",
            shell_quote(&rel),
            defect.message
        ));
    }

    records.sort();
    records.dedup();
    emit(&records, args.rows || !args.markdown);

    diagnostics.sort();
    diagnostics.dedup();
    for diagnostic in &diagnostics {
        eprintln!("{diagnostic}");
    }

    Ok(diagnostics.is_empty())
}

/// Prints caller-selected heading fields as TSV or an escaped Markdown table, stopping on a closed output stream.
fn emit(records: &[(String, usize, String)], rows: bool) {
    let mut out = io::stdout().lock();

    if !rows && writeln!(out, "| Path | Line | Title |\n|---|---|---|").is_err() {
        return;
    }

    for (path, line, title) in records {
        let result = if rows {
            crate::tsv::write_row(&mut out, [path.as_str(), &line.to_string(), title.as_str()])
        } else {
            writeln!(
                out,
                "| {} | {line} | {} |",
                markdown_escape(path),
                markdown_escape(title)
            )
        };

        if result.is_err() {
            return;
        }
    }
}
