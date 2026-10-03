#!/usr/bin/env bash
set -euo pipefail

# Build the native release executable from any working directory without discarding incremental artifacts.
RUST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cargo build --manifest-path "$RUST_DIR/Cargo.toml" --release --locked
