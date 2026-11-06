//! Read-only, atomic line selection from Markdown files under `.cumaru/`.
//!
//! Selectors follow `git log -L` and `sed` addresses: `path`, `path:N`,
//! `path:N,M`, `path:N,`, `path:N,$`, `path:,M`, `path:N,+K`, and `path:N,-K`.
//! Every selector is resolved and validated before anything is printed.

use std::fs;
use std::io::{self, Write};
use std::path::Path;
use std::process::ExitCode;

use clap::Args;

use crate::config::CUMARU_DIR;
use crate::paths::{is_symlink, resolve_target, validate_target_syntax};
use crate::text::shell_quote;

/// Byte budget for the complete output, headers included.
const BUDGET: usize = 32768;

/// Arguments for `cumaru get`.
#[derive(Args)]
pub struct GetArgs {
    /// One or more `path[:range]` selectors, relative to .cumaru/.
    #[arg(value_name = "path[:range]", required = true)]
    selectors: Vec<String>,
}

/// A selector range before it is resolved against a file's line count.
#[derive(Debug, PartialEq)]
enum Range {
    Whole,
    Span(Option<usize>, End),
    Below(usize, usize),
    Above(usize, usize),
}

/// The end of a span: an explicit line or the end of the file.
#[derive(Debug, PartialEq)]
enum End {
    Line(usize),
    Eof,
}

/// A failure with its exit status: 2 for selector syntax or bounds, 1 for file access.
struct Failure {
    status: u8,
    message: String,
}

/// Runs every selector atomically and prints headed blocks or one diagnostic.
pub fn run(args: GetArgs) -> ExitCode {
    match execute(&args.selectors) {
        Ok(text) => {
            // A closed output stream (e.g. `| head`) is not an error for a read-only command.
            let _ = io::stdout().lock().write_all(text.as_bytes());
            ExitCode::SUCCESS
        }
        Err(failure) => {
            eprintln!("cumaru get: {}", failure.message);
            ExitCode::from(failure.status)
        }
    }
}

/// Resolves all selectors, then builds the complete output within budget.
fn execute(selectors: &[String]) -> Result<String, Failure> {
    let cumaru = Path::new(CUMARU_DIR);
    if is_symlink(cumaru) || !cumaru.is_dir() {
        return Err(io_failure(".cumaru/ not found or is a symlink".into()));
    }
    let root =
        fs::canonicalize(cumaru).map_err(|_| io_failure("cannot resolve .cumaru/".into()))?;

    let mut blocks = Vec::new();
    for selector in selectors {
        let (path, range) = split(selector).map_err(|message| usage(selector, message))?;
        validate_target_syntax(path).map_err(io_failure)?;

        let file = resolve_target(&root, path).map_err(io_failure)?;
        if !file.is_file() {
            return Err(io_failure(format!(
                "target must be a Markdown file: {}",
                shell_quote(path)
            )));
        }
        let text = fs::read_to_string(&file)
            .map_err(|_| io_failure(format!("cannot read UTF-8 file: {}", shell_quote(path))))?;

        let lines: Vec<&str> = text.split_inclusive('\n').collect();
        let (start, end) =
            resolve(&range, lines.len()).map_err(|message| usage(selector, message))?;
        let (start, end) = trim(&lines, start, end);
        blocks.push((path.to_string(), start, end, lines[start - 1..end].concat()));
    }

    let mut output = String::new();
    for (index, (path, start, end, body)) in blocks.iter().enumerate() {
        if index > 0 {
            output.push('\n');
        }
        output.push_str(&format!("==> {} <==\n{body}", selector(path, *start, *end)));
        if !body.ends_with('\n') {
            output.push('\n');
        }
    }
    if output.len() > BUDGET {
        return Err(Failure {
            status: 1,
            message: format!(
                "output is {} bytes, over the {BUDGET}-byte budget; narrow the ranges",
                output.len()
            ),
        });
    }

    Ok(output)
}

/// Splits `path[:range]` at the last colon that follows a `.md` path.
fn split(selector: &str) -> Result<(&str, Range), String> {
    match selector.rsplit_once(':') {
        Some((path, range)) if path.ends_with(".md") => Ok((path, parse(range)?)),
        _ => Ok((selector, Range::Whole)),
    }
}

/// Parses the range grammar without knowing the file length.
fn parse(range: &str) -> Result<Range, String> {
    let line = |text: &str| -> Result<usize, String> {
        match text.parse::<usize>() {
            Ok(value) if value > 0 && text.bytes().all(|b| b.is_ascii_digit()) => Ok(value),
            _ => Err(format!("invalid line number {}", shell_quote(text))),
        }
    };
    let end = |text: &str| -> Result<End, String> {
        match text {
            "" | "$" => Ok(End::Eof),
            _ => line(text).map(End::Line),
        }
    };

    let Some((left, right)) = range.split_once(',') else {
        let start = line(range)?;
        return Ok(Range::Span(Some(start), End::Line(start)));
    };

    if left.is_empty() {
        if right.is_empty() {
            return Err("empty range; use the bare path for the whole file".into());
        }
        if right.starts_with(['+', '-']) {
            return Err("relative counts need an explicit start line".into());
        }
        return Ok(Range::Span(None, end(right)?));
    }

    let start = line(left)?;
    if let Some(count) = right.strip_prefix('+') {
        return Ok(Range::Below(start, line(count)?));
    }
    if let Some(count) = right.strip_prefix('-') {
        return Ok(Range::Above(start, line(count)?));
    }

    Ok(Range::Span(Some(start), end(right)?))
}

