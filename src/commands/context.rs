//! Query relevance ranking with an optional encoder and its project-local vector cache.

use clap::Args;
use std::{
    collections::HashSet,
    fs,
    io::{self, Write},
    path::{Component, Path, PathBuf},
    process::ExitCode,
};

use crate::{
    models,
    relevance::{Query, Scorer},
    walk::Walk,
};

/// Ranked rows printed by default; `--full` prints all.
const LIMIT: usize = 16;

/// Per-file byte budget; framework/adopter files over it are diagnosed, source files skipped.
const BUDGET: u64 = 1024 * 1024;

/// One vector-cache scope, configured by `meta.context` in `.cumaru/config.yaml`.
#[derive(Clone, Copy, PartialEq, Eq, clap::ValueEnum)]
pub(crate) enum Scope {
    Framework,
    Adopter,
    Source,
}

impl Scope {
    /// Every scope, in processing order.
    const ALL: [Scope; 3] = [Scope::Framework, Scope::Adopter, Scope::Source];

    /// Returns the scope's config key and cache directory name.
    fn name(self) -> &'static str {
        match self {
            Scope::Framework => "framework",
            Scope::Adopter => "adopter",
            Scope::Source => "source",
        }
    }
}

#[derive(Args)]
pub struct ContextArgs {
    /// English query to rank the files configured by meta.context (all visible .cumaru/ Markdown without it).
    #[arg(value_name = "QUERY")]
    query: Option<String>,

    /// Build or refresh the encoder vector cache without ranking (no QUERY needed).
    #[arg(long)]
    warm: bool,

    /// Delete the vector cache and rebuild it from scratch; ranks too when a QUERY is given.
    #[arg(long)]
    reset: bool,

    /// Print every ranked file instead of the best LIMIT.
    #[arg(long)]
    full: bool,

    /// Restrict ranking, --warm, and --reset to one scope (all scopes by default).
    #[arg(long, value_enum)]
    scope: Option<Scope>,
}

/// Rank configured scopes without installing models; an enabled encoder reuses and refreshes `.cumaru/.cache/context/<scope>/` vectors.
pub fn run(args: ContextArgs) -> ExitCode {
    let query = args.query.as_deref();
    if query.is_none() && !args.warm && !args.reset {
        eprintln!("cumaru context: a QUERY is required unless --warm or --reset is given");
        return ExitCode::from(2);
    }

    match execute(
        query,
        Path::new(crate::config::CUMARU_DIR),
        &models::cache_root(),
        args.reset,
        (!args.full).then_some(LIMIT),
        args.scope,
    ) {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(error) => {
            eprintln!("cumaru context: {error}");
            ExitCode::FAILURE
        }
    }
}

/// Builds the vector cache of one scope (or every scope) for `project` when an encoder is enabled.
///
/// Returns an error for cache/encoder failures and for partial failures (such as a missing listed path),
/// whose diagnostics were already printed; no enabled encoder is not an error.
pub(crate) fn warm(project: &Path, scope: Option<Scope>) -> Result<(), String> {
    match execute(None, project, &models::cache_root(), false, None, scope)? {
        true => Ok(()),
        false => Err("partial failure; see the diagnostics above".into()),
    }
}

/// Widens a paragraph range to the innermost `map` section that contains it, or keeps it when none does.
fn section(file: &Path, (start, end): models::Lines) -> models::Lines {
    crate::markdown::read_headings(file)
        .unwrap_or_default()
        .into_iter()
        .filter(|(first, last, _)| *first <= start && *last >= end)
        .max_by_key(|(first, _, _)| *first)
        .map_or((start, end), |(first, last, _)| (first, last))
}

