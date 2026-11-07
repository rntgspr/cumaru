//! Project-local cache of encoder chunk vectors under `.cumaru/.cache/context/`.
//!
//! Each vector is keyed by the SHA-256 of the exact token IDs fed to the model, so
//! unchanged paragraphs reuse their vectors across edits, renames, and documents,
//! and any change to chunking or tokenization yields new keys automatically. One
//! file exists per model identity and cache format; files for other identities or
//! formats are removed on save. A missing, unreadable, or mismatched cache is
//! treated as empty, never as an error, and saves are atomic (temporary file, then
//! rename).

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::models::{Encoder, Lines};

/// On-disk schema version; bump it whenever `Stored` changes shape or meaning.
const FORMAT: u32 = 1;

/// The `.gitignore` entry that keeps the cache out of version control by default.
const IGNORE: &str = ".cumaru/.cache/";

/// Explains the ignore entry so an adopter can opt into versioning the cache.
const IGNORE_COMMENT: &str =
    "# Cumaru local cache (context vectors); comment out the next line to version it.";

/// On-disk shape of one model's vector cache.
#[derive(Default, Deserialize, Serialize)]
struct Stored {
    format: u32,
    identity: String,
    chunks: BTreeMap<String, Vec<f32>>,
}

/// Vectors loaded for one model, with the keys seen in this run so stale entries are pruned on save.
pub(crate) struct Cache {
    file: PathBuf,
    stored: Stored,
    seen: BTreeSet<String>,
    dirty: bool,
}

impl Cache {
    /// Loads the cache for `encoder` under the canonical `.cumaru/` root, starting empty on any defect.
    pub(crate) fn load(root: &Path, encoder: &Encoder) -> Self {
        let name: String = encoder
            .identity
            .chars()
            .map(|c| {
                if c.is_ascii_alphanumeric() || c == '-' {
                    c
                } else {
                    '_'
                }
            })
            .collect();
        let file = root
            .join(".cache/context")
            .join(format!("{name}.v{FORMAT}.json"));

        let stored = fs::read(&file)
            .ok()
            .and_then(|bytes| serde_json::from_slice::<Stored>(&bytes).ok())
            .filter(|stored| stored.format == FORMAT && stored.identity == encoder.identity)
            .unwrap_or_else(|| Stored {
                format: FORMAT,
                identity: encoder.identity.clone(),
                chunks: BTreeMap::new(),
            });

        Self {
            file,
            stored,
            seen: BTreeSet::new(),
            dirty: false,
        }
    }

    /// Deletes this project's vector cache directory so the next load starts empty.
    pub(crate) fn reset(root: &Path) -> Result<(), String> {
        let directory = root.join(".cache/context");
        if crate::paths::is_symlink(&directory) {
            return Err(".cumaru/.cache/context must not be a symlink".into());
        }
        match fs::remove_dir_all(&directory) {
            Err(error) if error.kind() != std::io::ErrorKind::NotFound => {
                Err(format!("cannot reset cache: {error}"))
            }
            _ => Ok(()),
        }
    }

    /// Embeds every chunk of `document` missing from the cache, returning each chunk's key and line range and how many were added.
    pub(crate) fn embed(
        &mut self,
        encoder: &Encoder,
        document: &str,
    ) -> Result<(Vec<(String, Lines)>, usize), String> {
        let mut keys = Vec::new();
        let mut added = 0;
        for (ids, lines) in encoder.document_chunks(document)? {
            let bytes: Vec<u8> = ids.iter().flat_map(|id| id.to_le_bytes()).collect();
            let key = format!("{:x}", Sha256::digest(&bytes));
            self.seen.insert(key.clone());

            if !self.stored.chunks.contains_key(&key) {
                let vector = encoder.embed_chunk(&ids)?;
                self.stored.chunks.insert(key.clone(), vector);
                self.dirty = true;
                added += 1;
            }
            keys.push((key, lines));
        }

        Ok((keys, added))
    }

