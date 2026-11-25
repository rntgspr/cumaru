#!/usr/bin/env bash
set -euo pipefail

experiment_root=$(cd "$(dirname "$0")" && pwd)
binary=${CUMARU_CONTEXT_BINARY:-$experiment_root/target/release/cumaru-context-feasibility}
output=${1:?usage: bench.sh OUTPUT_DIRECTORY}
mkdir -p "$output"
output=$(cd "$output" && pwd)

for variant in incidental relevant; do
  {
    printf '# Database operations\n\n'
    for ((index=0; index<200; index++)); do
      printf 'Database migrations preserve existing rows and verify foreign keys.\n\n'
    done
    if [[ "$variant" == relevant ]]; then
      cat "$experiment_root/corpus/eggs.md"
    else
      cat "$experiment_root/corpus/incidental.md"
    fi
  } > "$output/long-$variant.md"
done

cd "$experiment_root/corpus"

for candidate in tiny mini; do
  for query_case in eggs code update navigation irrelevant; do
    case "$query_case" in
      eggs) query='look for egg recipes' ;;
      code) query='rotate_refresh_token' ;;
      update) query='preserve local tag bodies during framework update' ;;
      navigation) query='reject symlinks during Markdown traversal' ;;
      irrelevant) query='orbital mechanics of binary neutron stars' ;;
    esac
    "$binary" "$candidate" "$query" ./*.md > "$output/$candidate-$query_case.tsv" 2> "$output/$candidate-$query_case.metrics"
  done

  for strategy in paragraphs sections; do
    CUMARU_CONTEXT_FRAGMENTATION=$strategy "$binary" "$candidate" 'look for egg recipes' "$output"/long-*.md \
      > "$output/$candidate-long-$strategy.tsv" 2> "$output/$candidate-long-$strategy.metrics"
  done
done
