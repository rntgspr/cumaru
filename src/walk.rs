//! Contained filesystem traversal with caller-owned filters and parsing.

use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

use crate::paths::{canonical_inside, file_name, has_symlink_component, is_symlink};
use crate::text::has_control;

pub(crate) struct Entry<'a> {
    pub path: &'a Path,
    pub target: &'a Path,
    pub is_dir: bool,
}

pub(crate) struct Diagnostic {
    pub path: PathBuf,
    pub message: &'static str,
}

pub(crate) struct Walk<'a> {
    pub root: &'a Path,
    pub deep: bool,
}

impl Walk<'_> {
    /// Visits unique safe entries, filtering files and passing directories to the caller's parser.
    pub(crate) fn run(
        &self,
        targets: &[PathBuf],
        filter: impl Fn(&Path) -> bool,
        mut parse: impl FnMut(Entry<'_>) -> Result<(), String>,
    ) -> Result<Vec<Diagnostic>, String> {
        let mut diagnostics = Vec::new();
        let mut seen = HashSet::new();
        let mut expanded = HashSet::new();

        for target in targets {
            let mut pending = vec![target.clone()];
            while let Some(path) = pending.pop() {
                let rel = path.strip_prefix(self.root).unwrap_or(&path);
                let control = has_control(&rel.to_string_lossy());
                let symlink = is_symlink(&path) || has_symlink_component(self.root, &path);
                if symlink || control {
                    if symlink {
                        diagnostics.push(Diagnostic {
                            path: path.clone(),
                            message: "symlinks are not supported",
                        });
                    }
                    if control {
                        diagnostics.push(Diagnostic {
                            path,
                            message: "candidate path contains a control character",
                        });
                    }
                    continue;
                }

                let Some(canonical) = canonical_inside(self.root, &path) else {
                    diagnostics.push(Diagnostic {
                        path,
                        message: "entry does not resolve safely inside the traversal root",
                    });
                    continue;
                };
                let is_dir = canonical.is_dir();
                if seen.insert((canonical.clone(), canonical == *target))
                    && (is_dir || (canonical.is_file() && filter(&canonical)))
                {
                    parse(Entry {
                        path: &canonical,
                        target,
                        is_dir,
                    })?;
                }

                if !is_dir
                    || (!self.deep && canonical != *target)
                    || !expanded.insert(canonical.clone())
                {
                    continue;
                }

                match fs::read_dir(&canonical) {
                    Ok(entries) => {
                        let mut children = Vec::new();
                        for entry in entries {
                            match entry {
                                Ok(entry) if !file_name(&entry.path()).starts_with('.') => {
                                    children.push(entry.path())
                                }
                                Ok(_) => {}
                                Err(_) => diagnostics.push(Diagnostic {
                                    path: canonical.clone(),
                                    message: "could not completely inspect directory",
                                }),
                            }
                        }
                        children.sort();
                        pending.extend(children.into_iter().rev());
                    }
                    Err(_) => diagnostics.push(Diagnostic {
                        path: canonical,
                        message: "could not completely inspect directory",
                    }),
                }
            }
        }

        Ok(diagnostics)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    struct Fixture(PathBuf);

    impl Fixture {
        /// Creates an isolated tree containing mixed file types and a hidden branch.
        fn new() -> Self {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let root =
                std::env::temp_dir().join(format!("cumaru-walk-{}-{nonce}", std::process::id()));
            fs::create_dir_all(root.join("child")).unwrap();
            fs::create_dir_all(root.join(".hidden")).unwrap();
            fs::write(root.join("one.txt"), "text").unwrap();
            fs::write(root.join("ignored.md"), "markdown").unwrap();
            fs::write(root.join("child/two.txt"), "text").unwrap();
            fs::write(root.join(".hidden/three.txt"), "text").unwrap();

            Self(fs::canonicalize(root).unwrap())
        }
    }

    impl Drop for Fixture {
        /// Removes only the temporary tree owned by this fixture.
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    /// Reuses traversal with a text-file parser, retaining directories and respecting depth and overlap.
    #[test]
    fn filters_files_and_deduplicates_overlapping_targets() {
        let fixture = Fixture::new();
        for deep in [false, true] {
            let walk = Walk {
                root: &fixture.0,
                deep,
            };
            let mut files = Vec::new();
            let mut dirs = Vec::new();
            let diagnostics = walk
                .run(
                    &[fixture.0.clone(), fixture.0.join("child")],
                    |path| path.extension().is_some_and(|extension| extension == "txt"),
                    |entry| {
                        if entry.is_dir {
                            dirs.push(entry.path.to_path_buf());
                        } else {
                            files.push(entry.path.strip_prefix(&fixture.0).unwrap().to_path_buf());
                        }
                        Ok(())
                    },
                )
                .unwrap();
            files.sort();

            assert!(diagnostics.is_empty());
            assert_eq!(
                files,
                vec![PathBuf::from("child/two.txt"), PathBuf::from("one.txt")]
            );
            assert!(dirs.contains(&fixture.0.join("child")));
        }
    }

    /// Reports unsafe symlinks without invoking the parser on their targets.
    #[cfg(unix)]
    #[test]
    fn rejects_symlinks_before_parsing() {
        let fixture = Fixture::new();
        std::os::unix::fs::symlink(fixture.0.join("child"), fixture.0.join("link")).unwrap();
        let walk = Walk {
            root: &fixture.0,
            deep: true,
        };
        let mut parsed = Vec::new();
        let diagnostics = walk
            .run(
                &[fixture.0.clone()],
                |_| true,
                |entry| {
                    parsed.push(entry.path.to_path_buf());
                    Ok(())
                },
            )
            .unwrap();

        assert_eq!(diagnostics.len(), 1);
        assert_eq!(diagnostics[0].path, fixture.0.join("link"));
        assert!(!parsed.contains(&fixture.0.join("link")));
    }
}
