//! `cumaru tree`: filesystem-backed navigation for `.cumaru/`.
//!
//! The filesystem supplies structural candidates and Markdown frontmatter
//! supplies summaries. Symlinks are never followed and Markdown bodies are
//! never read: frontmatter extraction stops at the closing `---` fence.
//!
//! Port of `src/cmd_tree.sh` with two deliberate differences: no `--domain`
//! guard, and a v9 `--pillars` filter resolves only the requested pillars
//! instead of failing when any other config entry does not resolve.

use std::fs;
use std::io::{self, BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use clap::Args;
use yaml_rust2::{Yaml, YamlLoader};

use crate::paths::{CONFIG_FILE, CUMARU_DIR};

const RESERVED_KEYS: [&str; 5] = ["path", "optional", "framework", "frontmatter", "tags"];
const SUMMARY_MIN: usize = 32;
const SUMMARY_MAX: usize = 512;

/// Arguments for `cumaru tree`.
#[derive(Args)]
#[command(
    override_usage = "cumaru tree [<directory-or-md>] [--deep] [--rows] [--pillars <name[,name...]>]",
    args_override_self = true
)]
pub struct TreeArgs {
    /// Directory or Markdown file relative to .cumaru/; a Markdown file is normalized to its parent.
    #[arg(value_name = "directory-or-md")]
    target: Option<String>,

    /// Recursively inspect all non-hidden descendants and report every defect.
    #[arg(long)]
    deep: bool,

    /// Emit path<TAB>summary TSV instead of a Markdown table.
    #[arg(long)]
    rows: bool,

    /// Restrict navigation to comma-separated schema-declared pillars.
    #[arg(long, value_name = "name[,name...]")]
    pillars: Option<String>,
}

/// State accumulated by one traversal: valid candidate rows and diagnostics.
struct Walk {
    root: PathBuf,
    pillars: Vec<String>,
    records: Vec<String>,
    diagnostics: Vec<String>,
}

