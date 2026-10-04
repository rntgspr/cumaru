//! `cumaru fs`: guarded mechanical file operations inside `.cumaru/`.
//!
//! Mirrors the retired Bash `src/cmd_fs.sh` (tag 0.10.0): four verbs, no content awareness, and every path
//! validated and resolved before mutation. Parent symlinks are resolved and
//! accepted only when the canonical destination stays inside the root; direct
//! symlink targets are refused. Navigation's stricter symlink policy does not
//! apply here.

use std::fs::{self, OpenOptions};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use clap::{Args, ValueEnum};

use crate::config::CUMARU_DIR;
use crate::paths::{file_name, is_symlink, normalize_target};
use crate::text::shell_quote;

/// Arguments for `cumaru fs`, in the Bash positional order `<src> <verb> [<dst>]`.
#[derive(Args)]
#[command(
    override_usage = "cumaru fs <src> move|copy <dst>\n       cumaru fs <path> create|remove",
    after_help = "Paths are relative to .cumaru/. Files must end in .md; directory names must not contain dots.\n`remove` refuses index.md files and direct-child directories of .cumaru/."
)]
pub struct FsArgs {
    /// Source path (or the target path for create/remove), relative to .cumaru/.
    src: String,

    /// Operation to perform.
    verb: Verb,

    /// Destination path for move/copy, relative to .cumaru/.
    dst: Option<String>,
}

/// The four supported operations.
#[derive(Clone, Copy, PartialEq, Eq, ValueEnum)]
enum Verb {
    Move,
    Copy,
    Create,
    Remove,
}

/// Classified failure; usage errors exit 2, rejected or failed operations exit 1.
#[derive(Debug)]
enum Failure {
    Usage(String),
    Rejected(String),
}

/// The file/directory contract used for shape validation.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Kind {
    File,
    Dir,
}

