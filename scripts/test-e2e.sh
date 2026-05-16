#!/usr/bin/env bash
set -euo pipefail

strict="${HARNESS_STRICT:-0}"
feature="${FEATURE:-manual}"
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
e2e_dir="${workspace_dir}/tests/e2e"
screenshot_dir=".harness/runs/${feature}/screenshots"
mkdir -p "$screenshot_dir"

if compgen -G "${e2e_dir}/*.spec.ts" > /dev/null; then
  ./scripts/check-e2e-tests-real-browser.sh
  echo "[test-e2e] Running Playwright E2E tests"
  E2E_BASE_URL="${E2E_BASE_URL:-http://127.0.0.1:${FRONTEND_PORT:-5173}}" npx playwright test --project=e2e --reporter=line

  if [[ "$strict" == "1" ]]; then
    ./scripts/check-real-screenshots.sh
  fi
else
  if [[ "$strict" == "1" ]]; then
    echo "[test-e2e] Strict mode requires E2E specs under ${e2e_dir}" >&2
    exit 1
  fi
  echo "[test-e2e] SKIP: no E2E specs found under ${e2e_dir}"
fi