/// Collect safe hosts per scope, refresh each scope's vector cache with progress, and emit bounded two-decimal ranking TSV for a query.
fn execute(
    query: Option<&str>,
    project: &Path,
    cache: &Result<PathBuf, String>,
    reset: bool,
    limit: Option<usize>,
    scope: Option<Scope>,
) -> Result<bool, String> {
    let prepared = query.map(Query::new).transpose()?;

    if crate::paths::is_symlink(project) || !project.is_dir() {
        return Err(".cumaru/ not found or is a symlink".into());
    }

    let root = fs::canonicalize(project).map_err(|e| e.to_string())?;
    let plan = resolve(&root)?;
    let encoder = models::local(cache.as_ref().map_err(Clone::clone)?)?;

    // Listed paths are checked even when there is nothing to cache, so a warm still reports them.
    let mut diagnostics = Vec::new();
    let hosts = inventory(&root, plan.as_ref(), scope, &mut diagnostics)?;
    if query.is_none() && encoder.is_none() {
        eprintln!(
            "cumaru context: no enabled encoder; nothing to cache (enable one with cumaru model pull)"
        );
        return Ok(emit(diagnostics));
    }

    let vector = match (&encoder, query) {
        (Some(encoder), Some(query)) => Some(encoder.embed(query)?),
        _ => None,
    };
    let scorer = Scorer::new(
        [
            1.6516180059844272,
            -0.29166447445653965,
            7.092405754054716,
            1.0572771405692523,
            2.135778445663964,
            -8.433062931187917,
        ],
        0.046831893207445977,
    )?;
    eprintln!(
        "cumaru context: backend={} (experimental relevance scale)",
        if encoder.is_some() {
            "bge-micro-v2"
        } else {
            "lightweight"
        }
    );

    if reset {
        crate::vectors::Cache::reset(&root, scope.map(Scope::name))?;
    }

    let mut records = Vec::new();
    for current in Scope::ALL {
        if scope.is_some_and(|scope| scope != current) {
            continue;
        }

        let scoped: Vec<_> = hosts.iter().filter(|host| host.0 == current).collect();
        let mut cache = encoder
            .as_ref()
            .map(|encoder| crate::vectors::Cache::load(&root, current.name(), encoder));
        let mut progress = Progress::new(
            scoped.len(),
            crate::vectors::Cache::directory(&root, current.name()),
        );

        for (index, (_, path, file)) in scoped.into_iter().enumerate() {
            let markdown = path.ends_with(".md");
            let evaluated = (|| {
                let document = if current == Scope::Source {
                    // Binary or non-UTF-8 source files are skipped silently.
                    match String::from_utf8(fs::read(file).map_err(|e| e.to_string())?) {
                        Ok(text) if !text.contains('\0') => text,
                        _ => return Ok(None),
                    }
                } else {
                    if fs::metadata(file).map_err(|e| e.to_string())?.len() > BUDGET {
                        return Err("document exceeds the 1-MiB budget".into());
                    }
                    fs::read_to_string(file).map_err(|e| e.to_string())?
                };

                let whole = (1, document.lines().count());
                let widen = |lines| {
                    if markdown {
                        section(file, lines)
                    } else {
                        lines
                    }
                };
                let (score, lines) = match (&encoder, cache.as_mut()) {
                    (Some(encoder), Some(cache)) => {
                        let (keys, added) = cache.embed(encoder, &document)?;
                        progress.file(index, path, added);
                        match &vector {
                            Some(vector) => {
                                let (score, lines) = cache.score(&keys, vector)?;
                                (score, lines.map_or(whole, widen))
                            }
                            None => (0.0, whole),
                        }
                    }
                    _ => match &prepared {
                        Some(prepared) => (scorer.score(prepared, &document)?, whole),
                        None => (0.0, whole),
                    },
                };

                Ok::<_, String>(Some(((score * 100.0).round() as u16, lines)))
            })();

            match evaluated {
                Ok(Some((score, (start, end)))) => {
                    let selector = if end == 0 {
                        path.clone()
                    } else {
                        crate::commands::get::selector(path, start, end)
                    };
                    records.push((selector, score));
                }
                Ok(None) => {}
                Err(error) => {
                    diagnostics.push(format!("{}: {error}", crate::text::shell_quote(path)))
                }
            }
        }

        // A cache write failure only costs speed on the next run, so it warns instead of failing.
        let total = cache.as_ref().map_or(0, crate::vectors::Cache::len);
        if let Some(Err(error)) = cache.map(crate::vectors::Cache::save) {
            eprintln!("cumaru context: vector cache not saved: {error}");
        }
        progress.finish(total, query.is_none());
    }

    if query.is_some() {
        records.sort_by(|left, right| {
            right
                .1
                .cmp(&left.1)
                .then_with(|| left.0.as_bytes().cmp(right.0.as_bytes()))
        });
        let stdout = io::stdout();
        let mut out = stdout.lock();

        for (path, score) in records.into_iter().take(limit.unwrap_or(usize::MAX)) {
            let score = format!("{:.2}", f64::from(score) / 100.0);
            crate::tsv::write_row(&mut out, [path.as_str(), score.as_str()])
                .map_err(|e| e.to_string())?;
        }

        out.flush().map_err(|e| e.to_string())?;
    }

    Ok(emit(diagnostics))
}

