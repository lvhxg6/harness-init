#!/usr/bin/env bash
set -euo pipefail

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/review-blockers.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

failures=0

write_review() {
  local name="$1"
  shift
  cat > "${tmp_dir}/${name}.md"
}

run_case() {
  local name="$1"
  local live="$2"
  local expected_code="$3"
  local expect_blockers="$4"
  local expect_pending="$5"
  local review="${tmp_dir}/${name}.md"
  local blockers="${tmp_dir}/${name}.blockers"
  local pending="${tmp_dir}/${name}.pending"
  local code=0

  HARNESS_LIVE="$live" ./scripts/check-review-blockers.sh "$review" > "${tmp_dir}/${name}.log" 2>&1 || code="$?"

  if [[ "$code" != "$expected_code" ]]; then
    echo "[FAIL] ${name}: expected exit ${expected_code}, got ${code}" >&2
    failures=$((failures + 1))
  fi
  if [[ "$expect_blockers" == "yes" && ! -s "$blockers" ]]; then
    echo "[FAIL] ${name}: expected blockers file to be non-empty" >&2
    failures=$((failures + 1))
  fi
  if [[ "$expect_blockers" == "no" && -s "$blockers" ]]; then
    echo "[FAIL] ${name}: expected blockers file to be empty" >&2
    failures=$((failures + 1))
  fi
  if [[ "$expect_pending" == "yes" && ! -s "$pending" ]]; then
    echo "[FAIL] ${name}: expected pending file to be non-empty" >&2
    failures=$((failures + 1))
  fi
  if [[ "$expect_pending" == "no" && -s "$pending" ]]; then
    echo "[FAIL] ${name}: expected pending file to be empty" >&2
    failures=$((failures + 1))
  fi
}

write_review no_blocking_prose <<'EOF'
**Findings**
No blocking findings.

当前未发现 High、Medium 或 Live Pending 阻断项。
EOF
run_case no_blocking_prose 1 0 no no

write_review live_pending <<'EOF'
Findings:

No blocking findings.

- Severity: Live Pending
  Category: live-only
  Blocks stable: no
  Blocks live: yes
  Summary: 缺少 live-results.png，只阻断 live 交付。
EOF
run_case live_pending 0 0 no yes
run_case live_pending 1 1 yes no

write_review high_workspace <<'EOF'
Findings:

- Severity: High
  Category: workspace-fixable
  Blocks stable: yes
  Blocks live: yes
  Summary: API 测试没有真实走 HTTP。
EOF
run_case high_workspace 0 1 yes no

if [[ -f ".harness/runs/activity-checkin-image-generator/review-e2-0.md" ]]; then
  cp ".harness/runs/activity-checkin-image-generator/review-e2-0.md" "${tmp_dir}/real-review-e2.md"
  run_case real-review-e2 1 0 no no
fi

if [[ -f ".harness/runs/activity-checkin-image-generator/review-e1-0.md" ]]; then
  cp ".harness/runs/activity-checkin-image-generator/review-e1-0.md" "${tmp_dir}/real-review-e1.md"
  run_case real-review-e1 1 1 yes no
fi

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "[test-review-blockers] OK"
