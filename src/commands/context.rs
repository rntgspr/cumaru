//! Query relevance ranking with an optional encoder and its project-local vector cache.

use clap::Args;
use std::{
    fs,
    io::{self, Write},
    path::Path,
    process::ExitCode,
};

use crate::{
    models,
    relevance::{Query, Scorer},
    walk::Walk,
};

/// Ranked rows printed by default; `--full` prints all.
const LIMIT: usize = 16;

#[derive(Args)]
pub struct ContextArgs {
    /// English query to rank visible Markdown files inside the current .cumaru/.
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
}

/// Rank local Markdown without installing models; an enabled encoder reuses and refreshes `.cumaru/.cache/` vectors.
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
    ) {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(error) => {
            eprintln!("cumaru context: {error}");
            ExitCode::FAILURE
        }
    }
}

/// Builds the vector cache for the current `.cumaru/` when an encoder is enabled, warning instead of failing.
pub(crate) fn warm(project: &Path) {
    if let Err(error) = execute(None, project, &models::cache_root(), false, None) {
        eprintln!("cumaru context: vector cache not warmed: {error}");
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

/// Collect safe hosts, refresh the vector cache with progress, and emit bounded two-decimal ranking TSV for a query.
fn execute(
    query: Option<&str>,
    project: &Path,
    cache: &Result<std::path::PathBuf, String>,
    reset: bool,
    limit: Option<usize>,
) -> Result<bool, String> {
    let prepared = query.map(Query::new).transpose()?;

    if crate::paths::is_symlink(project) || !project.is_dir() {
        return Err(".cumaru/ not found or is a symlink".into());
    }

    let root = fs::canonicalize(project).map_err(|e| e.to_string())?;
    let encoder = models::local(cache.as_ref().map_err(Clone::clone)?)?;
    if query.is_none() && encoder.is_none() {
        eprintln!(
            "cumaru context: no enabled encoder; nothing to cache (enable one with cumaru model pull)"
        );
        return Ok(true);
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
        crate::vectors::Cache::reset(&root)?;
    }
    let mut cache = encoder
        .as_ref()
        .map(|encoder| crate::vectors::Cache::load(&root, encoder));

    let mut hosts = Vec::new();
    let mut diagnostics = Vec::new();
    let defects = Walk {
        root: &root,
        deep: true,
    }
    .run(
        std::slice::from_ref(&root),
        |path| crate::paths::file_name(path).ends_with(".md"),
        |entry| {
            if !entry.is_dir {
                let path = entry
                    .path
                    .strip_prefix(&root)
                    .map_err(|e| e.to_string())?
                    .to_string_lossy()
                    .into_owned();
                hosts.push((path, entry.path.to_path_buf()));
            }

            Ok(())
        },
    )?;

    let mut progress = Progress::new(hosts.len());
    let mut records = Vec::new();
    for (index, (path, file)) in hosts.iter().enumerate() {
        let evaluated = (|| {
            if fs::metadata(file).map_err(|e| e.to_string())?.len() > 1024 * 1024 {
                return Err("document exceeds the 1-MiB budget".into());
            }

            let document = fs::read_to_string(file).map_err(|e| e.to_string())?;
            let whole = (1, document.lines().count());
            let (score, lines) = match (&encoder, cache.as_mut()) {
                (Some(encoder), Some(cache)) => {
                    let (keys, added) = cache.embed(encoder, &document)?;
                    progress.file(index, path, added);
                    match &vector {
                        Some(vector) => {
                            let (score, lines) = cache.score(&keys, vector)?;
                            (score, lines.map_or(whole, |lines| section(file, lines)))
                        }
                        None => (0.0, whole),
                    }
                }
                _ => match &prepared {
                    Some(prepared) => (scorer.score(prepared, &document)?, whole),
                    None => (0.0, whole),
                },
            };

            Ok::<_, String>(((score * 100.0).round() as u16, lines))
        })();

        match evaluated {
            Ok((score, (start, end))) => {
                let selector = if end == 0 {
                    path.clone()
                } else {
                    crate::commands::get::selector(path, start, end)
                };
                records.push((selector, score));
            }
            Err(error) => diagnostics.push(format!("{}: {error}", crate::text::shell_quote(path))),
        }
    }

    // A cache write failure only costs speed on the next run, so it warns instead of failing.
    let total = cache.as_ref().map_or(0, crate::vectors::Cache::len);
    if let Some(Err(error)) = cache.map(crate::vectors::Cache::save) {
        eprintln!("cumaru context: vector cache not saved: {error}");
    }
    progress.finish(total, query.is_none());

    for defect in defects {
        diagnostics.push(format!(
            "{}: {}",
            crate::text::shell_quote(
                &defect
                    .path
                    .strip_prefix(&root)
                    .unwrap_or(&defect.path)
                    .to_string_lossy()
            ),
            defect.message
        ));
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

    diagnostics.sort();
    diagnostics.dedup();

    for diagnostic in &diagnostics {
        eprintln!("cumaru context: {diagnostic}");
    }

    Ok(diagnostics.is_empty())
}

/// Reports vector-cache building on stderr: a start notice, one line per embedded file, and a summary.
///
/// On a terminal the per-file line is rewritten in place; elsewhere (agents, logs) each file gets its own line.
struct Progress {
    total: usize,
    files: usize,
    chunks: usize,
    started: Option<std::time::Instant>,
    terminal: bool,
}

impl Progress {
    /// Starts an idle reporter for `total` candidate files.
    fn new(total: usize) -> Self {
        Self {
            total,
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
            eprintln!("cumaru context: building vector cache in .cumaru/.cache/context/");
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
                    "cumaru context: cached {total} chunks ({} new from {} files) in {:.1}s",
                    self.chunks,
                    self.files,
                    started.elapsed().as_secs_f64()
                );
            }
            None if explicit => {
                eprintln!("cumaru context: vector cache is up to date ({total} chunks)")
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
                None
            )
            .is_err()
        );
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
                None
            )
            .unwrap()
        );
        let vectors = root.join("project/.cache/context");
        assert_eq!(fs::read_dir(&vectors).unwrap().count(), 1);
        assert!(
            fs::read_to_string(root.join(".gitignore"))
                .unwrap()
                .contains(".cumaru/.cache/")
        );
        assert!(execute(None, &root.join("project"), &Ok(cache.clone()), true, None).unwrap());
        assert_eq!(fs::read_dir(&vectors).unwrap().count(), 1);
        assert!(models::release(&cache).unwrap());
        assert!(models::local(&cache).unwrap().is_none());
        assert!(
            execute(
                Some("look for egg recipes"),
                &root.join("project"),
                &Ok(cache.clone()),
                false,
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
                None
            )
            .unwrap()
        );
        fs::remove_dir_all(root).unwrap();
    }
}