/// Prints sorted, deduplicated diagnostics on stderr and returns whether there were none.
fn emit(mut diagnostics: Vec<String>) -> bool {
    diagnostics.sort();
    diagnostics.dedup();

    for diagnostic in &diagnostics {
        eprintln!("cumaru context: {diagnostic}");
    }

    diagnostics.is_empty()
}

/// Configured `meta.context` entries per scope, normalized and validated.
struct Plan {
    framework: Vec<String>,
    adopter: Vec<String>,
    source: Vec<String>,
}

/// Reads `meta.context` from `.cumaru/config.yaml`; a missing or unreadable config, or no `meta.context`, yields `None` (config-free).
fn resolve(root: &Path) -> Result<Option<Plan>, String> {
    let config = root.join(crate::config::CONFIG_FILE);
    if crate::paths::is_symlink(&config) || !config.is_file() {
        return Ok(None);
    }
    let Ok(text) = fs::read_to_string(&config) else {
        return Ok(None);
    };

    let doc = crate::config::parse(&text)?;
    let context = &doc["meta"]["context"];
    if context.as_hash().is_none() {
        return Ok(None);
    }

    let project = root.parent().ok_or(".cumaru/ has no parent directory")?;
    let list = |scope: Scope, base: &Path| -> Result<Vec<String>, String> {
        let mut entries = Vec::new();
        for value in context[scope.name()].as_vec().into_iter().flatten() {
            let raw = value.as_str().unwrap_or_default();
            entries.push(entry(base, scope, raw)?);
        }

        Ok(entries)
    };

    Ok(Some(Plan {
        framework: list(Scope::Framework, root)?,
        adopter: list(Scope::Adopter, root)?,
        source: list(Scope::Source, project)?,
    }))
}

/// Normalizes one `meta.context` entry, rejecting absolute, parent, and (inside `.cumaru/`) symlinked paths as configuration errors.
fn entry(base: &Path, scope: Scope, raw: &str) -> Result<String, String> {
    let invalid = |reason: &str| {
        Err(format!(
            "invalid .cumaru/config.yaml: meta.context.{} entry {} {reason}",
            scope.name(),
            crate::text::shell_quote(raw)
        ))
    };

    let path = Path::new(raw);
    if raw.is_empty() || raw.starts_with('/') || path.is_absolute() {
        return invalid("must be a relative path");
    }
    if path.components().any(|c| c == Component::ParentDir) {
        return invalid("must not contain `..` segments");
    }

    let normalized = path
        .components()
        .filter(|c| *c != Component::CurDir)
        .map(|c| c.as_os_str().to_string_lossy().into_owned())
        .collect::<Vec<_>>()
        .join("/");

    let target = base.join(&normalized);
    if scope != Scope::Source
        && fs::symlink_metadata(&target).is_ok()
        && (crate::paths::has_symlink_component(base, &target)
            || crate::paths::canonical_inside(base, &target).is_none())
    {
        return invalid("must resolve inside .cumaru/ without symlinks");
    }

    Ok(normalized)
}

/// True when the normalized `entry` is `rel` itself or one of its ancestor directories.
fn covers(entry: &str, rel: &str) -> bool {
    entry.is_empty()
        || rel == entry
        || rel
            .strip_prefix(entry)
            .is_some_and(|rest| rest.starts_with('/'))
}

