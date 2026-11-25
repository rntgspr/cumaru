use std::{io::Cursor, time::Instant};
use tokenizers::Tokenizer;
use tract_onnx::prelude::*;
use tract_onnx::tract_core::internal::{anyhow, bail, ensure};

const TINY_MODEL: &[u8] =
    include_bytes!(concat!(env!("CUMARU_CONTEXT_ASSETS"), "/tiny/model.onnx"));
const TINY_TOKENIZER: &[u8] = include_bytes!(concat!(
    env!("CUMARU_CONTEXT_ASSETS"),
    "/tiny/tokenizer.json"
));
const MINI_MODEL: &[u8] =
    include_bytes!(concat!(env!("CUMARU_CONTEXT_ASSETS"), "/mini/model.onnx"));
const MINI_TOKENIZER: &[u8] = include_bytes!(concat!(
    env!("CUMARU_CONTEXT_ASSETS"),
    "/mini/tokenizer.json"
));

/// Measure embedded CPU initialization and score explicit query/document pairs.
fn main() -> TractResult<()> {
    let args: Vec<String> = std::env::args().collect();

    if args.get(1).map(String::as_str) == Some("--identity") {
        println!("cumaru-context-feasibility 0.1.0");
        return Ok(());
    }

    ensure!(args.len() >= 4, "usage: experiment tiny|mini QUERY FILE...");
    let (bytes, tokenizer_bytes) = match args[1].as_str() {
        "tiny" => (TINY_MODEL, TINY_TOKENIZER),
        "mini" => (MINI_MODEL, MINI_TOKENIZER),
        _ => bail!("unknown model"),
    };

    let started = Instant::now();
    let mut tokenizer =
        Tokenizer::from_bytes(tokenizer_bytes).map_err(|e| anyhow!(e.to_string()))?;
    tokenizer
        .with_truncation(None)
        .map_err(|e| anyhow!(e.to_string()))?;
    tokenizer.with_padding(None);
    let query = tokenizer
        .encode(args[2].as_str(), false)
        .map_err(|e| anyhow!(e.to_string()))?;
    ensure!(
        !query.is_empty() && query.len() <= 64,
        "query must contain 1..64 tokens"
    );

    let mut model = tract_onnx::onnx().model_for_read(&mut Cursor::new(bytes))?;
    let inputs = model.input_outlets()?.to_vec();

    for (index, outlet) in inputs.iter().enumerate() {
        eprintln!("input: {}", model.node(outlet.node).name);
        model.set_input_fact(index, i64::fact([1, 512]).into())?;
    }

    let model = model.into_optimized()?.into_runnable()?;
    eprintln!(
        "initialization_ms: {:.3}",
        started.elapsed().as_secs_f64() * 1000.0
    );

    for path in &args[3..] {
        let document = std::fs::read_to_string(path)?;
        let encoding = tokenizer
            .encode(document.as_str(), false)
            .map_err(|e| anyhow!(e.to_string()))?;
        ensure!(
            encoding.len() <= 16384,
            "document exceeds experimental 16384-token budget: {}",
            path
        );
        let section_aware =
            std::env::var("CUMARU_CONTEXT_FRAGMENTATION").as_deref() == Ok("sections");
        let ranges = fragments(&document, &encoding, 512 - query.len() - 3, section_aware);
        let mut scores = Vec::new();
        let inference = Instant::now();

        for (start, end) in &ranges {
            let mut ids = vec![101_i64];
            ids.extend(query.get_ids().iter().map(|&n| n as i64));
            ids.push(102);
            ids.extend(encoding.get_ids()[*start..*end].iter().map(|&n| n as i64));
            ids.push(102);
            let mut mask = vec![1_i64; ids.len()];
            let mut types = vec![0_i64; query.len() + 2];
            types.resize(ids.len(), 1);
            ids.resize(512, 0);
            mask.resize(512, 0);
            types.resize(512, 0);

            let tensors = [ids, mask, types]
                .into_iter()
                .map(|v| Tensor::from_shape(&[1, 512], &v).map(TValue::from))
                .collect::<TractResult<TVec<_>>>()?;
            let result = model.run(tensors)?;
            scores.push(result[0].to_array_view::<f32>()?[[0, 0]]);
        }

        let maximum = scores.iter().copied().fold(f32::NEG_INFINITY, f32::max);
        let mean = scores.iter().sum::<f32>() / scores.len() as f32;
        let displayed = (10.0 / (1.0 + (-maximum).exp())).round() as u8;
        println!(
            "{}\t{}\t{}\t{}\t{}\t{}\t{:.3}",
            path,
            encoding.len(),
            ranges.len(),
            maximum,
            mean,
            displayed,
            inference.elapsed().as_secs_f64() * 1000.0
        );
    }

    #[cfg(unix)]
    {
        let mut usage = std::mem::MaybeUninit::<libc::rusage>::uninit();

        // getrusage initializes the complete structure only on a successful return.
        if unsafe { libc::getrusage(libc::RUSAGE_SELF, usage.as_mut_ptr()) } == 0 {
            let usage = unsafe { usage.assume_init() };
            eprintln!("peak_rss_native_units: {}", usage.ru_maxrss);
        }
    }

    Ok(())
}

