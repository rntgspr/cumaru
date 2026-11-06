//! `cumaru hooks`: deterministic, offline payloads for native agent hooks.
//!
//! Each subcommand reads only installed local files and prints the complete
//! context a hook injects into the agent message. Output is atomic: the whole
//! set is validated before anything is printed, and failures print a single
//! diagnostic line instead of partial context. Every outcome exits 0 so a hook
//! never blocks the user's prompt; the diagnostic itself reaches the agent.

use std::fs;
use std::io::Read;
use std::path::Path;
use std::process::{Command, ExitCode, Stdio};

use clap::{Args, Subcommand};

use crate::config::CUMARU_DIR;
use crate::markdown::{frontmatter, validate_strictness, validate_summary};
use crate::paths::is_symlink;
use crate::text::has_control;

/// Byte budget for the per-prompt digest, including the header and the kernel line.
const DIGEST_BUDGET: usize = 32768;

/// Byte budget for the complete session-start payload, including the tree projection.
const SESSION_BUDGET: usize = 65536;

/// The universal priority gate, always listed first.
const FIRST: &str = "cumaru-first";

/// Arguments for `cumaru hooks`.
#[derive(Args)]
pub struct HooksArgs {
    #[command(subcommand)]
    hook: Hook,
}

/// Supported hook payloads.
#[derive(Subcommand)]
enum Hook {
    /// Print a compact per-prompt digest of every installed discipline summary.
    Disciplines,

    /// Print the kernel summary, then the discipline digest, for every prompt.
    Prompt,

    /// Print the discipline index and every discipline body, then the root tree projection.
    Session,

    /// Read native PreToolUse JSON on stdin and deny whole-file shell reads of `.cumaru/` Markdown.
    Pretool,
}

/// One installed discipline reduced to its digest fields.
#[derive(Debug, PartialEq)]
struct Discipline {
    name: String,
    strictness: u8,
    summary: String,
    path: String,
}

/// Runs the selected hook payload and always exits successfully.
pub fn run(args: HooksArgs) -> ExitCode {
    let (label, result) = match args.hook {
        Hook::Pretool => {
            let mut input = String::new();
            if std::io::stdin().read_to_string(&mut input).is_ok()
                && let Some(decision) = pretool(&input)
            {
                println!("{decision}");
            }
            return ExitCode::SUCCESS;
        }
        Hook::Disciplines => ("disciplines", digest(Path::new(CUMARU_DIR))),
        Hook::Prompt => ("prompt", prompt(Path::new(CUMARU_DIR))),
        Hook::Session => (
            "session",
            session(Path::new(CUMARU_DIR)).and_then(|body| body.map(with_tree).transpose()),
        ),
    };

    match result {
        Ok(Some(text)) => print!("{text}"),
        Ok(None) => {}
        Err(error) => println!(
            "cumaru hooks {label}: {}; no context emitted. Read .cumaru/disciplines/ manually.",
            flatten(&error)
        ),
    }

    ExitCode::SUCCESS
}

/// Appends the captured root tree projection and validates the complete session budget.
fn with_tree(body: String) -> Result<String, String> {
    let binary = std::env::current_exe().map_err(|error| error.to_string())?;
    let tree = Command::new(binary)
        .args(["tree", "."])
        .stderr(Stdio::null())
        .output()
        .map_err(|error| format!("cannot run cumaru tree: {error}"))?;
    let tree = String::from_utf8(tree.stdout).map_err(|_| "tree output is not UTF-8")?;

    let output = format!("{body}\n{tree}");
    if output.len() > SESSION_BUDGET {
        return Err(format!(
            "session payload is {} bytes, over the {SESSION_BUDGET}-byte budget",
            output.len()
        ));
    }

    Ok(output)
}

/// Replaces control characters so a diagnostic always stays on one line.
fn flatten(text: &str) -> String {
    text.chars()
        .map(|c| if c.is_control() { '?' } else { c })
        .collect()
}

