#!/usr/bin/env bash
set -euo pipefail

feature="${FEATURE:-manual}"
run_dir=".harness/runs/${feature}"

stop_pid() {
  local name="$1"
  local pid_file="$2"

  if [[ ! -f "$pid_file" ]]; then
    return 0
  fi

  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "[stop-test-env] Stopping $name pid $pid"
    kill "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$pid_file"
}

stop_pid "backend" "$run_dir/backend.pid"
stop_pid "frontend" "$run_dir/frontend.pid"
