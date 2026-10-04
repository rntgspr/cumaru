//! Balanced semantic marker parsing and fail-closed body replacement.

use std::collections::BTreeSet;

pub(crate) struct Block {
    pub name: String,
    pub start: usize,
    pub body_start: usize,
    pub body_end: usize,
    pub end: usize,
    pub depth: usize,
}

/// Accepts the canonical colon-separated tag grammar without a framework prefix.
pub(crate) fn valid_name(name: &str) -> bool {
    name.split(':').enumerate().all(|(index, segment)| {
        let mut chars = segment.bytes();
        chars.next().is_some_and(|c| c.is_ascii_lowercase())
            && chars.all(|c| {
                c.is_ascii_lowercase()
                    || c.is_ascii_digit()
                    || c == b'_'
                    || c == b'-'
                    || (index > 0 && c == b'*')
            })
    })
}

/// Recognizes whole-line markers, including the supported # and // comment prefixes.
fn marker(line: &str) -> Option<(&str, bool)> {
    let line = line.trim();
    let line = line
        .strip_prefix('#')
        .or_else(|| line.strip_prefix("//"))
        .unwrap_or(line)
        .trim();
    let (name, closing) = if let Some(name) = line.strip_prefix("<!-- /cumaru:") {
        (name, true)
    } else {
        (line.strip_prefix("<!-- cumaru:")?, false)
    };
    let name = name.strip_suffix(" -->")?;

    valid_name(name).then_some((name, closing))
}

/// Parses all balanced blocks before exposing any result; rejects unmatched or crossing closers.
pub(crate) fn parse(text: &str) -> Result<Vec<Block>, String> {
    let mut blocks: Vec<Block> = Vec::new();
    let mut stack: Vec<usize> = Vec::new();
    let mut offset = 0;

    for (line_index, line) in text.split_inclusive('\n').enumerate() {
        if let Some((name, closing)) = marker(line) {
            if closing {
                let index = *stack.last().ok_or_else(|| {
                    format!(
                        "line {}: closing tag \"{name}\" has no opening tag",
                        line_index + 1
                    )
                })?;
                if blocks[index].name != name {
                    return Err(format!(
                        "line {}: unexpected closing tag \"{name}\" while \"{}\" is open",
                        line_index + 1,
                        blocks[index].name
                    ));
                }
                blocks[index].body_end = offset;
                blocks[index].end = offset + line.len();
                stack.pop();
            } else {
                stack.push(blocks.len());
                blocks.push(Block {
                    name: name.into(),
                    start: offset,
                    body_start: offset + line.len(),
                    body_end: 0,
                    end: 0,
                    depth: stack.len(),
                });
            }
        }
        offset += line.len();
    }

    if let Some(index) = stack.last() {
        return Err(format!("tag \"{}\" was never closed", blocks[*index].name));
    }
    Ok(blocks)
}

/// Extracts independently addressable bodies, joining duplicate occurrences in document order.
pub(crate) fn extract(text: &str, blocks: &[Block], name: &str) -> Option<String> {
    let mut end = 0;
    let mut bodies = Vec::new();
    for block in blocks.iter().filter(|block| block.name == name) {
        if block.start < end {
            continue;
        }
        bodies.push(text[block.body_start..block.body_end].to_string());
        end = block.end;
    }
    (!bodies.is_empty()).then(|| bodies.join("\n"))
}

/// Consolidates repeated top-level blocks at their first position while preserving unrelated bytes.
fn consolidate(text: &str) -> Result<String, String> {
    let blocks = parse(text)?;
    let mut used = BTreeSet::new();
    let mut output = String::new();
    let mut cursor = 0;
    for block in blocks.iter().filter(|block| block.depth == 1) {
        output.push_str(&text[cursor..block.start]);
        if used.insert(&block.name) {
            output.push_str(&text[block.start..block.body_start]);
            let bodies: Vec<_> = blocks
                .iter()
                .filter(|other| other.depth == 1 && other.name == block.name)
                .map(|other| &text[other.body_start..other.body_end])
                .collect();
            output.push_str(&bodies.join("\n"));
            output.push_str(&text[block.body_end..block.end]);
        }
        cursor = block.end;
    }
    output.push_str(&text[cursor..]);
    Ok(output)
}

