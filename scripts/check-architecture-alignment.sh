#!/usr/bin/env bash
set -euo pipefail

strict="${HARNESS_ARCHITECTURE_STRICT:-1}"
[[ "$strict" == "1" ]] || { echo "[architecture] SKIP: HARNESS_ARCHITECTURE_STRICT=$strict"; exit 0; }

feature="${FEATURE:-manual}"
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
architecture_file="docs/architecture/${feature}.md"
frontend_pkg="${workspace_dir}/frontend/package.json"
backend_pkg="${workspace_dir}/backend/package.json"
failed=0

[[ -f "$architecture_file" ]] || { echo "[architecture] Missing $architecture_file" >&2; exit 1; }

require_if_mentioned() {
  local keyword="$1"
  local evidence_desc="$2"
  local evidence_cmd="$3"

  if grep -qiE "$keyword" "$architecture_file"; then
    if eval "$evidence_cmd"; then
      echo "[architecture] OK: $evidence_desc"
    else
      echo "[architecture] Missing evidence for architecture keyword '$keyword': $evidence_desc" >&2
      failed=1
    fi
  fi
}

require_if_mentioned "React" "frontend package depends on react" "[[ -f '$frontend_pkg' ]] && grep -qi 'react' '$frontend_pkg'"
require_if_mentioned "Vite" "frontend package uses vite" "[[ -f '$frontend_pkg' ]] && grep -qi 'vite' '$frontend_pkg'"
require_if_mentioned "TypeScript" "workspace has TypeScript config or source" "find '$workspace_dir' \( -path '*/node_modules' -o -path '*/dist' \) -prune -o \( -name tsconfig.json -o -name '*.ts' -o -name '*.tsx' \) -print -quit | grep -q ."
require_if_mentioned "Fastify" "backend package depends on fastify" "[[ -f '$backend_pkg' ]] && grep -qi 'fastify' '$backend_pkg'"

if [[ "$failed" == "1" ]]; then
  echo "[architecture] Alignment failed. Add architecture-deviations.md only if this is an explicit approved deviation." >&2
  exit 1
fi

echo "[architecture] Alignment OK"
