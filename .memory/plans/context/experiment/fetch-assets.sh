#!/usr/bin/env bash
set -euo pipefail

destination=${1:?usage: fetch-assets.sh DESTINATION}
mkdir -p "$destination/tiny" "$destination/mini"

for candidate in tiny mini; do
  if [[ "$candidate" == tiny ]]; then
    repository=cross-encoder/ms-marco-TinyBERT-L2-v2
    revision=81d1926f67cb8eee2c2be17ca9f793c7c3bd20cc
    model_hash=0eac39ee56a3edf98d0beee17fa1bb368a5a1d8c8671b5afd6dd71677f8d8496
    config_hash=2144195e107cd7ea61556478e7add12986ebfbc3085f924fc0b90c2410604879
  else
    repository=cross-encoder/ms-marco-MiniLM-L2-v2
    revision=1b5cd67b15209f24824c50370e0397743aa9b787
    model_hash=97ae94c94faf17d97398a7af38e44ee0ef326eff99ece940423b187e885eae6a
    config_hash=7868e36c3024c21f7a3ac64e058b36898a331035784cce7ec1496b434aa44c4f
  fi

  for artifact in model.onnx tokenizer.json config.json; do
    source_path=$artifact
    [[ "$artifact" != model.onnx ]] || source_path=onnx/model.onnx
    curl -fsSL --retry 2 "https://huggingface.co/$repository/resolve/$revision/$source_path" -o "$destination/$candidate/$artifact"
  done

  (
    cd "$destination/$candidate"
    printf '%s  model.onnx\n%s  config.json\n%s  tokenizer.json\n' \
      "$model_hash" "$config_hash" d241a60d5e8f04cc1b2b3e9ef7a4921b27bf526d9f6050ab90f9267a1f9e5c66 | shasum -a 256 -c -
  )
done
