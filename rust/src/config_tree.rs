//! Installed configuration selectors and their resolved tag contracts.

use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use glob::{MatchOptions, Pattern, glob_with};
use yaml_rust2::Yaml;

use crate::paths::{canonical_inside, has_symlink_component};

struct Declaration {
    logical: String,
    physical: String,
    directory: bool,
    optional: bool,
    owned: bool,
    tags: BTreeSet<String>,
    frontmatter: BTreeMap<String, bool>,
}

pub(crate) struct Contract {
    pub tags: BTreeSet<String>,
    pub frontmatter: BTreeMap<String, bool>,
}

/// Reads declared frontmatter field optionality without inheriting parent entry metadata.
fn fields(value: &Yaml) -> BTreeMap<String, bool> {
    value
        .as_hash()
        .into_iter()
        .flatten()
        .filter_map(|(name, value)| {
            name.as_str()
                .map(|name| (name.to_string(), value["optional"].as_bool() == Some(true)))
        })
        .collect()
}

/// Reads a v9 tag-name array without coercing other YAML types.
fn names(value: &Yaml) -> BTreeSet<String> {
    value
        .as_vec()
        .into_iter()
        .flatten()
        .filter_map(Yaml::as_str)
        .map(String::from)
        .collect()
}

/// Flattens direct-tree selectors while keeping logical names and physical overrides separate.
fn declarations(
    node: &Yaml,
    logical: &str,
    physical: &str,
    rows: &mut Vec<Declaration>,
) -> Result<(), String> {
    let Some(node) = node.as_hash() else {
        return Ok(());
    };
    for (key, value) in node {
        let key = key.as_str().ok_or("config selector must be a string")?;
        if ["path", "optional", "framework", "frontmatter", "tags"].contains(&key) {
            continue;
        }
        let segment = value["path"].as_str().unwrap_or(key);
        if segment.is_empty()
            || segment.starts_with('/')
            || segment
                .split('/')
                .any(|s| s.is_empty() || s.starts_with('.'))
            || segment.contains("**")
            || crate::text::has_control(segment)
        {
            return Err(format!("unsafe config path: {segment}"));
        }
        let logical = if logical.is_empty() {
            key.into()
        } else {
            format!("{logical}/{key}")
        };
        let physical = if physical.is_empty() {
            segment.into()
        } else {
            format!("{physical}/{segment}")
        };
        rows.push(Declaration {
            logical: logical.clone(),
            physical: physical.clone(),
            directory: !key.contains('.'),
            optional: value["optional"].as_bool().unwrap_or(false),
            owned: value["framework"].as_bool().unwrap_or(false),
            tags: names(&value["tags"]),
            frontmatter: fields(&value["frontmatter"]),
        });
        declarations(value, &logical, &physical, rows)?;
    }
    Ok(())
}

/// Identifies selectors whose expansion is zero-or-more rather than required literal lookup.
fn wildcard(selector: &str) -> bool {
    selector.contains(['*', '?', '['])
}

