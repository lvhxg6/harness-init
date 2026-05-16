#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
feature="${FEATURE:-manual}"
policy_file=".harness/policies/protected-paths.txt"
manifest=".harness/runs/${feature}/protected-paths.sha256"
current=".harness/runs/${feature}/protected-paths.current.sha256"

usage() {
  echo "Usage: FEATURE=<feature> $0 snapshot|verify" >&2
  exit 2
}

[[ "$mode" == "snapshot" || "$mode" == "verify" ]] || usage
[[ -f "$policy_file" ]] || { echo "[protected-paths] Missing $policy_file" >&2; exit 1; }

mkdir -p "$(dirname "$manifest")"

list_paths() {
  while IFS= read -r pattern; do
    [[ -z "$pattern" || "$pattern" == \#* ]] && continue
    if [[ "${pattern: -3}" == "/**" ]]; then
      dir="${pattern%/**}"
      [[ -d "$dir" ]] && find "$dir" -type f ! -name ".DS_Store"
    else
      [[ -f "$pattern" && "$(basename "$pattern")" != ".DS_Store" ]] && printf '%s\n' "$pattern"
    fi
  done < "$policy_file" | sort -u
}

write_manifest() {
  local output="$1"
  : > "$output"
  while IFS= read -r path; do
    shasum -a 256 "$path" >> "$output"
  done < <(list_paths)
}

if [[ "${HARNESS_MAINTENANCE:-0}" == "1" ]]; then
  echo "[protected-paths] HARNESS_MAINTENANCE=1, skipping protected path check"
  exit 0
fi

case "$mode" in
  snapshot)
    write_manifest "$manifest"
    echo "[protected-paths] Snapshot written to $manifest"
    ;;
  verify)
    [[ -f "$manifest" ]] || { echo "[protected-paths] Missing snapshot $manifest" >&2; exit 1; }
    write_manifest "$current"
    if ! diff -u "$manifest" "$current" > ".harness/runs/${feature}/protected-paths.diff"; then
      echo "[protected-paths] Protected Harness files changed during feature implementation" >&2
      echo "[protected-paths] See .harness/runs/${feature}/protected-paths.diff" >&2
      exit 1
    fi
    echo "[protected-paths] OK"
    ;;
esac
