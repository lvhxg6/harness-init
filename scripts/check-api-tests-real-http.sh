#!/usr/bin/env bash
set -euo pipefail

strict="${HARNESS_STRICT:-0}"
[[ "$strict" == "1" ]] || exit 0
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
api_dir="${workspace_dir}/tests/api"
source ./scripts/search-utils.sh
echo "[check-api] Search engine: $(search_engine)"

if ! compgen -G "${api_dir}/*.spec.ts" > /dev/null; then
  echo "[check-api] Strict mode requires API specs under ${api_dir}" >&2
  exit 1
fi

failed=0
for spec in "${api_dir}"/*.spec.ts; do
  if search_file "from ['\"].*backend/src|generateImages\\(|new MockImageProvider\\(|new RateLimitStore\\(" "$spec" > /tmp/check-api-imports.txt; then
    echo "[check-api] $spec bypasses the real HTTP API:" >&2
    cat /tmp/check-api-imports.txt >&2
    failed=1
  fi

  if ! quiet_search_file "request\\.(get|post|fetch)|APIRequestContext|baseURL|/api/images/generate" "$spec"; then
    echo "[check-api] $spec does not appear to call the HTTP API" >&2
    failed=1
  fi

  if ! quiet_search_file "multipart|form|FormData|setInputFiles|/api/images/generate" "$spec"; then
    echo "[check-api] $spec does not appear to cover multipart image generation" >&2
    failed=1
  fi
done

if [[ "$failed" == "1" ]]; then
  exit 1
fi

echo "[check-api] Real HTTP API test constraints OK"
