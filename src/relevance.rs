//! Experimental fixed text features and a compact query/document relevance head.
//! Inspired by steph4n-gh's System1 fixed-feature numerical heads for lightweight local scoring; this is an original reduced implementation, not a port: https://github.com/steph4n-gh/system1/blob/fb518ccc37829d3a14490f0e1a5920b402e711da/docs/architecture/technical_specification.md

use std::collections::BTreeSet;

pub(crate) const FEATURE_COUNT: usize = 6;
const MAX_QUERY_BYTES: usize = 1024;
const MAX_DOCUMENT_BYTES: usize = 1024 * 1024;
const WINDOW_WORDS: usize = 128;
const OVERLAP_WORDS: usize = 16;

pub(crate) struct Query {
    words: Vec<String>,
    terms: BTreeSet<String>,
    grams: BTreeSet<String>,
    identifiers: BTreeSet<String>,
}

pub(crate) struct Scorer {
    weights: [f64; FEATURE_COUNT],
    bias: f64,
}

impl Query {
    /// Prepare fixed query features and reject empty or over-budget input.
    pub(crate) fn new(text: &str) -> Result<Self, String> {
        if text.len() > MAX_QUERY_BYTES {
            return Err("query exceeds the experimental 1024-byte budget".into());
        }

        let words = words(text);
        let terms: BTreeSet<_> = words.iter().cloned().collect();

        if terms.is_empty() {
            return Err("query has no searchable terms".into());
        }

        let grams = grams(&terms);
        let identifiers = terms
            .iter()
            .filter(|term| term.contains('_'))
            .cloned()
            .collect();

        Ok(Self {
            words,
            terms,
            grams,
            identifiers,
        })
    }

    /// Extract independent features from one bounded fragment without corpus statistics.
    #[allow(dead_code)]
    pub(crate) fn features(&self, text: &str) -> [f64; FEATURE_COUNT] {
        self.word_features(&words(text))
    }

    /// Compare query terms, phrases, subwords, identifiers, density, and explicit negation.
    fn word_features(&self, words: &[String]) -> [f64; FEATURE_COUNT] {
        let terms: BTreeSet<_> = words.iter().cloned().collect();
        let matching = self.terms.intersection(&terms).count();
        let coverage = matching as f64 / self.terms.len() as f64;
        let phrase = f64::from(
            words
                .windows(self.words.len())
                .any(|window| window == self.words),
        );
        let document_grams = grams(&terms);
        let subwords = if self.grams.is_empty() {
            0.0
        } else {
            self.grams.intersection(&document_grams).count() as f64 / self.grams.len() as f64
        };
        let identifiers = if self.identifiers.is_empty() {
            0.0
        } else {
            self.identifiers.intersection(&terms).count() as f64 / self.identifiers.len() as f64
        };
        let density = if words.is_empty() {
            0.0
        } else {
            words
                .iter()
                .filter(|word| self.terms.contains(*word))
                .count() as f64
                / words.len() as f64
        };
        let negated = words.iter().enumerate().any(|(index, word)| {
            matches!(word.as_str(), "no" | "not" | "never" | "without")
                && words[index + 1..words.len().min(index + 6)]
                    .iter()
                    .any(|next| self.terms.contains(next))
        });

        [
            coverage,
            phrase,
            subwords,
            identifiers,
            density,
            f64::from(negated),
        ]
    }
}

impl Scorer {
    /// Accept explicit experimental coefficients without introducing default production weights.
    pub(crate) fn new(weights: [f64; FEATURE_COUNT], bias: f64) -> Result<Self, String> {
        if !bias.is_finite() || weights.iter().any(|weight| !weight.is_finite()) {
            return Err("scorer coefficients must be finite".into());
        }

        Ok(Self { weights, bias })
    }

    /// Evaluate a fixed feature vector as a bounded relevance score, not a probability.
    pub(crate) fn predict(&self, features: [f64; FEATURE_COUNT]) -> f64 {
        if features[0] == 0.0 && features[2] == 0.0 && features[3] == 0.0 {
            return 0.0;
        }

        let raw = self.bias
            + self
                .weights
                .iter()
                .zip(features)
                .map(|(weight, value)| weight * value)
                .sum::<f64>();

        raw.clamp(0.0, 10.0)
    }

