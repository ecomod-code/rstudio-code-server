#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and edit it first." >&2
  exit 1
fi

./scripts/prepare-directories.sh
docker compose up -d

echo
echo "Stack started."
echo "  RStudio:     https://${SERVER_URL}/"
echo "  code-server: https://${SERVER_URL}/code/"