/// Rebuilds canonical framework prose while preserving every local top-level body, including orphan tags.
pub(crate) fn merge(source: &str, local: &str) -> Result<String, String> {
    let source_blocks = parse(source)?;
    let local_blocks = parse(local)?;
    let mut bodies: std::collections::BTreeMap<&str, Vec<&str>> = std::collections::BTreeMap::new();
    let mut order = Vec::new();
    for block in local_blocks.iter().filter(|block| block.depth == 1) {
        if !bodies.contains_key(block.name.as_str()) {
            order.push(block.name.as_str());
        }
        bodies
            .entry(&block.name)
            .or_default()
            .push(&local[block.body_start..block.body_end]);
    }
    let mut used = BTreeSet::new();
    let mut output = String::new();
    let mut cursor = 0;
    for block in source_blocks.iter().filter(|block| block.depth == 1) {
        output.push_str(&source[cursor..block.start]);
        if used.insert(block.name.as_str()) {
            output.push_str(&source[block.start..block.body_start]);
            if let Some(body) = bodies.get(block.name.as_str()) {
                output.push_str(&body.join("\n"));
            } else {
                output.push_str(&source[block.body_start..block.body_end]);
            }
            output.push_str(&source[block.body_end..block.end]);
        }
        cursor = block.end;
    }
    output.push_str(&source[cursor..]);
    let mut orphans = String::new();
    for name in order.into_iter().filter(|name| !used.contains(name)) {
        orphans.push_str(&format!(
            "<!-- cumaru:{name} -->\n{}<!-- /cumaru:{name} -->\n\n",
            bodies[name].join("\n")
        ));
    }
    if !orphans.is_empty() {
        let mut offset = 0;
        if output.lines().next() == Some("---") {
            let mut closed = false;
            for line in output.split_inclusive('\n').skip(1) {
                offset += line.len();
                if line.trim_end() == "---" {
                    closed = true;
                    break;
                }
            }
            if !closed {
                return Err("canonical frontmatter was never closed".into());
            }
            offset += output.split_inclusive('\n').next().unwrap().len();
        }
        output.insert_str(offset, &format!("\n{orphans}"));
    }
    parse(&output)?;
    Ok(output)
}

