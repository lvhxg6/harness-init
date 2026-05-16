#!/usr/bin/env bash
set -euo pipefail

feature="${FEATURE:-}"
reconcile=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reconcile)
      reconcile=1
      shift
      ;;
    -h|--help)
      echo "Usage: ./scripts/harness-status.sh <feature> [--reconcile]" >&2
      exit 0
      ;;
    *)
      if [[ -n "$feature" ]]; then
        echo "Unexpected argument: $1" >&2
        echo "Usage: ./scripts/harness-status.sh <feature> [--reconcile]" >&2
        exit 2
      fi
      feature="$1"
      shift
      ;;
  esac
done

if [[ -z "$feature" ]]; then
  echo "Usage: ./scripts/harness-status.sh <feature> [--reconcile]" >&2
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
  if [[ "$reconcile" == "1" ]]; then
    node ./scripts/harness-state.mjs reconcile --run-dir "$run_dir" >/dev/null 2>&1 || {
      code="$?"
      if [[ "$code" != "10" ]]; then
        echo "[harness-status] reconcile failed with exit code $code" >&2
      fi
    }
    node ./scripts/harness-state.mjs render --run-dir "$run_dir" >/dev/null 2>&1 || true
  fi

  if [[ -f "$status_md" ]]; then
    cat "$status_md"
  else
    node -e "const fs=require('fs'); const s=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log('# Harness Status'); console.log(); console.log('- Feature: '+(s.feature||'unknown')); console.log('- Status: '+(s.status||'unknown')); console.log('- Current stage: '+(s.currentStage||'none')); console.log('- Current task: '+(s.currentTask||'none')); console.log('- Current PID: '+(s.currentPid||'none')); console.log('- Blocked category: '+(s.blockedCategory||'none')); console.log('- Blocked reason: '+(s.blockedReason||'none'));" "$run_dir/state.json"
  fi
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
