//! Read-only query relevance ranking with optional cached CPU embeddings.

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

#[derive(Args)]
pub struct ContextArgs {
    /// English query to rank visible Markdown files inside the current .cumaru/.
    #[arg(value_name = "QUERY")]
    query: String,
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
                "egg recipes",
                &root.join("project"),
                &Ok(root.join("cache"))
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
                "egg recipes",
                &root.join("project"),
                &Ok(root.join("cache"))
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
                "egg recipes",
                &root.join("project"),
                &Ok(root.join("cache"))
            )
            .unwrap()
        );
        assert!(execute(" ", &root.join("project"), &Ok(root.join("cache"))).is_err());
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
        assert!(execute("look for egg recipes", &root.join("project"), &Ok(cache)).unwrap());
        fs::remove_dir_all(root).unwrap();
    }
}

/// Rank local Markdown without installing models or changing project/cache state.
pub fn run(args: ContextArgs) -> ExitCode {
    match execute(
        &args.query,
        Path::new(crate::config::CUMARU_DIR),
        &models::cache_root(),
    ) {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(error) => {
            eprintln!("cumaru context: {error}");
            ExitCode::FAILURE
        }
    }
}

/// Collect safe hosts, evaluate the selected backend, and emit bounded two-decimal ranking TSV.
fn execute(
    query: &str,
    project: &Path,
    cache: &Result<std::path::PathBuf, String>,
) -> Result<bool, String> {
    let prepared = Query::new(query)?;

    if crate::paths::is_symlink(project) || !project.is_dir() {
        return Err(".cumaru/ not found or is a symlink".into());
    }

    let root = fs::canonicalize(project).map_err(|e| e.to_string())?;
    let encoder = models::local(cache.as_ref().map_err(Clone::clone)?)?;
    let vector = encoder
        .as_ref()
        .map(|encoder| encoder.embed(query))
        .transpose()?;
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
    let mut records = Vec::new();
    let mut diagnostics = Vec::new();
    let defects = Walk {
        root: &root,
        deep: true,
    }
    .run(
        std::slice::from_ref(&root),
        |path| crate::paths::file_name(path).ends_with(".md"),
        |entry| {
            if entry.is_dir {
                return Ok(());
            }

            let path = entry
                .path
                .strip_prefix(&root)
                .map_err(|e| e.to_string())?
                .to_string_lossy()
                .into_owned();
            let evaluated = (|| {
                if fs::metadata(entry.path).map_err(|e| e.to_string())?.len() > 1024 * 1024 {
                    return Err("document exceeds the 1-MiB budget".into());
                }

                let document = fs::read_to_string(entry.path).map_err(|e| e.to_string())?;
                let score = if let (Some(encoder), Some(vector)) = (&encoder, &vector) {
                    encoder.document_score(&document, vector)?
                } else {
                    scorer.score(&prepared, &document)?
                };

                Ok::<_, String>((score * 100.0).round() as u16)
            })();

            match evaluated {
                Ok(score) => records.push((path, score)),
                Err(error) => {
                    diagnostics.push(format!("{}: {error}", crate::text::shell_quote(&path)))
                }
            }

            Ok(())
        },
    )?;

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

    records.sort_by(|left, right| {
        right
            .1
            .cmp(&left.1)
            .then_with(|| left.0.as_bytes().cmp(right.0.as_bytes()))
    });
    let stdout = io::stdout();
    let mut out = stdout.lock();

    for (path, score) in records {
        let score = format!("{:.2}", f64::from(score) / 100.0);
        crate::tsv::write_row(&mut out, [path.as_str(), score.as_str()])
            .map_err(|e| e.to_string())?;
    }

    out.flush().map_err(|e| e.to_string())?;
    diagnostics.sort();
    diagnostics.dedup();

    for diagnostic in &diagnostics {
        eprintln!("cumaru context: {diagnostic}");
    }

    Ok(diagnostics.is_empty())
}