/// Matches explicitly owned local hosts to equally owned canonical logical entries.
pub(crate) fn update_pairs(
    local: &Yaml,
    source: &Yaml,
    local_files: &BTreeSet<String>,
    source_files: &BTreeSet<String>,
) -> Result<BTreeMap<String, String>, String> {
    let root = |config: &Yaml| Declaration {
        logical: ".".into(),
        physical: "index.md".into(),
        directory: false,
        optional: false,
        owned: config["root"]["framework"].as_bool() == Some(true),
        tags: BTreeSet::new(),
        frontmatter: BTreeMap::new(),
    };
    let mut local_rows = vec![root(local)];
    let mut source_rows = vec![root(source)];
    declarations(&local["root"], "", "", &mut local_rows)?;
    declarations(&source["root"], "", "", &mut source_rows)?;
    install_files(source, source_files)?;
    let options = MatchOptions {
        case_sensitive: true,
        require_literal_separator: true,
        require_literal_leading_dot: true,
    };
    let mut pairs = BTreeMap::new();
    for row in &local_rows {
        if !row.owned {
            continue;
        }
        let Some(canonical) = source_rows
            .iter()
            .find(|entry| entry.logical == row.logical && entry.owned)
        else {
            continue;
        };
        let host_selector = if row.directory {
            format!("{}/index.md", row.physical)
        } else {
            row.physical.clone()
        };
        let source_selector = if canonical.directory {
            format!("{}/index.md", canonical.physical)
        } else {
            canonical.physical.clone()
        };
        let pattern = Pattern::new(&host_selector).map_err(|e| e.to_string())?;
        for host in local_files
            .iter()
            .filter(|host| pattern.matches_with(host, options))
        {
            if wildcard(&row.physical)
                && local_rows.iter().any(|entry| {
                    !wildcard(&entry.physical)
                        && (entry.physical == *host
                            || (entry.directory && format!("{}/index.md", entry.physical) == *host))
                })
            {
                continue;
            }
            if !row.directory
                && wildcard(&row.physical)
                && host.ends_with("/index.md")
                && !row.physical.ends_with("/index.md")
            {
                continue;
            }
            let origin = if wildcard(&row.physical) || wildcard(&canonical.physical) {
                if row.physical != canonical.physical {
                    continue;
                }
                host.clone()
            } else {
                source_selector.clone()
            };
            if !source_files.contains(&origin) {
                continue;
            }
            if wildcard(&canonical.physical)
                && source_rows.iter().any(|entry| {
                    !wildcard(&entry.physical)
                        && (entry.physical == origin
                            || (entry.directory
                                && format!("{}/index.md", entry.physical) == origin))
                })
            {
                continue;
            }
            if !host.ends_with(".md")
                || ["bootstrap.md", "migration.md"].contains(&host.as_str())
                || host.starts_with("skills/")
                || host.starts_with("commands/")
            {
                return Err(format!("unsupported framework update target: {host}"));
            }
            if pairs
                .insert(host.clone(), origin.clone())
                .is_some_and(|previous| previous != origin)
            {
                return Err(format!("conflicting update source: {host}"));
            }
        }
    }
    Ok(pairs)
}

/// Selects initial-install files from a remote inventory using the same direct-tree declarations.
pub(crate) fn install_files(
    config: &Yaml,
    inventory: &BTreeSet<String>,
) -> Result<BTreeSet<String>, String> {
    let mut rows = vec![Declaration {
        logical: ".".into(),
        physical: "index.md".into(),
        directory: false,
        optional: false,
        owned: false,
        tags: BTreeSet::new(),
        frontmatter: BTreeMap::new(),
    }];
    declarations(&config["root"], "", "", &mut rows)?;
    let mut directories = BTreeSet::new();
    for file in inventory {
        let mut parent = Path::new(file).parent();
        while let Some(path) = parent.filter(|path| !path.as_os_str().is_empty()) {
            directories.insert(path.to_string_lossy().into_owned());
            parent = path.parent();
        }
    }
    let options = MatchOptions {
        case_sensitive: true,
        require_literal_separator: true,
        require_literal_leading_dot: true,
    };
    let mut selected = BTreeSet::new();
    let mut contracts = BTreeMap::new();
    for row in &rows {
        let pattern = Pattern::new(&row.physical).map_err(|e| e.to_string())?;
        let entries = if row.directory {
            &directories
        } else {
            inventory
        };
        let matches: Vec<_> = entries
            .iter()
            .filter(|path| pattern.matches_with(path, options))
            .collect();
        if matches.is_empty() && !wildcard(&row.physical) && !row.optional {
            return Err(format!(
                "release is missing required config entry: {}",
                row.logical
            ));
        }
        for path in matches {
            if wildcard(&row.physical)
                && rows
                    .iter()
                    .any(|literal| !wildcard(&literal.physical) && literal.physical == *path)
            {
                continue;
            }
            if !row.directory
                && wildcard(&row.physical)
                && Path::new(path)
                    .file_name()
                    .is_some_and(|name| name == "index.md")
                && !row.physical.ends_with("/index.md")
            {
                continue;
            }
            let host = if row.directory {
                format!("{path}/index.md")
            } else {
                path.clone()
            };
            if !inventory.contains(&host) {
                return Err(format!("release is missing directory index: {host}"));
            }
            let signature = (wildcard(&row.physical), row.owned);
            if let Some(previous) = contracts.insert(host.clone(), signature) {
                if !previous.0 || !signature.0 || previous.1 != signature.1 {
                    return Err(format!("release config destination collision: {host}"));
                }
            }
            if ["skills", "commands"]
                .iter()
                .any(|source| host.starts_with(&format!("{source}/")))
                || ["bootstrap.md", "migration.md"].contains(&host.as_str())
            {
                return Err(format!("config selects source-only content: {host}"));
            }
            selected.insert(host);
        }
    }
    selected.insert("config.yaml".into());
    Ok(selected)
}

