//! Closed model packages and CPU embeddings; Candle executes TaylorAI's BGE Micro: https://huggingface.co/TaylorAI/bge-micro-v2

use candle_core::{DType, Device, Tensor};
use candle_nn::VarBuilder;
use candle_transformers::models::bert::{BertModel, Config};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{
    collections::BTreeSet,
    fs,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};
use tokenizers::Tokenizer;

const CATALOG: &str = include_str!("../models/catalog.json");

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Catalog {
    version: u32,
    pub models: Vec<Model>,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub(crate) struct Model {
    pub name: String,
    profile: String,
    repository: String,
    revision: String,
    pub license: String,
    source: String,
    max_tokens: usize,
    pub artifacts: Vec<Artifact>,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub(crate) struct Artifact {
    file: String,
    pub bytes: usize,
    sha256: String,
}

pub(crate) struct Encoder {
    model: BertModel,
    tokenizer: Tokenizer,
    max_tokens: usize,
}

/// Read the binary's closed compatibility inventory; it contains metadata, never model weights.
fn supported() -> Catalog {
    serde_json::from_str(CATALOG).expect("bundled model catalog must be valid")
}

/// Reject arbitrary names before network access or filesystem mutation.
pub(crate) fn known(name: &str) -> Result<Model, String> {
    supported()
        .models
        .into_iter()
        .find(|entry| entry.name == name)
        .ok_or_else(|| format!("unsupported model name: {}", crate::text::shell_quote(name)))
}

/// Validate the complete remote inventory against exactly the packages this binary supports.
fn parse_catalog(bytes: &[u8]) -> Result<Catalog, String> {
    let catalog: Catalog =
        serde_json::from_slice(bytes).map_err(|e| format!("invalid model catalog: {e}"))?;
    let mut seen = BTreeSet::new();

    if catalog.version != 1 || catalog.models.is_empty() {
        return Err("unsupported or empty model catalog".into());
    }

    for entry in &catalog.models {
        if !seen.insert(&entry.name) || known(&entry.name)? != *entry {
            return Err(format!(
                "model metadata is incompatible with this binary: {}",
                entry.name
            ));
        }
    }

    Ok(catalog)
}

/// Pin the GitHub catalog to one main commit and return no invented inventory on failure.
pub(crate) fn remote_catalog() -> Result<(String, Catalog), String> {
    let commit: serde_json::Value = serde_json::from_slice(&crate::distribution::download(
        "https://api.github.com/repos/rntgspr/cumaru/commits/main",
    )?)
    .map_err(|e| format!("invalid main revision: {e}"))?;
    let revision = commit["sha"]
        .as_str()
        .filter(|s| s.len() == 40 && s.bytes().all(|b| b.is_ascii_hexdigit()))
        .ok_or("invalid main revision")?
        .to_string();
    let url =
        format!("https://raw.githubusercontent.com/rntgspr/cumaru/{revision}/models/catalog.json");
    let catalog = parse_catalog(&crate::distribution::download(&url)?)?;

    Ok((revision, catalog))
}

/// Resolve user-owned model storage independently of the project's .cumaru tree.
pub(crate) fn cache_root() -> Result<PathBuf, String> {
    let home = std::env::var_os("HOME")
        .filter(|value| !value.is_empty())
        .ok_or("HOME is unavailable")?;
    let home = PathBuf::from(home);

    if !home.is_absolute() {
        return Err("HOME must be an absolute path".into());
    }

    Ok(home.join(".cumaru"))
}

/// Refuse symlinked cache components and non-directory parents without touching legacy contents.
fn safe_directory(path: &Path) -> Result<(), String> {
    for component in path.ancestors() {
        match fs::symlink_metadata(component) {
            Ok(metadata) if metadata.file_type().is_symlink() || !metadata.is_dir() => {
                return Err(format!("unsafe model directory: {}", component.display()));
            }
            Ok(_) => {}
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
            Err(error) => return Err(error.to_string()),
        }
    }

    Ok(())
}

/// Read one regular package file without accepting a direct symlink or special file.
fn regular_bytes(path: &Path) -> Result<Vec<u8>, String> {
    let metadata = fs::symlink_metadata(path).map_err(|e| format!("{}: {e}", path.display()))?;

    if !metadata.is_file() || metadata.file_type().is_symlink() {
        return Err(format!("model file is not regular: {}", path.display()));
    }

    if metadata.len() > 100 * 1024 * 1024 {
        return Err("model file exceeds the supported package budget".into());
    }

    fs::read(path).map_err(|e| e.to_string())
}

/// Validate size and SHA-256 before package publication or offline inference.
fn verify(artifact: &Artifact, bytes: &[u8]) -> Result<(), String> {
    if bytes.len() != artifact.bytes || format!("{:x}", Sha256::digest(bytes)) != artifact.sha256 {
        return Err(format!(
            "model artifact size/checksum mismatch: {}",
            artifact.file
        ));
    }

    Ok(())
}

/// Read a complete installed package and require its manifest to match supported pinned metadata.
fn package(directory: &Path, entry: &Model) -> Result<Vec<Vec<u8>>, String> {
    safe_directory(directory)?;
    let manifest: Model = serde_json::from_slice(&regular_bytes(&directory.join("manifest.json"))?)
        .map_err(|e| format!("invalid installed model manifest: {e}"))?;

    if manifest != *entry {
        return Err("installed model manifest differs from the supported package".into());
    }

    entry
        .artifacts
        .iter()
        .map(|artifact| {
            let bytes = regular_bytes(&directory.join(&artifact.file))?;
            verify(artifact, &bytes)?;
            Ok(bytes)
        })
        .collect()
}

/// Download and verify all artifacts first, then publish a new complete directory without replacing existing data.
pub(crate) fn install(
    root: &Path,
    entry: &Model,
    mut download: impl FnMut(&str) -> Result<Vec<u8>, String>,
) -> Result<bool, String> {
    safe_directory(root)?;
    let directory = root.join(&entry.name);
    safe_directory(&directory)?;

    if directory.exists() {
        package(&directory, entry)?;
        return Ok(false);
    }

    let mut files = Vec::new();

    for artifact in &entry.artifacts {
        let url = format!(
            "https://huggingface.co/{}/resolve/{}/{}",
            entry.repository, entry.revision, artifact.file
        );
        let bytes = download(&url)?;
        verify(artifact, &bytes)?;
        files.push((&artifact.file, bytes));
    }

    fs::create_dir_all(root).map_err(|e| e.to_string())?;
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_nanos();
    let staging = root.join(format!(".{}-{}-{nonce}", entry.name, std::process::id()));
    fs::create_dir(&staging).map_err(|e| e.to_string())?;
    let result = (|| {
        for (file, bytes) in files {
            fs::write(staging.join(file), bytes).map_err(|e| e.to_string())?;
        }

        fs::write(
            staging.join("manifest.json"),
            serde_json::to_vec_pretty(entry).map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
        safe_directory(root)?;

        if fs::symlink_metadata(&directory).is_ok() {
            return Err(
                "model destination appeared during download; existing content preserved".into(),
            );
        }

        fs::rename(&staging, &directory).map_err(|e| e.to_string())?;
        Ok(true)
    })();

    if staging.exists() {
        let _ = fs::remove_dir_all(&staging);
    }

    result
}

/// Discover the one supported cached encoder offline; absence permits fallback, invalid packages fail.
pub(crate) fn local(root: &Path) -> Result<Option<Encoder>, String> {
    safe_directory(root)?;
    let entry = known("bge-micro-v2")?;
    let directory = root.join(&entry.name);

    match fs::symlink_metadata(&directory) {
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(error.to_string()),
        Ok(_) => {}
    }

    let files = package(&directory, &entry)?;
    let config: Config = serde_json::from_slice(&files[2]).map_err(|e| e.to_string())?;
    let builder = VarBuilder::from_buffered_safetensors(files[0].clone(), DType::F32, &Device::Cpu)
        .map_err(|e| e.to_string())?;
    let model = BertModel::load(builder, &config).map_err(|e| e.to_string())?;
    let mut tokenizer = Tokenizer::from_bytes(&files[1]).map_err(|e| e.to_string())?;
    tokenizer.with_truncation(None).map_err(|e| e.to_string())?;
    tokenizer.with_padding(None);

    Ok(Some(Encoder {
        model,
        tokenizer,
        max_tokens: entry.max_tokens,
    }))
}

impl Encoder {
    /// Evaluate every paragraph through token-aware windows, retaining the highest cosine similarity.
    pub(crate) fn document_score(&self, document: &str, query: &[f32]) -> Result<f64, String> {
        let mut maximum = 0.0_f32;

        for paragraph in document
            .split("\n\n")
            .filter(|text| !text.trim().is_empty())
        {
            let encoding = self
                .tokenizer
                .encode(paragraph, false)
                .map_err(|e| e.to_string())?;
            let mut start = 0;

            while start < encoding.len() {
                let end = encoding.len().min(start + self.max_tokens - 2);
                let mut ids = vec![101];
                ids.extend_from_slice(&encoding.get_ids()[start..end]);
                ids.push(102);
                let vector = self.normalized(&ids)?;
                let cosine: f32 = query
                    .iter()
                    .zip(vector)
                    .map(|(left, right)| left * right)
                    .sum();

                if !cosine.is_finite() {
                    return Err("nonfinite model similarity".into());
                }

                maximum = maximum.max(cosine.clamp(0.0, 1.0));

                if end == encoding.len() {
                    break;
                }

                start = end - 32;
            }
        }

        Ok(f64::from(maximum) * 10.0)
    }

    /// Mean-pool and normalize unpadded token vectors without truncating an oversized fragment.
    pub(crate) fn embed(&self, text: &str) -> Result<Vec<f32>, String> {
        let encoding = self
            .tokenizer
            .encode(text, true)
            .map_err(|e| e.to_string())?;

        if encoding.len() > self.max_tokens {
            return Err(format!(
                "fragment exceeds the {}-token model limit",
                self.max_tokens
            ));
        }

        self.normalized(encoding.get_ids())
    }

    /// Run the known BERT profile with zero segment IDs and normalize its mean-pooled output.
    fn normalized(&self, ids: &[u32]) -> Result<Vec<f32>, String> {
        let result = (|| {
            let ids = Tensor::new(ids, &Device::Cpu)?.unsqueeze(0)?;
            let types = ids.zeros_like()?;
            let mut vector = self
                .model
                .forward(&ids, &types, None)?
                .mean(1)?
                .squeeze(0)?
                .to_vec1::<f32>()?;
            let norm = vector.iter().map(|value| value * value).sum::<f32>().sqrt();

            if !norm.is_finite() || norm <= 0.0 {
                candle_core::bail!("invalid embedding norm");
            }

            for value in &mut vector {
                *value /= norm;
            }

            Ok::<_, candle_core::Error>(vector)
        })();

        result.map_err(|e| e.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Create an isolated canonical scratch directory without changing HOME or process environment.
    pub(crate) fn scratch(label: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root = fs::canonicalize(std::env::temp_dir())
            .unwrap()
            .join(format!(
                "cumaru-model-{label}-{}-{nonce}",
                std::process::id()
            ));
        fs::create_dir(&root).unwrap();

        root
    }

    /// Require the closed package metadata and reject unknown names, changed profiles, and duplicate rows.
    #[test]
    fn catalog_is_closed() {
        assert!(parse_catalog(CATALOG.as_bytes()).is_ok());
        assert!(known("../../escape").is_err());
        assert!(
            parse_catalog(
                CATALOG
                    .replace("bert-mean-v1", "arbitrary-runtime")
                    .as_bytes()
            )
            .is_err()
        );
        let mut value: serde_json::Value = serde_json::from_str(CATALOG).unwrap();
        let entry = value["models"][0].clone();
        value["models"].as_array_mut().unwrap().push(entry);
        assert!(parse_catalog(&serde_json::to_vec(&value).unwrap()).is_err());
    }

    /// Preserve a legacy root and create nothing on absence or failed download/checksum.
    #[test]
    fn failed_download_preserves_cache() {
        let parent = scratch("failure");
        let root = parent.join("cache");
        let entry = known("bge-micro-v2").unwrap();
        assert!(local(&root).unwrap().is_none());
        assert!(!root.exists());
        assert!(install(&root, &entry, |_| Err("offline".into())).is_err());
        assert!(install(&root, &entry, |_| Ok(b"wrong checksum".to_vec())).is_err());
        assert!(!root.exists());
        fs::create_dir(&root).unwrap();
        fs::write(root.join("legacy.txt"), "keep").unwrap();
        assert!(local(&root).unwrap().is_none());
        assert_eq!(fs::read_to_string(root.join("legacy.txt")).unwrap(), "keep");
        fs::remove_dir_all(parent).unwrap();
    }

    /// Publish only a complete verified package, then make identical installation a no-download no-op.
    #[test]
    fn verified_publication_is_idempotent() {
        let parent = scratch("publication");
        let root = parent.join("cache");
        let mut entry = known("bge-micro-v2").unwrap();
        let bytes = b"fixture";

        for artifact in &mut entry.artifacts {
            artifact.bytes = bytes.len();
            artifact.sha256 = format!("{:x}", Sha256::digest(bytes));
        }

        assert!(install(&root, &entry, |_| Ok(bytes.to_vec())).unwrap());
        assert!(!install(&root, &entry, |_| panic!("no second download")).unwrap());
        assert_eq!(fs::read_dir(&root).unwrap().count(), 1);
        fs::write(root.join(&entry.name).join("tokenizer.json"), "changed").unwrap();
        assert!(install(&root, &entry, |_| panic!("preserve damaged package")).is_err());
        assert_eq!(
            fs::read_to_string(root.join(&entry.name).join("tokenizer.json")).unwrap(),
            "changed"
        );
        fs::remove_dir_all(parent).unwrap();
    }

    /// Refuse root/package symlinks and malformed packages rather than silently selecting fallback.
    #[test]
    #[cfg(unix)]
    fn unsafe_or_invalid_packages_fail() {
        let parent = scratch("unsafe");
        let root = parent.join("cache");
        std::os::unix::fs::symlink(&parent, &root).unwrap();
        assert!(local(&root).is_err());
        fs::remove_file(&root).unwrap();
        fs::create_dir(&root).unwrap();
        fs::create_dir(root.join("bge-micro-v2")).unwrap();
        assert!(local(&root).is_err());
        fs::write(root.join("bge-micro-v2/manifest.json"), "{}").unwrap();
        assert!(local(&root).is_err());
        fs::remove_dir_all(parent).unwrap();
    }
}
