#!/usr/bin/env bash
set -euo pipefail

strict="${HARNESS_STRICT:-0}"
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
backend_dir="${workspace_dir}/backend"

has_npm_script() {
  local dir="$1"
  local script="$2"
  node -e "const p=require('./${dir}/package.json'); process.exit(p.scripts && p.scripts['${script}'] ? 0 : 1)"
}

if [[ -f "${backend_dir}/package.json" ]]; then
  echo "[test-backend] Running backend Node checks"
  ran=0

  if has_npm_script "$backend_dir" "typecheck"; then
    npm --prefix "$backend_dir" run typecheck
    ran=1
  fi

  if has_npm_script "$backend_dir" "test"; then
    npm --prefix "$backend_dir" test
    ran=1
  fi

  if [[ "$strict" == "1" && "$ran" == "0" ]]; then
    echo "[test-backend] Strict mode requires backend typecheck or test script" >&2
    exit 1
  fi
elif [[ -f "${backend_dir}/pom.xml" ]]; then
  echo "[test-backend] Running backend Maven tests"
  mvn -f "${backend_dir}/pom.xml" test
else
  if [[ "$strict" == "1" ]]; then
    echo "[test-backend] Strict mode requires ${backend_dir}/package.json or ${backend_dir}/pom.xml" >&2
    exit 1
  fi
  echo "[test-backend] SKIP: no backend detected"
fi
