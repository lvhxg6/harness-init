#!/usr/bin/env bash
set -euo pipefail

feature="${FEATURE:-manual}"
run_dir=".harness/runs/${feature}"
screenshot_dir="$run_dir/screenshots"
mkdir -p "$run_dir"
mkdir -p "$screenshot_dir"

{
  echo "# Verification Evidence"
  echo
  echo "- Feature: ${feature}"
  echo "- Timestamp: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "- Git repository: $(git rev-parse --is-inside-work-tree 2>/dev/null || echo no)"
  echo "- Strict mode: ${HARNESS_STRICT:-0}"
  echo
  echo "## Screenshots"
  find "$screenshot_dir" -type f -name '*.png' 2>/dev/null | sort | sed 's#^#- #'
} > "$run_dir/evidence.md"

echo "[collect-evidence] Wrote $run_dir/evidence.md"