/// Reads every regular discipline Markdown file in C byte order, rejecting unsafe entries first.
fn installed(cumaru: &Path) -> Result<Option<Vec<(String, String)>>, String> {
    if fs::symlink_metadata(cumaru).is_err() {
        return Ok(None);
    }
    let directory = cumaru.join("disciplines");
    if is_symlink(cumaru) || is_symlink(&directory) || !directory.is_dir() {
        return Err(".cumaru/disciplines must be a regular directory".into());
    }

    let mut files = Vec::new();
    for entry in fs::read_dir(&directory).map_err(|error| error.to_string())? {
        let path = entry.map_err(|error| error.to_string())?.path();
        let Some(file) = path.file_name().and_then(|name| name.to_str()) else {
            return Err("discipline file names must be UTF-8".into());
        };
        if has_control(file) {
            return Err("discipline file names must not contain control characters".into());
        }
        if !file.ends_with(".md") {
            continue;
        }
        if is_symlink(&path) || !path.is_file() {
            return Err(format!(".cumaru/disciplines/{file} must be a regular file"));
        }

        let text = fs::read_to_string(&path).map_err(|error| format!("{file}: {error}"))?;
        files.push((file.to_string(), text));
    }
    files.sort_by(|a, b| a.0.as_bytes().cmp(b.0.as_bytes()));

    Ok(Some(files))
}

/// Builds the session payload: index first, then every other body, within budget.
fn session(cumaru: &Path) -> Result<Option<String>, String> {
    let Some(mut files) = installed(cumaru)? else {
        return Ok(None);
    };
    if !files.iter().any(|(file, _)| file == "index.md") {
        return Err("missing .cumaru/disciplines/index.md".into());
    }
    if !files.iter().any(|(file, _)| file != "index.md") {
        return Err("no installed disciplines".into());
    }
    files.sort_by_key(|(file, _)| file != "index.md");

    let mut output = String::new();
    for (file, text) in &files {
        output.push_str(&format!(
            "\n## Discipline: .cumaru/disciplines/{file}\n\n{text}"
        ));
    }
    if output.len() > SESSION_BUDGET {
        return Err(format!(
            "discipline bodies are {} bytes, over the {SESSION_BUDGET}-byte budget",
            output.len()
        ));
    }

    Ok(Some(output))
}

/// Builds the digest for an installed `.cumaru/`; absence of an installation yields no output.
fn digest(cumaru: &Path) -> Result<Option<String>, String> {
    let Some(files) = installed(cumaru)? else {
        return Ok(None);
    };

    let mut disciplines = Vec::new();
    for (file, text) in files.iter().filter(|(file, _)| file != "index.md") {
        disciplines.push(parse(file, text).map_err(|error| format!("{file}: {error}"))?);
    }
    if disciplines.is_empty() {
        return Err("no installed disciplines".into());
    }

    disciplines.sort_by(|a, b| {
        (
            a.name != FIRST,
            std::cmp::Reverse(a.strictness),
            a.path.as_bytes(),
        )
            .cmp(&(
                b.name != FIRST,
                std::cmp::Reverse(b.strictness),
                b.path.as_bytes(),
            ))
    });

    let mut output = String::from(
        "Cumaru disciplines (active every turn): evaluate each applies-when by strictness and reread the full body before acting on a match.\n",
    );
    for discipline in &disciplines {
        output.push_str(&format!(
            "- {} [{}/10] {} ({})\n",
            discipline.name, discipline.strictness, discipline.summary, discipline.path
        ));
    }
    if output.len() > DIGEST_BUDGET {
        return Err(format!(
            "digest is {} bytes, over the {DIGEST_BUDGET}-byte budget",
            output.len()
        ));
    }

    Ok(Some(output))
}