/// Collects `(scope, selector path, file)` hosts for the selected scopes, recording traversal defects and missing listed paths.
fn inventory(
    root: &Path,
    plan: Option<&Plan>,
    scope: Option<Scope>,
    diagnostics: &mut Vec<String>,
) -> Result<Vec<(Scope, String, PathBuf)>, String> {
    let selected = |candidate: Scope| scope.is_none_or(|scope| scope == candidate);
    let mut hosts = Vec::new();
    let mut seen = HashSet::new();

    let entries: Vec<(&str, Scope)> = plan.map_or_else(Vec::new, |plan| {
        let framework = plan
            .framework
            .iter()
            .map(|e| (e.as_str(), Scope::Framework));
        framework
            .chain(plan.adopter.iter().map(|e| (e.as_str(), Scope::Adopter)))
            .collect()
    });
    let mut targets = Vec::new();
    match plan {
        None if selected(Scope::Adopter) => targets.push(root.to_path_buf()),
        None => {}
        Some(_) => {
            for (entry, owner) in entries.iter().filter(|(_, owner)| selected(*owner)) {
                let target = root.join(entry);
                if fs::symlink_metadata(&target).is_ok() {
                    targets.push(target);
                } else {
                    diagnostics.push(missing(*owner, entry));
                }
            }
        }
    }

    let defects = Walk { root, deep: true }.run(
        &targets,
        |path| crate::paths::file_name(path).ends_with(".md"),
        |found| {
            if found.is_dir || !seen.insert(found.path.to_path_buf()) {
                return Ok(());
            }

            let rel = found
                .path
                .strip_prefix(root)
                .map_err(|e| e.to_string())?
                .to_string_lossy()
                .into_owned();
            let owner = match plan {
                None => Some(Scope::Adopter),
                Some(_) => entries
                    .iter()
                    .filter(|(entry, _)| covers(entry, &rel))
                    .max_by_key(|(entry, _)| entry.len())
                    .map(|(_, owner)| *owner),
            };
            if let Some(owner) = owner.filter(|owner| selected(*owner)) {
                hosts.push((owner, rel, found.path.to_path_buf()));
            }

            Ok(())
        },
    )?;
    report(defects, root, "", diagnostics);

    if let Some(plan) = plan.filter(|_| selected(Scope::Source)) {
        let project = root.parent().ok_or(".cumaru/ has no parent directory")?;
        let mut targets = Vec::new();
        let mut literals = Vec::new();
        let mut patterns = Vec::new();
        for entry in &plan.source {
            let (base, pattern) = match glob_base(entry) {
                Some(base) => {
                    let pattern = glob::Pattern::new(entry).map_err(|error| {
                        format!(
                            "invalid .cumaru/config.yaml: meta.context.source glob {}: {error}",
                            crate::text::shell_quote(entry)
                        )
                    })?;
                    (base, Some(pattern))
                }
                None => (entry.as_str(), None),
            };

            let target = project.join(base);
            if fs::symlink_metadata(&target).is_err() {
                diagnostics.push(missing(Scope::Source, base));
                continue;
            }

            match pattern {
                Some(pattern) => patterns.push(pattern),
                None => literals.push(target.clone()),
            }
            targets.push(target);
        }

        // Gitignore-style matching: `*` stays within one segment, `**/` spans zero or more directories.
        let options = glob::MatchOptions {
            case_sensitive: true,
            require_literal_separator: true,
            require_literal_leading_dot: true,
        };

        let mut seen = HashSet::new();
        let defects = Walk {
            root: project,
            deep: true,
        }
        .run(
            &targets,
            |path| fs::metadata(path).is_ok_and(|meta| meta.len() <= BUDGET),
            |found| {
                if found.is_dir || !seen.insert(found.path.to_path_buf()) {
                    return Ok(());
                }

                let rel = found
                    .path
                    .strip_prefix(project)
                    .map_err(|e| e.to_string())?
                    .to_string_lossy()
                    .into_owned();
                let wanted = literals
                    .iter()
                    .any(|literal| found.path.starts_with(literal))
                    || patterns
                        .iter()
                        .any(|pattern| pattern.matches_with(&rel, options));
                if !wanted {
                    return Ok(());
                }

                hosts.push((Scope::Source, format!("./{rel}"), found.path.to_path_buf()));

                Ok(())
            },
        )?;
        report(defects, project, "./", diagnostics);
    }

    Ok(hosts)
}

/// Returns the literal directory prefix of a glob `entry` (segments before the first wildcard), or `None` when it has no wildcard.
fn glob_base(entry: &str) -> Option<&str> {
    let wildcard = entry.find(['*', '?', '['])?;
    Some(
        entry[..wildcard]
            .rfind('/')
            .map_or("", |slash| &entry[..slash]),
    )
}