/// Cover every token with bounded fragments and compare paragraph versus literal heading cuts.
fn fragments(
    document: &str,
    encoding: &tokenizers::Encoding,
    budget: usize,
    section_aware: bool,
) -> Vec<(usize, usize)> {
    let mut ranges = Vec::new();
    let mut start = 0;

    while start < encoding.len() {
        let mut end = (start + budget).min(encoding.len());
        let mut section_boundary = false;

        if section_aware {
            for boundary in (start + 1)..end {
                let offset = encoding.get_offsets()[boundary].0;

                if (offset == 0 || document.as_bytes()[offset - 1] == b'\n')
                    && document[offset..].starts_with('#')
                {
                    end = boundary;
                    section_boundary = true;
                    break;
                }
            }
        }

        if !section_boundary && end < encoding.len() {
            let lower = start + budget / 2;

            for boundary in (lower..end).rev() {
                let previous = encoding.get_offsets()[boundary - 1].1;
                let next = encoding.get_offsets()[boundary].0;

                if document[previous..next].contains("\n\n") {
                    end = boundary;
                    break;
                }
            }
        }

        ranges.push((start, end));

        if end == encoding.len() {
            break;
        }

        start = if section_boundary {
            end
        } else {
            end.saturating_sub(32).max(start + 1)
        };
    }

    if ranges.is_empty() {
        ranges.push((0, 0));
    }

    ranges
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Prove long-fragment coverage, bounded lengths, overlap, and a retained final token.
    #[test]
    fn fragments_cover_long_documents() {
        let tokenizer = Tokenizer::from_bytes(TINY_TOKENIZER).unwrap();
        let document = "Database migrations preserve existing rows.\n\n".repeat(300);
        let encoding = tokenizer.encode(document.as_str(), false).unwrap();
        let ranges = fragments(&document, &encoding, 440, false);

        assert!(ranges.len() > 1);
        assert_eq!(ranges[0].0, 0);
        assert_eq!(ranges.last().unwrap().1, encoding.len());

        for &(start, end) in &ranges {
            assert!(end > start && end - start <= 440);
        }

        for pair in ranges.windows(2) {
            assert!(pair[1].0 <= pair[0].1);
            assert!(pair[1].1 > pair[0].1);
        }
    }

    /// Verify explicit behavior for an empty host without losing its ranking candidate.
    #[test]
    fn empty_document_has_one_empty_fragment() {
        let tokenizer = Tokenizer::from_bytes(TINY_TOKENIZER).unwrap();
        let encoding = tokenizer.encode("", false).unwrap();

        assert_eq!(fragments("", &encoding, 440, false), vec![(0, 0)]);
    }

    /// Verify heading cuts retain every token and separate a late relevant section.
    #[test]
    fn heading_cuts_keep_late_sections() {
        let tokenizer = Tokenizer::from_bytes(TINY_TOKENIZER).unwrap();
        let document = format!(
            "{}\n# Egg recipes\n\nCook eggs in butter.\n",
            "Database migrations preserve rows.\n\n".repeat(200)
        );
        let encoding = tokenizer.encode(document.as_str(), false).unwrap();
        let ranges = fragments(&document, &encoding, 440, true);
        let heading = document.find("# Egg recipes").unwrap();
        let token = encoding
            .get_offsets()
            .iter()
            .position(|&(start, _)| start == heading)
            .unwrap();

        assert!(ranges.iter().any(|&(start, _)| start == token));
        assert_eq!(ranges[0].0, 0);
        assert_eq!(ranges.last().unwrap().1, encoding.len());
        assert!(
            ranges
                .iter()
                .all(|&(start, end)| end > start && end - start <= 440)
        );
        assert!(
            ranges
                .windows(2)
                .all(|pair| pair[1].0 <= pair[0].1 && pair[1].1 > pair[0].1)
        );
    }
}