/// Runs `cumaru tree` and maps the outcome to the documented exit codes.
pub fn run(args: TreeArgs) -> ExitCode {
    if args.pillars.as_deref() == Some("") {
        eprintln!("cumaru tree: --pillars requires a value");
        return ExitCode::from(2);
    }

    match execute(&args) {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(message) => {
            eprintln!("cumaru tree: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Validates inputs, walks the target, and prints results; returns whether the walk was clean.
fn execute(args: &TreeArgs) -> Result<bool, String> {
    let target = normalize_target(args.target.as_deref());
    validate_target_syntax(&target)?;

    let cumaru = Path::new(CUMARU_DIR);
    if is_symlink(cumaru) {
        return Err(".cumaru/ must not be a symlink".into());
    }
    if !cumaru.is_dir() {
        return Err(".cumaru/ not found; run `cumaru install` first".into());
    }
    let root = fs::canonicalize(cumaru).map_err(|_| "cannot resolve .cumaru/".to_string())?;

    let pillars = match &args.pillars {
        Some(requested) => validate_pillars(&root, requested)?,
        None => Vec::new(),
    };
    if target != "." && !matches_pillars(&pillars, &target) {
        return Err(format!(
            "target is outside the selected pillars: {}",
            quote(&target)
        ));
    }

    let target_dir = resolve_target(&root, &target)?;

    let mut walk = Walk {
        root,
        pillars,
        records: Vec::new(),
        diagnostics: Vec::new(),
    };
    if args.deep {
        walk.deep(&target_dir);
    } else {
        walk.shallow(&target_dir)?;
    }

    emit(&mut walk.records, args.rows);

    walk.diagnostics.sort();
    for line in &walk.diagnostics {
        eprintln!("{line}");
    }

    Ok(walk.diagnostics.is_empty())
}

/// Defaults an omitted target to the root and strips trailing slashes.
fn normalize_target(target: Option<&str>) -> String {
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

/// Rejects absolute, control-character, `..`, and hidden target paths before any filesystem access.
fn validate_target_syntax(target: &str) -> Result<(), String> {
    if target.starts_with('/') {
        return Err(format!(
            "target must be relative to .cumaru/: {}",
            quote(target)
        ));
    }
    if has_control(target) {
        return Err(format!(
            "target path contains a control character: {}",
            quote(target)
        ));
    }

    for segment in target.split('/') {
        if segment == ".." {
            return Err(format!(
                "`..` path segments are not allowed: {}",
                quote(target)
            ));
        }
        if segment.starts_with('.') && segment != "." {
            return Err(format!(
                "hidden target paths are not allowed: {}",
                quote(target)
            ));
        }
    }

    Ok(())
}

/// Validates the pillar filter against `.cumaru/config.yaml` and returns the physical pillar directories.
fn validate_pillars(root: &Path, requested: &str) -> Result<Vec<String>, String> {
    let config = root.join(CONFIG_FILE);
    if is_symlink(&config) || !config.is_file() {
        return Err("filters require a regular .cumaru/config.yaml".into());
    }

    let unreadable = || "cannot read domain from .cumaru/config.yaml".to_string();
    let text = fs::read_to_string(&config).map_err(|_| unreadable())?;
    let doc = YamlLoader::load_from_str(&text)
        .map_err(|_| unreadable())?
        .into_iter()
        .next()
        .unwrap_or(Yaml::Null);

    let domain = match &doc["domain"] {
        Yaml::String(domain) if !domain.is_empty() => domain.clone(),
        _ => return Err("config domain must be a non-empty string".into()),
    };
    let is_v9 = doc["version"].as_i64() == Some(9);

    let mut physical_dirs: Vec<String> = Vec::new();
    for pillar in requested.split(',') {
        let valid = !pillar.is_empty()
            && pillar
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-');
        if !valid {
            return Err(format!("invalid pillar filter: {}", quote(requested)));
        }

        let physical = if is_v9 {
            resolve_v9_pillar(root, &doc, pillar, &domain)?
        } else {
            resolve_legacy_pillar(&doc, pillar, &domain)?
        };
        if !physical_dirs.contains(&physical) {
            physical_dirs.push(physical);
        }
    }

    Ok(physical_dirs)
}

/// Resolves a v9 top-level `root` selector to its directory, which must hold a regular `index.md`.
fn resolve_v9_pillar(
    root: &Path,
    doc: &Yaml,
    pillar: &str,
    domain: &str,
) -> Result<String, String> {
    let entry = &doc["root"][pillar];
    if RESERVED_KEYS.contains(&pillar) || entry.is_badvalue() {
        return Err(format!(
            "unknown pillar for domain {}: {}",
            quote(domain),
            quote(pillar)
        ));
    }

    let physical = entry["path"].as_str().unwrap_or(pillar).to_string();
    let safe = !physical.is_empty()
        && !physical.starts_with('/')
        && physical
            .split('/')
            .all(|part| !part.is_empty() && part != "." && part != "..");
    let index = root.join(&physical).join("index.md");
    let resolved = safe
        && !has_symlink_component(root, &index)
        && index.is_file()
        && canonical_inside(root, &index).is_some();
    if !resolved {
        return Err(format!(
            "cannot resolve pillar for domain {}: {}",
            quote(domain),
            quote(pillar)
        ));
    }

    Ok(physical)
}

/// Resolves a pre-v9 pillar declared under `root.entities`; its directory name is the pillar name.
fn resolve_legacy_pillar(doc: &Yaml, pillar: &str, domain: &str) -> Result<String, String> {
    let declared = doc["root"]["entities"]
        .as_hash()
        .is_some_and(|entities| entities.contains_key(&Yaml::String(pillar.to_string())));
    if !declared {
        return Err(format!(
            "unknown pillar for domain {}: {}",
            quote(domain),
            quote(pillar)
        ));
    }

    Ok(pillar.to_string())
}

/// True when a `.cumaru/`-relative path starts inside a selected pillar; an empty filter admits all paths.
fn matches_pillars(pillars: &[String], rel: &str) -> bool {
    if pillars.is_empty() {
        return true;
    }

    let mut rel = rel;
    while let Some(rest) = rel.strip_prefix("./") {
        rel = rest;
    }
    let first = rel.trim_end_matches('/').split('/').next().unwrap_or("");

    pillars.iter().any(|pillar| pillar == first)
}

/// Resolves the target to the directory to walk; a Markdown file target becomes its parent.
fn resolve_target(root: &Path, target: &str) -> Result<PathBuf, String> {
    let candidate = if target == "." {
        root.to_path_buf()
    } else {
        root.join(target)
    };
    if has_symlink_component(root, &candidate) {
        return Err(format!("target contains a symlink: {}", quote(target)));
    }

    let unsafe_target = || {
        format!(
            "target does not resolve safely inside .cumaru/: {}",
            quote(target)
        )
    };
    if candidate.is_dir() {
        return canonical_inside(root, &candidate).ok_or_else(unsafe_target);
    }
    if candidate.is_file() {
        if !target.ends_with(".md") {
            return Err(format!("file target must end in .md: {}", quote(target)));
        }
        let canonical = canonical_inside(root, &candidate).ok_or_else(unsafe_target)?;
        return Ok(canonical.parent().unwrap_or(root).to_path_buf());
    }

    if candidate.exists() {
        return Err(format!(
            "target must be a directory or Markdown file: {}",
            quote(target)
        ));
    }
    Err(format!("target not found: {}", quote(target)))
}

impl Walk {
    /// Lists direct Markdown files and indexed child directories; the target itself needs a regular `index.md`.
    fn shallow(&mut self, target: &Path) -> Result<(), String> {
        let target_index = target.join("index.md");
        let target_index_rel = self.rel(&target_index);
        if is_symlink(&target_index) {
            return Err(format!(
                "target index is a symlink: {}",
                quote(&target_index_rel)
            ));
        }
        if !target_index.is_file()
            || has_symlink_component(&self.root, &target_index)
            || canonical_inside(&self.root, &target_index).is_none()
        {
            return Err(format!(
                "target requires a regular index.md: {}",
                quote(&target_index_rel)
            ));
        }

        for path in self.list(target) {
            let base = file_name(&path);
            if base.starts_with('.') {
                continue;
            }
            let rel = self.rel(&path);
            if !matches_pillars(&self.pillars, &rel) || !self.admit(&path, &rel) {
                continue;
            }

            if path.is_dir() {
                let Some(canonical) = self.safe_dir(&path, &rel) else {
                    continue;
                };
                let index = canonical.join("index.md");
                let index_rel = format!("{rel}/index.md");
                if is_symlink(&index) {
                    self.diag(&index_rel, "symlinks are not supported");
                } else if index.is_file() {
                    self.add_candidate(&format!("{rel}/"), &index, &index_rel);
                }
            } else if path.is_file() && base.ends_with(".md") && base != "index.md" {
                self.add_candidate(&rel, &path, &rel);
            }
        }

        Ok(())
    }

    /// Recursively audits every non-hidden descendant, collecting all defects instead of stopping.
    fn deep(&mut self, target: &Path) {
        let target_index = target.join("index.md");
        if !is_symlink(&target_index) && !target_index.is_file() {
            let rel = self.rel(&target_index);
            self.diag(&rel, "directory is missing a regular index.md");
        }

        self.descend(target, target);
    }

    /// Visits one directory level of the deep walk; hidden entries are pruned and symlinks never followed.
    fn descend(&mut self, dir: &Path, target: &Path) {
        for path in self.list(dir) {
            let base = file_name(&path);
            if base.starts_with('.') {
                continue;
            }

            self.inspect_deep(&path, &base, target);

            if !is_symlink(&path) && path.is_dir() {
                self.descend(&path, target);
            }
        }
    }

    /// Classifies one deep-walk entry: directories need an index, `index.md` represents its directory.
    fn inspect_deep(&mut self, path: &Path, base: &str, target: &Path) {
        let rel = self.rel(path);
        if !matches_pillars(&self.pillars, &rel) || !self.admit(path, &rel) {
            return;
        }

        if path.is_dir() {
            let Some(canonical) = self.safe_dir(path, &rel) else {
                return;
            };
            let index = canonical.join("index.md");
            if !is_symlink(&index) && !index.is_file() {
                self.diag(
                    &format!("{rel}/index.md"),
                    "directory is missing a regular index.md",
                );
            }
            return;
        }
        if !path.is_file() || !base.ends_with(".md") {
            return;
        }

        if base != "index.md" {
            self.add_candidate(&rel, path, &rel);
            return;
        }

        let parent = path.parent().unwrap_or(target);
        if parent != target {
            let parent_rel = self.rel(parent);
            self.add_candidate(&format!("{parent_rel}/"), path, &rel);
            return;
        }

        match self.safe_file(path) {
            Some(canonical) => {
                self.summary(&canonical, &rel);
            }
            None => self.diag(&rel, "file does not resolve safely inside .cumaru/"),
        }
    }

    /// Validates a candidate's source and records `path<TAB>summary` when its summary is valid.
    fn add_candidate(&mut self, output: &str, source: &Path, source_rel: &str) {
        if has_control(output) {
            self.diag(output, "candidate path contains a control character");
            return;
        }
        if has_symlink_component(&self.root, source) {
            self.diag(source_rel, "symlinks are not supported");
            return;
        }

        let Some(canonical) = self.safe_file(source) else {
            self.diag(source_rel, "file does not resolve safely inside .cumaru/");
            return;
        };
        if let Some(summary) = self.summary(&canonical, source_rel) {
            self.records.push(format!("{output}\t{summary}"));
        }
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

    /// Rejects symlinks and control-character paths, reporting both defects when both apply.
    fn admit(&mut self, path: &Path, rel: &str) -> bool {
        if is_symlink(path) {
            self.diag(rel, "symlinks are not supported");
            if has_control(rel) {
                self.diag(rel, "candidate path contains a control character");
            }
            return false;
        }
        if has_control(rel) {
            self.diag(rel, "candidate path contains a control character");
            return false;
        }

        true
    }

    /// Returns the canonical directory when it resolves inside the root without symlinks.
    fn safe_dir(&mut self, path: &Path, rel: &str) -> Option<PathBuf> {
        let canonical = if has_symlink_component(&self.root, path) {
            None
        } else {
            canonical_inside(&self.root, path)
        };
        if canonical.is_none() {
            self.diag(
                &format!("{rel}/"),
                "directory does not resolve safely inside .cumaru/",
            );
        }

        canonical
    }

    /// Returns the canonical file when it resolves inside the root without symlinks.
    fn safe_file(&self, path: &Path) -> Option<PathBuf> {
        if has_symlink_component(&self.root, path) {
            return None;
        }

        canonical_inside(&self.root, path)
    }

    /// Returns the directory entries, recording a diagnostic when the listing is incomplete.
    fn list(&mut self, dir: &Path) -> Vec<PathBuf> {
        let mut paths = Vec::new();
        let mut complete = true;

        match fs::read_dir(dir) {
            Ok(entries) => {
                for entry in entries {
                    match entry {
                        Ok(entry) => paths.push(entry.path()),
                        Err(_) => complete = false,
                    }
                }
            }
            Err(_) => complete = false,
        }

        if !complete {
            let rel = self.rel(dir);
            self.diag(&rel, "could not completely inspect directory");
        }

        paths
    }

    /// Records one sorted-later diagnostic line for stderr.
    fn diag(&mut self, rel: &str, message: &str) {
        self.diagnostics
            .push(format!("cumaru tree: {}: {message}", quote(rel)));
    }

    /// Returns a path relative to `.cumaru/`, or `.` for the root itself.
    fn rel(&self, path: &Path) -> String {
        match path.strip_prefix(&self.root) {
            Ok(rel) if rel.as_os_str().is_empty() => ".".to_string(),
            Ok(rel) => rel.to_string_lossy().into_owned(),
            Err(_) => path.to_string_lossy().into_owned(),
        }
    }
}

/// Returns the YAML between a leading `---` fence and the next `---`, never reading past it.
///
/// A file without a leading fence yields empty YAML, which has no summary.
fn read_frontmatter(file: &Path) -> io::Result<String> {
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

/// Prints sorted records as TSV rows or as an escaped Markdown table; stops quietly on a closed pipe.
fn emit(records: &mut [String], rows: bool) {
    records.sort();
    let mut out = io::stdout().lock();

    if rows {
        for record in records.iter() {
            if writeln!(out, "{record}").is_err() {
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

/// Escapes backslashes and pipes so a value stays inside one Markdown table cell.
fn markdown_escape(value: &str) -> String {
    value.replace('\\', "\\\\").replace('|', "\\|")
}

/// Quotes a path for diagnostics like bash `printf %q`, so control characters never reach stderr raw.
fn quote(value: &str) -> String {
    if value.is_empty() {
        return "''".to_string();
    }

    if has_control(value) {
        let mut quoted = String::from("$'");
        for c in value.chars() {
            match c {
                '\n' => quoted.push_str("\\n"),
                '\t' => quoted.push_str("\\t"),
                '\r' => quoted.push_str("\\r"),
                '\'' => quoted.push_str("\\'"),
                '\\' => quoted.push_str("\\\\"),
                c if is_control(c) => quoted.push_str(&format!("\\{:03o}", c as u32)),
                c => quoted.push(c),
            }
        }
        quoted.push('\'');
        return quoted;
    }

    let mut quoted = String::new();
    for (index, c) in value.chars().enumerate() {
        let safe = !c.is_ascii()
            || c.is_ascii_alphanumeric()
            || "_-./:@%+=~".contains(c)
            || (c == '#' && index > 0);
        if safe {
            quoted.push(c);
        } else {
            quoted.push('\\');
            quoted.push(c);
        }
    }

    quoted
}

/// True for C0 control characters and DEL.
fn is_control(c: char) -> bool {
    c < ' ' || c == '\x7f'
}

/// True when any character of the value is a C0 control character or DEL.
fn has_control(value: &str) -> bool {
    value.chars().any(is_control)
}

/// True when the path itself is a symlink (the link is inspected, not its target).
fn is_symlink(path: &Path) -> bool {
    fs::symlink_metadata(path).is_ok_and(|meta| meta.file_type().is_symlink())
}

/// True when any component below the root is a symlink, or when the path is outside the root.
fn has_symlink_component(root: &Path, path: &Path) -> bool {
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
fn canonical_inside(root: &Path, path: &Path) -> Option<PathBuf> {
    fs::canonicalize(path)
        .ok()
        .filter(|canonical| canonical.starts_with(root))
}

/// Returns the final path component as text.
fn file_name(path: &Path) -> String {
    path.file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default()
}