/// Formats the diagnostic for a listed `meta.context` path that does not exist.
fn missing(scope: Scope, entry: &str) -> String {
    format!(
        "meta.context.{}: {}: listed path does not exist",
        scope.name(),
        crate::text::shell_quote(entry)
    )
}

/// Appends traversal defects as diagnostics, shown relative to `base` with `prefix`.
fn report(
    defects: Vec<crate::walk::Diagnostic>,
    base: &Path,
    prefix: &str,
    diagnostics: &mut Vec<String>,
) {
    for defect in defects {
        let rel = defect.path.strip_prefix(base).unwrap_or(&defect.path);
        diagnostics.push(format!(
            "{}: {}",
            crate::text::shell_quote(&format!("{prefix}{}", rel.to_string_lossy())),
            defect.message
        ));
    }
}

/// Reports vector-cache building on stderr: a start notice, one line per embedded file, and a summary.
///
/// On a terminal the per-file line is rewritten in place; elsewhere (agents, logs) each file gets its own line.
struct Progress {
    total: usize,
    directory: String,
    files: usize,
    chunks: usize,
    started: Option<std::time::Instant>,
    terminal: bool,
}

impl Progress {
    /// Starts an idle reporter for `total` candidate files cached in `directory`.
    fn new(total: usize, directory: String) -> Self {
        Self {
            total,
            directory,
            files: 0,
            chunks: 0,
            started: None,
            terminal: std::io::IsTerminal::is_terminal(&io::stderr()),
        }
    }

    /// Records one file; prints only when it needed new embeddings.
    fn file(&mut self, index: usize, path: &str, added: usize) {
        if added == 0 {
            return;
        }
        if self.started.is_none() {
            eprintln!(
                "cumaru context: building vector cache in {}",
                self.directory
            );
            self.started = Some(std::time::Instant::now());
        }

        self.files += 1;
        self.chunks += added;
        let line = format!(
            "cumaru context: [{:>width$}/{}] {path} (+{added} chunks)",
            index + 1,
            self.total,
            width = self.total.to_string().len()
        );
        if self.terminal {
            eprint!("\r\x1b[2K{line}");
        } else {
            eprintln!("{line}");
        }
    }