/// Builds and validates a replacement before publication, inserting missing blocks after frontmatter.
pub(crate) fn replace(text: &str, name: &str, content: &str) -> Result<String, String> {
    if !valid_name(name) {
        return Err("invalid tag name".into());
    }
    let text = consolidate(text)?;
    let blocks = parse(&text)?;
    let mut output = String::new();
    let mut cursor = 0;
    let mut found = false;
    let content = if content.is_empty() || content.ends_with('\n') {
        content.to_string()
    } else {
        format!("{content}\n")
    };

    for block in blocks.iter().filter(|block| block.name == name) {
        if block.start < cursor {
            continue;
        }
        output.push_str(&text[cursor..block.body_start]);
        output.push_str(&content);
        output.push_str(&text[block.body_end..block.end]);
        cursor = block.end;
        found = true;
    }
    output.push_str(&text[cursor..]);

    if !found {
        let mut lines = text.split_inclusive('\n');
        if lines.next().map(str::trim_end) != Some("---") {
            return Err("cannot insert block: file has no leading frontmatter fence".into());
        }
        let mut offset = text.split_inclusive('\n').next().unwrap().len();
        let mut fence = None;
        for line in lines {
            offset += line.len();
            if line.trim_end() == "---" {
                fence = Some(offset);
                break;
            }
        }
        let offset = fence.ok_or("cannot insert block: frontmatter is not closed")?;
        output = format!(
            "{}\n<!-- cumaru:{name} -->\n{content}<!-- /cumaru:{name} -->\n{}",
            &text[..offset],
            &text[offset..]
        );
    }

    parse(&output)?;
    Ok(output)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Preserves opaque duplicates, nested bodies, and local-only tags through an idempotent merge.
    #[test]
    fn merges_canonical_prose_and_local_islands() {
        let source = "---\nsummary: Canonical\n---\n# Canonical\n<!-- cumaru:a:b -->\nscaffold\n<!-- /cumaru:a:b -->\n<!-- cumaru:new -->\nplaceholder\n<!-- /cumaru:new -->\n<!-- cumaru:a:b -->\nduplicate source\n<!-- /cumaru:a:b -->\n";
        let local = "# Local prose\n<!-- cumaru:a:b -->\nfirst\n<!-- cumaru:nested -->\ninside\n<!-- /cumaru:nested -->\n<!-- /cumaru:a:b -->\n<!-- cumaru:a:b -->\nsecond\n<!-- /cumaru:a:b -->\n<!-- cumaru:a__b -->\n[opaque](../missing)\n<!-- /cumaru:a__b -->\n";
        let merged = merge(source, local).unwrap();
        assert!(merged.starts_with("---\nsummary: Canonical\n---\n"));
        assert!(!merged.contains("Local prose"));
        assert!(merged.contains("first\n<!-- cumaru:nested -->"));
        assert!(merged.contains("second\n"));
        assert!(merged.contains("placeholder\n"));
        assert!(merged.contains("[opaque](../missing)"));
        assert_eq!(merged.matches("<!-- cumaru:a:b -->").count(), 1);
        assert_eq!(merge(source, &merged).unwrap(), merged);
        assert!(merge(source, "<!-- cumaru:broken -->\n").is_err());
        assert!(merge("<!-- /cumaru:broken -->\n", local).is_err());
    }

    /// Protects canonical grammar, nested extraction, and whole-line marker recognition.
    #[test]
    fn nested_bodies_and_grammar() {
        assert!(valid_name("plans:task:files*"));
        for name in ["", "Bad", "a:", "a*", "a:2bad"] {
            assert!(!valid_name(name));
        }
        let text = "<!-- cumaru:outer -->\nstart\n# <!-- cumaru:inner -->\ninside\n# <!-- /cumaru:inner -->\nend\n<!-- /cumaru:outer -->\n";
        let blocks = parse(text).unwrap();
        assert_eq!(extract(text, &blocks, "inner").unwrap(), "inside\n");
        assert!(
            extract(text, &blocks, "outer")
                .unwrap()
                .contains("cumaru:inner")
        );
        let output = replace(text, "inner", "new").unwrap();
        assert!(output.contains("# <!-- cumaru:inner -->\nnew\n# <!-- /cumaru:inner -->"));
    }

    /// Rejects malformed input and replacement content before the caller can write.
    #[test]
    fn malformed_and_duplicate_replacement() {
        for text in [
            "<!-- /cumaru:a -->\n",
            "<!-- cumaru:a -->\n",
            "<!-- cumaru:a -->\n<!-- cumaru:b -->\n<!-- /cumaru:a -->\n",
        ] {
            assert!(parse(text).is_err());
        }
        let text = "before\n<!-- cumaru:a -->\none\n<!-- /cumaru:a -->\nbetween\n<!-- cumaru:a -->\ntwo\n<!-- /cumaru:a -->\nafter\n";
        let output = replace(text, "a", "new").unwrap();
        assert_eq!(parse(&output).unwrap().len(), 1);
        assert!(output.contains("between\nafter\n"));
        assert!(replace(text, "a", "<!-- cumaru:bad -->").is_err());
        assert!(
            replace("---\nx: y\n---\nbody\n", "new", "value")
                .unwrap()
                .contains("<!-- cumaru:new -->\nvalue\n")
        );
        assert!(replace("body\n", "new", "value").is_err());
    }

    /// Keeps tables, links, YAML, and arbitrary prose unchanged inside a replacement body.
    #[test]
    fn treats_bodies_as_opaque_text() {
        let text = "<!-- cumaru:notes -->\nold\n<!-- /cumaru:notes -->\n";
        let content = "| strange | table |\n[link](../missing)\nkey: value\nplain\ttext\n";
        let output = replace(text, "notes", content).unwrap();
        assert_eq!(
            extract(&output, &parse(&output).unwrap(), "notes").unwrap(),
            content
        );
    }
}
