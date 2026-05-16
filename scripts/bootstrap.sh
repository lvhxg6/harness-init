#!/usr/bin/env bash
set -euo pipefail

echo "[bootstrap] Checking Harness skeleton"

required=(
  "AGENTS.md"
  "Makefile"
  "docs/architecture/system.md"
  "docs/architecture/testing.md"
  "docs/architecture/_feature-template.md"
  ".harness/prompts/generate-architecture.md"
  ".harness/prompts/implement-feature.md"
  "scripts/harness-preflight.sh"
  "scripts/classify-verification-failure.sh"
  "scripts/harness-status.sh"
  "scripts/install-workspace-deps.sh"
)

for path in "${required[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "[bootstrap] Missing required file: $path" >&2
    exit 1
  fi
done

echo "[bootstrap] OK"
