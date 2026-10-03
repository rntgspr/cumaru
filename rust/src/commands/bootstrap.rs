//! `cumaru bootstrap`: print the post-install bootstrap steps for this project.
//!
//! Mirrors `src/cmd_bootstrap.sh` without a local domain snapshot: the installed
//! domain comes from `.cumaru/config.yaml`, and both documents are read from the
//! main HEAD, pinned to that main commit. Read-only.

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

/// The bootstrap document name at each domain root.
const BOOTSTRAP_FILE: &str = "bootstrap.md";

/// The universal domain whose bootstrap body always comes first.
const BASE_DOMAIN: &str = "__base";

/// Arguments for `cumaru bootstrap`; it takes none.
#[derive(Args)]
#[command(
    after_help = "Reads domains/__base/bootstrap.md plus the installed domain's optional bootstrap.md\nfrom the main HEAD, pinned to one commit, strips their frontmatter, and\nprints the bodies. Nothing is written; the agent executes the steps, asking the user."
)]
pub struct BootstrapArgs {}

/// Runs `cumaru bootstrap`, printing the complete document only after every read succeeded.
pub fn run(_args: BootstrapArgs) -> ExitCode {
    match execute(Path::new(CUMARU_DIR)) {
        Ok(document) => {
            let _ = io::stdout().lock().write_all(document.as_bytes());
            ExitCode::SUCCESS
        }
        Err(message) => {
            eprintln!("cumaru bootstrap: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Resolves the installed domain, fetches both bodies from one pinned main commit, and renders them.
fn execute(cumaru: &Path) -> Result<String, String> {
    let domain = installed_domain(cumaru)?;

    let release = distribution::domain_source(&domain)?;
    let base = if domain == BASE_DOMAIN {
        release.read(BOOTSTRAP_FILE)?
    } else {
        release.read_repository(&format!("domains/{BASE_DOMAIN}/{BOOTSTRAP_FILE}"))?
    };
    let extension = if domain != BASE_DOMAIN && release.files.contains_key(BOOTSTRAP_FILE) {
        Some(release.read(BOOTSTRAP_FILE)?)
    } else {
        None
    };

    Ok(render(
        &domain,
        &utf8(base, "domains/__base/bootstrap.md")?,
        extension
            .map(|bytes| utf8(bytes, &format!("domains/{domain}/{BOOTSTRAP_FILE}")))
            .transpose()?
            .as_deref(),
    ))
}

/// Reads the `domain` scalar from the regular project config, mapping `base` to `__base`.
fn installed_domain(cumaru: &Path) -> Result<String, String> {
    let config = cumaru.join(CONFIG_FILE);
    let missing = || "no installed .cumaru/config.yaml; run this inside an adopted project";
    if is_symlink(&config) || !config.is_file() {
        return Err(missing().into());
    }

    let text = fs::read_to_string(&config)
        .map_err(|error| format!("cannot read .cumaru/config.yaml: {error}"))?;
    domain_from_config(&text)
}

/// Extracts and validates the installed domain name from one YAML document.
fn domain_from_config(text: &str) -> Result<String, String> {
    let docs = YamlLoader::load_from_str(text)
        .map_err(|error| format!("cannot parse .cumaru/config.yaml: {error}"))?;
    let [doc] = docs.as_slice() else {
        return Err("config must contain exactly one YAML document".into());
    };
    let Yaml::String(domain) = &doc["domain"] else {
        return Err(".cumaru/config.yaml declares no domain string".into());
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

/// Builds the heading, the base body, and the domain body or its absence note.
fn render(domain: &str, base: &str, extension: Option<&str>) -> String {
    let mut out = format!("# Bootstrap — {domain}\n\n");
    out.push_str(&strip_frontmatter(base));
    if domain == BASE_DOMAIN {
        return out;
    }

    out.push('\n');
    match extension {
        Some(body) => out.push_str(&strip_frontmatter(body)),
        None => out.push_str(&format!(
            "> Domain `{domain}` ships no bootstrap.md; only the universal steps apply.\n"
        )),
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    /// Renders base then domain bodies, the absence note, and the base-only form.
    #[test]
    fn renders_documents_in_order() {
        let base = "---\nsummary: base\n---\n\n## Universal rules\n";
        let focus = "---\nsummary: focus\n---\n\n## focus steps\n";

        assert_eq!(
            render("focus", base, Some(focus)),
            "# Bootstrap — focus\n\n\n## Universal rules\n\n\n## focus steps\n"
        );
        assert_eq!(
            render("sdlc-light", base, None),
            "# Bootstrap — sdlc-light\n\n\n## Universal rules\n\n> Domain `sdlc-light` ships no bootstrap.md; only the universal steps apply.\n"
        );
        assert_eq!(
            render("__base", base, None),
            "# Bootstrap — __base\n\n\n## Universal rules\n"
        );
    }

    /// Resolves the domain scalar, maps `base`, and rejects missing, ambiguous, or unsafe values.
    #[test]
    fn resolves_installed_domain() {
        assert_eq!(
            domain_from_config("version: 9\ndomain: focus\n").unwrap(),
            "focus"
        );
        assert_eq!(domain_from_config("domain: base\n").unwrap(), "__base");
        assert_eq!(
            domain_from_config("domain: sdlc_full-2\n").unwrap(),
            "sdlc_full-2"
        );

        for text in [
            "version: 9\n",
            "domain: 42\n",
            "domain: [focus]\n",
            "domain: ''\n",
            "domain: ../focus\n",
            "domain: a/b\n",
            "domain: x\n---\ndomain: y\n",
            "domain: [unclosed\n",
        ] {
            assert!(domain_from_config(text).is_err(), "{text:?}");
        }
    }

    /// Fails before any network access when the project config is missing or a symlink, writing nothing.
    #[test]
    fn requires_a_regular_project_config() {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let base =
            std::env::temp_dir().join(format!("cumaru-bootstrap-{}-{nonce}", std::process::id()));
        let cumaru = base.join(".cumaru");
        fs::create_dir_all(&cumaru).unwrap();

        let missing = execute(&cumaru).unwrap_err();
        assert!(
            missing.contains("no installed .cumaru/config.yaml"),
            "{missing}"
        );

        fs::write(base.join("real.yaml"), "domain: focus\n").unwrap();
        std::os::unix::fs::symlink(base.join("real.yaml"), cumaru.join(CONFIG_FILE)).unwrap();
        let linked = execute(&cumaru).unwrap_err();
        assert!(
            linked.contains("no installed .cumaru/config.yaml"),
            "{linked}"
        );
        assert_eq!(fs::read_dir(&cumaru).unwrap().count(), 1);

        fs::remove_dir_all(base).unwrap();
    }
}
