mod bm25;
#[allow(dead_code)]
#[path = "../../current-relevance.rs"]
mod relevance;

use candle_core::{DType, Device, Tensor};
use candle_nn::VarBuilder;
use candle_transformers::models::bert::{BertModel, Config};
use relevance::{Query, Scorer};
use std::{error::Error, time::Instant};
use tokenizers::Tokenizer;

const MODEL: &[u8] = include_bytes!(concat!(env!("CUMARU_ENCODER_ASSETS"), "/model.safetensors"));
const TOKENIZER: &[u8] = include_bytes!(concat!(env!("CUMARU_ENCODER_ASSETS"), "/tokenizer.json"));
const CONFIG: &[u8] = include_bytes!(concat!(env!("CUMARU_ENCODER_ASSETS"), "/config.json"));
const WEIGHTS: [f64; 6] = [
    1.6516180059844272,
    -0.29166447445653965,
    7.092405754054716,
    1.0572771405692523,
    2.135778445663964,
    -8.433062931187917,
];
const BIAS: f64 = 0.046831893207445977;

struct Encoder {
    model: BertModel,
    tokenizer: Tokenizer,
}

impl Encoder {
    /// Load TaylorAI's embedded BGE Micro v2 on CPU through Hugging Face Candle.
    /// Source: https://huggingface.co/TaylorAI/bge-micro-v2/tree/3edf6d7de0faa426b09780416fe61009f26ae589
    fn new() -> Result<Self, Box<dyn Error>> {
        let config: Config = serde_json::from_slice(CONFIG)?;
        let builder =
            VarBuilder::from_buffered_safetensors(MODEL.to_vec(), DType::F32, &Device::Cpu)?;
        let model = BertModel::load(builder, &config)?;
        let mut tokenizer = Tokenizer::from_bytes(TOKENIZER).map_err(|e| e.to_string())?;
        tokenizer.with_truncation(None).map_err(|e| e.to_string())?;
        tokenizer.with_padding(None);

        Ok(Self { model, tokenizer })
    }

    /// Produce a normalized mean-pooled vector without padding or silent truncation.
    fn embed(&self, text: &str) -> Result<Vec<f32>, Box<dyn Error>> {
        let encoding = self
            .tokenizer
            .encode(text, true)
            .map_err(|e| e.to_string())?;

        if encoding.len() > 512 {
            return Err("fragment exceeds the encoder's 512-token budget".into());
        }

        let ids = Tensor::new(encoding.get_ids(), &Device::Cpu)?.unsqueeze(0)?;
        let types = Tensor::new(encoding.get_type_ids(), &Device::Cpu)?.unsqueeze(0)?;
        let hidden = self.model.forward(&ids, &types, None)?;
        let mut vector = hidden.mean(1)?.squeeze(0)?.to_vec1::<f32>()?;
        let norm = vector.iter().map(|value| value * value).sum::<f32>().sqrt();

        if !norm.is_finite() || norm <= 0.0 {
            return Err("invalid embedding norm".into());
        }

        for value in &mut vector {
            *value /= norm;
        }

        Ok(vector)
    }
}

