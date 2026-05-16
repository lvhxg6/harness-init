#!/usr/bin/env bash
set -euo pipefail

strict="${HARNESS_STRICT:-0}"
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
frontend_dir="${workspace_dir}/frontend"

has_npm_script() {
  local dir="$1"
  local script="$2"
  node -e "const p=require('./${dir}/package.json'); process.exit(p.scripts && p.scripts['${script}'] ? 0 : 1)"
}

if [[ -f "${frontend_dir}/package.json" ]]; then
  echo "[test-frontend] Running frontend checks"
  ran=0

  if has_npm_script "$frontend_dir" "typecheck"; then
    npm --prefix "$frontend_dir" run typecheck
    ran=1
  fi

  if has_npm_script "$frontend_dir" "lint"; then
    npm --prefix "$frontend_dir" run lint
    ran=1
  fi

  if has_npm_script "$frontend_dir" "build"; then
    npm --prefix "$frontend_dir" run build
    ran=1
  fi

  if [[ "$strict" == "1" && "$ran" == "0" ]]; then
    echo "[test-frontend] Strict mode requires frontend typecheck, lint, or build script" >&2
    exit 1
  fi
else
  if [[ "$strict" == "1" ]]; then
    echo "[test-frontend] Strict mode requires ${frontend_dir}/package.json" >&2
    exit 1
  fi
  echo "[test-frontend] SKIP: no frontend package.json detected"
fi
