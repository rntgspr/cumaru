//! Access to the official release repository and binary installer.

use serde_json::Value;
use std::collections::BTreeMap;
use std::process::{Command, ExitCode, Stdio};

use crate::release::highest_release;

const REMOTE: &str = "https://github.com/rntgspr/cumaru.git";
const INSTALL: &str = include_str!("../install.sh");

pub(crate) struct DomainRelease {
    pub revision: String,
    pub domain: String,
    pub files: BTreeMap<String, String>,
    pub repository_files: BTreeMap<String, String>,
}

/// Fetches a public resource with bounded cURL execution, classifying missing release files explicitly.
fn download(url: &str) -> Result<Vec<u8>, String> {
    let output = Command::new("curl")
        .args([
            "-fsSL",
            "--connect-timeout",
            "15",
            "--max-time",
            "120",
            "-H",
            "Accept: application/vnd.github+json",
            "-H",
            "User-Agent: cumaru",
            "-w",
            "%{http_code}",
            url,
        ])
        .output()
        .map_err(|e| format!("cannot run cURL: {e}"))?;
    let code = output
        .stdout
        .get(output.stdout.len().saturating_sub(3)..)
        .unwrap_or_default();
    if !output.status.success() {
        if code == b"404" {
            return Err(format!("release file was not found (HTTP 404): {url}"));
        }
        return Err(format!(
            "cannot download {url}: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    if code != b"200" {
        return Err(format!(
            "unexpected HTTP status {} from {url}",
            String::from_utf8_lossy(code)
        ));
    }
    Ok(output.stdout[..output.stdout.len() - 3].to_vec())
}

/// Encodes path bytes for public HTTPS URLs while retaining hierarchy separators.
fn url_path(path: &str) -> String {
    path.bytes()
        .map(|byte| {
            if byte.is_ascii_alphanumeric() || b"/-_.~".contains(&byte) {
                (byte as char).to_string()
            } else {
                format!("%{byte:02X}")
            }
        })
        .collect()
}

/// Resolves a tag's recursive Git inventory and keeps regular selected-domain blobs pinned to one revision.
pub(crate) fn domain_release(tag: &str, domain: &str) -> Result<DomainRelease, String> {
    if crate::release::release_parts(tag).is_none() {
        return Err("project source must be a plain X.Y.Z release tag".into());
    }
    let commit_url = format!("https://api.github.com/repos/rntgspr/cumaru/commits/{tag}");
    let commit: Value = serde_json::from_slice(&download(&commit_url)?)
        .map_err(|e| format!("invalid release commit: {e}"))?;
    let revision = commit["sha"]
        .as_str()
        .filter(|sha| sha.len() == 40 && sha.bytes().all(|c| c.is_ascii_hexdigit()))
        .ok_or("release has no valid commit revision")?
        .to_string();
    let url =
        format!("https://api.github.com/repos/rntgspr/cumaru/git/trees/{revision}?recursive=1");
    let value: Value = serde_json::from_slice(&download(&url)?)
        .map_err(|e| format!("invalid release inventory: {e}"))?;
    if value["truncated"].as_bool() != Some(false) {
        return Err("release inventory is truncated or missing its completeness flag".into());
    }
    let entries = value["tree"]
        .as_array()
        .ok_or("release inventory has no tree")?;
    let prefix = format!("domains/{domain}/");
    let mut files = BTreeMap::new();
    let mut repository_files = BTreeMap::new();
    for entry in entries {
        let path = entry["path"]
            .as_str()
            .ok_or("release inventory path is missing")?;
        if entry["type"] == "blob" {
            repository_files.insert(
                path.to_string(),
                entry["mode"].as_str().unwrap_or("").to_string(),
            );
        }
        let Some(rel) = path.strip_prefix(&prefix) else {
            continue;
        };
        if rel.is_empty()
            || rel
                .split('/')
                .any(|s| s.is_empty() || s == "." || s == "..")
            || crate::text::has_control(rel)
        {
            return Err("release inventory contains an unsafe domain path".into());
        }
        if entry["type"] == "tree" {
            continue;
        }
        if entry["type"] != "blob" || !matches!(entry["mode"].as_str(), Some("100644" | "100755")) {
            return Err(format!(
                "release domain contains a symlink or unsupported entry: {rel}"
            ));
        }
        let mode = entry["mode"].as_str().unwrap();
        if files.insert(rel.to_string(), mode.to_string()).is_some() {
            return Err(format!("duplicate release path: {rel}"));
        }
    }
    if !files.contains_key("config.yaml") {
        return Err(format!("domain '{domain}' was not found in release {tag}"));
    }
    Ok(DomainRelease {
        revision,
        domain: domain.into(),
        files,
        repository_files,
    })
}

impl DomainRelease {
    /// Downloads an inventoried regular repository blob, supporting explicitly selected top-level opt-in skills.
    pub(crate) fn read_repository(&self, path: &str) -> Result<Vec<u8>, String> {
        if path.starts_with('/')
            || path
                .split('/')
                .any(|s| s.is_empty() || s == "." || s == "..")
            || crate::text::has_control(path)
            || !matches!(
                self.repository_files.get(path).map(String::as_str),
                Some("100644" | "100755")
            )
        {
            return Err(format!(
                "release repository file is missing or unsafe: {path}"
            ));
        }
        download(&format!(
            "https://raw.githubusercontent.com/rntgspr/cumaru/{}/{}",
            self.revision,
            url_path(path)
        ))
    }
    /// Downloads an inventoried domain blob from the pinned release tree identity.
    pub(crate) fn read(&self, path: &str) -> Result<Vec<u8>, String> {
        if !self.files.contains_key(path) {
            return Err(format!("release file was not found: {path}"));
        }
        download(&format!(
            "https://raw.githubusercontent.com/rntgspr/cumaru/{}/domains/{}/{}",
            self.revision,
            self.domain,
            url_path(path)
        ))
    }
}

/// Selects the latest release and runs the embedded binary installer with inherited streams.
pub(crate) fn install() -> Result<ExitCode, String> {
    let latest = latest_release()?;
    let status = Command::new("bash")
        .args(["-c", INSTALL, "cumaru-install", &latest])
        .status()
        .map_err(|error| format!("cannot run installer: {error}"))?;

    Ok(if status.success() {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    })
}

/// Queries the official repository and returns its highest plain release tag without changing local files.
pub(crate) fn latest_release() -> Result<String, String> {
    let output = Command::new("git")
        .args(["ls-remote", "--tags", "--refs", REMOTE])
        .stderr(Stdio::null())
        .output()
        .map_err(|error| format!("cannot check: unable to list tags at {REMOTE}: {error}"))?;
    if !output.status.success() {
        return Err(format!("cannot check: unable to reach {REMOTE}"));
    }

    let refs = String::from_utf8_lossy(&output.stdout);
    highest_release(&refs)
        .map(str::to_string)
        .ok_or_else(|| format!("cannot check: no X.Y.Z release tag published at {REMOTE}"))
}
