//! In-memory Okapi BM25 inspired by Robertson and colleagues; equations and conventions: https://nlp.stanford.edu/IR-book/html/htmledition/okapi-bm25-a-non-binary-model-1.html

use std::collections::{BTreeMap, BTreeSet};

pub(super) struct Index {
    postings: BTreeMap<String, Vec<(usize, usize)>>,
    lengths: Vec<usize>,
    average_length: f64,
}

impl Index {
    /// Index each fragment's term frequencies and lengths entirely in process memory.
    pub(super) fn new(documents: &[&str]) -> Self {
        let mut postings: BTreeMap<String, Vec<(usize, usize)>> = BTreeMap::new();
        let mut lengths = Vec::new();

        for (id, document) in documents.iter().enumerate() {
            let words = tokens(document);
            lengths.push(words.len());
            let mut frequencies = BTreeMap::new();

            for word in words {
                *frequencies.entry(word).or_insert(0) += 1;
            }

            for (word, frequency) in frequencies {
                postings.entry(word).or_default().push((id, frequency));
            }
        }

        let average_length = if lengths.is_empty() {
            0.0
        } else {
            lengths.iter().sum::<usize>() as f64 / lengths.len() as f64
        };

        Self {
            postings,
            lengths,
            average_length,
        }
    }

    /// Apply positive smoothed IDF, k1=1.2 and b=0.75; unmatched fragments receive zero.
    pub(super) fn scores(&self, query: &str) -> Vec<f64> {
        let mut scores = vec![0.0; self.lengths.len()];

        if self.average_length == 0.0 {
            return scores;
        }

        let terms: BTreeSet<_> = tokens(query).into_iter().collect();

        for term in terms {
            let Some(postings) = self.postings.get(&term) else {
                continue;
            };
            let df = postings.len() as f64;
            let idf = (1.0 + (self.lengths.len() as f64 - df + 0.5) / (df + 0.5)).ln();

            for &(id, frequency) in postings {
                let tf = frequency as f64;
                let norm = 1.2 * (0.25 + 0.75 * self.lengths[id] as f64 / self.average_length);
                scores[id] += idf * tf * 2.2 / (tf + norm);
            }
        }

        scores
    }
}

/// Preserve exact words/identifiers with the comparison's English stop list, without stemming or synonyms.
fn tokens(text: &str) -> Vec<String> {
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

#[cfg(test)]
mod tests {
    use super::*;

    /// Find exact identifiers and leave empty/unmatched corpora at zero.
    #[test]
    fn exact_matches_and_empty_inputs() {
        let index = Index::new(&["fn rotate_refresh_token", "login form", ""]);
        let scores = index.scores("ROTATE_REFRESH_TOKEN");

        assert!(scores[0] > 0.0);
        assert_eq!(scores[1..], [0.0, 0.0]);
        assert_eq!(index.scores("neutron stars"), [0.0; 3]);
        assert!(Index::new(&[]).scores("eggs").is_empty());
        assert_eq!(Index::new(&[""]).scores("eggs"), [0.0]);
    }

    /// Prefer a short focused fragment and bound the gain from repeated matching words.
    #[test]
    fn length_normalization_and_frequency_saturation() {
        let padding = format!("eggs {}", "database ".repeat(100));
        let repetition = "eggs ".repeat(100);
        let index = Index::new(&["eggs", &padding, &repetition]);
        let scores = index.scores("eggs");

        assert!(scores[0] > scores[1]);
        assert!(scores[2] < scores[0] * 3.0);
        assert_eq!(index.scores("eggs eggs"), scores);
    }

    /// Expose corpus dependence instead of pretending BM25 supplies an absolute pair score.
    #[test]
    fn adding_candidates_changes_pair_scores() {
        let before = Index::new(&["eggs", "database"]).scores("eggs")[0];
        let after = Index::new(&["eggs", "database", "typography"]).scores("eggs")[0];

        assert_ne!(before, after);
    }
}
