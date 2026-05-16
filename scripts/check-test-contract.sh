#!/usr/bin/env bash
set -euo pipefail

workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
backend_dir="${workspace_dir}/backend"
failed=0

fail() {
  echo "[test-contract] $*" >&2
  failed=1
}

has_node_script() {
  local package_json="$1"
  local script="$2"
  node -e "const fs=require('node:fs'); const p=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); process.exit(p.scripts && p.scripts[process.argv[2]] ? 0 : 1)" "$package_json" "$script"
}

has_files() {
  local dir="$1"
  shift
  [[ -d "$dir" ]] || return 1
  find "$dir" "$@" -print -quit | grep -q .
}

has_node_tests() {
  has_files "$backend_dir" \
    -type f \( \
      -name '*.test.ts' -o -name '*.spec.ts' -o \
      -name '*.test.tsx' -o -name '*.spec.tsx' -o \
      -name '*.test.js' -o -name '*.spec.js' -o \
      -name '*.test.jsx' -o -name '*.spec.jsx' -o \
      -name '*.test.mjs' -o -name '*.spec.mjs' -o \
      -name '*.test.cjs' -o -name '*.spec.cjs' \
    \) \
    ! -path '*/node_modules/*' \
    ! -path '*/dist/*' \
    ! -path '*/coverage/*' \
    ! -path '*/.cache/*'
}

has_java_tests() {
  has_files "${backend_dir}/src/test" \
    -type f \( -name '*.java' -o -name '*.kt' -o -name '*.groovy' -o -name '*.scala' \)
}

has_python_tests() {
  has_files "$backend_dir" \
    -type f \( -name 'test_*.py' -o -name '*_test.py' \) \
    ! -path '*/.venv/*' \
    ! -path '*/venv/*' \
    ! -path '*/__pycache__/*'
}

has_go_tests() {
  has_files "$backend_dir" \
    -type f -name '*_test.go' \
    ! -path '*/vendor/*'
}

python_has_pytest_entry() {
  [[ -f "${backend_dir}/pytest.ini" ]] && return 0
  [[ -f "${backend_dir}/tox.ini" ]] && grep -Eq 'pytest|^\[pytest\]' "${backend_dir}/tox.ini" && return 0
  [[ -f "${backend_dir}/setup.cfg" ]] && grep -Eq 'pytest|^\[tool:pytest\]' "${backend_dir}/setup.cfg" && return 0
  [[ -f "${backend_dir}/pyproject.toml" ]] && grep -Eq 'pytest|^\[tool\.pytest' "${backend_dir}/pyproject.toml" && return 0
  return 1
}

go_test_enabled_by_harness() {
  grep -Eq '(^|[[:space:]])go[[:space:]]+test([[:space:]]|$)' scripts/test-backend.sh
}

if [[ ! -d "$workspace_dir" ]]; then
  fail "missing workspace directory: ${workspace_dir}"
fi

if [[ -f "${backend_dir}/package.json" ]] && has_node_script "${backend_dir}/package.json" "test"; then
  echo "[test-contract] Node backend test script detected"
  if ! has_node_tests; then
    fail "backend test script exists but no backend unit test files were found under ${backend_dir}"
  fi
fi

if [[ -f "${backend_dir}/pom.xml" ]]; then
  echo "[test-contract] Maven backend test entry detected"
  if ! has_java_tests; then
    fail "Maven backend test entry exists but no Java test files were found under ${backend_dir}/src/test"
  fi
fi

if [[ -f "${backend_dir}/build.gradle" || -f "${backend_dir}/build.gradle.kts" ]]; then
  echo "[test-contract] Gradle backend test entry detected"
  if ! has_java_tests; then
    fail "Gradle backend test entry exists but no JVM test files were found under ${backend_dir}/src/test"
  fi
fi

if [[ -d "$backend_dir" ]] && python_has_pytest_entry; then
  echo "[test-contract] Python pytest entry detected"
  if ! has_python_tests; then
    fail "pytest entry exists but no Python test files were found under ${backend_dir}"
  fi
fi

if [[ -f "${backend_dir}/go.mod" ]] && go_test_enabled_by_harness; then
  echo "[test-contract] Go backend test entry detected"
  if ! has_go_tests; then
    fail "go test entry exists but no Go test files were found under ${backend_dir}"
  fi
fi

if [[ "$failed" != "0" ]]; then
  exit 1
fi

echo "[test-contract] OK"
