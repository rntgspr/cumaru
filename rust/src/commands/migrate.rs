//! `cumaru migrate`: print the current rolling migration instructions for this project.
//!
//! Mirrors `src/cmd_migrate.sh` without a local checkout: the installed domain
//! comes from `.cumaru/config.yaml` or, only when it is absent, the legacy
//! `.cumaru/schema.yaml`; both documents are read from the main HEAD,
//! pinned to that main commit. Strictly read-only, with no apply mode.

use std::fs;
use std::io::{self, Write};
use std::path::Path;
use std::process::ExitCode;

use clap::Args;
use yaml_rust2::{Yaml, YamlLoader};

use crate::config::{CONFIG_FILE, CUMARU_DIR};
use crate::distribution;
use crate::markdown::strip_frontmatter;
use crate::paths::is_symlink;

/// The migration document name at each domain root.
const MIGRATION_FILE: &str = "migration.md";

/// The legacy configuration name, read only as migration input.
const LEGACY_CONFIG_FILE: &str = "schema.yaml";

/// The universal domain whose migration body frames every domain extension.
const BASE_DOMAIN: &str = "__base";

/// The base line where the domain preservation extension is inserted.
const CHECKPOINT: &str = "<!-- cumaru:migration-domain-extension -->";

/// The execution contract printed before the migration bodies.
const PREAMBLE: &str = "\
> **You (the LLM) execute this.** `cumaru migrate` only delivers these
> instructions; it changes nothing and has no `--apply`. Dispatch every step
> yourself, including the deterministic commands.
>
> **Commit or stash first.** There is no transactional rollback — the adopter's
> git history is the only safety net.
>
> Steps are detection-first and idempotent: check whether each applies, skip the
> ones that do not, and re-running the whole document must be a no-op. On any
> blocker, STOP and ask rather than guess.

";

/// Arguments for `cumaru migrate`; `--apply` is accepted only to refuse it with an explanation.
#[derive(Args)]
#[command(
    after_help = "Reads domains/__base/migration.md plus the installed domain's optional migration.md\nfrom the main HEAD, pinned to one commit, strips their frontmatter, and\nprints the bodies with the domain extension at the base preservation checkpoint.\nThe document is never copied into .cumaru/.\n\nThis command performs no migration and has no --apply. The LLM executes the printed\ninstructions. Commit or stash before starting: git is the only rollback."
)]
pub struct MigrateArgs {
    /// Refused: the LLM executes the printed instructions.
    #[arg(long, hide = true)]
    apply: bool,
}