/// Compare a frozen scorer, embedded encoder, and in-memory BM25 without changing the production CLI.
fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<_> = std::env::args().collect();

    if args.get(1).map(String::as_str) == Some("--identity") {
        println!("cumaru-encoder-comparison 0.1.0");
        return Ok(());
    }

    if args.len() < 4 || !matches!(args[1].as_str(), "encoder" | "lightweight" | "bm25") {
        return Err("usage: comparison encoder|lightweight|bm25 QUERY FILE...".into());
    }

    let prepared = Query::new(&args[2])?;
    let mut documents = Vec::new();

    for path in &args[3..] {
        let document = std::fs::read_to_string(path)?;

        if document.len() > 1024 * 1024 {
            return Err("document exceeds the experimental 1-MiB budget".into());
        }

        documents.push((path, fragments(&document)));
    }

    let initialized = Instant::now();
    let fragment_texts: Vec<_> = documents
        .iter()
        .flat_map(|(_, parts)| parts.iter().map(String::as_str))
        .collect();
    let index = if args[1] == "bm25" {
        Some(bm25::Index::new(&fragment_texts))
    } else {
        None
    };
    let scorer = Scorer::new(WEIGHTS, BIAS)?;
    let encoder = if args[1] == "encoder" {
        Some(Encoder::new()?)
    } else {
        None
    };
    eprintln!(
        "initialization_ms: {:.3}",
        initialized.elapsed().as_secs_f64() * 1000.0
    );
    let scoring = Instant::now();
    let vector = encoder
        .as_ref()
        .map(|encoder| encoder.embed(&args[2]))
        .transpose()?;
    let mut records = Vec::new();
    let mut fragment_count = 0;
    let bm25_scores = index.as_ref().map(|index| index.scores(&args[2]));

    for (path, parts) in &documents {
        let mut score = 0.0_f64;

        for fragment in parts {
            let fragment_score = if let Some(raw_scores) = &bm25_scores {
                let raw = raw_scores[fragment_count];
                10.0 * raw / (raw + 3.0)
            } else if let (Some(encoder), Some(query_vector)) = (&encoder, &vector) {
                let document_vector = encoder.embed(&fragment)?;
                let cosine: f32 = query_vector
                    .iter()
                    .zip(document_vector)
                    .map(|(query, document)| query * document)
                    .sum();
                f64::from(cosine.clamp(0.0, 1.0)) * 10.0
            } else {
                scorer.score(&prepared, &fragment)?
            };

            score = score.max(fragment_score);
            fragment_count += 1;
        }

        records.push((path, (score * 100.0).round() as u16));
    }

    records.sort_by(|left, right| {
        right
            .1
            .cmp(&left.1)
            .then_with(|| left.0.as_bytes().cmp(right.0.as_bytes()))
    });

    for (path, score) in records {
        println!("{path}\t{:.2}", f64::from(score) / 100.0);
    }

    eprintln!(
        "scoring_ms: {:.3}\nfragments: {fragment_count}",
        scoring.elapsed().as_secs_f64() * 1000.0
    );

    let mut usage = std::mem::MaybeUninit::<libc::rusage>::uninit();

    // getrusage initializes the complete structure only on a successful return.
    if unsafe { libc::getrusage(libc::RUSAGE_SELF, usage.as_mut_ptr()) } == 0 {
        eprintln!(
            "peak_rss_native_units: {}",
            unsafe { usage.assume_init() }.ru_maxrss
        );
    }

    Ok(())
}

/// Supply identical paragraph fragments to every variant, covering long paragraphs with overlap.
fn fragments(document: &str) -> Vec<String> {
    let mut result = Vec::new();

    for paragraph in document
        .split("\n\n")
        .filter(|paragraph| !paragraph.trim().is_empty())
    {
        let words: Vec<_> = paragraph.split_whitespace().collect();
        let mut start = 0;

        while start < words.len() {
            let end = words.len().min(start + 128);
            result.push(words[start..end].join(" "));

            if end == words.len() {
                break;
            }

            start = end - 16;
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Retain the last word and preserve code/link tokens while covering long text.
    #[test]
    fn fragments_preserve_signals_and_suffix() {
        let document = format!(
            "{} END\n\n```rust fn code() {{}} ``` [link](src/auth.rs)",
            "word ".repeat(300)
        );
        let fragments = fragments(&document);

        assert!(fragments.iter().any(|fragment| fragment.ends_with("END")));
        assert!(fragments.last().unwrap().contains("[link](src/auth.rs)"));
        assert!(
            fragments
                .iter()
                .all(|fragment| fragment.split_whitespace().count() <= 128)
        );
        assert!(super::fragments("").is_empty());
    }
}
