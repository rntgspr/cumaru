use std::fs;
use std::path::Path;

/// Extracts table rows belonging to selected innermost balanced tags, reusing the caller's parsed Markdown blocks.
pub(crate) fn cells(
    text: &str,
    blocks: &[crate::tags::Block],
    names: &[&str],
) -> Vec<(String, String, String, String)> {
    let mut cells = Vec::new();
    let mut offset = 0;
    for line in text.split_inclusive('\n') {
        let innermost = blocks
            .iter()
            .filter(|block| block.body_start <= offset && offset < block.body_end)
            .max_by_key(|block| block.depth);
        if let Some(block) = innermost.filter(|block| names.contains(&block.name.as_str())) {
            if let Some((link, description, target)) =
                table_row(line.trim_end_matches(['\n', '\r']))
            {
                cells.push((block.name.clone(), link, description, target));
            }
        }
        offset += line.len();
    }
    cells
}

/// Resolution of one reference row target under the source-file rule.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) enum Status {
    Ok,
    Missing,
    Invalid,
}

/// Parses one `[Link, Description]` table line like the Bash awk reader, skipping headers and separators.
pub(crate) fn table_row(line: &str) -> Option<(String, String, String)> {
    let row = line.trim_start().strip_prefix('|')?;
    let row = row.trim_end();
    let row = row.strip_suffix('|').unwrap_or(row);
    let cells: Vec<&str> = row.split('|').map(str::trim).collect();

    let header = cells.len() == 2
        && cells[0].eq_ignore_ascii_case("link")
        && cells[1].eq_ignore_ascii_case("description");
    let separator = cells.len() >= 2
        && cells
            .iter()
            .all(|cell| !cell.is_empty() && cell.chars().all(|c| matches!(c, '-' | ':' | ' ')));
    if cells.len() < 2 || header || separator {
        return None;
    }

    let link = cells[0].replace('\t', " ");
    let desc = cells[1..].join(" | ").replace('\t', " ");
    let target = link_target(cells[0]).replace('\t', " ");

    Some((link, desc, target))
}

/// Returns the first Markdown link destination in a cell, or the cell itself, without backticks.
fn link_target(cell: &str) -> String {
    let mut raw = cell;
    let mut search = 0;
    while let Some(open) = cell[search..].find('[').map(|index| index + search) {
        let Some(close) = cell[open + 1..].find(']').map(|index| index + open + 1) else {
            break;
        };
        if close > open + 1
            && cell[close + 1..].starts_with('(')
            && let Some(end) = cell[close + 2..].find(')').map(|index| index + close + 2)
            && end > close + 2
        {
            raw = &cell[close + 2..end];
            break;
        }
        search = open + 1;
    }

    raw.replace('`', "").trim().to_string()
}

/// Applies the reference source-file rule, returning the status and displayed target; `None` skips template or empty rows.
pub(crate) fn resolve(root: &Path, raw: &str) -> Option<(Status, String)> {
    if raw.is_empty() {
        return None;
    }
    let scheme = raw.split_once(':').is_some_and(|(scheme, _)| {
        scheme.starts_with(|c: char| c.is_ascii_alphabetic())
            && scheme
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || matches!(c, '+' | '.' | '-'))
    });
    if raw.starts_with('#') || scheme {
        return Some((Status::Invalid, raw.into()));
    }
    if raw.contains(['<', '>']) {
        return None;
    }

    let target = raw.split('#').next().unwrap_or_default();
    let project = root.parent()?;
    let verdict = |status| Some((status, target.to_string()));
    if target.is_empty()
        || target.starts_with('/')
        || target.trim_start_matches("./").starts_with(".cumaru/")
        || target == ".cumaru"
        || crate::text::has_control(target)
    {
        return verdict(Status::Invalid);
    }
    let mut relative = std::path::PathBuf::new();
    for component in Path::new(target).components() {
        match component {
            std::path::Component::Normal(part) => relative.push(part),
            std::path::Component::CurDir => {}
            std::path::Component::ParentDir if relative.pop() => {}
            _ => return verdict(Status::Invalid),
        }
    }
    if relative.as_os_str().is_empty() || relative.starts_with(".cumaru") {
        return verdict(Status::Invalid);
    }
    let candidate = project.join(relative);
    if fs::symlink_metadata(&candidate).is_ok_and(|metadata| metadata.file_type().is_symlink()) {
        return verdict(Status::Invalid);
    }
    if !candidate.exists() {
        return verdict(Status::Missing);
    }
    if !candidate.is_file() {
        return verdict(Status::Invalid);
    }

    let parent = candidate
        .parent()
        .and_then(|parent| fs::canonicalize(parent).ok());
    let physical = match (parent, candidate.file_name()) {
        (Some(parent), Some(name)) => parent.join(name),
        _ => candidate.clone(),
    };
    if physical.starts_with(root) {
        return verdict(Status::Invalid);
    }

    match physical.strip_prefix(project) {
        Ok(rel) => Some((Status::Ok, rel.to_string_lossy().into_owned())),
        Err(_) => verdict(Status::Invalid),
    }
}