/// Runs `cumaru migrate`, printing the complete document only after every read succeeded.
pub fn run(args: MigrateArgs) -> ExitCode {
    if args.apply {
        eprintln!("cumaru migrate: no --apply; the LLM executes the printed instructions");
        return ExitCode::from(2);
    }

    match execute(Path::new(CUMARU_DIR)) {
        Ok(document) => {
            let _ = io::stdout().lock().write_all(document.as_bytes());
            ExitCode::SUCCESS
        }
        Err(message) => {
            eprintln!("cumaru migrate: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Resolves the installed domain, fetches both bodies from one pinned main commit, and renders them.
fn execute(cumaru: &Path) -> Result<String, String> {
    let domain = installed_domain(cumaru)?;

    let release = distribution::domain_source(BASE_DOMAIN)?;
    let base = utf8(release.read(MIGRATION_FILE)?, "domains/__base/migration.md")?;

    let path = format!("domains/{domain}/{MIGRATION_FILE}");
    let extension = if domain != BASE_DOMAIN && release.repository_files.contains_key(&path) {
        Some(utf8(release.read_repository(&path)?, &path)?)
    } else {
        None
    };

    render(&domain, &base, extension.as_deref())
}

/// Reads the domain from current config, or legacy schema only when current config is absent, without schema validation.
fn installed_domain(cumaru: &Path) -> Result<String, String> {
    let current = cumaru.join(CONFIG_FILE);
    let (config, name) = if fs::symlink_metadata(&current).is_ok() {
        (current, CONFIG_FILE)
    } else {
        (cumaru.join(LEGACY_CONFIG_FILE), LEGACY_CONFIG_FILE)
    };

    if fs::symlink_metadata(&config).is_err() {
        return Err(
            "no installed .cumaru/config.yaml or legacy schema.yaml; run this inside an adopted project"
                .into(),
        );
    }
    if is_symlink(&config) || !config.is_file() {
        return Err(format!(
            ".cumaru/{name} must be a regular file, not a symlink"
        ));
    }

    let text = fs::read_to_string(&config)
        .map_err(|error| format!("cannot read .cumaru/{name}: {error}"))?;
    domain_from_config(&text, name)
}

/// Extracts the `domain` scalar, or legacy `flavor`, from one YAML document and validates it as a domain name.
fn domain_from_config(text: &str, name: &str) -> Result<String, String> {
    let docs = YamlLoader::load_from_str(text)
        .map_err(|error| format!("cannot parse .cumaru/{name}: {error}"))?;
    let [doc] = docs.as_slice() else {
        return Err(format!(
            ".cumaru/{name} must contain exactly one YAML document"
        ));
    };
    let domain = match (&doc["domain"], &doc["flavor"]) {
        (Yaml::String(domain), _) | (Yaml::BadValue | Yaml::Null, Yaml::String(domain)) => domain,
        _ => return Err(format!(".cumaru/{name} declares no domain string")),
    };

    let valid = !domain.is_empty()
        && domain
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-' || byte == b'_');
    if !valid {
        return Err(format!(
            "unknown domain {}: not a domain name",
            crate::text::shell_quote(domain)
        ));
    }

    Ok(if domain == "base" {
        BASE_DOMAIN.into()
    } else {
        domain.clone()
    })
}

/// Decodes a source document as UTF-8 text.
fn utf8(bytes: Vec<u8>, path: &str) -> Result<String, String> {
    String::from_utf8(bytes).map_err(|_| format!("source file is not UTF-8: {path}"))
}

/// Builds the heading and preamble, then the base body split at its checkpoint around the optional domain body.
fn render(domain: &str, base: &str, extension: Option<&str>) -> Result<String, String> {
    let body = strip_frontmatter(base);
    let lines: Vec<&str> = body.lines().collect();
    let Some(at) = lines.iter().position(|line| *line == CHECKPOINT) else {
        return Err("base migration is missing its domain preservation checkpoint".into());
    };

    let mut out = format!("# Migration — {domain}\n\n{PREAMBLE}");
    push_lines(
        &mut out,
        lines[..at]
            .iter()
            .copied()
            .skip_while(|line| line.is_empty()),
    );

    if let Some(extension) = extension.filter(|_| domain != BASE_DOMAIN) {
        out.push('\n');
        out.push_str(&strip_frontmatter(extension));
    }

    out.push('\n');
    push_lines(
        &mut out,
        lines[at + 1..]
            .iter()
            .copied()
            .filter(|line| *line != CHECKPOINT)
            .skip_while(|line| line.is_empty()),
    );

    Ok(out)
}

/// Appends each line with an LF terminator.
fn push_lines<'a>(out: &mut String, lines: impl Iterator<Item = &'a str>) {
    for line in lines {
        out.push_str(line);
        out.push('\n');
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    const BASE: &str = "---\nrelease: 2026-08-01\n---\n\n## 1. Preflight\n\n## 3. Discover\n\n<!-- cumaru:migration-domain-extension -->\n\n\n## 4. Convert\n";

    /// Creates an empty disposable `.cumaru/` directory unique to this test run.
    fn fixture(label: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let base = std::env::temp_dir().join(format!(
            "cumaru-migrate-{label}-{}-{nonce}",
            std::process::id()
        ));
        fs::create_dir_all(base.join(CUMARU_DIR)).unwrap();

        base
    }

    /// Inserts the stripped domain body at the checkpoint and keeps the Bash spacing.
    #[test]
    fn inserts_extension_at_checkpoint() {
        let extension = "---\nsummary: x\n---\n\n## sdlc-full — domain notes\n";
        let out = render("sdlc-full", BASE, Some(extension)).unwrap();

        assert!(out.starts_with(&format!(
            "# Migration — sdlc-full\n\n{PREAMBLE}## 1. Preflight"
        )));
        assert!(
            out.ends_with("## 3. Discover\n\n\n\n## sdlc-full — domain notes\n\n## 4. Convert\n")
        );
        assert!(!out.contains("release:") && !out.contains(CHECKPOINT));
    }

    /// Prints only base content without an extension and ignores a base-domain extension.
    #[test]
    fn renders_base_only_forms() {
        let expected = "## 3. Discover\n\n\n## 4. Convert\n";

        assert!(render("vault", BASE, None).unwrap().ends_with(expected));
        assert!(
            render(BASE_DOMAIN, BASE, Some("## ignored\n"))
                .unwrap()
                .ends_with(expected)
        );
    }

    /// Fails when the checkpoint is absent or appears only inside another line.
    #[test]
    fn requires_checkpoint_line() {
        for base in [
            "## 1. Preflight\n",
            "## 1. Preflight <!-- cumaru:migration-domain-extension -->\n",
        ] {
            assert!(render("sdlc-full", base, None).is_err(), "{base:?}");
        }
    }

    /// Resolves domain or legacy flavor without schema validation and rejects unsafe values.
    #[test]
    fn resolves_domain_from_old_configs() {
        let old = "version: 4\ndomain: sdlc-full\nmeta:\n  tags:\n    absorptions: table\nretired: true\n";
        assert_eq!(
            domain_from_config(old, LEGACY_CONFIG_FILE).unwrap(),
            "sdlc-full"
        );
        assert_eq!(
            domain_from_config("flavor: qa-basic\n", LEGACY_CONFIG_FILE).unwrap(),
            "qa-basic"
        );
        assert_eq!(
            domain_from_config("domain: base\n", CONFIG_FILE).unwrap(),
            BASE_DOMAIN
        );
        assert_eq!(
            domain_from_config("domain: focus\nflavor: other\n", CONFIG_FILE).unwrap(),
            "focus"
        );

        for text in [
            "version: 6\n",
            "domain: 42\n",
            "domain: ''\n",
            "domain: ../focus\n",
            "domain: [focus]\nflavor: focus\n",
            "domain: x\n---\ndomain: y\n",
        ] {
            assert!(domain_from_config(text, CONFIG_FILE).is_err(), "{text:?}");
        }
    }

    /// Prefers current config over legacy schema and reads legacy only when current is absent.
    #[test]
    fn selects_current_then_legacy_config() {
        let base = fixture("select");
        let cumaru = base.join(CUMARU_DIR);

        fs::write(
            cumaru.join(LEGACY_CONFIG_FILE),
            "version: 6\ndomain: qa-basic\n",
        )
        .unwrap();
        assert_eq!(installed_domain(&cumaru).unwrap(), "qa-basic");

        fs::write(cumaru.join(CONFIG_FILE), "version: 9\ndomain: sdlc-full\n").unwrap();
        assert_eq!(installed_domain(&cumaru).unwrap(), "sdlc-full");

        fs::remove_dir_all(base).unwrap();
    }

    /// Fails before network access for missing or symlinked configuration, writing nothing.
    #[test]
    fn requires_regular_installed_config() {
        let base = fixture("missing");
        let cumaru = base.join(CUMARU_DIR);

        let missing = execute(&cumaru).unwrap_err();
        assert!(
            missing.contains("no installed .cumaru/config.yaml or legacy schema.yaml"),
            "{missing}"
        );

        fs::write(base.join("real.yaml"), "domain: focus\n").unwrap();
        std::os::unix::fs::symlink(base.join("real.yaml"), cumaru.join(LEGACY_CONFIG_FILE))
            .unwrap();
        let linked = execute(&cumaru).unwrap_err();
        assert!(linked.contains("must be a regular file"), "{linked}");
        assert_eq!(fs::read_dir(&cumaru).unwrap().count(), 1);

        fs::remove_dir_all(base).unwrap();
    }
}
