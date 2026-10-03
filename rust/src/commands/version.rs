//! `cumaru version`: print the build-time CLI version and, inside an adopter,
//! the installed domain and config contract version.
//!
//! Offline and read-only. The CLI and installed config versions are independent
//! identities; neither is inferred from the other, and the installed config is
//! not validated against the current schema so older contracts still report.

use std::fs;
use std::path::Path;
use std::process::ExitCode;

use yaml_rust2::{Yaml, YamlLoader};

use crate::config::{CONFIG_FILE, CUMARU_DIR};
use crate::paths::is_symlink;
use crate::release::VERSION;
use crate::text::has_control;

/// Installed adopter identity read from `.cumaru/config.yaml`.
#[derive(Debug, PartialEq)]
struct Installed {
    domain: String,
    version: i64,
}

/// Runs `cumaru version`: always prints the CLI version, then the adopter identity or a diagnostic.
pub fn run() -> ExitCode {
    println!("version:  {VERSION}");

    match installed(Path::new(CUMARU_DIR)) {
        Ok(None) => ExitCode::SUCCESS,
        Ok(Some(Installed { domain, version })) => {
            println!("domain:   {domain}");
            println!("config:   {version}");
            ExitCode::SUCCESS
        }
        Err(message) => {
            eprintln!("cumaru version: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Reads the adopter identity when `.cumaru/` exists; absence is not an error, a present but unsafe or malformed adopter is.
fn installed(cumaru: &Path) -> Result<Option<Installed>, String> {
    if fs::symlink_metadata(cumaru).is_err() {
        return Ok(None);
    }
    if is_symlink(cumaru) || !cumaru.is_dir() {
        return Err(".cumaru must be a regular directory, not a symlink".into());
    }

    let config = cumaru.join(CONFIG_FILE);
    if fs::symlink_metadata(&config).is_err() {
        return Err("adopter has no .cumaru/config.yaml".into());
    }
    if is_symlink(&config) || !config.is_file() {
        return Err(".cumaru/config.yaml must be a regular file, not a symlink".into());
    }

    let text = fs::read_to_string(&config)
        .map_err(|error| format!("cannot read .cumaru/config.yaml: {error}"))?;
    identity(&text).map(Some)
}

/// Extracts the `domain` string and integer `version` from exactly one YAML document, without schema validation.
fn identity(text: &str) -> Result<Installed, String> {
    let docs = YamlLoader::load_from_str(text)
        .map_err(|error| format!("cannot parse .cumaru/config.yaml: {error}"))?;
    let [doc] = docs.as_slice() else {
        return Err(".cumaru/config.yaml must contain exactly one YAML document".into());
    };

    let domain = match &doc["domain"] {
        Yaml::String(domain) if !domain.is_empty() && !has_control(domain) => domain.clone(),
        _ => return Err(".cumaru/config.yaml declares no valid domain string".into()),
    };

    let Yaml::Integer(version) = doc["version"] else {
        return Err(".cumaru/config.yaml declares no integer version".into());
    };

    Ok(Installed { domain, version })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    /// Creates a unique disposable project directory for one test.
    fn project(label: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let base = std::env::temp_dir().join(format!(
            "cumaru-version-{label}-{}-{nonce}",
            std::process::id()
        ));
        fs::create_dir_all(&base).unwrap();

        base
    }

    /// Reports no adopter when `.cumaru/` is absent, creating nothing.
    #[test]
    fn absent_adopter_reports_cli_only() {
        let base = project("absent");

        assert_eq!(installed(&base.join(CUMARU_DIR)), Ok(None));
        assert_eq!(fs::read_dir(&base).unwrap().count(), 0);

        fs::remove_dir_all(base).unwrap();
    }

    /// Reports the shipped base identity and config 9 independently of the CLI version.
    #[test]
    fn reports_installed_identity() {
        let base = project("valid");
        let cumaru = base.join(CUMARU_DIR);
        fs::create_dir_all(&cumaru).unwrap();
        let text = include_str!("../../../domains/__base/config.yaml");
        fs::write(cumaru.join(CONFIG_FILE), text).unwrap();

        let found = installed(&cumaru).unwrap().unwrap();
        assert_eq!(found.domain, "base");
        assert_eq!(found.version, 9);
        assert_ne!(found.version.to_string(), VERSION);
        assert_eq!(fs::read_to_string(cumaru.join(CONFIG_FILE)).unwrap(), text);

        fs::remove_dir_all(base).unwrap();
    }

    /// Reports an older installed integer without requiring current-schema compatibility.
    #[test]
    fn reports_older_contract_verbatim() {
        let text = "version: 3\ndomain: legacy\nunknown: [not, in, schema]\n";

        assert_eq!(
            identity(text),
            Ok(Installed {
                domain: "legacy".into(),
                version: 3
            })
        );
    }

    /// Rejects malformed, multi-document, and mistyped metadata without inventing a version.
    #[test]
    fn rejects_malformed_metadata() {
        for text in [
            "domain: [unclosed\n",
            "version: 9\ndomain: a\n---\nversion: 9\ndomain: b\n",
            "",
            "version: 9\n",
            "version: 9\ndomain: 42\n",
            "version: 9\ndomain: ''\n",
            "version: 9\ndomain: \"a\\tb\"\n",
            "domain: focus\n",
            "version: '9'\ndomain: focus\n",
            "version: 9.0\ndomain: focus\n",
        ] {
            assert!(identity(text).is_err(), "{text:?}");
        }
    }

    /// Diagnoses a present adopter with a missing, linked, or non-file config, or a linked root, leaving files unchanged.
    #[test]
    fn rejects_unsafe_adopter_layout() {
        let base = project("unsafe");
        let cumaru = base.join(CUMARU_DIR);
        fs::create_dir_all(&cumaru).unwrap();

        let missing = installed(&cumaru).unwrap_err();
        assert!(missing.contains("no .cumaru/config.yaml"), "{missing}");

        fs::create_dir(cumaru.join(CONFIG_FILE)).unwrap();
        let directory = installed(&cumaru).unwrap_err();
        assert!(directory.contains("regular file"), "{directory}");
        fs::remove_dir(cumaru.join(CONFIG_FILE)).unwrap();

        fs::write(base.join("real.yaml"), "version: 9\ndomain: focus\n").unwrap();
        std::os::unix::fs::symlink(base.join("real.yaml"), cumaru.join(CONFIG_FILE)).unwrap();
        let linked = installed(&cumaru).unwrap_err();
        assert!(linked.contains("regular file"), "{linked}");
        assert_eq!(fs::read_dir(&cumaru).unwrap().count(), 1);

        let elsewhere = base.join("elsewhere");
        fs::create_dir(&elsewhere).unwrap();
        fs::write(elsewhere.join(CONFIG_FILE), "version: 9\ndomain: focus\n").unwrap();
        let root = base.join("linked");
        fs::create_dir(&root).unwrap();
        std::os::unix::fs::symlink(&elsewhere, root.join(CUMARU_DIR)).unwrap();
        let linked_root = installed(&root.join(CUMARU_DIR)).unwrap_err();
        assert!(linked_root.contains("regular directory"), "{linked_root}");

        fs::write(root.join("file"), "").unwrap();
        let file_root = installed(&root.join("file")).unwrap_err();
        assert!(file_root.contains("regular directory"), "{file_root}");

        fs::remove_dir_all(base).unwrap();
    }

    /// Keeps every shipped domain config at the base contract version, named after its domain.
    #[test]
    fn shipped_configs_match_base_version() {
        let domains = Path::new(env!("CARGO_MANIFEST_DIR")).join("../domains");
        let base = identity(&fs::read_to_string(domains.join("__base").join(CONFIG_FILE)).unwrap())
            .unwrap();
        assert_eq!(base.version, 9);

        let mut checked = 0;
        for entry in fs::read_dir(&domains).unwrap() {
            let dir = entry.unwrap().path();
            let config = dir.join(CONFIG_FILE);
            if !config.is_file() {
                continue;
            }

            let shipped = identity(&fs::read_to_string(&config).unwrap()).unwrap();
            let name = dir.file_name().unwrap().to_string_lossy().into_owned();
            let expected = if name == "__base" {
                "base"
            } else {
                name.as_str()
            };
            assert_eq!(shipped.domain, expected, "{}", config.display());
            assert_eq!(shipped.version, base.version, "{}", config.display());
            checked += 1;
        }
        assert!(checked > 1);
    }
}
