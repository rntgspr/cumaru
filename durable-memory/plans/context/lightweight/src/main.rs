#[path = "../../../../../src/relevance.rs"]
mod relevance;

use relevance::{FEATURE_COUNT, Query, Scorer};
use std::time::Instant;

const TRAINING: &[(&str, &str, f64)] = &[
    (
        "bread recipes",
        "Bread recipes explain baking dough with yeast.",
        9.0,
    ),
    (
        "bread recipes",
        "Bread appears in this database label, not recipes.",
        1.0,
    ),
    ("bread recipes", "Typography controls font sizes.", 0.0),
    (
        "refresh_session",
        "fn refresh_session() renews the authentication cookie.",
        10.0,
    ),
    ("refresh_session", "Sessions expire after inactivity.", 3.0),
    ("refresh_session", "Bread recipes use flour.", 0.0),
    (
        "preserve config",
        "Preserve config choices when updating the framework.",
        9.0,
    ),
    (
        "preserve config",
        "Delete config files, never preserve config.",
        1.0,
    ),
    ("preserve config", "Adjust button typography.", 0.0),
    (
        "reject unsafe paths",
        "Reject unsafe paths before traversing files.",
        10.0,
    ),
    ("reject unsafe paths", "Paths describe file locations.", 3.0),
    (
        "reject unsafe paths",
        "Bake bread at high temperature.",
        0.0,
    ),
];

const HELD_OUT: &[(&str, &str, &str, bool)] = &[
    (
        "eggs",
        "egg recipes",
        "Egg recipes explain boiling eggs and cooking them in butter.",
        true,
    ),
    (
        "eggs",
        "egg recipes",
        "Database migration nickname: eggs. No egg recipes are provided.",
        false,
    ),
    (
        "eggs",
        "egg recipes",
        "Typography controls headings and paragraph spacing.",
        false,
    ),
    (
        "code",
        "rotate_refresh_token",
        "fn rotate_refresh_token() invalidates the old authentication token.",
        true,
    ),
    (
        "code",
        "rotate_refresh_token",
        "The login screen displays a password form.",
        false,
    ),
    (
        "update",
        "retain adopter bodies",
        "Retain adopter bodies during canonical Markdown replacement.",
        true,
    ),
    (
        "update",
        "retain adopter bodies",
        "Replace adopter bodies, never retain adopter bodies.",
        false,
    ),
    (
        "paraphrase",
        "renew credentials",
        "Rotate authentication tokens before they expire.",
        true,
    ),
    (
        "paraphrase",
        "renew credentials",
        "Typography controls heading sizes.",
        false,
    ),
];

/// Fit and evaluate a tiny numerical head on disclosed, unreviewed synthetic examples.
fn main() -> Result<(), String> {
    let started = Instant::now();
    let (weights, bias) = fit()?;
    let scorer = Scorer::new(weights, bias)?;
    let baseline = Scorer::new([10.0, 0.0, 0.0, 0.0, 0.0, 0.0], 0.0)?;
    println!(
        "weights: {weights:?}\nbias: {bias}\nfit_ms: {:.3}",
        started.elapsed().as_secs_f64() * 1000.0
    );

    for &(group, text, document, relevant) in HELD_OUT {
        let query = Query::new(text)?;
        println!(
            "{group}\t{relevant}\t{:.2}\t{:.2}\t{document}",
            baseline.score(&query, document)?,
            scorer.score(&query, document)?
        );
    }

    let recipe_query = Query::new("look for egg recipes")?;
    let recipes = include_str!("../../experiment/corpus/eggs.md");

    for (path, document) in [
        ("eggs.md", recipes),
        (
            "incidental.md",
            include_str!("../../experiment/corpus/incidental.md"),
        ),
        (
            "unrelated.md",
            include_str!("../../experiment/corpus/unrelated.md"),
        ),
    ] {
        println!(
            "corpus\t{path}\t{:.2}",
            scorer.score(&recipe_query, document)?
        );
    }

    println!(
        "recipe_without_title_score: {:.2}",
        scorer.score(&recipe_query, &recipes.replacen("# Egg recipes", "", 1))?
    );

    let query = Query::new("egg recipes")?;
    let document = format!(
        "{}\n\nEgg recipes describe cooking eggs in butter.",
        "Database migrations preserve rows.\n\n".repeat(200)
    );
    let ranking = Instant::now();
    let score = scorer.score(&query, &document)?;
    println!(
        "long_suffix_score: {score:.2}\nlong_score_ms: {:.3}\nhead_bytes: {}",
        ranking.elapsed().as_secs_f64() * 1000.0,
        std::mem::size_of_val(&weights) + std::mem::size_of_val(&bias)
    );

    Ok(())
}

/// Fit regularized least squares with deterministic gradient updates, outside production runtime.
fn fit() -> Result<([f64; FEATURE_COUNT], f64), String> {
    let examples = TRAINING
        .iter()
        .map(|&(text, document, target)| Ok((Query::new(text)?.features(document), target)))
        .collect::<Result<Vec<_>, String>>()?;
    let mut weights = [0.0; FEATURE_COUNT];
    let mut bias = 0.0;

    for _ in 0..10000 {
        let mut gradient = [0.0; FEATURE_COUNT];
        let mut bias_gradient = 0.0;

        for &(features, target) in &examples {
            let error = bias
                + weights
                    .iter()
                    .zip(features)
                    .map(|(weight, value)| weight * value)
                    .sum::<f64>()
                - target;
            bias_gradient += error;

            for index in 0..FEATURE_COUNT {
                gradient[index] += error * features[index];
            }
        }

        for index in 0..FEATURE_COUNT {
            weights[index] -=
                0.05 * (gradient[index] / examples.len() as f64 + 0.001 * weights[index]);
        }

        bias -= 0.05 * bias_gradient / examples.len() as f64;
    }

    Ok((weights, bias))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Verify learned weighting separates explicit positive and negated ranking probes.
    #[test]
    fn learned_head_orders_disclosed_probes() {
        let (weights, bias) = fit().unwrap();
        let scorer = Scorer::new(weights, bias).unwrap();

        for group in ["eggs", "code", "update"] {
            let probes: Vec<_> = HELD_OUT.iter().filter(|probe| probe.0 == group).collect();
            let positive = probes.iter().find(|probe| probe.3).unwrap();
            let query = Query::new(positive.1).unwrap();
            let positive_score = scorer.score(&query, positive.2).unwrap();

            for negative in probes.iter().filter(|probe| !probe.3) {
                assert!(
                    positive_score > scorer.score(&query, negative.2).unwrap(),
                    "{group}"
                );
            }
        }
    }

    /// Verify training and evaluation queries are distinct and fitting is reproducible.
    #[test]
    fn separate_queries_and_repeatable_fitting() {
        assert!(
            HELD_OUT
                .iter()
                .all(|probe| TRAINING.iter().all(|example| probe.1 != example.0))
        );
        assert_eq!(fit().unwrap(), fit().unwrap());
    }
}
