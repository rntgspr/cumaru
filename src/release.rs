//! Build identity and plain release version interpretation.

pub(crate) const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Returns numeric components for a plain three-component release tag, rejecting prefixes and suffixes.
pub(crate) fn release_parts(tag: &str) -> Option<[u64; 3]> {
    let mut parts = tag.split('.');
    let mut version = [0; 3];

    for component in &mut version {
        let part = parts.next()?;
        if part.is_empty() || !part.bytes().all(|byte| byte.is_ascii_digit()) {
            return None;
        }
        *component = part.parse().ok()?;
    }

    parts.next().is_none().then_some(version)
}

/// Selects the highest plain release tag from git ls-remote records, ignoring non-release refs.
pub(crate) fn highest_release(refs: &str) -> Option<&str> {
    refs.lines()
        .filter_map(|line| line.split_once('\t'))
        .filter_map(|(_, reference)| reference.strip_prefix("refs/tags/"))
        .filter_map(|tag| release_parts(tag).map(|parts| (parts, tag)))
        .max_by_key(|(parts, _)| *parts)
        .map(|(_, tag)| tag)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Rejects tags outside the plain release grammar instead of comparing them as releases.
    #[test]
    fn accepts_only_plain_releases() {
        assert_eq!(release_parts("9.10.2"), Some([9, 10, 2]));
        for invalid in ["v9.0.0", "9.0", "9.0.0.1", "9.0.0-beta", "+9.0.0", "9..0"] {
            assert_eq!(release_parts(invalid), None);
        }
    }

    /// Chooses numeric release order and ignores branches, prefixed tags, and peeled refs.
    #[test]
    fn selects_highest_numeric_release() {
        let refs = "abc\trefs/tags/9.9.9\nabc\trefs/tags/9.10.0\nabc\trefs/tags/v99.0.0\nabc\trefs/tags/99.0.0^{}\nabc\trefs/heads/100.0.0\n";
        assert_eq!(highest_release(refs), Some("9.10.0"));
        assert_eq!(highest_release("abc\trefs/tags/beta\n"), None);
        assert!(release_parts("10.0.0") > release_parts("9.99.99"));
    }
}
