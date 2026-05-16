#!/usr/bin/env bash
set -euo pipefail

workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"

install_if_needed() {
  local dir="$1"
  local hash_file package_hash
  [[ -f "${dir}/package.json" ]] || return 0

  hash_file="${dir}/node_modules/.harness-install-hash"
  package_hash="$({
    shasum -a 256 "${dir}/package.json"
    if [[ -f "${dir}/package-lock.json" ]]; then
      shasum -a 256 "${dir}/package-lock.json"
    fi
  } | shasum -a 256 | awk '{print $1}')"

  if [[ -d "${dir}/node_modules" && -f "$hash_file" && "$(cat "$hash_file")" == "$package_hash" ]]; then
    echo "[deps] SKIP: ${dir}/node_modules is current"
    return 0
  fi

  echo "[deps] Installing npm dependencies in ${dir}"
  echo "[deps] npm registry: $(npm config get registry 2>/dev/null || printf 'unknown')"
  npm --prefix "$dir" install
  mkdir -p "${dir}/node_modules"
  printf '%s\n' "$package_hash" > "$hash_file"
}

install_if_needed "${workspace_dir}/backend"
install_if_needed "${workspace_dir}/frontend"
