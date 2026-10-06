use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;
use std::process::ExitCode;

use clap::Args;
use yaml_rust2::Yaml;

use crate::adapter::{self, Adapter};
use crate::walk::Walk;
use crate::{config, config_tree, markdown, paths, references, tags};

#[derive(Args, Default)]
pub struct DoctorArgs {
    /// Suppress successful checks; retain warnings, errors, and the summary.
    #[arg(long)]
    quiet: bool,
}

#[derive(Debug)]
struct Check {
    label: &'static str,
    error: bool,
    issues: Vec<String>,
}

#[derive(Debug)]
pub(crate) struct Report(Vec<Check>);

impl Report {
    /// Records one deterministic top-level check, retaining all host-attributed issues.
    fn check(&mut self, label: &'static str, error: bool, mut issues: Vec<String>) {
        issues.sort();
        issues.dedup();
        self.0.push(Check {
            label,
            error,
            issues,
        });
    }

    /// Returns whether at least one blocking check failed.
    pub(crate) fn failed(&self) -> bool {
        self.0
            .iter()
            .any(|check| check.error && !check.issues.is_empty())
    }

    /// Renders checks and counts without hiding diagnostics in quiet mode.
    pub(crate) fn render(&self, quiet: bool) -> String {
        let (mut errors, mut warnings, mut ok) = (0, 0, 0);
        let mut output = String::new();
        for check in &self.0 {
            let status = if check.issues.is_empty() {
                ok += 1;
                if quiet {
                    continue;
                }
                "ok"
            } else if check.error {
                errors += 1;
                "error"
            } else {
                warnings += 1;
                "warn"
            };
            output.push_str(&format!("[{status}] {}\n", check.label));
            for issue in &check.issues {
                output.push_str(&format!("    {issue}\n"));
            }
        }
        output.push_str(&format!(
            "Summary: {errors} error(s), {warnings} warning(s), {ok} ok\n"
        ));
        output
    }
}

