#!/usr/bin/env bash
set -euo pipefail

feature="${FEATURE:-manual}"
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
run_dir=".harness/runs/${feature}"
mkdir -p "$run_dir"

backend_port="${PORT:-3001}"
frontend_port="${FRONTEND_PORT:-5173}"
backend_log="$run_dir/backend.log"
frontend_log="$run_dir/frontend.log"
backend_pid_file="$run_dir/backend.pid"
frontend_pid_file="$run_dir/frontend.pid"

wait_for_url() {
  local url="$1"
  local name="$2"
  local attempts=60

  for _ in $(seq 1 "$attempts"); do
    if curl -sS "$url" >/dev/null 2>&1; then
      echo "[start-test-env] $name is ready at $url"
      return 0
    fi
    sleep 1
  done

  echo "[start-test-env] Timed out waiting for $name at $url" >&2
  return 1
}

stop_existing() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pid_file"
  fi
}

stop_existing "$backend_pid_file"
stop_existing "$frontend_pid_file"

backend_dir="${workspace_dir}/backend"
frontend_dir="${workspace_dir}/frontend"

if [[ -f "${backend_dir}/package.json" ]]; then
  echo "[start-test-env] Starting backend on port $backend_port"
  PORT="$backend_port" IMAGE_PROVIDER="${IMAGE_PROVIDER:-mock}" npm --prefix "$backend_dir" run dev > "$backend_log" 2>&1 &
  echo "$!" > "$backend_pid_file"
  wait_for_url "http://127.0.0.1:${backend_port}/api/health" "backend"
else
  echo "[start-test-env] No ${backend_dir}/package.json; backend not started"
fi

if [[ -f "${frontend_dir}/package.json" ]]; then
  echo "[start-test-env] Building and starting frontend on port $frontend_port"
  npm --prefix "$frontend_dir" run build > "$frontend_log" 2>&1
  FRONTEND_PORT="$frontend_port" npm --prefix "$frontend_dir" run dev >> "$frontend_log" 2>&1 &
  echo "$!" > "$frontend_pid_file"
  wait_for_url "http://127.0.0.1:${frontend_port}/" "frontend"
else
  echo "[start-test-env] No ${frontend_dir}/package.json; frontend not started"
fi

cat > "$run_dir/test-env.md" <<NOTE
Backend URL: http://127.0.0.1:${backend_port}
Frontend URL: http://127.0.0.1:${frontend_port}
Workspace: ${workspace_dir}
Backend log: ${backend_log}
Frontend log: ${frontend_log}
NOTE
