#!/usr/bin/env bash
set -euo pipefail

feature="${FEATURE:-${1:-manual}}"
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
run_dir=".harness/runs/${feature}"
log_file="${run_dir}/preflight.log"
mkdir -p "$run_dir" "$workspace_dir"

failures=0

log() {
  echo "$*" | tee -a "$log_file"
}

require_command() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    log "[preflight] OK command: $cmd"
  else
    log "[preflight] MISSING command: $cmd"
    failures=1
  fi
}

: > "$log_file"
log "[preflight] Feature: $feature"
log "[preflight] Workspace: $workspace_dir"

for cmd in bash sed awk find xargs shasum curl file node npm npx codex; do
  require_command "$cmd"
done

if command -v rg >/dev/null 2>&1; then
  log "[preflight] OK command: rg"
else
  log "[preflight] rg not found; grep fallback will be used"
  require_command grep
fi

required_paths=(
  "AGENTS.md"
  "Makefile"
  "docs/product/${feature}.md"
  ".harness/run-feature.sh"
  ".harness/stop-feature.sh"
  ".harness/prompts/implement-task.md"
  ".harness/prompts/recover-task.md"
  ".harness/prompts/fix-light-check.md"
  ".harness/prompts/blocked-report.md"
  "scripts/harness-state.mjs"
  "scripts/harness-tasks.mjs"
  "scripts/harness-light-check.sh"
  "scripts/verify.sh"
)

for path in "${required_paths[@]}"; do
  if [[ -e "$path" ]]; then
    log "[preflight] OK path: $path"
  else
    log "[preflight] MISSING path: $path"
    failures=1
  fi
done

for root_business_dir in backend frontend tests; do
  if [[ -e "$root_business_dir" ]]; then
    log "[preflight] root-level business path is not allowed: $root_business_dir"
    failures=1
  fi
done

find "$workspace_dir" ".harness" "docs" -name ".DS_Store" -type f -print 2>/dev/null | while IFS= read -r junk; do
  log "[preflight] ignoring macOS metadata file: $junk"
done

if [[ "${HARNESS_LIVE:-0}" == "1" || "${HARNESS_LIVE_OPENAI:-0}" == "1" ]]; then
  log "[preflight] Live mode requested; live env will be validated by load-live-env.sh"
fi

if [[ "$failures" == "1" ]]; then
  log "[preflight] FAILED"
  exit 1
fi

log "[preflight] OK"