    /// Score every paragraph through bounded overlapping windows and retain the best fragment.
    pub(crate) fn score(&self, query: &Query, document: &str) -> Result<f64, String> {
        if document.len() > MAX_DOCUMENT_BYTES {
            return Err("document exceeds the experimental 1-MiB budget".into());
        }

        let mut maximum = 0.0_f64;

        for paragraph in document.split("\n\n") {
            let words = words(paragraph);
            let mut start = 0;

            while start < words.len() {
                let end = words.len().min(start + WINDOW_WORDS);
                maximum = maximum.max(self.predict(query.word_features(&words[start..end])));

                if end == words.len() {
                    break;
                }

                start = end - OVERLAP_WORDS;
            }
        }

        Ok(maximum)
    }
}

/// Preserve identifier tokens and English word signals without a language-model tokenizer.
fn words(text: &str) -> Vec<String> {
    text.split(|character: char| !character.is_alphanumeric() && character != '_')
        .filter(|word| !word.is_empty())
        .map(str::to_lowercase)
        .filter(|word| {
            !matches!(
                word.as_str(),
                "a" | "an"
                    | "the"
                    | "to"
                    | "of"
                    | "for"
                    | "in"
                    | "on"
                    | "and"
                    | "is"
                    | "are"
                    | "how"
                    | "where"
                    | "find"
                    | "look"
                    | "show"
                    | "me"
            )
        })
        .collect()
}

/// Build stable character trigrams to expose limited spelling and morphology similarity.
fn grams(terms: &BTreeSet<String>) -> BTreeSet<String> {
    let mut grams = BTreeSet::new();

    for term in terms {
        let characters: Vec<_> = term.chars().collect();

        for window in characters.windows(3) {
            grams.insert(window.iter().collect());
        }
    }

    grams
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Reject meaningless input, oversized queries, and nonfinite coefficients.
    #[test]
    fn input_validation() {
        assert!(Query::new(" ").is_err());
        assert!(Query::new("look for the").is_err());
        assert!(Query::new(&"x".repeat(MAX_QUERY_BYTES + 1)).is_err());
        assert!(Scorer::new([f64::NAN; FEATURE_COUNT], 0.0).is_err());
    }

    /// Preserve code identifiers and link destinations as independently usable signals.
    #[test]
    fn code_and_links_remain_features() {
        let query = Query::new("rotate_refresh_token").unwrap();
        let features = query.features(
            "```rust\nfn rotate_refresh_token() {}\n```\n[code](src/rotate_refresh_token.rs)",
        );

        assert_eq!(features[0], 1.0);
        assert_eq!(features[3], 1.0);
    }

    /// Keep scores independent of repeated terms and unrelated candidate evaluations.
    #[test]
    fn candidate_independence_and_repetition() {
        let query = Query::new("egg recipes").unwrap();
        let scorer = Scorer::new([6.0, 2.0, 1.0, 0.0, 0.0, -3.0], 0.0).unwrap();
        let expected = scorer.score(&query, "egg recipes").unwrap();
        let _ = scorer.score(&query, "database migration").unwrap();

        assert_eq!(scorer.score(&query, "egg recipes").unwrap(), expected);
        assert_eq!(
            scorer
                .score(&query, &"egg recipes\n\n".repeat(200))
                .unwrap(),
            expected
        );
    }

    /// Retain a late matching fragment and make document-budget failures explicit.
    #[test]
    fn late_content_and_budget() {
        let query = Query::new("egg recipes").unwrap();
        let scorer = Scorer::new([8.0, 1.0, 1.0, 0.0, 0.0, 0.0], 0.0).unwrap();
        let long = format!("{} egg recipes", "database migration ".repeat(2000));

        assert!(scorer.score(&query, &long).unwrap() >= 9.0);
        assert_eq!(scorer.score(&query, "").unwrap(), 0.0);
        assert!(
            scorer
                .score(&query, &"x".repeat(MAX_DOCUMENT_BYTES + 1))
                .is_err()
        );
    }
}
