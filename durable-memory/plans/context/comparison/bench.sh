#!/usr/bin/env bash
set -euo pipefail

comparison_root=$(cd "$(dirname "$0")" && pwd)
output=${1:?usage: bench.sh OUTPUT_DIRECTORY}
mkdir -p "$output"
output=$(cd "$output" && pwd)
binary=$comparison_root/experiment/target/release/cumaru-encoder-comparison

cd "$comparison_root/corpus"

for variant in lightweight encoder bm25; do
  for query_case in eggs paraphrase code irrelevant; do
    case "$query_case" in
      eggs) query='look for egg recipes' ;;
      paraphrase) query='renew credentials before they expire' ;;
      code) query='rotate_refresh_token' ;;
      irrelevant) query='orbital mechanics of binary neutron stars' ;;
    esac

    "$binary" "$variant" "$query" ./*.md > "$output/$variant-$query_case.tsv" 2> "$output/$variant-$query_case.metrics"
  done
done

for variant in lightweight encoder bm25; do
  "$binary" "$variant" 'look for egg recipes' eggs-body.md incidental.md unrelated.md \
    > "$output/$variant-no-title.tsv" 2> "$output/$variant-no-title.metrics"
done
