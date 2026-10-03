#!/usr/bin/env bash
set -euo pipefail

destination=${1:?usage: fetch-assets.sh DESTINATION}
mkdir -p "$destination"
revision=3edf6d7de0faa426b09780416fe61009f26ae589

for artifact in model.safetensors tokenizer.json config.json; do
  curl -fsSL --retry 2 "https://huggingface.co/TaylorAI/bge-micro-v2/resolve/$revision/$artifact" -o "$destination/$artifact"
done

(
  cd "$destination"
  printf '%s  model.safetensors\n%s  tokenizer.json\n%s  config.json\n' \
    792472b64c3ca1c725e55f6a9d2a58143d4ce6b3ffde05bf55bc8427cb3733c8 \
    cb374d6bc042c22455946f4e09a89d29882a199fdaf8fb25be00dc8b8857a448 \
    86d7047bf568a9263c7020fb4950741b19b1df3de3539385d83d9e3df1e56c5b | shasum -a 256 -c -
)