/// Runs `cumaru fs` against the project's `.cumaru/` and maps the outcome to the documented exit codes.
pub fn run(args: FsArgs) -> ExitCode {
    match execute(&args, Path::new(CUMARU_DIR)) {
        Ok(message) => {
            let _ = writeln!(io::stdout().lock(), "{message}");
            ExitCode::SUCCESS
        }
        Err(Failure::Usage(message)) => {
            eprintln!("cumaru fs: {message}");
            ExitCode::from(2)
        }
        Err(Failure::Rejected(message)) => {
            eprintln!("cumaru fs: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Validates the invocation and every path, then performs exactly one operation and returns its success line.
fn execute(args: &FsArgs, cumaru: &Path) -> Result<String, Failure> {
    match (args.verb, &args.dst) {
        (Verb::Move | Verb::Copy, None) => {
            return Err(Failure::Usage(format!(
                "{} requires <dst>",
                verb_name(args.verb)
            )));
        }
        (Verb::Create | Verb::Remove, Some(_)) => {
            return Err(Failure::Usage(format!(
                "{} takes no <dst>",
                verb_name(args.verb)
            )));
        }
        _ => {}
    }

    let src = check_syntax(&args.src, "<src>")?;
    let dst = args
        .dst
        .as_deref()
        .map(|dst| check_syntax(dst, "<dst>"))
        .transpose()?;

    let root = fs::canonicalize(cumaru)
        .ok()
        .filter(|root| root.is_dir())
        .ok_or_else(|| rejected(".cumaru/ not found; run `cumaru install` first"))?;

    let src_path = resolve_inside(&root, &src, "<src>")?;
    let dst_path = dst
        .as_deref()
        .map(|dst| resolve_inside(&root, dst, "<dst>"))
        .transpose()?;

    if args.verb == Verb::Create {
        return create(&src, &src_path);
    }

    let kind = kind_of(&src_path, &src)?;
    check_shape(&src, kind, "<src>")?;
    if let Some(dst) = &dst {
        check_shape(dst, kind, "<dst>")?;
    }

    match (args.verb, dst, dst_path) {
        (Verb::Remove, _, _) => remove(&root, &src, &src_path, kind),
        (verb, Some(dst), Some(dst_path)) => {
            transfer(verb, &root, (&src, &src_path), (&dst, &dst_path), kind)
        }
        _ => unreachable!("move/copy arity is validated before path resolution"),
    }
}

/// Returns the verb as typed on the command line.
fn verb_name(verb: Verb) -> &'static str {
    match verb {
        Verb::Move => "move",
        Verb::Copy => "copy",
        Verb::Create => "create",
        Verb::Remove => "remove",
    }
}

/// Builds a rejected-operation failure.
fn rejected(message: impl Into<String>) -> Failure {
    Failure::Rejected(message.into())
}

/// Rejects empty, absolute, and `.`/`..`-segment paths, returning the path without trailing slashes.
fn check_syntax(path: &str, label: &str) -> Result<String, Failure> {
    if path.is_empty() {
        return Err(Failure::Usage(format!("missing {label}")));
    }

    let path = normalize_target(Some(path));
    if path.starts_with('/') {
        return Err(rejected(format!(
            "{label} must be relative to .cumaru/ (no leading /): {}",
            shell_quote(&path)
        )));
    }
    if path
        .split('/')
        .any(|segment| segment == "." || segment == "..")
    {
        return Err(rejected(format!(
            "'.' / '..' segments not allowed in {label} (use a clean path from .cumaru/ root): {}",
            shell_quote(&path)
        )));
    }

    Ok(path)
}

/// Resolves a possibly missing path through its nearest existing ancestor and requires it to stay inside the root.
fn resolve_inside(root: &Path, rel: &str, label: &str) -> Result<PathBuf, Failure> {
    let candidate = root.join(rel);
    if is_symlink(&candidate) {
        return Err(rejected(format!(
            "symlink targets are not supported in {label}: {}",
            shell_quote(rel)
        )));
    }

    let mut probe = candidate.as_path();
    let mut suffix = Vec::new();
    while fs::symlink_metadata(probe).is_err() {
        let (Some(parent), Some(name)) = (probe.parent(), probe.file_name()) else {
            break;
        };
        suffix.push(name);
        probe = parent;
    }

    let unresolved = || {
        rejected(format!(
            "cannot resolve {label} inside .cumaru/: {}",
            shell_quote(rel)
        ))
    };
    let mut resolved = fs::canonicalize(probe).map_err(|_| unresolved())?;
    for name in suffix.iter().rev() {
        resolved.push(name);
    }

    if resolved == root || !resolved.starts_with(root) {
        return Err(rejected(format!(
            "{label} resolves outside .cumaru/: {}",
            shell_quote(rel)
        )));
    }

    Ok(resolved)
}

/// Enforces `.md` file names and dot-free directory segments, including implicit parents.
fn check_shape(rel: &str, kind: Kind, label: &str) -> Result<(), Failure> {
    let dirs = match kind {
        Kind::File => {
            if !rel.ends_with(".md") {
                return Err(rejected(format!(
                    "{label} file must end in .md: {}",
                    shell_quote(rel)
                )));
            }
            rel.rsplit_once('/').map_or("", |(parent, _)| parent)
        }
        Kind::Dir => rel,
    };

    match dirs.split('/').find(|segment| segment.contains('.')) {
        Some(segment) => Err(rejected(format!(
            "directory names must not contain dots in {label}: {}",
            shell_quote(segment)
        ))),
        None => Ok(()),
    }
}

/// Classifies an existing source as a regular file or directory; missing and other types are rejected.
fn kind_of(path: &Path, rel: &str) -> Result<Kind, Failure> {
    let meta = fs::symlink_metadata(path)
        .map_err(|_| rejected(format!("source not found: {}", shell_quote(rel))))?;

    if meta.is_file() {
        Ok(Kind::File)
    } else if meta.is_dir() {
        Ok(Kind::Dir)
    } else {
        Err(rejected(format!(
            "unsupported file type: {}",
            shell_quote(rel)
        )))
    }
}

/// Creates an empty Markdown file or a directory with implicit parents; an existing path is a no-op.
fn create(rel: &str, path: &Path) -> Result<String, Failure> {
    if fs::symlink_metadata(path).is_ok() {
        return Ok(format!("already exists (no-op): {}", shell_quote(rel)));
    }

    let failed =
        |error: io::Error| rejected(format!("cannot create {}: {error}", shell_quote(rel)));
    if rel.ends_with(".md") {
        check_shape(rel, Kind::File, "<path>")?;
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(failed)?;
        }
        OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(path)
            .map_err(failed)?;

        return Ok(format!("create: {} (file)", shell_quote(rel)));
    }

    check_shape(rel, Kind::Dir, "<path>")?;
    fs::create_dir_all(path).map_err(failed)?;

    Ok(format!("create: {}/ (dir)", shell_quote(rel)))
}

/// Removes a file or directory tree, refusing `index.md` files and direct-child directories of the root.
fn remove(root: &Path, rel: &str, path: &Path, kind: Kind) -> Result<String, Failure> {
    if file_name(path) == "index.md" {
        return Err(rejected(
            "cannot remove an index.md (system-critical for the entity)",
        ));
    }
    if kind == Kind::Dir && path.parent() == Some(root) {
        return Err(rejected(format!(
            "cannot remove a pillar root: {}/",
            shell_quote(rel)
        )));
    }

    let result = match kind {
        Kind::File => fs::remove_file(path),
        Kind::Dir => fs::remove_dir_all(path),
    };
    result.map_err(|error| rejected(format!("cannot remove {}: {error}", shell_quote(rel))))?;

    Ok(format!("remove: {}", shell_quote(rel)))
}

/// Moves or copies one source to an absent destination, creating destination parents as needed.
fn transfer(
    verb: Verb,
    root: &Path,
    (src, src_path): (&str, &Path),
    (dst, dst_path): (&str, &Path),
    kind: Kind,
) -> Result<String, Failure> {
    if fs::symlink_metadata(dst_path).is_ok() {
        return Err(rejected(format!(
            "destination already exists: {}",
            shell_quote(dst)
        )));
    }
    if kind == Kind::Dir && dst_path.starts_with(src_path) {
        return Err(rejected(format!(
            "cannot {} a directory into itself: {} -> {}",
            verb_name(verb),
            shell_quote(src),
            shell_quote(dst)
        )));
    }
    if verb == Verb::Copy && kind == Kind::Dir {
        scan_copy_source(root, src_path)?;
    }

    let failed = |error: io::Error| {
        rejected(format!(
            "cannot {} {} -> {}: {error}",
            verb_name(verb),
            shell_quote(src),
            shell_quote(dst)
        ))
    };
    if let Some(parent) = dst_path.parent() {
        fs::create_dir_all(parent).map_err(failed)?;
    }
    match (verb, kind) {
        (Verb::Move, _) => fs::rename(src_path, dst_path).map_err(failed)?,
        (_, Kind::File) => {
            fs::copy(src_path, dst_path).map_err(failed)?;
        }
        (_, Kind::Dir) => copy_tree(src_path, dst_path).map_err(failed)?,
    }

    Ok(format!(
        "{}: {} -> {}",
        verb_name(verb),
        shell_quote(src),
        shell_quote(dst)
    ))
}

/// Rejects a directory copy before mutation when any descendant is a symlink or neither file nor directory.
fn scan_copy_source(root: &Path, dir: &Path) -> Result<(), Failure> {
    let rel = |path: &Path| shell_quote(&path.strip_prefix(root).unwrap_or(path).to_string_lossy());
    let entries = fs::read_dir(dir)
        .map_err(|error| rejected(format!("cannot read {}: {error}", rel(dir))))?;

    for entry in entries {
        let entry =
            entry.map_err(|error| rejected(format!("cannot read {}: {error}", rel(dir))))?;
        let path = entry.path();
        let file_type = entry
            .file_type()
            .map_err(|error| rejected(format!("cannot read {}: {error}", rel(&path))))?;

        if file_type.is_symlink() {
            return Err(rejected(format!(
                "copy source contains a symlink: {}",
                rel(&path)
            )));
        }
        if file_type.is_dir() {
            scan_copy_source(root, &path)?;
        } else if !file_type.is_file() {
            return Err(rejected(format!(
                "copy source contains an unsupported file type: {}",
                rel(&path)
            )));
        }
    }

    Ok(())
}

/// Recursively copies regular files and directories; stops at the first error without rollback.
fn copy_tree(src: &Path, dst: &Path) -> io::Result<()> {
    fs::create_dir(dst)?;

    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let file_type = entry.file_type()?;
        let target = dst.join(entry.file_name());

        if file_type.is_dir() {
            copy_tree(&entry.path(), &target)?;
        } else if file_type.is_file() {
            fs::copy(entry.path(), &target)?;
        } else {
            return Err(io::Error::other(format!(
                "unsupported entry appeared during copy: {}",
                entry.path().display()
            )));
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::symlink;
    use std::time::{SystemTime, UNIX_EPOCH};

    /// Isolated project mirroring `tests/fixtures/fs`, plus a sibling directory outside `.cumaru/`.
    struct Fixture(PathBuf);

    impl Fixture {
        /// Creates `.cumaru/plans/item/{index,note}.md`, an `archive` pillar, and an `outside` directory.
        fn new() -> Self {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let base = std::env::temp_dir().join(format!(
                "cumaru-fs-{}-{nonce}-{:?}",
                std::process::id(),
                std::thread::current().id()
            ));
            fs::create_dir_all(base.join(".cumaru/plans/item")).unwrap();
            fs::create_dir_all(base.join(".cumaru/archive")).unwrap();
            fs::create_dir_all(base.join("outside")).unwrap();
            fs::write(base.join(".cumaru/plans/item/index.md"), "index").unwrap();
            fs::write(base.join(".cumaru/plans/item/note.md"), "note").unwrap();
            fs::write(base.join(".cumaru/archive/index.md"), "archive").unwrap();

            Self(fs::canonicalize(base).unwrap())
        }

        /// The fixture's `.cumaru/` directory.
        fn cumaru(&self) -> PathBuf {
            self.0.join(".cumaru")
        }

        /// Runs one invocation against this fixture.
        fn run(&self, src: &str, verb: Verb, dst: Option<&str>) -> Result<String, Failure> {
            let args = FsArgs {
                src: src.into(),
                verb,
                dst: dst.map(Into::into),
            };
            execute(&args, &self.cumaru())
        }

        /// Sorted relative paths plus file bytes for the whole fixture, used to prove no mutation.
        fn snapshot(&self) -> Vec<(String, Vec<u8>)> {
            let mut out = Vec::new();
            let mut stack = vec![self.0.clone()];
            while let Some(dir) = stack.pop() {
                for entry in fs::read_dir(&dir).unwrap() {
                    let path = entry.unwrap().path();
                    let meta = fs::symlink_metadata(&path).unwrap();
                    let rel = path.strip_prefix(&self.0).unwrap().display().to_string();
                    let bytes = if meta.is_file() {
                        fs::read(&path).unwrap()
                    } else {
                        Vec::new()
                    };
                    if meta.is_dir() {
                        stack.push(path);
                    }
                    out.push((rel, bytes));
                }
            }
            out.sort();
            out
        }
    }

    impl Drop for Fixture {
        /// Removes only the temporary tree owned by this fixture.
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    /// Asserts a rejected failure containing the message, with the fixture left untouched.
    fn assert_rejected(fixture: &Fixture, src: &str, verb: Verb, dst: Option<&str>, text: &str) {
        let before = fixture.snapshot();
        match fixture.run(src, verb, dst) {
            Err(Failure::Rejected(message)) => assert!(message.contains(text), "{message}"),
            other => panic!("expected rejection containing {text:?}, got {other:?}"),
        }
        assert_eq!(fixture.snapshot(), before);
    }

    /// Creates files and directories with implicit parents; an existing path keeps its bytes.
    #[test]
    fn creates_files_dirs_and_preserves_existing_paths() {
        let fixture = Fixture::new();
        let root = fixture.cumaru();

        let message = fixture
            .run("plans/new/deep/note.md", Verb::Create, None)
            .unwrap();
        assert_eq!(message, "create: plans/new/deep/note.md (file)");
        assert_eq!(fs::read(root.join("plans/new/deep/note.md")).unwrap(), b"");

        let message = fixture.run("plans/dir/", Verb::Create, None).unwrap();
        assert_eq!(message, "create: plans/dir/ (dir)");
        assert!(root.join("plans/dir").is_dir());

        let message = fixture
            .run("plans/item/note.md", Verb::Create, None)
            .unwrap();
        assert!(message.starts_with("already exists (no-op)"));
        assert_eq!(fs::read(root.join("plans/item/note.md")).unwrap(), b"note");
    }

    /// Moves and copies files and directory trees, refusing existing destinations.
    #[test]
    fn moves_and_copies_files_and_trees() {
        let fixture = Fixture::new();
        let root = fixture.cumaru();

        fixture
            .run(
                "plans/item/note.md",
                Verb::Copy,
                Some("archive/copied/note.md"),
            )
            .unwrap();
        assert_eq!(
            fs::read(root.join("archive/copied/note.md")).unwrap(),
            b"note"
        );
        assert!(root.join("plans/item/note.md").is_file());

        fixture
            .run("plans/item", Verb::Copy, Some("archive/item"))
            .unwrap();
        assert_eq!(
            fs::read(root.join("archive/item/index.md")).unwrap(),
            b"index"
        );
        assert!(root.join("plans/item/index.md").is_file());

        assert_rejected(
            &fixture,
            "plans/item",
            Verb::Move,
            Some("archive/item"),
            "destination already exists",
        );

        let message = fixture
            .run("plans/item", Verb::Move, Some("archive/moved/item"))
            .unwrap();
        assert_eq!(message, "move: plans/item -> archive/moved/item");
        assert!(!root.join("plans/item").exists());
        assert!(root.join("archive/moved/item/note.md").is_file());
    }

    /// Removes files and entity directories but never index files or pillar roots.
    #[test]
    fn removes_with_protections() {
        let fixture = Fixture::new();
        let root = fixture.cumaru();

        assert_rejected(
            &fixture,
            "plans/item/index.md",
            Verb::Remove,
            None,
            "cannot remove an index.md",
        );
        assert_rejected(
            &fixture,
            "plans",
            Verb::Remove,
            None,
            "cannot remove a pillar root",
        );
        assert_rejected(
            &fixture,
            "plans/missing.md",
            Verb::Remove,
            None,
            "source not found",
        );

        fixture
            .run("plans/item/note.md", Verb::Remove, None)
            .unwrap();
        assert!(!root.join("plans/item/note.md").exists());
        fixture.run("plans/item", Verb::Remove, None).unwrap();
        assert!(!root.join("plans/item").exists());
        assert!(root.join("plans").is_dir());
    }

    /// Classifies arity, syntax, and shape violations without mutation.
    #[test]
    fn rejects_invalid_invocations_and_shapes() {
        let fixture = Fixture::new();

        assert!(matches!(
            fixture.run("plans/item", Verb::Move, None),
            Err(Failure::Usage(_))
        ));
        assert!(matches!(
            fixture.run("plans/item", Verb::Create, Some("x")),
            Err(Failure::Usage(_))
        ));
        assert!(matches!(
            fixture.run("", Verb::Remove, None),
            Err(Failure::Usage(_))
        ));

        assert_rejected(&fixture, "/tmp", Verb::Remove, None, "must be relative");
        assert_rejected(
            &fixture,
            "plans/../item",
            Verb::Remove,
            None,
            "segments not allowed",
        );
        assert_rejected(
            &fixture,
            "plans/./item",
            Verb::Remove,
            None,
            "segments not allowed",
        );
        assert_rejected(
            &fixture,
            "plans/data.txt",
            Verb::Create,
            None,
            "directory names must not contain dots",
        );
        assert_rejected(
            &fixture,
            "plans/item.v2",
            Verb::Create,
            None,
            "directory names must not contain dots",
        );
        assert_rejected(
            &fixture,
            "plans/v.2/x.md",
            Verb::Create,
            None,
            "directory names must not contain dots",
        );
        assert_rejected(
            &fixture,
            "plans/item/note.md",
            Verb::Copy,
            Some("archive/note.txt"),
            "file must end in .md",
        );
        assert_rejected(
            &fixture,
            "plans/item",
            Verb::Copy,
            Some("archive/item.v2"),
            "directory names must not contain dots",
        );

        fs::write(fixture.cumaru().join("plans/data.txt"), "x").unwrap();
        assert_rejected(
            &fixture,
            "plans/data.txt",
            Verb::Remove,
            None,
            "file must end in .md",
        );
    }

    /// Accepts in-root parent symlinks and refuses escaping parents and direct (including broken) links.
    #[test]
    fn applies_the_fs_symlink_policy() {
        let fixture = Fixture::new();
        let root = fixture.cumaru();
        symlink(root.join("plans"), root.join("archive/alias")).unwrap();
        symlink(fixture.0.join("outside"), root.join("escape")).unwrap();
        symlink("item", root.join("plans/link")).unwrap();
        symlink("missing", root.join("plans/broken")).unwrap();

        assert_rejected(
            &fixture,
            "escape/new.md",
            Verb::Create,
            None,
            "resolves outside .cumaru",
        );
        assert!(!fixture.0.join("outside/new.md").exists());
        assert_rejected(
            &fixture,
            "plans/link",
            Verb::Remove,
            None,
            "symlink targets are not supported",
        );
        assert_rejected(
            &fixture,
            "plans/broken",
            Verb::Remove,
            None,
            "symlink targets are not supported",
        );
        assert_rejected(
            &fixture,
            "plans/broken/x.md",
            Verb::Create,
            None,
            "cannot resolve",
        );
        assert_rejected(
            &fixture,
            "plans/item/note.md",
            Verb::Copy,
            Some("plans/link"),
            "symlink targets are not supported",
        );

        fixture
            .run("archive/alias/item/new.md", Verb::Create, None)
            .unwrap();
        assert!(root.join("plans/item/new.md").is_file());
        assert_rejected(
            &fixture,
            "archive/alias",
            Verb::Remove,
            None,
            "symlink targets are not supported",
        );
        assert!(root.join("plans/item").is_dir());
    }

    /// Refuses copying or moving a directory into its own descendants and copying trees with nested symlinks.
    #[test]
    fn guards_directory_transfers() {
        let fixture = Fixture::new();
        let root = fixture.cumaru();

        assert_rejected(
            &fixture,
            "plans/item",
            Verb::Copy,
            Some("plans/item/sub"),
            "into itself",
        );
        assert_rejected(
            &fixture,
            "plans/item",
            Verb::Move,
            Some("plans/item/sub/deeper"),
            "into itself",
        );

        symlink("note.md", root.join("plans/item/alias.md")).unwrap();
        assert_rejected(
            &fixture,
            "plans/item",
            Verb::Copy,
            Some("archive/item"),
            "contains a symlink",
        );
    }

    /// Reports filesystem failures as rejections instead of success.
    #[test]
    fn reports_io_failures() {
        let fixture = Fixture::new();
        fs::write(fixture.cumaru().join("plans/blocker"), "not a directory").unwrap();

        let result = fixture.run("plans/blocker/x.md", Verb::Create, None);
        assert!(
            matches!(result, Err(Failure::Rejected(message)) if message.contains("cannot create"))
        );
        assert_eq!(
            fs::read(fixture.cumaru().join("plans/blocker")).unwrap(),
            b"not a directory"
        );
    }
}
