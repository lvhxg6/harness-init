#!/usr/bin/env bash
set -euo pipefail

workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"

if [[ ! -d "$workspace_dir" ]]; then
  echo "[light-check] Missing workspace directory: $workspace_dir" >&2
  exit 1
fi

echo "[light-check] Workspace: $workspace_dir"

while IFS= read -r package_json; do
  echo "[light-check] JSON parse: $package_json"
  node -e "JSON.parse(require('node:fs').readFileSync(process.argv[1], 'utf8'))" "$package_json"
done < <(find "$workspace_dir" -type f -name package.json \
  ! -path "*/node_modules/*" \
  ! -path "*/dist/*" \
  ! -path "*/coverage/*" \
  ! -path "*/.cache/*" \
  -print)

while IFS= read -r script_file; do
  echo "[light-check] bash -n: $script_file"
  bash -n "$script_file"
done < <(find "$workspace_dir" -type f -name '*.sh' \
  ! -path "*/node_modules/*" \
  ! -path "*/dist/*" \
  ! -path "*/coverage/*" \
  ! -path "*/.cache/*" \
  -print)

while IFS= read -r js_file; do
  echo "[light-check] node --check: $js_file"
  node --check "$js_file"
done < <(find "$workspace_dir" -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' \) \
  ! -path "*/node_modules/*" \
  ! -path "*/dist/*" \
  ! -path "*/coverage/*" \
  ! -path "*/.cache/*" \
  -print)

./scripts/check-test-contract.sh

echo "[light-check] OK"
