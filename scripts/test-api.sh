#!/usr/bin/env bash
set -euo pipefail

strict="${HARNESS_STRICT:-0}"
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
api_dir="${workspace_dir}/tests/api"

if compgen -G "${api_dir}/*.spec.ts" > /dev/null; then
  ./scripts/check-api-tests-real-http.sh
  echo "[test-api] Running Playwright API tests"
  API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:${PORT:-3001}}" npx playwright test --project=api --reporter=line
else
  if [[ "$strict" == "1" ]]; then
    echo "[test-api] Strict mode requires API specs under ${api_dir}" >&2
    exit 1
  fi
  echo "[test-api] SKIP: no API specs found under ${api_dir}"
fi