    /// Prints the summary after building, or a one-line status for an explicit warm with nothing to do.
    fn finish(&self, total: usize, explicit: bool) {
        match self.started {
            Some(started) => {
                if self.terminal {
                    eprintln!();
                }
                eprintln!(
                    "cumaru context: {}: cached {total} chunks ({} new from {} files) in {:.1}s",
                    self.directory,
                    self.chunks,
                    self.files,
                    started.elapsed().as_secs_f64()
                );
            }
            None if explicit => {
                eprintln!(
                    "cumaru context: vector cache {} is up to date ({total} chunks)",
                    self.directory
                )
            }
            None => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Prepare one disposable project/cache pair without mutating the actual user model cache.
    fn fixture(label: &str) -> std::path::PathBuf {
        let root = fs::canonicalize(std::env::temp_dir())
            .unwrap()
            .join(format!(
                "cumaru-context-{label}-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
        fs::create_dir_all(root.join("project")).unwrap();

        root
    }

    /// Rank raw Markdown without config or summaries and prove project/cache non-mutation.
    #[test]
    fn fallback_is_read_only_and_config_free() {
        let root = fixture("fallback");
        let host = root.join("project/eggs.md");
        fs::write(&host, "Egg recipes describe cooking eggs in butter.").unwrap();
        assert!(
            execute(
                Some("egg recipes"),
                &root.join("project"),
                &Ok(root.join("cache")),
                false,
                None,
                None
            )
            .unwrap()
        );
        assert_eq!(
            fs::read_to_string(host).unwrap(),
            "Egg recipes describe cooking eggs in butter."
        );
        assert!(!root.join("cache").exists());
        assert!(
            execute(
                Some("egg recipes"),
                &root.join("project"),
                &Ok(root.join("cache")),
                false,
                None,
                None
            )
            .unwrap()
        );
        fs::remove_dir_all(root).unwrap();
    }

    /// Preserve safe results while reporting invalid UTF-8 and symlinked hosts as failures.
    #[test]
    #[cfg(unix)]
    fn host_defects_report_partial_failure() {
        let root = fixture("defects");
        fs::write(root.join("project/safe.md"), "egg recipes").unwrap();
        fs::write(root.join("project/bad.md"), [255]).unwrap();
        std::os::unix::fs::symlink("safe.md", root.join("project/link.md")).unwrap();
        assert!(
            !execute(
                Some("egg recipes"),
                &root.join("project"),
                &Ok(root.join("cache")),
                false,
                None,
                None
            )
            .unwrap()
        );
        assert!(
            execute(
                Some(" "),
                &root.join("project"),
                &Ok(root.join("cache")),
                false,
                None,
                None
            )
            .is_err()
        );
        fs::remove_dir_all(root).unwrap();
    }

    /// Writes a valid `config.yaml` into the fixture `.cumaru/` with the given inline `meta.context` mapping.
    fn configure(root: &Path, context: &str) {
        let base = include_str!("../../domains/__base/config.yaml");
        let head = &base[..base.find("\nmeta:").unwrap()];
        fs::write(
            root.join("project/config.yaml"),
            format!(
                "{head}\nmeta:\n  targets: {{values: [platform, meta]}}\n  context: {context}\n"
            ),
        )
        .unwrap();
    }

    /// Lists the `(scope, selector path)` pairs the inventory resolves for one scope filter.
    fn listed(root: &Path, scope: Option<Scope>) -> (Vec<(&'static str, String)>, Vec<String>) {
        let project = fs::canonicalize(root.join("project")).unwrap();
        let plan = resolve(&project).unwrap();
        let mut diagnostics = Vec::new();
        let mut hosts: Vec<_> = inventory(&project, plan.as_ref(), scope, &mut diagnostics)
            .unwrap()
            .into_iter()
            .map(|(scope, path, _)| (scope.name(), path))
            .collect();
        hosts.sort();

        (hosts, diagnostics)
    }

    /// Filters source files through gitignore-style globs rooted at their literal prefix, diagnosing only a missing prefix.
    #[test]
    fn source_globs_filter_by_extension_across_subdirectories() {
        let root = fixture("globs");
        fs::create_dir_all(root.join("project")).unwrap();
        fs::create_dir_all(root.join("app/src/deep/er")).unwrap();
        fs::write(root.join("app/src/a.ts"), "a").unwrap();
        fs::write(root.join("app/src/deep/er/b.ts"), "b").unwrap();
        fs::write(root.join("app/src/deep/c.md"), "c").unwrap();
        fs::write(root.join("app/top.ts"), "t").unwrap();
        configure(
            &root,
            "{source: ['app/src/**/*.ts', 'app/*.md', 'nope/**/*.rs']}",
        );

        let (hosts, diagnostics) = listed(&root, None);
        assert_eq!(
            hosts,
            vec![
                ("source", "./app/src/a.ts".to_string()),
                ("source", "./app/src/deep/er/b.ts".to_string()),
            ]
        );
        assert_eq!(
            diagnostics,
            vec!["meta.context.source: nope: listed path does not exist".to_string()]
        );
        fs::remove_dir_all(root).unwrap();
    }

    /// Splits a glob entry at the last `/` before its first wildcard; literal entries yield `None`.
    #[test]
    fn glob_base_returns_the_literal_directory_prefix() {
        assert_eq!(glob_base("app/src"), None);
        assert_eq!(glob_base("app/src/**/*.ts"), Some("app/src"));
        assert_eq!(glob_base("app/src/*.ts"), Some("app/src"));
        assert_eq!(glob_base("app/fi?e.ts"), Some("app"));
        assert_eq!(glob_base("app/[ab].ts"), Some("app"));
        assert_eq!(glob_base("app/src*/x.ts"), Some("app"));
        assert_eq!(glob_base("**/*.ts"), Some(""));
        assert_eq!(glob_base("*.ts"), Some(""));
    }

    /// Root-level globs skip hidden trees, `?`/`[]` match one segment character, and literal/glob overlaps are indexed once.
    #[test]
    fn source_globs_from_the_project_root_deduplicate_and_skip_hidden() {
        let root = fixture("root-globs");
        fs::create_dir_all(root.join("lib/nested")).unwrap();
        fs::create_dir_all(root.join(".secret")).unwrap();
        fs::write(root.join("top.ts"), "t").unwrap();
        fs::write(root.join("lib/a.ts"), "a").unwrap();
        fs::write(root.join("lib/b1.rs"), "b").unwrap();
        fs::write(root.join("lib/b22.rs"), "b").unwrap();
        fs::write(root.join("lib/nested/c.ts"), "c").unwrap();
        fs::write(root.join(".secret/d.ts"), "d").unwrap();
        configure(
            &root,
            "{source: ['**/*.ts', 'lib', 'lib/b?.rs', 'lib/[xa].ts']}",
        );

        let (hosts, diagnostics) = listed(&root, None);
        assert_eq!(
            hosts,
            vec![
                ("source", "./lib/a.ts".to_string()),
                ("source", "./lib/b1.rs".to_string()),
                ("source", "./lib/b22.rs".to_string()),
                ("source", "./lib/nested/c.ts".to_string()),
                ("source", "./top.ts".to_string()),
            ]
        );
        assert!(diagnostics.is_empty(), "{diagnostics:?}");

        configure(&root, "{source: ['lib/b?.rs', 'lib/*.ts']}");
        let (hosts, _) = listed(&root, None);
        assert_eq!(
            hosts,
            vec![
                ("source", "./lib/a.ts".to_string()),
                ("source", "./lib/b1.rs".to_string()),
            ]
        );
        fs::remove_dir_all(root).unwrap();
    }

    /// A malformed source glob is a configuration error, not a silent skip.
    #[test]
    fn rejects_malformed_source_globs() {
        let root = fixture("bad-glob");
        fs::create_dir_all(root.join("lib")).unwrap();
        configure(&root, "{source: ['lib/[.ts']}");

        let project = fs::canonicalize(root.join("project")).unwrap();
        let plan = resolve(&project).unwrap();
        let Err(error) = inventory(&project, plan.as_ref(), None, &mut Vec::new()) else {
            panic!("malformed glob must fail");
        };
        assert!(
            error.contains("meta.context.source glob lib/\\[.ts: Pattern syntax error"),
            "{error}"
        );
        fs::remove_dir_all(root).unwrap();
    }

    /// Classifies by the longest covering entry, skips uncovered/hidden/binary-size files, prefixes source rows, and filters by scope.
    #[test]
    fn scopes_classify_filter_and_prefix_source_rows() {
        let root = fixture("scopes");
        fs::create_dir_all(root.join("project/specs/core")).unwrap();
        fs::create_dir_all(root.join("src/.hidden")).unwrap();
        fs::write(root.join("project/domain.md"), "# Domain").unwrap();
        fs::write(root.join("project/specs/a.md"), "# A").unwrap();
        fs::write(root.join("project/specs/core/b.md"), "# B").unwrap();
        fs::write(root.join("project/other.md"), "# Other").unwrap();
        fs::write(root.join("src/x.rs"), "fn main() {}").unwrap();
        fs::write(root.join("src/.hidden/y.rs"), "fn y() {}").unwrap();
        fs::write(root.join("src/big.txt"), vec![b'a'; 1024 * 1024 + 1]).unwrap();
        configure(
            &root,
            "{framework: [domain.md, specs/core], adopter: [specs/], source: [src, gone]}",
        );

        let (hosts, diagnostics) = listed(&root, None);
        assert_eq!(
            hosts,
            vec![
                ("adopter", "specs/a.md".to_string()),
                ("framework", "domain.md".to_string()),
                ("framework", "specs/core/b.md".to_string()),
                ("source", "./src/x.rs".to_string()),
            ]
        );
        assert_eq!(
            diagnostics,
            vec!["meta.context.source: gone: listed path does not exist".to_string()]
        );

        let (hosts, diagnostics) = listed(&root, Some(Scope::Framework));
        assert_eq!(
            hosts,
            vec![
                ("framework", "domain.md".to_string()),
                ("framework", "specs/core/b.md".to_string()),
            ]
        );
        assert!(diagnostics.is_empty());

        assert!(
            !execute(
                Some("domain"),
                &root.join("project"),
                &Ok(root.join("cache")),
                false,
                None,
                Some(Scope::Source)
            )
            .unwrap()
        );
        assert!(
            execute(
                Some("domain"),
                &root.join("project"),
                &Ok(root.join("cache")),
                false,
                None,
                Some(Scope::Adopter)
            )
            .unwrap()
        );
        fs::remove_dir_all(root).unwrap();
    }

    /// Without `meta.context`, or without a config at all, every visible `.cumaru/` Markdown file is `adopter`.
    #[test]
    fn config_free_indexes_everything_as_adopter() {
        let root = fixture("config-free");
        fs::write(root.join("project/one.md"), "# One").unwrap();
        fs::write(root.join("src.rs"), "fn main() {}").unwrap();
        let expected = vec![("adopter", "one.md".to_string())];

        assert_eq!(listed(&root, None).0, expected);
        assert!(listed(&root, Some(Scope::Framework)).0.is_empty());

        let base = include_str!("../../domains/__base/config.yaml");
        fs::write(
            root.join("project/config.yaml"),
            format!(
                "{}\nmeta: {{targets: {{values: [platform]}}}}\n",
                &base[..base.find("\nmeta:").unwrap()]
            ),
        )
        .unwrap();
        assert_eq!(listed(&root, None).0, expected);
        fs::remove_dir_all(root).unwrap();
    }

    /// Rejects absolute, parent, and symlink-escaping entries as configuration errors.
    #[test]
    fn rejects_unsafe_context_entries() {
        let root = fixture("unsafe");
        let project = fs::canonicalize(root.join("project")).unwrap();
        for context in [
            "{framework: [/etc]}",
            "{adopter: [specs/../..]}",
            "{source: [../outside]}",
            "{source: [/abs]}",
        ] {
            configure(&root, context);
            assert!(resolve(&project).is_err(), "{context}");
        }

        for (scope, raw) in [
            (Scope::Framework, "/etc"),
            (Scope::Adopter, "a/../b"),
            (Scope::Source, "../x"),
        ] {
            assert!(entry(&project, scope, raw).is_err(), "{raw}");
        }

        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(&root, root.join("project/escape")).unwrap();
            configure(&root, "{framework: [escape]}");
            let error = resolve(&project).err().unwrap();
            assert!(error.contains("symlinks"), "{error}");
        }
        fs::remove_dir_all(root).unwrap();
    }

    /// Exercise actual cached CPU inference only when pinned external artifacts are explicitly prepared.
    #[test]
    #[ignore = "manual smoke requires CUMARU_TEST_MODEL_ASSETS with pinned BGE files"]
    fn cached_encoder_smoke() {
        let source = std::path::PathBuf::from(
            std::env::var_os("CUMARU_TEST_MODEL_ASSETS").expect("prepare pinned model artifacts"),
        );
        let root = fixture("encoder");
        let cache = root.join("cache");
        let catalog = models::known("bge-micro-v2").unwrap();
        models::install(&cache, &catalog, |url| {
            fs::read(source.join(url.rsplit('/').next().unwrap())).map_err(|e| e.to_string())
        })
        .unwrap();
        fs::write(
            root.join("project/eggs.md"),
            "Beat two eggs. Melt butter in a pan and stir the eggs until cooked.",
        )
        .unwrap();
        assert!(
            execute(
                Some("look for egg recipes"),
                &root.join("project"),
                &Ok(cache.clone()),
                false,
                None,
                None
            )
            .unwrap()
        );
        let vectors = root.join("project/.cache/context/adopter");
        assert_eq!(fs::read_dir(&vectors).unwrap().count(), 1);
        assert!(
            fs::read_to_string(root.join(".gitignore"))
                .unwrap()
                .contains(".cumaru/.cache/")
        );
        assert!(
            execute(
                None,
                &root.join("project"),
                &Ok(cache.clone()),
                true,
                None,
                None
            )
            .unwrap()
        );
        assert_eq!(fs::read_dir(&vectors).unwrap().count(), 1);
        assert!(models::release(&cache).unwrap());
        assert!(models::local(&cache).unwrap().is_none());
        assert!(
            execute(
                Some("look for egg recipes"),
                &root.join("project"),
                &Ok(cache.clone()),
                false,
                None,
                None
            )
            .unwrap()
        );
        assert!(!models::install(&cache, &catalog, |_| panic!("reuse cached weights")).unwrap());
        assert!(models::local(&cache).unwrap().is_some());
        assert!(
            execute(
                Some("look for egg recipes"),
                &root.join("project"),
                &Ok(cache),
                false,
                None,
                None
            )
            .unwrap()
        );
        fs::remove_dir_all(root).unwrap();
    }
}
