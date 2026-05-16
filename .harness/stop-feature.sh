#!/usr/bin/env bash
set -euo pipefail

feature="${1:-${FEATURE:-}}"
if [[ -z "$feature" ]]; then
  echo "Usage: ./.harness/stop-feature.sh <feature-name>" >&2
  exit 2
fi

run_dir=".harness/runs/${feature}"
state_file="${run_dir}/state.json"

if [[ ! -f "$state_file" ]]; then
  echo "[harness] No state file: $state_file" >&2
  exit 1
fi

current_pid="$(node -e "const fs=require('node:fs'); const s=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(String(s.currentPid||''));" "$state_file")"
current_stage="$(node -e "const fs=require('node:fs'); const s=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(String(s.currentPidStage||s.currentStage||'manual-stop'));" "$state_file")"

if [[ -n "$current_pid" ]] && kill -0 "$current_pid" 2>/dev/null; then
  echo "[harness] Stopping feature=${feature} stage=${current_stage} pid=${current_pid}"
  kill "$current_pid" 2>/dev/null || true
else
  echo "[harness] No live child process recorded for feature=${feature}"
fi

node ./scripts/harness-state.mjs stage \
  --run-dir "$run_dir" \
  --id "$current_stage" \
  --label "$current_stage" \
  --status "STOPPED" \
  --message "stopped by user" \
  --category "STOPPED_BY_USER"

node ./scripts/harness-state.mjs meta \
  --run-dir "$run_dir" \
  --status "stopped" \
  --currentPid "" \
  --currentPidStage ""

node ./scripts/harness-state.mjs summary --run-dir "$run_dir"