/// Resolves a range to inclusive one-based lines inside a file of `total` lines.
fn resolve(range: &Range, total: usize) -> Result<(usize, usize), String> {
    if total == 0 {
        return Err("file is empty".into());
    }

    let (start, end) = match range {
        Range::Whole => (1, total),
        Range::Span(start, End::Line(end)) => (start.unwrap_or(1), *end),
        Range::Span(start, End::Eof) => (start.unwrap_or(1), total),
        Range::Below(start, count) => (*start, start + count),
        Range::Above(start, count) => (
            start
                .checked_sub(*count)
                .filter(|line| *line > 0)
                .ok_or("range starts before line 1")?,
            *start,
        ),
    };

    if start > end {
        return Err(format!("reversed range {start},{end}"));
    }
    if end > total {
        return Err(format!(
            "line {end} is past the end of the file ({total} lines)"
        ));
    }

    Ok((start, end))
}

/// Narrows an inclusive range past leading and trailing blank lines, keeping an all-blank range intact.
fn trim(lines: &[&str], mut start: usize, mut end: usize) -> (usize, usize) {
    let blank = |line: usize| lines[line - 1].trim().is_empty();
    if (start..=end).all(blank) {
        return (start, end);
    }

    while blank(start) {
        start += 1;
    }
    while blank(end) {
        end -= 1;
    }

    (start, end)
}

/// Formats the canonical `path:start,end` selector shared by `get` headers and `map` rows.
pub(crate) fn selector(path: &str, start: usize, end: usize) -> String {
    format!("{path}:{start},{end}")
}

/// Builds a status-2 selector diagnostic.
fn usage(selector: &str, message: String) -> Failure {
    Failure {
        status: 2,
        message: format!(
            "{}: {message}",
            selector
                .chars()
                .map(|c| if c.is_control() { '?' } else { c })
                .collect::<String>()
        ),
    }
}

/// Builds a status-1 file-access diagnostic.
fn io_failure(message: String) -> Failure {
    Failure { status: 1, message }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Parses every documented selector form.
    #[test]
    fn parses_selector_grammar() {
        assert_eq!(split("a.md").unwrap().1, Range::Whole);
        assert_eq!(
            split("a.md:18").unwrap().1,
            Range::Span(Some(18), End::Line(18))
        );
        assert_eq!(
            split("a.md:18,32").unwrap().1,
            Range::Span(Some(18), End::Line(32))
        );
        assert_eq!(
            split("a.md:18,").unwrap().1,
            Range::Span(Some(18), End::Eof)
        );
        assert_eq!(
            split("a.md:18,$").unwrap().1,
            Range::Span(Some(18), End::Eof)
        );
        assert_eq!(
            split("a.md:,32").unwrap().1,
            Range::Span(None, End::Line(32))
        );
        assert_eq!(split("a.md:18,+5").unwrap().1, Range::Below(18, 5));
        assert_eq!(split("a.md:33,-3").unwrap().1, Range::Above(33, 3));
        assert_eq!(split("dir/a.md").unwrap().0, "dir/a.md");
    }

    /// Trims blank edges and reports the narrowed range.
    #[test]
    fn trims_blank_edges() {
        let lines = ["\n", "a\n", "\n", "b\n", "  \n", "\n"];
        assert_eq!(trim(&lines, 1, 6), (2, 4));
        assert_eq!(trim(&lines, 5, 6), (5, 6));
        assert_eq!(trim(&lines, 2, 2), (2, 2));
    }

    /// Rejects ambiguous or malformed ranges.
    #[test]
    fn rejects_bad_selectors() {
        for selector in [
            "a.md:",
            "a.md:,",
            "a.md:,+5",
            "a.md:,-2",
            "a.md:0",
            "a.md:x",
            "a.md:1,+x",
            "a.md:+3",
        ] {
            assert!(split(selector).is_err(), "{selector}");
        }
    }

    /// Resolves bounds against the file length.
    #[test]
    fn resolves_bounds() {
        assert_eq!(resolve(&Range::Whole, 10), Ok((1, 10)));
        assert_eq!(resolve(&Range::Span(None, End::Line(4)), 10), Ok((1, 4)));
        assert_eq!(resolve(&Range::Span(Some(7), End::Eof), 10), Ok((7, 10)));
        assert_eq!(resolve(&Range::Below(3, 2), 10), Ok((3, 5)));
        assert_eq!(resolve(&Range::Above(5, 2), 10), Ok((3, 5)));
        assert!(resolve(&Range::Above(2, 2), 10).is_err());
        assert!(resolve(&Range::Span(Some(5), End::Line(3)), 10).is_err());
        assert!(resolve(&Range::Span(Some(5), End::Line(11)), 10).is_err());
        assert!(resolve(&Range::Whole, 0).is_err());
    }
}
