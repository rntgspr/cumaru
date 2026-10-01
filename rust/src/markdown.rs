//! Markdown content extraction and formatting shared by CLI commands.

use std::fs;
use std::io::{self, BufRead, BufReader};
use std::path::Path;

/// Minimum number of Unicode code points in a trimmed summary.
pub(crate) const SUMMARY_MIN: usize = 32;

/// Maximum number of Unicode code points in a trimmed summary.
pub(crate) const SUMMARY_MAX: usize = 512;

/// Returns the YAML between a leading `---` fence and the next `---`, never reading past it.
///
/// A file without a leading fence yields empty YAML, which has no summary.
pub(crate) fn read_frontmatter(file: &Path) -> io::Result<String> {
    let mut lines = BufReader::new(fs::File::open(file)?).lines();
    let mut yaml = String::new();

    let first = lines.next().transpose()?.unwrap_or_default();
    if first.trim_end_matches('\r') != "---" {
        return Ok(yaml);
    }

    for line in lines {
        let line = line?;
        let line = line.trim_end_matches('\r');
        if line == "---" {
            break;
        }
        yaml.push_str(line);
        yaml.push('\n');
    }

    Ok(yaml)
}

/// Escapes backslashes and pipes so a value stays inside one Markdown table cell.
pub(crate) fn markdown_escape(value: &str) -> String {
    value.replace('\\', "\\\\").replace('|', "\\|")
}
