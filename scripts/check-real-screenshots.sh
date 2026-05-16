#!/usr/bin/env bash
set -euo pipefail

strict="${HARNESS_STRICT:-0}"
[[ "$strict" == "1" ]] || exit 0

feature="${FEATURE:-manual}"
screenshot_dir=".harness/runs/${feature}/screenshots"

if [[ ! -d "$screenshot_dir" ]]; then
  echo "[screenshots] Missing screenshot directory: $screenshot_dir" >&2
  exit 1
fi

screenshots=()
while IFS= read -r shot; do
  screenshots+=("$shot")
done < <(find "$screenshot_dir" -type f -name '*.png' | sort)
if [[ "${#screenshots[@]}" -lt 4 ]]; then
  echo "[screenshots] Strict mode requires at least 4 PNG screenshots, found ${#screenshots[@]}" >&2
  exit 1
fi

required=(
  "initial-mobile-page.png"
  "form-filled-selections.png"
  "three-result-images.png"
  "enlarged-preview.png"
)

for name in "${required[@]}"; do
  if [[ ! -f "$screenshot_dir/$name" ]]; then
    echo "[screenshots] Missing required screenshot: $screenshot_dir/$name" >&2
    exit 1
  fi
done

if ! command -v file >/dev/null 2>&1; then
  echo "[screenshots] Missing 'file' command for PNG dimension checks" >&2
  exit 1
fi

tmp_hashes="$(mktemp)"
trap 'rm -f "$tmp_hashes"' EXIT

for shot in "${screenshots[@]}"; do
  size="$(wc -c < "$shot" | tr -d ' ')"
  if [[ "$size" -lt 2000 ]]; then
    echo "[screenshots] Screenshot is too small to be real browser evidence: $shot (${size} bytes)" >&2
    exit 1
  fi

  info="$(file "$shot")"
  if [[ "$info" != *"PNG image data"* ]]; then
    echo "[screenshots] Not a valid PNG: $shot" >&2
    exit 1
  fi

  dims="$(printf '%s\n' "$info" | sed -n 's/.*PNG image data, \([0-9][0-9]*\) x \([0-9][0-9]*\).*/\1 \2/p')"
  if [[ -z "$dims" ]]; then
    echo "[screenshots] Could not read PNG dimensions: $shot" >&2
    exit 1
  fi
  width="${dims%% *}"
  height="${dims##* }"
  if [[ "$width" -lt 320 || "$height" -lt 500 ]]; then
    echo "[screenshots] Screenshot dimensions too small: $shot (${width}x${height})" >&2
    exit 1
  fi

  shasum -a 256 "$shot" | awk '{print $1}' >> "$tmp_hashes"
done

unique_count="$(sort -u "$tmp_hashes" | wc -l | tr -d ' ')"
if [[ "$unique_count" -lt 4 ]]; then
  echo "[screenshots] Too many duplicate screenshots; expected at least 4 unique images" >&2
  exit 1
fi

echo "[screenshots] Real screenshot evidence OK"