/// Runs read-only health checks against the current project's fixed framework directory.
pub fn run(args: DoctorArgs) -> ExitCode {
    match inspect(Path::new(config::CUMARU_DIR)) {
        Ok(report) => {
            print!("{}", report.render(args.quiet));
            if report.failed() {
                ExitCode::FAILURE
            } else {
                ExitCode::SUCCESS
            }
        }
        Err(message) => {
            eprintln!("cumaru doctor: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Loads a safe v9 tree once, validates configured hosts, and reports independent cached health checks.
pub(crate) fn inspect(root: &Path) -> Result<Report, String> {
    if paths::is_symlink(root) || !root.is_dir() {
        return Err("a real .cumaru/ directory is required; run cumaru install first".into());
    }
    let root = fs::canonicalize(root).map_err(|error| error.to_string())?;
    let project = root.parent().ok_or("cannot resolve project directory")?;
    let config_path = root.join(config::CONFIG_FILE);
    if paths::is_symlink(&config_path) || !config_path.is_file() {
        return Err("a regular .cumaru/config.yaml is required".into());
    }
    let config_text = fs::read_to_string(&config_path).map_err(|error| error.to_string())?;
    let documents =
        yaml_rust2::YamlLoader::load_from_str(&config_text).map_err(|error| error.to_string())?;
    if documents.len() == 1
        && documents[0]["version"]
            .as_i64()
            .is_some_and(|version| version < 9)
    {
        return Err("older framework configuration; run cumaru migrate before doctor".into());
    }
    let config = config::parse(&config_text)?;
    validate_workflows(project, &config)?;
    let contracts = config_tree::contracts(&root, &config)?;

    let mut files = BTreeMap::new();
    let mut navigation = Vec::new();
    let diagnostics = Walk {
        root: &root,
        deep: true,
    }
    .run(
        std::slice::from_ref(&root),
        |path| path.extension().is_some_and(|extension| extension == "md"),
        |entry| {
            let host = entry
                .path
                .strip_prefix(&root)
                .unwrap()
                .to_string_lossy()
                .into_owned();
            if entry.is_dir {
                let index = entry.path.join("index.md");
                if paths::is_symlink(&index) || !index.is_file() {
                    navigation.push(format!("{host}/: missing regular index.md"));
                }
            } else {
                match fs::read_to_string(entry.path) {
                    Ok(text) => {
                        files.insert(host, text);
                    }
                    Err(error) => navigation.push(format!("{host}: {error}")),
                }
            }
            Ok(())
        },
    )?;
    navigation.extend(diagnostics.into_iter().map(|diagnostic| {
        format!(
            "{}: {}",
            diagnostic
                .path
                .strip_prefix(&root)
                .unwrap_or(&diagnostic.path)
                .to_string_lossy()
                .escape_debug(),
            diagnostic.message
        )
    }));

    let global_fields = config["rules"]["markdown"]["frontmatter"].as_hash();
    let known_tags: BTreeSet<_> = contracts
        .values()
        .flat_map(|contract| contract.tags.iter().cloned())
        .collect();
    let mut configured = Vec::new();
    let mut malformed = Vec::new();
    let mut tag_warnings = Vec::new();
    let mut stale = Vec::new();
    let mut raw = Vec::new();
    let mut retained = Vec::new();

    for (host, text) in &files {
        let contract = contracts.get(host);
        match markdown::frontmatter(text) {
            Ok(frontmatter) => {
                if let Err(error) = markdown::validate_summary(&frontmatter["summary"]) {
                    navigation.push(format!("{host}: {error}"));
                }
                if host.starts_with("disciplines/")
                    && host != "disciplines/index.md"
                    && let Err(error) = markdown::validate_strictness(&frontmatter["strictness"])
                {
                    navigation.push(format!("{host}: {error}"));
                }
                let fields: BTreeMap<String, bool> = contract
                    .map(|contract| contract.frontmatter.clone())
                    .unwrap_or_else(|| {
                        global_fields
                            .into_iter()
                            .flatten()
                            .filter_map(|(key, value)| {
                                key.as_str().map(|key| {
                                    (key.into(), value["optional"].as_bool() == Some(true))
                                })
                            })
                            .collect()
                    });
                for (field, optional) in &fields {
                    if !*optional
                        && !frontmatter
                            .as_hash()
                            .unwrap()
                            .contains_key(&Yaml::String(field.clone()))
                    {
                        configured.push(format!(
                            "{host}: missing required frontmatter field '{field}'"
                        ));
                    }
                }
                if fields.contains_key("targets")
                    && (!fields["targets"] || frontmatter["targets"] != Yaml::BadValue)
                {
                    match frontmatter["targets"].as_vec() {
                        Some(values) => {
                            for value in values {
                                if value.as_str().is_none()
                                    || !config["meta"]["targets"]["values"]
                                        .as_vec()
                                        .is_some_and(|allowed| allowed.contains(value))
                                {
                                    configured.push(format!("{host}: targets value is not a declared domain target: {value:?}"));
                                }
                            }
                        }
                        None => configured.push(format!(
                            "{host}: targets must be an array of domain target names"
                        )),
                    }
                }
            }
            Err(error) => navigation.push(format!("{host}: {error}")),
        }
        if config["rules"]["markdown"]["required_heading"].as_str() == Some("h1")
            && !text.lines().any(|line| line.starts_with("# "))
        {
            configured.push(format!("{host}: missing required H1 heading"));
        }
        match tags::parse(text) {
            Ok(blocks) => {
                if let Some(contract) = contract {
                    for name in &contract.tags {
                        if !blocks.iter().any(|block| &block.name == name) {
                            configured.push(format!("{host}: missing required tag '{name}'"));
                        }
                    }
                }
                for block in &blocks {
                    if !known_tags.contains(&block.name) {
                        tag_warnings
                            .push(format!("{host}: undeclared opaque tag '{}'", block.name));
                    }
                    if block.depth > 1 {
                        tag_warnings.push(format!("{host}: nested tag '{}'", block.name));
                    }
                }
                for (name, _, description, target) in
                    references::cells(text, &blocks, &["files", "touched", "reference"])
                {
                    if !contract.is_some_and(|contract| contract.tags.contains(&name)) {
                        continue;
                    }
                    let verdict = if name == "reference" {
                        references::resolve(&root, &target)
                    } else {
                        file_reference(&root, host, &target)
                    };
                    if let Some((status, target)) = verdict
                        && status != references::Status::Ok
                        && !(name == "touched"
                            && status == references::Status::Missing
                            && description.to_ascii_lowercase().contains("removed"))
                    {
                        retained.push(format!("{host}: {name} {status:?}: {target}"));
                    }
                }
            }
            Err(error) => malformed.push(format!("{host}: {error}")),
        }
        if host.ends_with(".delete-me.md") {
            stale.push(host.clone());
        }
        if text.contains("<!-- BEGIN RAW") {
            raw.push(host.clone());
        }
    }

    let mut report = Report(Vec::new());
    report.check("Configured v9 tree contracts", true, configured);
    report.check(
        "Navigation, summaries, and discipline metadata",
        true,
        navigation,
    );
    report.check("Balanced semantic tags", true, malformed);
    report.check("Unknown and nested tags", false, tag_warnings);
    report.check("Stale work markers", false, stale);
    report.check("Unrefined RAW blocks", false, raw);
    report.check("Retained file references", false, retained);
    report.check("External tools", false, missing_tools());
    report.check(
        "Agent instructions",
        false,
        instruction_issues(project, &files),
    );
    report.check("Configuration drift", false, drift(&config_text, &config)?);
    Ok(report)
}

/// Validates workflow dependencies, cycles, and safe installed skill availability without executing them.
fn validate_workflows(project: &Path, config: &Yaml) -> Result<(), String> {
    for (name, workflow) in config["workflows"].as_hash().into_iter().flatten() {
        let steps = workflow["steps"]
            .as_hash()
            .ok_or("workflow steps must be a mapping")?;
        let mut completed = BTreeSet::new();
        for (step, value) in steps {
            let skill = value["skill"]
                .as_str()
                .ok_or("workflow skill must be a string")?;
            let installed = [".agents/skills", ".claude/skills"]
                .iter()
                .any(|directory| {
                    paths::project_destination(project, &format!("{directory}/{skill}/SKILL.md"))
                        .is_ok_and(|path| path.is_file())
                });
            if !installed {
                return Err(format!(
                    "workflow {name:?}, step {step:?}: unavailable installed skill '{skill}'"
                ));
            }
            for dependency in value["needs"].as_vec().into_iter().flatten() {
                if dependency == step || !steps.contains_key(dependency) {
                    return Err(format!(
                        "workflow {name:?}, step {step:?}: invalid dependency {dependency:?}"
                    ));
                }
            }
        }
        loop {
            let ready: Vec<_> = steps
                .iter()
                .filter(|(step, value)| {
                    !completed.contains(*step)
                        && value["needs"]
                            .as_vec()
                            .into_iter()
                            .flatten()
                            .all(|dependency| completed.contains(dependency))
                })
                .map(|(step, _)| step.clone())
                .collect();
            if ready.is_empty() {
                break;
            }
            completed.extend(ready);
        }
        if completed.len() != steps.len() {
            return Err(format!("workflow {name:?}: dependency cycle"));
        }
    }
    Ok(())
}

/// Resolves retained files/touched links from their host, keeping external and template links out of diagnostics.
fn file_reference(root: &Path, host: &str, target: &str) -> Option<(references::Status, String)> {
    if target.is_empty()
        || target.starts_with('#')
        || target.contains(['<', '>'])
        || target.contains("://")
    {
        return None;
    }
    let target = target.split('#').next().unwrap_or_default();
    if target.starts_with('/') || crate::text::has_control(target) {
        return Some((references::Status::Invalid, target.into()));
    }
    let base = if ["index.md", "domain.md"].contains(&host) {
        root.parent()?.to_path_buf()
    } else {
        root.join(host).parent()?.to_path_buf()
    };
    let path = base.join(target);
    let project = root.parent()?;
    let status = if !path.exists() {
        references::Status::Missing
    } else if fs::canonicalize(&path).is_ok_and(|physical| physical.starts_with(project))
        && path.is_file()
        && !paths::is_symlink(&path)
    {
        references::Status::Ok
    } else {
        references::Status::Invalid
    };
    Some((status, target.into()))
}

/// Checks only native runtime tools needed by network commands, without invoking them or using the network.
fn missing_tools() -> Vec<String> {
    let paths = std::env::var_os("PATH").unwrap_or_default();
    ["git", "curl"]
        .iter()
        .filter(|tool| {
            !std::env::split_paths(&paths).any(|directory| {
                let path = directory.join(tool);
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    fs::metadata(path).is_ok_and(|metadata| {
                        metadata.is_file() && metadata.permissions().mode() & 0o111 != 0
                    })
                }
                #[cfg(not(unix))]
                {
                    path.is_file()
                }
            })
        })
        .map(|tool| format!("{tool} is unavailable on PATH"))
        .collect()
}

/// Discovers a complete generic/Claude/Codex/OpenCode instruction set while preserving all native files.
fn instruction_issues(project: &Path, files: &BTreeMap<String, String>) -> Vec<String> {
    if ["index.md", "domain.md", "disciplines/index.md"]
        .iter()
        .any(|path| !files.contains_key(*path))
    {
        return vec![
            "agent bootstrap requires index.md, domain.md, and disciplines/index.md".into(),
        ];
    }
    let files: BTreeMap<_, _> = files
        .iter()
        .map(|(path, text)| (path.clone(), text.as_bytes().to_vec()))
        .collect();
    for adapter in [
        Adapter::None,
        Adapter::Claude,
        Adapter::Codex,
        Adapter::Opencode,
    ] {
        let rel = adapter.instructions().unwrap_or("opencode.json");
        let text = paths::project_destination(project, rel)
            .ok()
            .and_then(|path| fs::read_to_string(path).ok());
        let Some(text) = text else {
            continue;
        };
        let valid = if adapter == Adapter::Opencode {
            adapter::opencode(Some(&text)).is_ok_and(|expected| {
                serde_json::from_str::<serde_json::Value>(&expected).ok()
                    == serde_json::from_str::<serde_json::Value>(&text).ok()
            })
        } else {
            adapter::markdown(adapter, Some(&text), &files).is_ok_and(|expected| expected == text)
        };
        if valid {
            return Vec::new();
        }
    }
    vec![
        "no complete current Cumaru agent instruction set; use cumaru update agent <agent> --apply"
            .into(),
    ]
}

/// Compares local config with embedded build-time domain defaults, keeping doctor independent of a local snapshot or network.
fn drift(text: &str, local: &Yaml) -> Result<Vec<String>, String> {
    let domain = local["domain"].as_str().unwrap_or_default();
    let source = match domain {
        "base" | "__base" => include_str!("../../domains/__base/config.yaml"),
        "sdlc-full" => include_str!("../../domains/sdlc-full/config.yaml"),
        "sdlc-light" => include_str!("../../domains/sdlc-light/config.yaml"),
        "design-as-code" => include_str!("../../domains/design-as-code/config.yaml"),
        "iac-basic" => include_str!("../../domains/iac-basic/config.yaml"),
        "qa-basic" => include_str!("../../domains/qa-basic/config.yaml"),
        "focus" => include_str!("../../domains/focus/config.yaml"),
        "vault-memory" => include_str!("../../domains/vault-memory/config.yaml"),
        _ => include_str!("../../domains/__base/config.yaml"),
    };
    let mut source = config::parse(source)?;
    if ![
        "base",
        "__base",
        "sdlc-full",
        "sdlc-light",
        "design-as-code",
        "iac-basic",
        "qa-basic",
        "focus",
        "vault-memory",
    ]
    .contains(&domain)
    {
        for key in ["domain", "root", "rules", "meta", "workflows"] {
            if local[key] != Yaml::BadValue
                && let Yaml::Hash(values) = &mut source
            {
                values.insert(Yaml::String(key.into()), local[key].clone());
            }
        }
    }
    let (candidate, removed) = config::reconcile(text, &source)?;
    let candidate = config::parse(&candidate)?;
    if config::yaml_to_json(&candidate)? == config::yaml_to_json(local)? && removed.is_empty() {
        return Ok(Vec::new());
    }
    let mut issues = Vec::new();
    review_properties(
        &config::yaml_to_json(local)?,
        &config::yaml_to_json(&candidate)?,
        "",
        &mut issues,
    );
    issues.push(format!("defaults are embedded in this binary for domain '{domain}'; review with cumaru update config (latest release)"));
    Ok(issues)
}

/// Names changed configuration properties by JSON Pointer rather than reporting formatting differences.
fn review_properties(
    local: &serde_json::Value,
    candidate: &serde_json::Value,
    pointer: &str,
    issues: &mut Vec<String>,
) {
    if local == candidate {
        return;
    }
    if let (Some(local), Some(candidate)) = (local.as_object(), candidate.as_object()) {
        for (key, value) in candidate {
            let pointer = format!("{pointer}/{}", key.replace('~', "~0").replace('/', "~1"));
            if let Some(local) = local.get(key) {
                review_properties(local, value, &pointer, issues);
            } else {
                issues.push(format!(
                    "{pointer}: missing source default; agent review required"
                ));
            }
        }
    } else {
        issues.push(format!(
            "{pointer}: differs from source default; agent review required"
        ));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    struct Fixture(PathBuf);

    impl Fixture {
        /// Creates a custom v9 adopter with safe indexes, a required tag, and complete native instructions.
        fn new() -> Self {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let project =
                std::env::temp_dir().join(format!("cumaru-doctor-{}-{nonce}", std::process::id()));
            fs::create_dir_all(project.join(".cumaru/area")).unwrap();
            fs::create_dir_all(project.join(".cumaru/disciplines")).unwrap();
            let config = "version: 9\ndomain: custom\nrules:\n  markdown: {required_heading: h1, frontmatter: {summary: {}, human_revised: {}}}\n  index_md: {frontmatter: {targets: {}}}\n  pillar_index: {frontmatter: {targets: {}}}\nroot:\n  domain.md: {}\n  disciplines: {}\n  renamed:\n    path: area\n    '*.md': {frontmatter: {status: {}, optional_value: {optional: true}}, tags: [reference]}\nmeta: {targets: {values: [platform]}}\n";
            fs::write(project.join(".cumaru/config.yaml"), config).unwrap();
            let text = "---\nsummary: A sufficiently long summary describing this document.\nhuman_revised: false\ntargets: [platform]\n---\n\n# Document\n";
            for host in [
                "index.md",
                "domain.md",
                "area/index.md",
                "disciplines/index.md",
            ] {
                fs::write(project.join(".cumaru").join(host), text).unwrap();
            }
            fs::write(
                project.join(".cumaru/area/one.md"),
                text.replace("targets: [platform]", "status: active")
                    + "\n<!-- cumaru:reference -->\n<!-- /cumaru:reference -->\n",
            )
            .unwrap();
            let files = ["index.md", "domain.md", "disciplines/index.md"]
                .into_iter()
                .map(|host| (host.into(), text.as_bytes().to_vec()))
                .collect();
            fs::write(
                project.join("AGENTS.md"),
                adapter::markdown(Adapter::Codex, None, &files).unwrap(),
            )
            .unwrap();
            Self(project)
        }

        /// Returns the framework directory of this disposable adopter.
        fn root(&self) -> PathBuf {
            self.0.join(".cumaru")
        }

        /// Captures all regular project file bytes before and after inspection.
        fn snapshot(&self) -> BTreeMap<PathBuf, Vec<u8>> {
            let mut files = BTreeMap::new();
            let mut pending = vec![self.0.clone()];
            while let Some(path) = pending.pop() {
                if path.is_dir() {
                    pending.extend(
                        fs::read_dir(path)
                            .unwrap()
                            .map(|entry| entry.unwrap().path()),
                    );
                } else if !paths::is_symlink(&path) {
                    files.insert(
                        path.strip_prefix(&self.0).unwrap().into(),
                        fs::read(path).unwrap(),
                    );
                }
            }
            files
        }
    }

    impl Drop for Fixture {
        /// Removes only this fixture's disposable adopter.
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    /// Checks a custom tree with an override, wildcard index exemption, optional fields, and no mutation.
    #[test]
    fn accepts_custom_tree_without_writes() {
        let fixture = Fixture::new();
        let before = fixture.snapshot();
        let report = inspect(&fixture.root()).unwrap();
        assert!(!report.failed(), "{}", report.render(false));
        assert!(
            !report.render(false).contains("[warn]"),
            "{}",
            report.render(false)
        );
        assert!(!report.render(true).contains("[ok]"));
        assert_eq!(fixture.snapshot(), before);
    }

    /// Aggregates metadata and malformed-tag errors while retaining opaque tags and stale references as warnings.
    #[test]
    fn reports_defects_and_preserves_bytes() {
        let fixture = Fixture::new();
        let path = fixture.root().join("area/one.md");
        let text = fs::read_to_string(&path).unwrap().replace("status: active", "").replace("<!-- /cumaru:reference -->", "| [missing](missing.rs) | Missing source |\n<!-- /cumaru:reference -->\n<!-- cumaru:opaque -->\n<!-- /cumaru:opaque -->\n<!-- BEGIN RAW");
        fs::write(&path, text).unwrap();
        fs::write(
            fixture.root().join("bad.md"),
            "---\nsummary: short\n---\n# Bad\n<!-- cumaru:bad -->\n",
        )
        .unwrap();
        fs::create_dir(fixture.root().join("unindexed")).unwrap();
        let before = fixture.snapshot();
        let report = inspect(&fixture.root()).unwrap();
        let output = report.render(true);
        assert!(report.failed());
        for expected in [
            "missing required frontmatter field 'status'",
            "summary must contain",
            "missing regular index.md",
            "bad.md:",
            "undeclared opaque tag 'opaque'",
            "Missing: missing.rs",
            "Unrefined RAW blocks",
        ] {
            assert!(output.contains(expected), "{expected}: {output}");
        }
        assert_eq!(fixture.snapshot(), before);
    }

    /// Rejects symlinked roots/configs and older versions before any inspection can mutate files.
    #[cfg(unix)]
    #[test]
    fn refuses_unsafe_and_older_config() {
        let fixture = Fixture::new();
        let alias = fixture.0.join("alias");
        std::os::unix::fs::symlink(fixture.root(), &alias).unwrap();
        assert!(inspect(&alias).unwrap_err().contains("real .cumaru"));
        let config = fixture.root().join("config.yaml");
        let text = fs::read_to_string(&config).unwrap();
        fs::write(&config, text.replace("version: 9", "version: 8")).unwrap();
        assert!(inspect(&fixture.root()).unwrap_err().contains("migrate"));
        fs::remove_file(&config).unwrap();
        std::os::unix::fs::symlink(fixture.0.join("AGENTS.md"), &config).unwrap();
        assert!(inspect(&fixture.root()).unwrap_err().contains("regular"));
    }

    /// Validates workflow skill availability and dependency cycles without running installed skills.
    #[test]
    fn validates_workflows_without_execution() {
        let fixture = Fixture::new();
        fs::create_dir_all(fixture.0.join(".agents/skills/cumaru-test")).unwrap();
        fs::write(
            fixture.0.join(".agents/skills/cumaru-test/SKILL.md"),
            "Never execute this fixture.",
        )
        .unwrap();
        let base = fs::read_to_string(fixture.root().join("config.yaml")).unwrap();
        let graph = "workflows:\n  delivery:\n    steps:\n      a: {skill: cumaru-test}\n      b: {skill: cumaru-test, needs: [a]}\n";
        let valid = config::parse(&(base.clone() + graph)).unwrap();
        validate_workflows(&fixture.0, &valid).unwrap();
        for (graph, message) in [
            (
                graph.replace(
                    "a: {skill: cumaru-test}",
                    "a: {skill: cumaru-test, needs: [b]}",
                ),
                "cycle",
            ),
            (
                graph.replace("needs: [a]", "needs: [missing]"),
                "dependency",
            ),
            (graph.replace("cumaru-test", "cumaru-absent"), "unavailable"),
        ] {
            let config = config::parse(&(base.clone() + &graph)).unwrap();
            assert!(
                validate_workflows(&fixture.0, &config)
                    .unwrap_err()
                    .contains(message)
            );
        }
    }

    /// Reports missing source defaults while accepting YAML formatting and additive local entries.
    #[test]
    fn reviews_config_defaults_offline() {
        let text = include_str!("../../domains/__base/config.yaml");
        let local = config::parse(text).unwrap();
        assert!(drift(text, &local).unwrap().is_empty());
        let changed = text.replace("depends-on: {optional: true}", "");
        let changed = config::parse(&changed).unwrap();
        let text = include_str!("../../domains/__base/config.yaml")
            .replace("depends-on: {optional: true}", "");
        assert!(
            drift(&text, &changed)
                .unwrap()
                .join("\n")
                .contains("/root/frontmatter/depends-on")
        );
        let mut additive = config::yaml_to_json(&local).unwrap();
        additive["root"]["new.md"] = serde_json::json!({});
        let text = additive.to_string();
        assert!(
            drift(&text, &config::parse(&text).unwrap())
                .unwrap()
                .is_empty()
        );
    }

    /// Reports target vocabulary, heading, discipline, and traversal failures without reading a linked outside file.
    #[cfg(unix)]
    #[test]
    fn checks_metadata_and_safe_traversal() {
        let fixture = Fixture::new();
        let index = fixture.root().join("area/index.md");
        let text = fs::read_to_string(&index)
            .unwrap()
            .replace("platform", "foreign")
            .replace("# Document", "Document");
        fs::write(index, &text).unwrap();
        fs::write(fixture.root().join("disciplines/one.md"), &text).unwrap();
        fs::create_dir(fixture.root().join(".hidden")).unwrap();
        fs::write(
            fixture.root().join(".hidden/bad.md"),
            "not Markdown frontmatter",
        )
        .unwrap();
        std::os::unix::fs::symlink(
            fixture.0.join("AGENTS.md"),
            fixture.root().join("outside.md"),
        )
        .unwrap();
        let before = fixture.snapshot();
        let report = inspect(&fixture.root()).unwrap();
        let output = report.render(true);
        assert!(report.failed());
        for expected in [
            "not a declared domain target",
            "missing required H1",
            "strictness must be",
            "outside.md: symlinks are not supported",
        ] {
            assert!(output.contains(expected), "{output}");
        }
        assert!(!output.contains(".hidden"));
        assert_eq!(fixture.snapshot(), before);
    }
}