/// Resolves the complete v9 tree before returning per-host tag sets, enforcing safe paths and collisions.
pub(crate) fn tag_contracts(
    root: &Path,
    config: &Yaml,
) -> Result<BTreeMap<String, BTreeSet<String>>, String> {
    Ok(contracts(root, config)?
        .into_iter()
        .map(|(host, contract)| (host, contract.tags))
        .collect())
}

/// Resolves safe declared hosts with their tag names and entry-specific frontmatter contract.
pub(crate) fn contracts(root: &Path, config: &Yaml) -> Result<BTreeMap<String, Contract>, String> {
    let mut rows = vec![Declaration {
        logical: ".".into(),
        physical: "index.md".into(),
        directory: false,
        optional: false,
        owned: config["root"]["framework"].as_bool().unwrap_or(false),
        tags: names(&config["root"]["tags"]),
        frontmatter: fields(&config["root"]["frontmatter"]),
    }];
    declarations(&config["root"], "", "", &mut rows)?;
    let mut resolved: BTreeMap<String, (bool, bool, Contract)> = BTreeMap::new();
    let mut pillar_hosts = BTreeSet::new();

    for row in &rows {
        let is_glob = wildcard(&row.physical);
        let candidates = if is_glob {
            let pattern = format!(
                "{}/{}",
                Pattern::escape(&root.to_string_lossy()),
                row.physical
            );
            glob_with(
                &pattern,
                MatchOptions {
                    case_sensitive: true,
                    require_literal_separator: true,
                    require_literal_leading_dot: true,
                },
            )
            .map_err(|error| error.to_string())?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|error| error.to_string())?
        } else {
            let path = root.join(&row.physical);
            if path.exists() || crate::paths::is_symlink(&path) {
                vec![path]
            } else {
                Vec::new()
            }
        };
        if candidates.is_empty() && !is_glob && !row.optional {
            return Err(format!("required config entry is missing: {}", row.logical));
        }
        for candidate in candidates {
            if has_symlink_component(root, &candidate) {
                return Err(format!("symlinked config destination: {}", row.logical));
            }
            let rel = candidate
                .strip_prefix(root)
                .map_err(|_| "config destination escapes .cumaru/")?
                .to_string_lossy()
                .into_owned();
            if crate::text::has_control(&rel) {
                return Err(format!(
                    "config destination contains a control character: {}",
                    crate::text::shell_quote(&rel)
                ));
            }
            if is_glob {
                if (!row.directory
                    && candidate.file_name().is_some_and(|name| name == "index.md")
                    && !row.physical.ends_with("/index.md"))
                    || rows
                        .iter()
                        .any(|literal| !wildcard(&literal.physical) && literal.physical == rel)
                {
                    continue;
                }
                if row.directory != candidate.is_dir() {
                    continue;
                }
            }
            if row.directory && !candidate.is_dir() {
                return Err(format!(
                    "config directory is not a directory: {}",
                    row.logical
                ));
            }
            let host = if row.directory {
                candidate.join("index.md")
            } else {
                candidate
            };
            if has_symlink_component(root, &host)
                || !host.is_file()
                || canonical_inside(root, &host).is_none()
            {
                return Err(format!(
                    "config Markdown entry is unsafe or missing: {}",
                    row.logical
                ));
            }
            let rel = host
                .strip_prefix(root)
                .unwrap()
                .to_string_lossy()
                .into_owned();
            if row.directory && row.logical.split('/').count() == 1 {
                pillar_hosts.insert(rel.clone());
            }
            if let Some((previous_glob, previous_owned, contract)) = resolved.get_mut(&rel) {
                if !is_glob || !*previous_glob || row.owned != *previous_owned {
                    return Err(format!("config destination collision: {rel}"));
                }
                contract.tags.extend(row.tags.clone());
                for (field, optional) in &row.frontmatter {
                    if contract
                        .frontmatter
                        .insert(field.clone(), *optional)
                        .is_some_and(|previous| previous != *optional)
                    {
                        return Err(format!("conflicting frontmatter field at {rel}: {field}"));
                    }
                }
            } else {
                resolved.insert(
                    rel,
                    (
                        is_glob,
                        row.owned,
                        Contract {
                            tags: row.tags.clone(),
                            frontmatter: row.frontmatter.clone(),
                        },
                    ),
                );
            }
        }
    }
    for (host, (_, _, contract)) in &mut resolved {
        let mut effective = fields(&config["rules"]["markdown"]["frontmatter"]);
        if host == "index.md" || host.ends_with("/index.md") {
            effective.extend(fields(&config["rules"]["index_md"]["frontmatter"]));
            if pillar_hosts.contains(host) {
                effective.extend(fields(&config["rules"]["pillar_index"]["frontmatter"]));
            }
        }
        effective.extend(contract.frontmatter.clone());
        contract.frontmatter = effective;
    }
    Ok(resolved
        .into_iter()
        .map(|(host, (_, _, contract))| (host, contract))
        .collect())
}

