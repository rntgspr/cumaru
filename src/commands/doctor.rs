use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;
use std::process::ExitCode;

use clap::Args;
use yaml_rust2::Yaml;

use crate::adapter::{self, Adapter};
use crate::walk::Walk;
use crate::{config, config_tree, distribution, markdown, paths, references, tags};

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

/// Runs read-only health checks against the current project's fixed framework directory, then the opt-in adopter cache warm.
pub fn run(args: DoctorArgs) -> ExitCode {
    match inspect(Path::new(config::CUMARU_DIR)) {
        Ok(report) => {
            print!("{}", report.render(args.quiet));
            if report.failed() {
                return ExitCode::FAILURE;
            }

            match after_warm(Path::new(config::CUMARU_DIR)) {
                Ok(()) => ExitCode::SUCCESS,
                Err(message) => {
                    eprintln!("cumaru doctor: vector cache warm failed: {message}");
                    ExitCode::FAILURE
                }
            }
        }
        Err(message) => {
            eprintln!("cumaru doctor: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Warms the `adopter` vector cache after a passing report when `meta.doctor.after.warm` is true; the only doctor side effect.
fn after_warm(root: &Path) -> Result<(), String> {
    let text = fs::read_to_string(root.join(config::CONFIG_FILE)).map_err(|e| e.to_string())?;
    if config::parse(&text)?["meta"]["doctor"]["after"]["warm"].as_bool() != Some(true) {
        return Ok(());
    }

    super::context::warm(root, Some(super::context::Scope::Adopter))
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
    report.check(
        "Configuration drift",
        false,
        drift(&root, &config_text, &config, &today(), &fetch_main)?,
    );
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

/// Highest configuration version this binary validates; a newer reference requires `cumaru migrate`.
const SUPPORTED_VERSION: i64 = 9;

/// Reference domain config chosen for drift, with the calendar date of its cached copy.
struct Reference {
    text: String,
    date: String,
}

/// Downloads the domain's `config.yaml` from GitHub main through the shared domain source.
fn fetch_main(domain: &str) -> Result<Vec<u8>, String> {
    if cfg!(test) {
        return Err("network disabled in unit tests".into());
    }

    let domain = if domain == "base" { "__base" } else { domain };
    distribution::domain_source(domain)?.read("config.yaml")
}

/// Returns today's UTC calendar date as `YYYY-MM-DD` (Hinnant's civil-from-days algorithm).
fn today() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| d.as_secs() as i64);
    let z = secs.div_euclid(86_400) + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = yoe + era * 400 + i64::from(month <= 2);

    format!("{year:04}-{month:02}-{day:02}")
}

/// Parses one YAML document without schema validation, so a newer reference version can still be recognized.
fn raw_yaml(text: &str) -> Result<Yaml, String> {
    yaml_rust2::YamlLoader::load_from_str(text)
        .map_err(|e| format!("invalid reference config: {e}"))?
        .into_iter()
        .next()
        .ok_or_else(|| "empty reference config".to_string())
}

/// Normalizes the `base`/`__base` alias so cached and local domain names compare equal.
fn same_domain(left: &str, right: &str) -> bool {
    let norm = |name: &str| {
        if name == "__base" {
            "base".to_string()
        } else {
            name.to_string()
        }
    };
    norm(left) == norm(right)
}

/// Resolves the drift reference from `.cumaru/.cache/config-<date>.yaml` or main (at most once per day), pushing warnings.
fn reference(
    root: &Path,
    domain: &str,
    today: &str,
    fetch: &dyn Fn(&str) -> Result<Vec<u8>, String>,
    warnings: &mut Vec<String>,
) -> Result<Option<Reference>, String> {
    let cache = root.join(".cache");
    if paths::is_symlink(&cache) {
        return Err(".cumaru/.cache must not be a symlink".into());
    }

    let mut cached = Vec::new();
    if let Ok(entries) = fs::read_dir(&cache) {
        for entry in entries {
            let path = entry.map_err(|e| e.to_string())?.path();
            let name = path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or_default();
            let Some(date) = name
                .strip_prefix("config-")
                .and_then(|rest| rest.strip_suffix(".yaml"))
            else {
                continue;
            };
            if paths::is_symlink(&path) {
                return Err(format!(".cumaru/.cache/{name} must not be a symlink"));
            }
            cached.push((date.to_string(), path));
        }
    }
    cached.sort();

    let matching = |path: &Path| {
        let text = fs::read_to_string(path).ok()?;
        let yaml = raw_yaml(&text).ok()?;
        same_domain(yaml["domain"].as_str()?, domain).then_some(text)
    };

    if let Some((_, path)) = cached.iter().find(|(date, _)| date == today)
        && let Some(text) = matching(path)
    {
        return Ok(Some(Reference {
            text,
            date: today.into(),
        }));
    }

    match fetch(domain).and_then(|bytes| String::from_utf8(bytes).map_err(|e| e.to_string())) {
        Ok(text) => {
            raw_yaml(&text)?;
            fs::create_dir_all(&cache).map_err(|e| format!("cannot create .cumaru/.cache: {e}"))?;
            if let Some(project) = root.parent() {
                crate::vectors::ignore(project)?;
            }

            let target = cache.join(format!("config-{today}.yaml"));
            let temp = cache.join(format!(".config-{today}.yaml.tmp"));
            fs::write(&temp, &text).map_err(|e| format!("cannot write config cache: {e}"))?;
            fs::rename(&temp, &target).map_err(|e| format!("cannot write config cache: {e}"))?;

            for (_, path) in cached.iter().filter(|(_, path)| *path != target) {
                fs::remove_file(path)
                    .map_err(|e| format!("cannot remove old config cache: {e}"))?;
            }

            Ok(Some(Reference {
                text,
                date: today.into(),
            }))
        }
        Err(error) => {
            if let Some((date, text)) = cached
                .iter()
                .rev()
                .find_map(|(date, path)| matching(path).map(|text| (date.clone(), text)))
            {
                warnings.push(format!(
                    "GitHub main is unreachable ({error}); using stale reference .cumaru/.cache/config-{date}.yaml from {date}"
                ));
                return Ok(Some(Reference { text, date }));
            }

            warnings.push(format!(
                "domain '{domain}' reference config is unavailable from GitHub main ({error}); drift was not checked, schema validation only"
            ));
            Ok(None)
        }
    }
}

/// Compares local config with the domain config on GitHub main, cached daily under `.cumaru/.cache/`.
fn drift(
    root: &Path,
    text: &str,
    local: &Yaml,
    today: &str,
    fetch: &dyn Fn(&str) -> Result<Vec<u8>, String>,
) -> Result<Vec<String>, String> {
    let domain = local["domain"].as_str().unwrap_or_default();
    let mut issues = Vec::new();
    let Some(reference) = reference(root, domain, today, fetch, &mut issues)? else {
        return Ok(issues);
    };
    let raw = raw_yaml(&reference.text)?;
    if raw["version"]
        .as_i64()
        .is_some_and(|version| version > SUPPORTED_VERSION)
    {
        return Err(format!(
            "domain '{domain}' reference config on main is version {}, newer than this binary supports ({SUPPORTED_VERSION}); run cumaru migrate",
            raw["version"].as_i64().unwrap_or_default()
        ));
    }
    let source = config::parse(&reference.text)?;

    for key in ["framework", "adopter"] {
        let local_list = local["meta"]["context"][key]
            .as_vec()
            .cloned()
            .unwrap_or_default();
        for entry in source["meta"]["context"][key]
            .as_vec()
            .into_iter()
            .flatten()
        {
            if !local_list.contains(entry) {
                issues.push(format!(
                    "/meta/context/{key}: reference entry '{}' is absent locally; review whether it was removed on purpose",
                    entry.as_str().unwrap_or("?")
                ));
            }
        }
    }

    let (candidate, removed) = config::reconcile(text, &source)?;
    let candidate = config::parse(&candidate)?;
    if config::yaml_to_json(&candidate)? == config::yaml_to_json(local)? && removed.is_empty() {
        return Ok(issues);
    }
    review_properties(
        &config::yaml_to_json(local)?,
        &config::yaml_to_json(&candidate)?,
        "",
        &mut issues,
    );
    issues.push(format!(
        "reference: domains/{domain}/config.yaml on GitHub main, cached .cumaru/.cache/config-{}.yaml; review with cumaru update config",
        reference.date
    ));
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
        let rendered = report.render(false);
        assert_eq!(rendered.matches("[warn]").count(), 1, "{rendered}");
        assert!(
            rendered.contains("[warn] Configuration drift"),
            "{rendered}"
        );
        assert!(rendered.contains("drift was not checked"), "{rendered}");
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

    /// Reports missing reference defaults while accepting YAML formatting and additive local entries, from today's cache.
    #[test]
    fn reviews_config_defaults_offline() {
        let fixture = Fixture::new();
        let root = fixture.root();
        let text = include_str!("../../domains/__base/config.yaml");
        fs::create_dir_all(root.join(".cache")).unwrap();
        fs::write(root.join(".cache/config-2026-01-02.yaml"), text).unwrap();
        let offline = |_: &str| -> Result<Vec<u8>, String> { panic!("network used") };

        let local = config::parse(text).unwrap();
        assert!(
            drift(&root, text, &local, "2026-01-02", &offline)
                .unwrap()
                .is_empty()
        );

        let changed_text = text.replace("depends-on: {optional: true}", "");
        let changed = config::parse(&changed_text).unwrap();
        let issues = drift(&root, &changed_text, &changed, "2026-01-02", &offline)
            .unwrap()
            .join("\n");
        assert!(issues.contains("/root/frontmatter/depends-on"), "{issues}");
        assert!(issues.contains("config-2026-01-02.yaml"), "{issues}");

        let mut additive = config::yaml_to_json(&local).unwrap();
        additive["root"]["new.md"] = serde_json::json!({});
        let text = additive.to_string();
        assert!(
            drift(
                &root,
                &text,
                &config::parse(&text).unwrap(),
                "2026-01-02",
                &offline
            )
            .unwrap()
            .is_empty()
        );
    }

    /// Covers download, daily reuse, stale fallback, refetch on domain mismatch, version gate, context warnings, and symlinks.
    #[cfg(unix)]
    #[test]
    fn resolves_daily_reference_cache() {
        let fixture = Fixture::new();
        let root = fixture.root();
        let text = include_str!("../../domains/__base/config.yaml");
        let local = config::parse(text).unwrap();
        let calls = std::cell::Cell::new(0);
        let online = |domain: &str| -> Result<Vec<u8>, String> {
            assert_eq!(domain, "base");
            calls.set(calls.get() + 1);
            Ok(text.as_bytes().to_vec())
        };
        let offline = |_: &str| -> Result<Vec<u8>, String> { Err("offline".into()) };

        fs::create_dir_all(root.join(".cache")).unwrap();
        fs::write(root.join(".cache/config-2026-01-01.yaml"), text).unwrap();
        assert!(
            drift(&root, text, &local, "2026-01-02", &online)
                .unwrap()
                .is_empty()
        );
        assert_eq!(calls.get(), 1);
        assert!(root.join(".cache/config-2026-01-02.yaml").is_file());
        assert!(!root.join(".cache/config-2026-01-01.yaml").exists());
        assert!(
            fs::read_to_string(fixture.0.join(".gitignore"))
                .unwrap()
                .contains(".cumaru/.cache/")
        );

        assert!(
            drift(&root, text, &local, "2026-01-02", &online)
                .unwrap()
                .is_empty()
        );
        assert_eq!(calls.get(), 1);

        let stale = drift(&root, text, &local, "2026-01-03", &offline)
            .unwrap()
            .join("\n");
        assert!(
            stale.contains("stale reference") && stale.contains("2026-01-02"),
            "{stale}"
        );

        fs::write(
            root.join(".cache/config-2026-01-03.yaml"),
            text.replace("domain: base", "domain: focus"),
        )
        .unwrap();
        drift(&root, text, &local, "2026-01-03", &online).unwrap();
        assert_eq!(calls.get(), 2);
        assert!(!root.join(".cache/config-2026-01-02.yaml").exists());

        fs::remove_dir_all(root.join(".cache")).unwrap();
        let none = drift(&root, text, &local, "2026-01-04", &offline)
            .unwrap()
            .join("\n");
        assert!(none.contains("drift was not checked"), "{none}");

        let newer = |_: &str| -> Result<Vec<u8>, String> {
            Ok(text.replace("version: 9", "version: 10").into_bytes())
        };
        let error = drift(&root, text, &local, "2026-01-05", &newer).unwrap_err();
        assert!(error.contains("cumaru migrate"), "{error}");

        let removed = text.replace("framework: [domain.md, index.md,", "framework: [domain.md,");
        let issues = drift(
            &root,
            &removed,
            &config::parse(&removed).unwrap(),
            "2026-01-06",
            &online,
        )
        .unwrap()
        .join("\n");
        assert!(
            issues.contains("/meta/context/framework: reference entry 'index.md'"),
            "{issues}"
        );

        fs::remove_dir_all(root.join(".cache")).unwrap();
        fs::create_dir_all(root.join(".cache")).unwrap();
        std::os::unix::fs::symlink(
            fixture.0.join("AGENTS.md"),
            root.join(".cache/config-2026-01-07.yaml"),
        )
        .unwrap();
        assert!(
            drift(&root, text, &local, "2026-01-07", &online)
                .unwrap_err()
                .contains("symlink")
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
