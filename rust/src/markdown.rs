//! Markdown content extraction and formatting shared by CLI commands.

use std::fs;
use std::io::{self, BufRead, BufReader};
use std::path::Path;
use yaml_rust2::{Yaml, YamlLoader};

/// Parses a closed leading YAML mapping from already-read Markdown, rejecting malformed or multiple documents.
pub(crate) fn frontmatter(text: &str) -> Result<Yaml, String> {
    let mut lines = text.lines();
    if lines.next() != Some("---") {
        return Err("missing leading YAML frontmatter".into());
    }
    let mut yaml = String::new();
    let mut closed = false;
    for line in lines {
        if line == "---" {
            closed = true;
            break;
        }
        yaml.push_str(line);
        yaml.push('\n');
    }
    if !closed {
        return Err("unclosed YAML frontmatter".into());
    }
    let mut documents = YamlLoader::load_from_str(&yaml).map_err(|error| error.to_string())?;
    if documents.len() != 1 || documents[0].as_hash().is_none() {
        return Err("frontmatter must contain exactly one YAML mapping".into());
    }
    Ok(documents.remove(0))
}

/// Validates a summary's type, whitespace, Unicode length, and control-character contract.
pub(crate) fn validate_summary(value: &Yaml) -> Result<(), String> {
    let summary = value.as_str().ok_or("summary must be a YAML string")?;
    if summary != summary.trim() {
        return Err("summary must be trimmed".into());
    }
    if crate::text::has_control(summary) {
        return Err("summary must not contain C0 or DEL control characters".into());
    }
    if !(SUMMARY_MIN..=SUMMARY_MAX).contains(&summary.chars().count()) {
        return Err(format!(
            "summary must contain {SUMMARY_MIN} to {SUMMARY_MAX} Unicode code points"
        ));
    }
    Ok(())
}

/// Validates the discipline strictness range using the canonical integer `/10` spelling.
pub(crate) fn validate_strictness(value: &Yaml) -> Result<(), String> {
    let number = value.as_str().and_then(|value| value.strip_suffix("/10"));
    if number.is_some_and(|number| {
        !number.is_empty()
            && number.bytes().all(|byte| byte.is_ascii_digit())
            && number.parse::<u8>().is_ok_and(|number| number <= 10)
    }) {
        Ok(())
    } else {
        Err("strictness must be 0/10 through 10/10; missing is invalid (effective 0/10)".into())
    }
}

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

/// Reads literal H1-H6 ATX headings with their original markers and one-based lines, including matches inside fences and frontmatter.
pub(crate) fn read_headings(file: &Path) -> io::Result<Vec<(usize, String)>> {
    let lines = BufReader::new(fs::File::open(file)?).lines();
    let mut headings = Vec::new();

    for (index, line) in lines.enumerate() {
        let line = line?;
        let level = line.bytes().take_while(|byte| *byte == b'#').count();
        if (1..=6).contains(&level)
            && matches!(line.as_bytes().get(level), None | Some(b' ' | b'\t'))
        {
            headings.push((index + 1, line));
        }
    }

    Ok(headings)
}

/// Drops a leading `---` frontmatter block like the Bash awk filter, ending every line with LF.
///
/// Leading blank lines are skipped only without frontmatter; blanks after the closing fence are kept.
pub(crate) fn strip_frontmatter(text: &str) -> String {
    let mut out = String::new();
    let mut in_frontmatter = false;
    let mut started = false;

    for (index, line) in text.lines().enumerate() {
        if index == 0 && line == "---" {
            in_frontmatter = true;
            continue;
        }
        if in_frontmatter {
            if line == "---" {
                in_frontmatter = false;
                started = true;
            }
            continue;
        }
        if !started && line.is_empty() {
            continue;
        }

        started = true;
        out.push_str(line);
        out.push('\n');
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Strips frontmatter like the Bash awk filter: blanks after the fence stay, leading blanks without one go.
    #[test]
    fn strips_frontmatter_like_bash() {
        assert_eq!(
            strip_frontmatter("---\nsummary: x\n---\n\n\n## Body\n\ntext\n---\nend"),
            "\n\n## Body\n\ntext\n---\nend\n"
        );
        assert_eq!(
            strip_frontmatter("\n# No frontmatter\n"),
            "# No frontmatter\n"
        );
        assert_eq!(strip_frontmatter("text\n---\nkept\n"), "text\n---\nkept\n");
        assert_eq!(strip_frontmatter("---\nunterminated: yes\n"), "");
        assert_eq!(
            strip_frontmatter("---\r\na: b\r\n---\r\n\r\nbody\r\n"),
            "\nbody\n"
        );
    }
}