/// Prepends the validated kernel summary to the discipline digest within the same budget.
fn prompt(cumaru: &Path) -> Result<Option<String>, String> {
    let Some(disciplines) = digest(cumaru)? else {
        return Ok(None);
    };

    let index = cumaru.join("index.md");
    if is_symlink(&index) || !index.is_file() {
        return Err(".cumaru/index.md must be a regular file".into());
    }
    let text = fs::read_to_string(&index).map_err(|error| format!("index.md: {error}"))?;
    let yaml = frontmatter(&text).map_err(|error| format!("index.md: {error}"))?;
    validate_summary(&yaml["summary"]).map_err(|error| format!("index.md: {error}"))?;

    let output = format!(
        "Cumaru kernel (active every turn; reread .cumaru/index.md before acting on its topic): {}\n{disciplines}",
        yaml["summary"].as_str().unwrap_or_default()
    );
    if output.len() > DIGEST_BUDGET {
        return Err(format!(
            "prompt digest is {} bytes, over the {DIGEST_BUDGET}-byte budget",
            output.len()
        ));
    }

    Ok(Some(output))
}

/// Shell readers whose `.cumaru/` Markdown targets are redirected to `cumaru map` and `cumaru get`.
const READERS: [&str; 4] = ["cat", "head", "tail", "sed"];

/// Returns a PreToolUse deny decision when a shell command reads `.cumaru/` Markdown, or `None` to pass.
///
/// Parsing is conservative: malformed input, non-shell tools, in-place `sed`, and paths not
/// spelled through a `.cumaru/` component all pass through untouched.
fn pretool(input: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(input).ok()?;
    // Claude sends a string; Codex shells may send an argv array such as ["bash", "-lc", "..."].
    let command = match &value["tool_input"]["command"] {
        serde_json::Value::String(command) => command.clone(),
        serde_json::Value::Array(argv) => argv
            .iter()
            .filter_map(|arg| arg.as_str())
            .collect::<Vec<_>>()
            .join("\n"),
        _ => return None,
    };

    let mut targets = Vec::new();
    for segment in command.split(['|', ';', '&', '(', ')', '\n']) {
        let words: Vec<String> = segment
            .split(|c: char| c.is_whitespace() || c == '<')
            .filter(|word| !word.is_empty())
            .map(|word| word.trim_matches(['\'', '"']).to_string())
            .collect();
        let Some(program) = words.first() else {
            continue;
        };

        let program = program.rsplit('/').next().unwrap_or(program);
        if !READERS.contains(&program) {
            continue;
        }
        if program == "sed"
            && words
                .iter()
                .any(|w| w.starts_with("-i") || w == "--in-place")
        {
            continue;
        }

        for word in &words[1..] {
            let rel = word
                .strip_prefix(".cumaru/")
                .or_else(|| word.split_once("/.cumaru/").map(|(_, rel)| rel));
            if let Some(rel) = rel.filter(|rel| rel.ends_with(".md") && !has_control(rel)) {
                targets.push(rel.to_string());
            }
        }
    }
    if targets.is_empty() {
        return None;
    }

    targets.dedup();
    let reason = format!(
        "Cumaru blocks shell reads of .cumaru/ Markdown. Outline first with `cumaru map {}`, then read only the needed sections with `cumaru get <path:start,end>...`, copying selectors from the map rows (paths are relative to .cumaru/).",
        targets.join(" ")
    );

    Some(
        serde_json::json!({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        })
        .to_string(),
    )
}

