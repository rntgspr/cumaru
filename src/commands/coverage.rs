//! `cumaru coverage`: report which Git-tracked source files the durable specification references.
//!
//! Mirrors the retired Bash `src/cmd_coverage.sh` (tag 0.10.0). Coverage owns the interpretation of `reference`
//! table bodies; the general tag command keeps bodies opaque. Strictly read-only:
//! Git is used only for work-tree and tracked-file queries.

use std::collections::BTreeSet;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode, Stdio};

use clap::{ArgGroup, Args};
use glob::{MatchOptions, Pattern};
use yaml_rust2::Yaml;

use crate::config::{self, CONFIG_FILE, CUMARU_DIR};
use crate::config_tree;
use crate::references::{self, Status, resolve};
use crate::tags;
use crate::tsv;
use crate::walk::Walk;

/// The specification pillar used when `meta.specification_dir` is absent or empty.
const DEFAULT_SPEC_DIR: &str = "specs";

/// The tag whose rows target repository source files.
const REFERENCE_TAG: &str = "reference";

/// Tracked path prefixes always excluded from the coverable source inventory.
const EXCLUDED_PREFIXES: [&str; 4] = [".cumaru/", ".agents/", ".claude/", ".opencode/"];

/// Root files always excluded from the coverable source inventory.
const EXCLUDED_FILES: [&str; 4] = ["AGENTS.md", "CLAUDE.md", "opencode.json", "opencode.jsonc"];

/// Arguments for `cumaru coverage`; output modes are mutually exclusive.
#[derive(Args)]
#[command(
    group(ArgGroup::new("mode").args(["refs", "gaps", "rows"])),
    after_help = "Spec files under the durable pillar (meta.specification_dir, default specs) carry\n<!-- cumaru:reference --> blocks whose rows target repository source files resolved\nfrom the project root. Source files come from git ls-files, optionally narrowed by\nmeta.coverage.source globs (* crosses /). .cumaru/ and agent adapter files are excluded.\n\nBuckets: covered, uncovered, stale, invalid, foreign.\nExit codes: 0 report printed; 1 runtime error, defects, or --strict with\nuncovered/stale/invalid entries; 2 usage error."
)]
pub struct CoverageArgs {
    /// List every reference row, grouped by spec file.
    #[arg(long)]
    refs: bool,

    /// List only uncovered source files, one per line.
    #[arg(long)]
    gaps: bool,

    /// Emit TSV rows: bucket, path, spec host, detail.
    #[arg(long)]
    rows: bool,

    /// Exit 1 when any uncovered, stale, or invalid entry exists.
    #[arg(long)]
    strict: bool,
}

/// Selected output projection.
#[derive(Clone, Copy, PartialEq)]
enum Mode {
    Report,
    Refs,
    Gaps,
    Rows,
}

/// One actionable reference row hosted under `.cumaru/`.
#[derive(Debug, PartialEq)]
struct Row {
    host: String,
    link: String,
    desc: String,
    target: String,
    status: Status,
}

/// Classified coverage state ready for rendering.
struct Buckets {
    spec_dir: String,
    refs: Vec<Row>,
    sources: BTreeSet<String>,
    uncovered: Vec<String>,
    foreign: usize,
    outside: usize,
}