/// Maps a literal logical directory entry to its physical path, honoring `path` overrides without filesystem access.
pub(crate) fn directory_path(config: &Yaml, logical: &str) -> Result<Option<String>, String> {
    let mut rows = Vec::new();
    declarations(&config["root"], "", "", &mut rows)?;

    Ok(rows
        .into_iter()
        .find(|row| row.directory && row.logical == logical && !wildcard(&row.physical))
        .map(|row| row.physical))
}

/// Resolves legacy v8 tag declarations and universal wildcard allowances for an exact host.
pub(crate) fn legacy_tags(config: &Yaml, host: &str) -> (BTreeSet<String>, BTreeSet<String>) {
    let mut expected = BTreeSet::new();
    let mut allowed = BTreeSet::new();
    let node = if host == "index.md" {
        Some(&config["root"]["tags"])
    } else if let Some(pillar) = host.strip_suffix("/index.md").filter(|s| !s.contains('/')) {
        Some(&config["root"]["entities"][pillar]["tags"])
    } else {
        None
    };
    if let Some(tags) = node.and_then(Yaml::as_hash) {
        expected.extend(tags.keys().filter_map(Yaml::as_str).map(String::from));
    }
    if let Some(tags) = config["meta"]["tags"].as_hash() {
        for (name, value) in tags {
            let Some(name) = name.as_str() else {
                continue;
            };
            match value["host_file"].as_str() {
                Some("*") => {
                    allowed.insert(name.into());
                }
                Some(file)
                    if file.ends_with(".md")
                        && (file == host || Some(file) == host.rsplit('/').next()) =>
                {
                    expected.insert(name.into());
                }
                _ => {}
            }
        }
    }
    allowed.extend(expected.clone());
    (expected, allowed)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};
    use yaml_rust2::YamlLoader;

    /// Requires ownership on both logical entries and honors overrides without inheriting ownership.
    #[test]
    fn selects_owned_update_pairs() {
        let source = YamlLoader::load_from_str("root:\n  framework: true\n  area:\n    framework: true\n    a.md: {framework: true}\n    b.md: {}\n    '*.md': {framework: true}\n").unwrap().remove(0);
        let local = YamlLoader::load_from_str("root:\n  framework: true\n  area:\n    path: renamed\n    framework: true\n    a.md: {framework: true}\n    b.md: {framework: true}\n    local.md: {}\n").unwrap().remove(0);
        let source_files = BTreeSet::from(
            ["index.md", "area/index.md", "area/a.md", "area/b.md"].map(String::from),
        );
        let local_files = BTreeSet::from(
            [
                "index.md",
                "renamed/index.md",
                "renamed/a.md",
                "renamed/b.md",
                "renamed/local.md",
            ]
            .map(String::from),
        );
        let pairs = update_pairs(&local, &source, &local_files, &source_files).unwrap();
        assert_eq!(pairs["renamed/a.md"], "area/a.md");
        assert_eq!(pairs["renamed/index.md"], "area/index.md");
        assert!(!pairs.contains_key("renamed/b.md"));
        assert!(!pairs.contains_key("renamed/local.md"));
    }

    struct Fixture(std::path::PathBuf);

    impl Fixture {
        /// Creates an isolated selector tree, including a metacharacter in its root path.
        fn new() -> Self {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let root =
                std::env::temp_dir().join(format!("cumaru-tags[{}]-{nonce}", std::process::id()));
            fs::create_dir_all(root.join("renamed")).unwrap();
            for file in [
                "index.md",
                "renamed/index.md",
                "renamed/a.md",
                "renamed/special.md",
            ] {
                fs::write(root.join(file), "body").unwrap();
            }
            Self(fs::canonicalize(root).unwrap())
        }
    }

    impl Drop for Fixture {
        /// Removes only this fixture's temporary tree.
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    /// Protects path overrides, literal precedence, wildcard composition, and index exclusion.
    #[test]
    fn resolves_tag_selectors() {
        let fixture = Fixture::new();
        let config = YamlLoader::load_from_str("root:\n  tags: [root]\n  pillar:\n    path: renamed\n    tags: [pillar]\n    '*.md': {tags: [wild]}\n    'a*.md': {tags: [extra]}\n    special.md: {tags: [literal]}\n  absent: {optional: true}\n").unwrap().remove(0);
        let result = tag_contracts(&fixture.0, &config).unwrap();
        assert_eq!(
            result["renamed/index.md"],
            BTreeSet::from(["pillar".into()])
        );
        assert_eq!(
            result["renamed/a.md"],
            BTreeSet::from(["wild".into(), "extra".into()])
        );
        assert_eq!(
            result["renamed/special.md"],
            BTreeSet::from(["literal".into()])
        );
    }

    /// Rejects missing required entries, unsafe paths, and physical collisions before tag lookup.
    #[test]
    fn rejects_invalid_tree() {
        let fixture = Fixture::new();
        for config in [
            "root: {missing: {}}",
            "root: {bad: {path: ../outside}}",
            "root: {a: {path: renamed}, b: {path: renamed}}",
        ] {
            let config = YamlLoader::load_from_str(config).unwrap().remove(0);
            assert!(tag_contracts(&fixture.0, &config).is_err());
        }
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(fixture.0.join("renamed"), fixture.0.join("link")).unwrap();
            let config = YamlLoader::load_from_str("root: {link: {}}")
                .unwrap()
                .remove(0);
            assert!(tag_contracts(&fixture.0, &config).is_err());
        }
    }

    /// Seeds configured adopter paths and templates while excluding unconfigured source-only files.
    #[test]
    fn selects_initial_domain_files() {
        let inventory = BTreeSet::from(
            [
                "index.md",
                "config.yaml",
                "domain.md",
                "plans/index.md",
                "plans/a/index.md",
                "plans/a/t1.md",
                "templates/index.md",
                "templates/one.md",
                "bootstrap.md",
                "skills/cumaru-test/SKILL.md",
            ]
            .map(String::from),
        );
        let config = YamlLoader::load_from_str("root:\n  domain.md: {}\n  plans:\n    '*': {'t*.md': {}}\n  templates: {'*.md': {}}\n  absent: {optional: true}\n").unwrap().remove(0);
        let selected = install_files(&config, &inventory).unwrap();
        assert!(selected.contains("plans/a/t1.md"));
        assert!(selected.contains("plans/a/index.md"));
        assert!(selected.contains("templates/one.md"));
        assert!(!selected.contains("bootstrap.md"));
        assert!(!selected.iter().any(|path| path.starts_with("skills/")));
        let config = YamlLoader::load_from_str("root: {missing.md: {}}")
            .unwrap()
            .remove(0);
        assert!(install_files(&config, &inventory).is_err());
    }
}