/// Extracts and validates the digest fields from one discipline's frontmatter.
fn parse(file: &str, text: &str) -> Result<Discipline, String> {
    let yaml = frontmatter(text)?;
    validate_summary(&yaml["summary"])?;
    validate_strictness(&yaml["strictness"])?;

    let name = yaml["name"]
        .as_str()
        .filter(|name| !name.is_empty() && !has_control(name))
        .ok_or("name must be a non-empty string")?;
    let strictness = yaml["strictness"].as_str().unwrap_or_default();

    Ok(Discipline {
        name: name.into(),
        strictness: strictness
            .trim_end_matches("/10")
            .parse()
            .unwrap_or_default(),
        summary: yaml["summary"].as_str().unwrap_or_default().into(),
        path: format!(".cumaru/disciplines/{file}"),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    /// Creates a disposable `.cumaru/disciplines` tree for one test.
    fn project(label: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let base = std::env::temp_dir().join(format!(
            "cumaru-hooks-{label}-{}-{nonce}",
            std::process::id()
        ));
        fs::create_dir_all(base.join("disciplines")).unwrap();

        base
    }

    /// Writes one discipline file with the given name, strictness, and summary.
    fn discipline(base: &Path, name: &str, strictness: &str) {
        let text = format!(
            "---\nname: {name}\nstrictness: {strictness}\nsummary: Apply the {name} rule before acting on its trigger.\n---\n\n# Body\n"
        );
        fs::write(base.join("disciplines").join(format!("{name}.md")), text).unwrap();
    }

    /// Orders cumaru-first first, then strictness descending, then path bytes, skipping the index.
    #[test]
    fn orders_priority_gate_then_strictness() {
        let base = project("order");
        discipline(&base, "acceptance", "10/10");
        discipline(&base, FIRST, "10/10");
        discipline(&base, "yagni", "8/10");
        discipline(&base, "kiss", "9/10");
        fs::write(base.join("disciplines/index.md"), "# Disciplines\n").unwrap();

        let text = digest(&base).unwrap().unwrap();
        let names: Vec<_> = text
            .lines()
            .skip(1)
            .map(|line| line.split(' ').nth(1).unwrap())
            .collect();
        assert_eq!(names, [FIRST, "acceptance", "kiss", "yagni"]);
        assert!(text.contains("(.cumaru/disciplines/kiss.md)"));

        fs::remove_dir_all(base).unwrap();
    }

    /// Emits nothing outside an installation.
    #[test]
    fn absent_installation_is_silent() {
        let base = project("absent");

        assert_eq!(digest(&base.join("missing")), Ok(None));

        fs::remove_dir_all(base).unwrap();
    }

    /// Fails atomically on invalid metadata, an empty set, or budget overflow.
    #[test]
    fn rejects_incomplete_or_oversized_sets() {
        let base = project("invalid");
        assert!(
            digest(&base)
                .unwrap_err()
                .contains("no installed disciplines")
        );

        fs::write(base.join("disciplines/bad.md"), "# no frontmatter\n").unwrap();
        assert!(digest(&base).unwrap_err().contains("bad.md"));
        fs::remove_file(base.join("disciplines/bad.md")).unwrap();

        discipline(&base, "loose", "11/10");
        assert!(digest(&base).unwrap_err().contains("strictness"));
        fs::remove_file(base.join("disciplines/loose.md")).unwrap();

        for index in 0..500 {
            discipline(
                &base,
                &format!("rule-{index:02}-{}", "x".repeat(40)),
                "5/10",
            );
        }
        assert!(digest(&base).unwrap_err().contains("budget"));

        fs::remove_dir_all(base).unwrap();
    }

    /// Keeps every shipped domain's digest within budget.
    #[test]
    fn shipped_domains_fit_budget() {
        let domains = Path::new(env!("CARGO_MANIFEST_DIR")).join("domains");
        for entry in fs::read_dir(domains).unwrap() {
            let dir = entry.unwrap().path();
            if dir.join("disciplines").is_dir() {
                let text = digest(&dir).unwrap().unwrap();
                assert!(text.len() <= DIGEST_BUDGET, "{}", dir.display());
            }
        }
    }

    /// Puts the kernel summary first, keeps the discipline digest, and requires a valid index.
    #[test]
    fn prompt_prepends_kernel_summary() {
        let base = project("prompt");
        discipline(&base, FIRST, "10/10");

        assert!(prompt(&base).unwrap_err().contains("index.md"));
        fs::write(
            base.join("index.md"),
            "---\nsummary: Load only what is declared and follow the output style.\n---\n",
        )
        .unwrap();
        let text = prompt(&base).unwrap().unwrap();
        let lines: Vec<_> = text.lines().collect();
        assert!(lines[0].starts_with("Cumaru kernel"));
        assert!(lines[0].ends_with("follow the output style."));
        assert!(lines[1].starts_with("Cumaru disciplines"));
        assert_eq!(prompt(&base.join("missing")), Ok(None));

        fs::remove_dir_all(base).unwrap();
    }

    /// Keeps every shipped domain's prompt digest, kernel included, within budget.
    #[test]
    fn shipped_domains_prompt_fits_budget() {
        let domains = Path::new(env!("CARGO_MANIFEST_DIR")).join("domains");
        for entry in fs::read_dir(domains).unwrap() {
            let dir = entry.unwrap().path();
            if dir.join("disciplines").is_dir() {
                assert!(prompt(&dir).unwrap().is_some(), "{}", dir.display());
            }
        }
    }

    /// Rejects control characters in file names and keeps diagnostics on one line.
    #[test]
    fn rejects_control_names() {
        let base = project("control");
        discipline(&base, "ok", "5/10");
        fs::copy(
            base.join("disciplines/ok.md"),
            base.join("disciplines/line\nbreak.md"),
        )
        .unwrap();

        let error = digest(&base).unwrap_err();
        assert!(error.contains("control characters"));
        assert!(session(&base).is_err());
        assert_eq!(flatten("a\nb\u{7f}"), "a?b?");

        fs::remove_dir_all(base).unwrap();
    }

    /// Denies shell reads of `.cumaru/` Markdown and passes everything else.
    #[test]
    fn pretool_denies_cumaru_reads_only() {
        let call = |command: &str| {
            pretool(
                &serde_json::json!({"tool_name": "Bash", "tool_input": {"command": command}})
                    .to_string(),
            )
        };

        let denied = call("cat .cumaru/specs/auth.md | head -5").unwrap();
        let value: serde_json::Value = serde_json::from_str(&denied).unwrap();
        assert_eq!(value["hookSpecificOutput"]["permissionDecision"], "deny");
        let reason = value["hookSpecificOutput"]["permissionDecisionReason"]
            .as_str()
            .unwrap();
        assert!(reason.contains("cumaru map specs/auth.md"));
        assert!(reason.contains("cumaru get"));

        assert!(call("cd x && /bin/cat \"/p/.cumaru/index.md\"").is_some());
        assert!(call("sed -n 1,20p .cumaru/a.md").is_some());
        assert!(call("tail < .cumaru/a.md").is_some());

        assert!(call("sed -i '' s/a/b/ .cumaru/a.md").is_none());
        assert!(call("cat README.md").is_none());
        assert!(call("cat .cumaru/config.yaml").is_none());
        assert!(call("cumaru get a.md:1,4").is_none());
        assert!(call("rg cat .cumaru/a.md").is_none());
        let argv = serde_json::json!({"tool_name": "Bash", "tool_input": {"command": ["bash", "-lc", "cat .cumaru/a.md"]}});
        assert!(pretool(&argv.to_string()).is_some());

        assert!(pretool("not json").is_none());
        assert!(pretool(r#"{"tool_input":{"file_path":".cumaru/a.md"}}"#).is_none());
    }

    /// Emits the index first, then bodies in C order, and fails atomically over budget.
    #[test]
    fn session_orders_index_and_bounds_bodies() {
        let base = project("session");
        discipline(&base, "b", "5/10");
        discipline(&base, "a", "5/10");

        assert!(session(&base).unwrap_err().contains("index.md"));
        fs::write(base.join("disciplines/index.md"), "INDEX\n").unwrap();
        let text = session(&base).unwrap().unwrap();
        let index = text.find("index.md").unwrap();
        assert!(index < text.find("/a.md").unwrap());
        assert!(text.find("/a.md").unwrap() < text.find("/b.md").unwrap());

        fs::write(base.join("disciplines/big.md"), "x".repeat(SESSION_BUDGET)).unwrap();
        assert!(session(&base).unwrap_err().contains("budget"));

        fs::remove_dir_all(base).unwrap();
    }
}