    /// Scores a document from the chunks returned by `embed`, with the line range of the best chunk.
    pub(crate) fn score(
        &self,
        keys: &[(String, Lines)],
        query: &[f32],
    ) -> Result<(f64, Option<Lines>), String> {
        let (score, winner) =
            crate::models::best(keys.iter().map(|(key, _)| &self.stored.chunks[key]), query)?;

        Ok((score, winner.map(|index| keys[index].1)))
    }

    /// Returns the number of chunks currently held.
    pub(crate) fn len(&self) -> usize {
        self.seen.len()
    }

    /// Prunes unseen chunks, writes atomically when anything changed, and removes other identities' files.
    pub(crate) fn save(mut self) -> Result<(), String> {
        let before = self.stored.chunks.len();
        self.stored.chunks.retain(|key, _| self.seen.contains(key));
        if !self.dirty && self.stored.chunks.len() == before {
            return Ok(());
        }

        let directory = self.file.parent().ok_or("invalid cache path")?;
        fs::create_dir_all(directory).map_err(|e| format!("cannot create cache: {e}"))?;

        let text = serde_json::to_vec(&self.stored).map_err(|e| e.to_string())?;
        let temporary = self
            .file
            .with_extension(format!("json.{}.tmp", std::process::id()));
        fs::write(&temporary, text).map_err(|e| format!("cannot write cache: {e}"))?;
        fs::rename(&temporary, &self.file).map_err(|e| format!("cannot publish cache: {e}"))?;

        for entry in fs::read_dir(directory).map_err(|e| e.to_string())? {
            let path = entry.map_err(|e| e.to_string())?.path();
            if path != self.file && path.extension().is_some_and(|ext| ext == "json") {
                fs::remove_file(&path).map_err(|e| format!("cannot remove stale cache: {e}"))?;
            }
        }

        if let Some(project) = directory.ancestors().nth(3) {
            ignore(project)?;
        }

        Ok(())
    }
}

/// Appends the commented cache entry to the project `.gitignore` unless a line already mentions it, active or commented.
fn ignore(project: &Path) -> Result<(), String> {
    let path = project.join(".gitignore");
    let existing = fs::read_to_string(&path).unwrap_or_default();

    let mentioned = existing.lines().any(|line| {
        let entry = line
            .trim()
            .trim_start_matches('#')
            .trim()
            .trim_start_matches('/');
        entry == IGNORE || entry == IGNORE.trim_end_matches('/')
    });
    if mentioned {
        return Ok(());
    }

    let separator = if existing.is_empty() || existing.ends_with('\n') {
        ""
    } else {
        "\n"
    };
    fs::write(
        &path,
        format!("{existing}{separator}{IGNORE_COMMENT}\n{IGNORE}\n"),
    )
    .map_err(|e| format!("cannot update .gitignore: {e}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    /// Creates a disposable project directory for one test.
    fn project(label: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let base = std::env::temp_dir().join(format!(
            "cumaru-vectors-{label}-{}-{nonce}",
            std::process::id()
        ));
        fs::create_dir_all(&base).unwrap();

        base
    }

    /// Adds the commented entry once and respects an adopter's commented-out line.
    #[test]
    fn ignore_appends_once_and_respects_comments() {
        let base = project("ignore");
        fs::write(base.join(".gitignore"), "/target").unwrap();

        ignore(&base).unwrap();
        ignore(&base).unwrap();
        let text = fs::read_to_string(base.join(".gitignore")).unwrap();
        assert_eq!(text, format!("/target\n{IGNORE_COMMENT}\n{IGNORE}\n"));

        fs::write(base.join(".gitignore"), "# .cumaru/.cache/\n").unwrap();
        ignore(&base).unwrap();
        assert_eq!(
            fs::read_to_string(base.join(".gitignore")).unwrap(),
            "# .cumaru/.cache/\n"
        );

        fs::remove_dir_all(base).unwrap();
    }

    /// Creates `.gitignore` when the project has none.
    #[test]
    fn ignore_creates_missing_file() {
        let base = project("create");

        ignore(&base).unwrap();
        assert_eq!(
            fs::read_to_string(base.join(".gitignore")).unwrap(),
            format!("{IGNORE_COMMENT}\n{IGNORE}\n")
        );

        fs::remove_dir_all(base).unwrap();
    }
}