/// Runs `cumaru coverage`, printing the projection only after every input was read.
pub fn run(args: CoverageArgs) -> ExitCode {
    let mode = if args.refs {
        Mode::Refs
    } else if args.gaps {
        Mode::Gaps
    } else if args.rows {
        Mode::Rows
    } else {
        Mode::Report
    };

    match execute(Path::new(CUMARU_DIR)) {
        Ok((buckets, defects)) => {
            let _ = io::stdout()
                .lock()
                .write_all(render(mode, &buckets).as_bytes());
            for defect in &defects {
                eprintln!("cumaru coverage: {defect}");
            }

            let failing = buckets.uncovered.len()
                + buckets
                    .refs
                    .iter()
                    .filter(|row| row.status != Status::Ok)
                    .count();
            if !defects.is_empty() || (args.strict && failing > 0) {
                ExitCode::FAILURE
            } else {
                ExitCode::SUCCESS
            }
        }
        Err(message) => {
            eprintln!("cumaru coverage: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Validates the tree, reads config, source inventory, and reference rows, then classifies them.
fn execute(cumaru: &Path) -> Result<(Buckets, Vec<String>), String> {
    if !cumaru.is_dir() {
        return Err(".cumaru not found; run 'cumaru install' first".into());
    }
    if fs::symlink_metadata(cumaru.join(CONFIG_FILE)).is_err() {
        return Err(".cumaru/config.yaml not found; not a Cumaru tree?".into());
    }
    let config = config::load(cumaru)?;

    let spec_dir = specification_dir(&config)?;
    if !cumaru.join(&spec_dir).is_dir() {
        return Err(format!(
            ".cumaru/{spec_dir}/ not found; set meta.specification_dir in .cumaru/config.yaml to the pillar that holds the durable specification (default: specs)"
        ));
    }

    let project = cumaru
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    let tracked = tracked_files(project)?;
    let sources = source_files(tracked, &source_globs(&config)?);

    let root =
        fs::canonicalize(cumaru).map_err(|error| format!("cannot resolve .cumaru: {error}"))?;
    let (rows, defects) = reference_rows(&root)?;

    Ok((classify(&spec_dir, sources, rows), defects))
}

/// Reads `meta.specification_dir`, resolving a v9 logical directory through its configured physical path.
fn specification_dir(config: &Yaml) -> Result<String, String> {
    let declared = config["meta"]["specification_dir"].as_str().unwrap_or("");
    if declared.is_empty() {
        return Ok(DEFAULT_SPEC_DIR.into());
    }
    if config["version"].as_i64() != Some(9) {
        return Ok(declared.into());
    }

    config_tree::directory_path(config, declared)?.ok_or_else(|| {
        format!("meta.specification_dir '{declared}' is not a configured literal directory")
    })
}

/// Reads `meta.coverage.source` as Bash-style patterns where `*` crosses `/`.
fn source_globs(config: &Yaml) -> Result<Vec<Pattern>, String> {
    config["meta"]["coverage"]["source"]
        .as_vec()
        .into_iter()
        .flatten()
        .filter_map(Yaml::as_str)
        .filter(|glob| !glob.is_empty())
        .map(|glob| {
            let mut collapsed = String::new();
            for c in glob.chars() {
                if c != '*' || !collapsed.ends_with('*') {
                    collapsed.push(c);
                }
            }

            Pattern::new(&collapsed)
                .map_err(|error| format!("invalid meta.coverage.source glob '{glob}': {error}"))
        })
        .collect()
}

/// Lists tracked files relative to the project through read-only Git queries.
fn tracked_files(project: &Path) -> Result<Vec<String>, String> {
    let inside = Command::new("git")
        .arg("-C")
        .arg(project)
        .args(["rev-parse", "--is-inside-work-tree"])
        .stderr(Stdio::null())
        .output();
    if !inside.is_ok_and(|output| output.status.success() && output.stdout.trim_ascii() == b"true")
    {
        return Err("needs a git work tree; the source file list comes from 'git ls-files'".into());
    }

    let output = Command::new("git")
        .arg("-C")
        .arg(project)
        .args(["-c", "core.quotepath=off", "ls-files", "-z"])
        .stderr(Stdio::null())
        .output()
        .map_err(|error| format!("cannot run git ls-files: {error}"))?;
    if !output.status.success() {
        return Err("git ls-files failed".into());
    }

    Ok(output
        .stdout
        .split(|byte| *byte == 0)
        .filter(|path| !path.is_empty())
        .map(|path| String::from_utf8_lossy(path).into_owned())
        .collect())
}

/// Applies the unconditional adapter exclusions, then optional globs; `.codex/` is intentionally not excluded yet.
fn source_files(tracked: Vec<String>, globs: &[Pattern]) -> BTreeSet<String> {
    let options = MatchOptions {
        case_sensitive: true,
        require_literal_separator: false,
        require_literal_leading_dot: false,
    };

    tracked
        .into_iter()
        .filter(|path| {
            !EXCLUDED_PREFIXES
                .iter()
                .any(|prefix| path.starts_with(prefix))
                && !EXCLUDED_FILES.contains(&path.as_str())
                && (globs.is_empty() || globs.iter().any(|glob| glob.matches_with(path, options)))
        })
        .collect()
}

/// Collects actionable reference rows from every safe Markdown host, reporting malformed hosts and traversal defects.
fn reference_rows(root: &Path) -> Result<(Vec<Row>, Vec<String>), String> {
    let mut files = Vec::new();
    let diagnostics = Walk { root, deep: true }.run(
        &[root.to_path_buf()],
        |path| path.extension().is_some_and(|extension| extension == "md"),
        |entry| {
            if !entry.is_dir {
                files.push(entry.path.to_path_buf());
            }
            Ok(())
        },
    )?;

    let mut hosts: Vec<(String, PathBuf)> = files
        .into_iter()
        .map(|path| {
            let rel = path
                .strip_prefix(root)
                .unwrap_or(&path)
                .to_string_lossy()
                .into_owned();
            (rel, path)
        })
        .collect();
    hosts.sort();

    let mut rows = Vec::new();
    let mut defects = Vec::new();
    for (host, path) in hosts {
        let parsed = fs::read_to_string(&path)
            .map_err(|error| error.to_string())
            .and_then(|text| reference_cells(&text).map_err(|error| error.to_string()));
        match parsed {
            Ok(cells) => {
                for (link, desc, raw) in cells {
                    if let Some((status, target)) = resolve(root, &raw) {
                        rows.push(Row {
                            host: host.clone(),
                            link,
                            desc,
                            target,
                            status,
                        });
                    }
                }
            }
            Err(error) => defects.push(format!("{host}: {error}")),
        }
    }

    defects.extend(diagnostics.into_iter().map(|diagnostic| {
        format!(
            "{}: {}",
            diagnostic
                .path
                .strip_prefix(root)
                .unwrap_or(&diagnostic.path)
                .display(),
            diagnostic.message
        )
    }));

    Ok((rows, defects))
}

/// Extracts `(link, description, target)` cells from table lines whose innermost balanced block is `reference`.
fn reference_cells(text: &str) -> Result<Vec<(String, String, String)>, String> {
    let blocks = tags::parse(text)?;
    Ok(references::cells(text, &blocks, &[REFERENCE_TAG])
        .into_iter()
        .map(|(_, link, description, target)| (link, description, target))
        .collect())
}

/// Keeps rows hosted under the specification pillar and derives uncovered and foreign sets.
fn classify(spec_dir: &str, sources: BTreeSet<String>, rows: Vec<Row>) -> Buckets {
    let prefix = format!("{spec_dir}/");
    let (refs, outside): (Vec<Row>, Vec<Row>) = rows
        .into_iter()
        .partition(|row| row.host.starts_with(&prefix));

    let covered: BTreeSet<&str> = refs
        .iter()
        .filter(|row| row.status == Status::Ok)
        .map(|row| row.target.as_str())
        .collect();
    let uncovered = sources
        .iter()
        .filter(|path| !covered.contains(path.as_str()))
        .cloned()
        .collect();
    let foreign = covered
        .iter()
        .filter(|path| !sources.contains(**path))
        .count();

    Buckets {
        spec_dir: spec_dir.into(),
        refs,
        sources,
        uncovered,
        foreign,
        outside: outside.len(),
    }
}

/// Renders the selected projection with Bash wording, without ANSI colors.
fn render(mode: Mode, b: &Buckets) -> String {
    let mut out = Vec::new();
    let stale: Vec<&Row> = b
        .refs
        .iter()
        .filter(|row| row.status == Status::Missing)
        .collect();
    let invalid: Vec<&Row> = b
        .refs
        .iter()
        .filter(|row| row.status == Status::Invalid)
        .collect();

    match mode {
        Mode::Rows => {
            for row in b.refs.iter().filter(|row| row.status == Status::Ok) {
                let bucket = if b.sources.contains(&row.target) {
                    "covered"
                } else {
                    "foreign"
                };
                let _ = tsv::write_row(&mut out, [bucket, &row.target, &row.host, &row.desc]);
            }
            for path in &b.uncovered {
                let _ = tsv::write_row(&mut out, ["uncovered", path, "", ""]);
            }
            for (bucket, rows) in [("stale", &stale), ("invalid", &invalid)] {
                for row in rows {
                    let _ = tsv::write_row(&mut out, [bucket, &row.target, &row.host, &row.link]);
                }
            }
        }
        Mode::Gaps => {
            for path in &b.uncovered {
                let _ = writeln!(out, "{path}");
            }
        }
        Mode::Refs if b.refs.is_empty() => {
            let _ = writeln!(out, "No reference rows found under .cumaru/{}/", b.spec_dir);
        }
        Mode::Refs => {
            let mut current = "";
            for row in &b.refs {
                if row.host != current {
                    if !current.is_empty() {
                        let _ = writeln!(out);
                    }
                    let _ = writeln!(out, "File: {}", row.host);
                    current = &row.host;
                }
                let label = match row.status {
                    Status::Ok => String::new(),
                    Status::Missing => "  [missing]".into(),
                    Status::Invalid => "  [invalid]".into(),
                };
                let _ = writeln!(out, "  • {} — {}{label}", row.link, row.desc);
            }
        }
        Mode::Report => report(&mut out, b, &stale, &invalid),
    }

    String::from_utf8(out).unwrap_or_default()
}

/// Writes the full report: counts, bucket details, informational notices, and the summary line.
fn report(out: &mut Vec<u8>, b: &Buckets, stale: &[&Row], invalid: &[&Row]) {
    let n_source = b.sources.len();
    let n_covered = n_source - b.uncovered.len();
    let pct = if n_source > 0 {
        n_covered * 100 / n_source
    } else {
        0
    };
    let hosts: BTreeSet<&str> = b.refs.iter().map(|row| row.host.as_str()).collect();

    let _ = writeln!(
        out,
        "Specification coverage — .cumaru/{}/ ↔ repository source\n",
        b.spec_dir
    );
    let _ = writeln!(
        out,
        "[refs]      {} reference row(s) across {} spec file(s)",
        b.refs.len(),
        hosts.len()
    );
    let _ = writeln!(
        out,
        "[covered]   {n_covered}/{n_source} source file(s) referenced ({pct}%)"
    );

    if b.uncovered.is_empty() {
        let _ = writeln!(
            out,
            "[uncovered] none — every source file is referenced by the specification"
        );
    } else {
        let _ = writeln!(
            out,
            "[uncovered] {} source file(s) without a reference row:",
            b.uncovered.len()
        );
        for path in &b.uncovered {
            let _ = writeln!(out, "              • {path}");
        }
    }

    if !stale.is_empty() {
        let _ = writeln!(
            out,
            "[stale]     {} reference row(s) point at missing files:",
            stale.len()
        );
        for row in stale {
            let _ = writeln!(out, "              • {}: {}", row.host, row.target);
        }
    }

    if !invalid.is_empty() {
        let _ = writeln!(
            out,
            "[invalid]   {} reference row(s) break the source-file rule (.cumaru/ path, directory, absolute path, or URL):",
            invalid.len()
        );
        for row in invalid {
            let _ = writeln!(out, "              • {}: {}", row.host, row.target);
        }
    }

    if b.foreign > 0 {
        let _ = writeln!(
            out,
            "[foreign]   {} referenced file(s) outside the source scope (untracked or filtered by coverage.source)",
            b.foreign
        );
    }
    if b.outside > 0 {
        let _ = writeln!(
            out,
            "[note]      {} reference row(s) hosted outside {}/ ignored",
            b.outside, b.spec_dir
        );
    }

    let _ = writeln!(
        out,
        "\nSummary: {n_covered} covered, {} uncovered, {} stale, {} invalid",
        b.uncovered.len(),
        stale.len(),
        invalid.len()
    );
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::references::table_row;
    use std::time::{SystemTime, UNIX_EPOCH};
    use yaml_rust2::YamlLoader;

    /// Disposable project with a `.cumaru/` tree, removed on drop.
    struct Fixture(PathBuf);

    impl Fixture {
        /// Creates a canonical project directory containing `.cumaru/` and `src/`.
        fn new(label: &str) -> Self {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let base = std::env::temp_dir().join(format!(
                "cumaru-coverage-{label}-{}-{nonce}",
                std::process::id()
            ));
            fs::create_dir_all(base.join(".cumaru/specs")).unwrap();
            fs::create_dir_all(base.join("src")).unwrap();

            Self(fs::canonicalize(base).unwrap())
        }

        /// Returns the canonical `.cumaru/` root.
        fn root(&self) -> PathBuf {
            self.0.join(".cumaru")
        }
    }

    impl Drop for Fixture {
        /// Removes only this fixture's temporary tree.
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    /// Builds a row with the given host, target, and status for classification tests.
    fn row(host: &str, target: &str, status: Status) -> Row {
        Row {
            host: host.into(),
            link: format!("[x]({target})"),
            desc: "d".into(),
            target: target.into(),
            status,
        }
    }

    /// Parses links, backticks, extra cells, and tabs, and skips headers, separators, and short rows.
    #[test]
    fn parses_table_rows_like_bash() {
        assert_eq!(
            table_row("| [a](`src/a.ts`) | Desc | more |"),
            Some((
                "[a](`src/a.ts`)".into(),
                "Desc | more".into(),
                "src/a.ts".into()
            ))
        );
        assert_eq!(
            table_row("  | src/b.ts |\tTabbed\t|"),
            Some(("src/b.ts".into(), "Tabbed".into(), "src/b.ts".into()))
        );
        assert_eq!(
            table_row("| [x](<source-file>) | t |").unwrap().2,
            "<source-file>"
        );
        for skipped in [
            "| Link | Description |",
            "|---|---|",
            "| :-- | --: |",
            "| only |",
            "text",
        ] {
            assert_eq!(table_row(skipped), None, "{skipped:?}");
        }
    }

    /// Attributes rows to their innermost balanced block and rejects malformed hosts.
    #[test]
    fn reads_rows_from_innermost_reference_blocks() {
        let text = "| [no](a) | outside |\n<!-- cumaru:reference -->\n| [a](src/a.ts) | A |\n<!-- cumaru:other -->\n| [b](src/b.ts) | nested |\n<!-- /cumaru:other -->\n| [c](src/c.ts) | after |\n<!-- /cumaru:reference -->\n";
        let targets: Vec<String> = reference_cells(text)
            .unwrap()
            .into_iter()
            .map(|(_, _, target)| target)
            .collect();

        assert_eq!(targets, ["src/a.ts", "src/c.ts"]);
        assert!(reference_cells("<!-- cumaru:reference -->\n| [a](b) | c |\n").is_err());
    }

    /// Classifies targets under the source-file rule and normalizes accepted paths.
    #[test]
    fn resolves_reference_targets() {
        let fixture = Fixture::new("resolve");
        let root = fixture.root();
        fs::write(fixture.0.join("src/a.ts"), "a").unwrap();
        fs::write(root.join("index.md"), "# i").unwrap();
        std::os::unix::fs::symlink(std::env::temp_dir(), fixture.0.join("out")).unwrap();
        std::os::unix::fs::symlink(fixture.0.join("src/a.ts"), fixture.0.join("source-link.ts"))
            .unwrap();

        for (raw, expected) in [
            ("src/a.ts", Some((Status::Ok, "src/a.ts"))),
            ("src/../src/a.ts#L1", Some((Status::Ok, "src/a.ts"))),
            (
                "src/missing.ts#L2",
                Some((Status::Missing, "src/missing.ts")),
            ),
            ("src", Some((Status::Invalid, "src"))),
            ("source-link.ts", Some((Status::Invalid, "source-link.ts"))),
            ("../missing.ts", Some((Status::Invalid, "../missing.ts"))),
            (
                ".cumaru/missing.md",
                Some((Status::Invalid, ".cumaru/missing.md")),
            ),
            (
                ".cumaru/index.md",
                Some((Status::Invalid, ".cumaru/index.md")),
            ),
            ("/etc/hosts", Some((Status::Invalid, "/etc/hosts"))),
            (
                "https://example.com/a#b",
                Some((Status::Invalid, "https://example.com/a#b")),
            ),
            ("#anchor", Some((Status::Invalid, "#anchor"))),
            ("<source-file>", None),
            ("", None),
        ] {
            let expected = expected.map(|(status, target)| (status, target.to_string()));
            assert_eq!(resolve(&root, raw), expected, "{raw:?}");
        }

        let outside =
            std::env::temp_dir().join(format!("cumaru-coverage-escape-{}", std::process::id()));
        fs::write(&outside, "x").unwrap();
        let escaped = format!("out/{}", outside.file_name().unwrap().to_string_lossy());
        assert_eq!(
            resolve(&root, &escaped).map(|(status, _)| status),
            Some(Status::Invalid)
        );
        fs::remove_file(outside).unwrap();
    }

    /// Excludes adapter paths, keeps `.codex/`, and applies globs where `*` and `**` cross `/`.
    #[test]
    fn filters_source_inventory() {
        let tracked: Vec<String> = [
            ".cumaru/index.md",
            ".agents/x.ts",
            ".claude/s.md",
            ".opencode/c.md",
            "AGENTS.md",
            "CLAUDE.md",
            "opencode.json",
            "opencode.jsonc",
            ".codex/config.toml",
            "docs/AGENTS.md",
            "src/deep/a.ts",
            "README.md",
        ]
        .map(String::from)
        .into();

        let all = source_files(tracked.clone(), &[]);
        assert_eq!(
            all.into_iter().collect::<Vec<_>>(),
            [
                ".codex/config.toml",
                "README.md",
                "docs/AGENTS.md",
                "src/deep/a.ts"
            ]
        );

        let config = YamlLoader::load_from_str("meta: {coverage: {source: ['src/**.ts', '*.md']}}")
            .unwrap()
            .remove(0);
        let narrowed = source_files(tracked, &source_globs(&config).unwrap());
        assert_eq!(
            narrowed.into_iter().collect::<Vec<_>>(),
            ["README.md", "docs/AGENTS.md", "src/deep/a.ts"]
        );
    }

    /// Defaults to specs, keeps v8 values, and maps v9 logical directories through path overrides.
    #[test]
    fn resolves_specification_dir() {
        let load = |text: &str| YamlLoader::load_from_str(text).unwrap().remove(0);

        assert_eq!(
            specification_dir(&load("version: 9\nmeta: {}\n")).unwrap(),
            "specs"
        );
        assert_eq!(
            specification_dir(&load("version: 8\nmeta: {specification_dir: topology}\n")).unwrap(),
            "topology"
        );
        assert_eq!(
            specification_dir(&load(
                "version: 9\nroot: {specs: {path: durable/specs}}\nmeta: {specification_dir: specs}\n"
            ))
            .unwrap(),
            "durable/specs"
        );
        assert!(
            specification_dir(&load(
                "version: 9\nroot: {}\nmeta: {specification_dir: specs}\n"
            ))
            .is_err()
        );
    }

    /// Reproduces the Bash fixture's rows output, outside-host count, and summary counts.
    #[test]
    fn classifies_and_renders_buckets() {
        let sources = BTreeSet::from(["src/covered.ts".into(), "src/uncovered.ts".into()]);
        let host = "specs/coverage-fixture.md";
        let rows = vec![
            row(host, "src/covered.ts", Status::Ok),
            row(host, "src/foreign-filtered.ts", Status::Ok),
            row(host, "src/missing.ts", Status::Missing),
            row(host, ".cumaru/index.md", Status::Invalid),
            row("domain.md", "src/covered.ts", Status::Ok),
        ];
        let buckets = classify("specs", sources, rows);

        assert_eq!(
            render(Mode::Rows, &buckets),
            "covered\tsrc/covered.ts\tspecs/coverage-fixture.md\td\nforeign\tsrc/foreign-filtered.ts\tspecs/coverage-fixture.md\td\nuncovered\tsrc/uncovered.ts\t\t\nstale\tsrc/missing.ts\tspecs/coverage-fixture.md\t[x](src/missing.ts)\ninvalid\t.cumaru/index.md\tspecs/coverage-fixture.md\t[x](.cumaru/index.md)\n"
        );
        assert_eq!(render(Mode::Gaps, &buckets), "src/uncovered.ts\n");

        let report = render(Mode::Report, &buckets);
        assert!(
            report.contains("[covered]   1/2 source file(s) referenced (50%)"),
            "{report}"
        );
        assert!(
            report.contains("[foreign]   1 referenced file(s)"),
            "{report}"
        );
        assert!(
            report.contains("[note]      1 reference row(s) hosted outside specs/ ignored"),
            "{report}"
        );
        assert!(
            report.ends_with("\nSummary: 1 covered, 1 uncovered, 1 stale, 1 invalid\n"),
            "{report}"
        );
    }
}
