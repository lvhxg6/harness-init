#!/usr/bin/env bash
set -euo pipefail

strict="${HARNESS_STRICT:-0}"
[[ "$strict" == "1" ]] || exit 0
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
e2e_dir="${workspace_dir}/tests/e2e"
source ./scripts/search-utils.sh
echo "[check-e2e] Search engine: $(search_engine)"

if ! compgen -G "${e2e_dir}/*.spec.ts" > /dev/null; then
  echo "[check-e2e] Strict mode requires E2E specs under ${e2e_dir}" >&2
  exit 1
fi

failed=0
for spec in "${e2e_dir}"/*.spec.ts; do
  if search_file "writeFile\\(|Buffer\\.from\\(|readFile\\(|workspace/frontend/src|workspace/frontend/index\\.html|frontend/src|frontend/index\\.html" "$spec" > /tmp/check-e2e-fake.txt; then
    echo "[check-e2e] $spec appears to synthesize evidence or inspect source instead of driving the browser:" >&2
    cat /tmp/check-e2e-fake.txt >&2
    failed=1
  fi

  if ! quiet_search_file "page\\.goto\\(" "$spec"; then
    echo "[check-e2e] $spec does not navigate with page.goto()" >&2
    failed=1
  fi

  if ! quiet_search_file "page\\.screenshot\\(" "$spec"; then
    echo "[check-e2e] $spec does not capture screenshots with page.screenshot()" >&2
    failed=1
  fi

  if ! quiet_search_file "click\\(|setInputFiles\\(|fill\\(|selectOption\\(" "$spec"; then
    echo "[check-e2e] $spec does not appear to perform real user interactions" >&2
    failed=1
  fi
done

if [[ "$failed" == "1" ]]; then
  exit 1
fi

echo "[check-e2e] Real browser E2E constraints OK"
