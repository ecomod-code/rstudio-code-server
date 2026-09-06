#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE"

mkdir -p \
  volumes/workspace \
  volumes/code_config \
  volumes/caddy_data \
  volumes/caddy_config
