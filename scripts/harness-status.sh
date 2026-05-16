#!/usr/bin/env bash
set -euo pipefail

feature="${1:-${FEATURE:-}}"
if [[ -z "$feature" ]]; then
  echo "Usage: ./scripts/harness-status.sh <feature>" >&2
  exit 2
fi

run_dir=".harness/runs/${feature}"
status_md="${run_dir}/status.md"
status_jsonl="${run_dir}/status.jsonl"

if [[ ! -d "$run_dir" ]]; then
  echo "No run directory: $run_dir" >&2
  exit 1
fi

if [[ -f "$run_dir/state.json" ]]; then
  node ./scripts/harness-state.mjs render --run-dir "$run_dir" >/dev/null 2>&1 || true
  cat "$status_md"
elif [[ -f "$run_dir/status.jsonl" ]]; then
  echo "# Harness Status"
  echo
  echo "- Feature: $feature"
  echo "- Status: legacy run; no state.json"
  echo "- Run dir: $run_dir"
  echo
  echo "This run was created before the stateful Harness format. Start a new run to get the full step table."
elif [[ -f "$status_md" ]]; then
  cat "$status_md"
else
  echo "Feature: $feature"
  echo "Run dir: $run_dir"
  echo "Status file missing: $status_md"
fi

echo
echo "Latest logs:"
find "$run_dir" -maxdepth 2 -type f \( -name '*.log' -o -name '*.md' -o -name '*.json' -o -name '*.yaml' \) -print | sort | tail -20 | sed 's#^#- #'

if [[ -f "$run_dir/timeline.jsonl" ]]; then
  echo
  echo "Last status events:"
  tail -8 "$run_dir/timeline.jsonl"
elif [[ -f "$status_jsonl" ]]; then
  echo
  echo "Last status events:"
  tail -8 "$status_jsonl"
fi
