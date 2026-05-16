#!/usr/bin/env bash
set -euo pipefail

review_file="${1:-}"
[[ -n "$review_file" && -f "$review_file" ]] || { echo "Usage: $0 <review-file>" >&2; exit 2; }

source ./scripts/search-utils.sh
echo "[review-gate] Search engine: $(search_engine)"

if search_file "(^|[^A-Za-z])(High|Medium|高|中)(:|：)|\\*\\*(High|Medium|高|中)" "$review_file" > "${review_file%.md}.blockers"; then
  echo "[review-gate] Blocking review findings detected in $review_file" >&2
  cat "${review_file%.md}.blockers" >&2
  exit 1
fi

echo "[review-gate] No blocking review findings"
