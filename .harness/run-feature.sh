#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: ./.harness/run-feature.sh <feature-name> [--live] [--fresh]

Options:
  --live     Run live dependency verification inside the Harness loop.
  --fresh    Remove this feature's run state and workspace before starting.

Environment:
  HARNESS_LIVE=1                         Same as --live.
  HARNESS_WORKSPACE_DIR=workspace        Business implementation root.
  HARNESS_ARCHITECTURE_MODE=...          prompt, require, or generate.
  HARNESS_MAX_REPAIRS=3                  Maximum verification repair rounds.
  HARNESS_MAX_TASK_RECOVERIES=2          Maximum recovery rounds per task.
  HARNESS_SOFT_WARN_SECONDS=300          Progress warning threshold.
  HARNESS_IDLE_WARN_SECONDS=600          Idle warning threshold.
  HARNESS_IDLE_TIMEOUT_SECONDS=1800      Idle timeout per Codex stage.
  HARNESS_WALL_TIMEOUT_SECONDS=7200      Wall-clock timeout per Codex stage.
  HARNESS_WATCH_INTERVAL_SECONDS=30      Watchdog polling interval.
  HARNESS_OUTPUT=compact                 compact or full status output.
USAGE
}

feature=""
live_mode="${HARNESS_LIVE:-0}"
fresh_mode=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live)
      live_mode=1
      shift
      ;;
    --fresh)
      fresh_mode=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$feature" ]]; then
        echo "Unexpected argument: $1" >&2
        usage
        exit 2
      fi
      feature="$1"
      shift
      ;;
  esac
done

if [[ -z "$feature" ]]; then
  usage
  exit 2
fi

model="${CODEX_MODEL:-gpt-5.5}"
max_repairs="${HARNESS_MAX_REPAIRS:-${HARNESS_MAX_ATTEMPTS:-3}}"
max_task_recoveries="${HARNESS_MAX_TASK_RECOVERIES:-2}"
architecture_mode="${HARNESS_ARCHITECTURE_MODE:-prompt}"
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
soft_warn_seconds="${HARNESS_SOFT_WARN_SECONDS:-300}"
idle_warn_seconds="${HARNESS_IDLE_WARN_SECONDS:-600}"
idle_timeout_seconds="${HARNESS_IDLE_TIMEOUT_SECONDS:-1800}"
wall_timeout_seconds="${HARNESS_WALL_TIMEOUT_SECONDS:-7200}"
watch_interval_seconds="${HARNESS_WATCH_INTERVAL_SECONDS:-30}"
output_mode="${HARNESS_OUTPUT:-compact}"
run_dir=".harness/runs/${feature}"
status_jsonl="${run_dir}/timeline.jsonl"
tasks_yaml="${run_dir}/tasks.yaml"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

fresh_start() {
  if [[ "$fresh_mode" != "1" ]]; then
    return
  fi
  rm -rf "$run_dir"
  rm -rf "$workspace_dir"
}

fresh_start
mkdir -p "$run_dir/screenshots" "$run_dir/prompts" "$run_dir/tasks" "$workspace_dir"

init_args=(init --run-dir "$run_dir" --feature "$feature" --workspace "$workspace_dir" --live "$live_mode")
if [[ "$fresh_mode" == "1" ]]; then
  init_args+=(--fresh)
fi
node ./scripts/harness-state.mjs "${init_args[@]}"
if [[ "$fresh_mode" == "1" || ! -f "$status_jsonl" ]]; then
  : > "$status_jsonl"
fi

state_stage() {
  node ./scripts/harness-state.mjs stage \
    --run-dir "$run_dir" \
    --id "$1" \
    --label "$2" \
    --status "$3" \
    --message "${4:-}" \
    --category "${5:-}" \
    --task-id "${6:-}" \
    --epoch "${current_epoch:-0}" \
    --reuse-policy "${7:-}"
}

state_meta() {
  node ./scripts/harness-state.mjs meta --run-dir "$run_dir" "$@"
}

state_event() {
  node ./scripts/harness-state.mjs event \
    --run-dir "$run_dir" \
    --event "$1" \
    --stage "$2" \
    --label "$3" \
    --message "${4:-}" \
    --category "${5:-}"
}

state_progress() {
  node ./scripts/harness-state.mjs progress \
    --run-dir "$run_dir" \
    --feature "$feature" \
    --stage "$1" \
    --task-id "${2:-}" \
    --status "${3:-running}" \
    --current-item "${4:-}" \
    --next-item "${5:-}"
}

render_status() {
  node ./scripts/harness-state.mjs render --run-dir "$run_dir" --print
}

render_status_if_full() {
  if [[ "$output_mode" == "full" ]]; then
    render_status
  fi
}

render_stage_boundary() {
  if [[ "$output_mode" == "compact" ]]; then
    node ./scripts/harness-state.mjs summary --run-dir "$run_dir"
  else
    render_status
  fi
}

stage_done() {
  node ./scripts/harness-state.mjs 'done?' --run-dir "$run_dir" --id "$1" >/dev/null 2>&1
}

state_epoch() {
  node -e "const fs=require('fs'); const s=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); console.log(Number(s.runEpoch || 0));" "${run_dir}/state.json"
}

refresh_epoch() {
  current_epoch="$(state_epoch)"
}

stage_exists() {
  node -e "const fs=require('fs'); const s=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); process.exit((s.stages||[]).some((stage)=>stage.id===process.argv[2]) ? 0 : 1)" "${run_dir}/state.json" "$1" >/dev/null 2>&1
}

state_reconcile() {
  local code
  if node ./scripts/harness-state.mjs reconcile --run-dir "$run_dir"; then
    return 0
  fi
  code="$?"
  if [[ "$code" == "10" ]]; then
    refresh_epoch
    echo "[harness] Reconciled interrupted state; resuming from durable files and checkpoints"
    return 0
  fi
  return "$code"
}

state_resolve_blocked() {
  local reason="$1"
  local code
  if node ./scripts/harness-state.mjs resolve-blocked --run-dir "$run_dir" --reason "$reason"; then
    return 0
  fi
  code="$?"
  if [[ "$code" == "10" ]]; then
    refresh_epoch
    echo "[harness] Cleared previous blocked state after: ${reason}"
    return 0
  fi
  return "$code"
}

blocked_category=""
blocked_reason=""
latest_verify_log=""
latest_live_log=""
current_epoch=0

state_reconcile
refresh_epoch

write_blocked_json() {
  local resume_command="./.harness/run-feature.sh ${feature}"
  local created_at
  created_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  if [[ "$live_mode" == "1" ]]; then
    resume_command="${resume_command} --live"
  fi
  cat > "${run_dir}/blocked.json" <<JSON
{
  "feature": "$(json_escape "$feature")",
  "status": "blocked",
  "active": true,
  "createdAt": "$(json_escape "$created_at")",
  "resolved": false,
  "resolvedAt": "",
  "supersededBy": "",
  "category": "$(json_escape "$blocked_category")",
  "reason": "$(json_escape "$blocked_reason")",
  "run_dir": "$(json_escape "$run_dir")",
  "workspace_dir": "$(json_escape "$workspace_dir")",
  "live_mode": "$(json_escape "$live_mode")",
  "run_epoch": ${current_epoch},
  "max_repairs": ${max_repairs},
  "latest_verify_log": "$(json_escape "$latest_verify_log")",
  "latest_live_log": "$(json_escape "$latest_live_log")",
  "resume_command": "$(json_escape "$resume_command")"
}
JSON
}

archive_existing_blocked_report() {
  local report="${run_dir}/blocked-report.md"
  local archived timestamp
  if [[ ! -f "$report" ]]; then
    return 0
  fi
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  archived="${run_dir}/blocked-report.${timestamp}.md"
  cp "$report" "$archived"
  node ./scripts/harness-state.mjs mark-superseded \
    --run-dir "$run_dir" \
    --path "$report" \
    --reason "archived as ${archived}" \
    --stage "blocked-report"
}

render_prompt() {
  local template="$1"
  local attempt="${2:-}"
  local task_id="${3:-}"
  local task_title="${4:-}"
  local task_type="${5:-}"
  local task_scope="${6:-}"
  local workspace_escaped="${workspace_dir//\//\\/}"
  sed \
    -e "s/{{FEATURE}}/${feature}/g" \
    -e "s/{{ATTEMPT}}/${attempt}/g" \
    -e "s/{{WORKSPACE}}/${workspace_escaped}/g" \
    -e "s/{{TASK_ID}}/${task_id//\//\\/}/g" \
    -e "s/{{TASK_TITLE}}/${task_title//\//\\/}/g" \
    -e "s/{{TASK_TYPE}}/${task_type//\//\\/}/g" \
    -e "s/{{TASK_SCOPE}}/${task_scope//\//\\/}/g" \
    "$template"
}

activity_snapshot() {
  local marker="$1"
  {
    find "$workspace_dir" "docs/architecture" "docs/acceptance" "$run_dir/tasks" \
      -type f \
      -newer "$marker" \
      ! -name ".DS_Store" \
      ! -path "*/node_modules/*" \
      ! -path "*/dist/*" \
      ! -path "*/coverage/*" \
      ! -path "*/.cache/*" \
      -exec stat -f '%m %N' {} + 2>/dev/null || true
    if [[ -f "${run_dir}/progress.json" && "${run_dir}/progress.json" -nt "$marker" ]]; then
      stat -f '%m %N' "${run_dir}/progress.json" 2>/dev/null || true
    fi
  } | sort | shasum -a 256 | awk '{print $1}'
}

activity_count() {
  local marker="$1"
  {
    find "$workspace_dir" "docs/architecture" "docs/acceptance" "$run_dir/tasks" \
      -type f \
      -newer "$marker" \
      ! -name ".DS_Store" \
      ! -path "*/node_modules/*" \
      ! -path "*/dist/*" \
      ! -path "*/coverage/*" \
      ! -path "*/.cache/*" \
      -print 2>/dev/null || true
    if [[ -f "${run_dir}/progress.json" && "${run_dir}/progress.json" -nt "$marker" ]]; then
      printf '%s\n' "${run_dir}/progress.json"
    fi
  } | sort -u | wc -l | tr -d ' '
}

run_codex_stage() {
  local stage_name="$1"
  local label="$2"
  local sandbox="$3"
  local output="$4"
  local template="$5"
  local attempt="${6:-}"
  local task_id="${7:-}"
  local task_title="${8:-}"
  local task_type="${9:-}"
  local task_scope="${10:-}"
  local reuse_policy="${RUN_CODEX_STAGE_REUSE_POLICY:-rerun}"
  local prompt_file="${run_dir}/prompts/${stage_name}.prompt.md"
  local marker="${run_dir}/.${stage_name}.marker"
  local started last_activity now elapsed idle pid code snapshot changed_count

  if [[ "$reuse_policy" == "durable" ]] && stage_done "$stage_name" && [[ -f "$output" ]]; then
    echo "[harness] ${label} already DONE; resume using ${output}"
    render_stage_boundary
    return 0
  fi

  state_stage "$stage_name" "$label" "RUNNING" "output=$output" "" "$task_id" "$reuse_policy"
  state_progress "$stage_name" "$task_id" "running" "starting ${label}" ""
  render_stage_boundary
  render_prompt "$template" "$attempt" "$task_id" "$task_title" "$task_type" "$task_scope" > "$prompt_file"
  touch "$marker"
  started="$(date +%s)"
  last_activity="$started"
  snapshot="$(activity_snapshot "$marker")"

  codex -a never exec --skip-git-repo-check \
    -C . \
    -m "$model" \
    -s "$sandbox" \
    -o "$output" \
    - < "$prompt_file" &
  pid="$!"
  state_meta --currentPid "$pid" --currentPidStage "$stage_name"

  while kill -0 "$pid" 2>/dev/null; do
    sleep "$watch_interval_seconds"
    now="$(date +%s)"
    elapsed=$((now - started))
    local new_snapshot
    new_snapshot="$(activity_snapshot "$marker")"
    if [[ "$new_snapshot" != "$snapshot" ]]; then
      snapshot="$new_snapshot"
      last_activity="$now"
    fi
    idle=$((now - last_activity))
    changed_count="$(activity_count "$marker")"

    if [[ "$elapsed" -ge "$soft_warn_seconds" ]]; then
      echo "[harness] heartbeat stage=${stage_name} label=\"${label}\" running=${elapsed}s idle=${idle}s changed=${changed_count} pid=${pid} output=${output}"
      state_event "warn" "$stage_name" "$label" "running=${elapsed}s idle=${idle}s changed=${changed_count}"
      render_status_if_full
    fi
    if [[ "$idle" -ge "$idle_warn_seconds" ]]; then
      state_event "idle-warn" "$stage_name" "$label" "idle=${idle}s changed=${changed_count}"
    fi
    if [[ "$idle" -ge "$idle_timeout_seconds" ]]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      blocked_category="STAGE_IDLE_TIMEOUT"
      blocked_reason="${label} had no effective progress for ${idle_timeout_seconds}s"
      state_stage "$stage_name" "$label" "FAILED" "$blocked_reason" "$blocked_category" "$task_id" "$reuse_policy"
      state_meta --currentPid "" --currentPidStage ""
      return 124
    fi
    if [[ "$elapsed" -ge "$wall_timeout_seconds" ]]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      blocked_category="STAGE_WALL_TIMEOUT"
      blocked_reason="${label} exceeded wall timeout ${wall_timeout_seconds}s"
      state_stage "$stage_name" "$label" "FAILED" "$blocked_reason" "$blocked_category" "$task_id" "$reuse_policy"
      state_meta --currentPid "" --currentPidStage ""
      return 124
    fi
  done

  set +e
  wait "$pid"
  code="$?"
  set -e
  if [[ "$code" == "0" ]]; then
    state_stage "$stage_name" "$label" "DONE" "output=$output" "" "$task_id" "$reuse_policy"
    state_progress "$stage_name" "$task_id" "done" "completed ${label}" ""
    state_meta --currentPid "" --currentPidStage ""
    render_stage_boundary
    return 0
  fi
  blocked_category="HARNESS_FAILURE"
  blocked_reason="Codex stage failed with exit code $code"
  state_stage "$stage_name" "$label" "FAILED" "$blocked_reason" "$blocked_category" "$task_id" "$reuse_policy"
  state_meta --currentPid "" --currentPidStage ""
  return "$code"
}

run_codex_stage_reuse() {
  local reuse_policy="$1"
  shift
  RUN_CODEX_STAGE_REUSE_POLICY="$reuse_policy" run_codex_stage "$@"
}

blocked_exit() {
  local category="$1"
  local reason="$2"
  local blocked_stage
  refresh_epoch
  blocked_stage="blocked-e${current_epoch}-$(date +%s)"
  blocked_category="$category"
  blocked_reason="$reason"
  state_progress "$blocked_stage" "" "blocked" "blocked: ${category}" "$reason"
  state_meta --status "blocked" --blockedCategory "$category" --blockedReason "$reason"
  state_stage "$blocked_stage" "blocked" "BLOCKED" "$reason" "$category" "" "ephemeral"
  write_blocked_json
  archive_existing_blocked_report
  run_codex_stage_reuse "ephemeral" "blocked-report-e${current_epoch}" "blocked report" "read-only" "${run_dir}/blocked-report.md" ".harness/prompts/blocked-report.md" || true
  state_meta --status "blocked" --currentStage "$blocked_stage" --blockedCategory "$category" --blockedReason "$reason" --currentPid "" --currentPidStage ""
  write_blocked_json
  render_stage_boundary
  echo "[harness] Blocked: ${category}: ${reason}. See ${run_dir}" >&2
  exit 1
}

classify_failure() {
  local log_file="$1"
  local result category retryable reason
  result="$(./scripts/classify-verification-failure.sh "$log_file")"
  category="$(printf '%s' "$result" | sed -n 's/.*"category":"\([^"]*\)".*/\1/p')"
  retryable="$(printf '%s' "$result" | sed -n 's/.*"retryable":\([^,}]*\).*/\1/p')"
  reason="$(printf '%s' "$result" | sed -n 's/.*"reason":"\([^"]*\)".*/\1/p')"
  printf '%s|%s|%s\n' "${category:-VERIFY_FAILURE}" "${retryable:-true}" "${reason:-verification failed}"
}

run_delivery_stage() {
  local delivery_stage delivery_json delivery_md
  refresh_epoch
  delivery_stage="delivery-e${current_epoch}"
  delivery_json="${run_dir}/delivery.json"
  delivery_md="${run_dir}/delivery.md"

  run_codex_stage_reuse "ephemeral" "$delivery_stage" "delivery report json" "read-only" "$delivery_json" ".harness/prompts/delivery-report.md" || return 1
  if ! node ./scripts/validate-delivery-report.mjs "$delivery_json" ".harness/schemas/delivery-report.schema.json"; then
    blocked_category="HARNESS_FAILURE"
    blocked_reason="delivery report JSON failed schema validation: ${delivery_json}"
    state_stage "$delivery_stage" "delivery report json" "FAILED" "$blocked_reason" "$blocked_category" "" "ephemeral"
    return 1
  fi

  run_codex_stage_reuse "ephemeral" "${delivery_stage}-md" "delivery report markdown" "read-only" "$delivery_md" ".harness/prompts/delivery-markdown.md"
}

review_blocker_category() {
  local blockers_file="$1"
  if grep -Eiq '(^|[^[:alnum:]_-])(category|Category|分类)[[:space:]:=：]+(environment|环境)([^[:alnum:]_-]|$)' "$blockers_file"; then
    printf 'ENVIRONMENT_FAILURE\n'
  elif grep -Eiq '(^|[^[:alnum:]_-])(category|Category|分类)[[:space:]:=：]+(human-input|needs-human|人工|用户)([^[:alnum:]_-]|$)' "$blockers_file"; then
    printf 'NEEDS_HUMAN_INPUT\n'
  elif grep -Eiq '(^|[^[:alnum:]_-])(category|Category|分类)[[:space:]:=：]+(harness)([^[:alnum:]_-]|$)' "$blockers_file"; then
    printf 'HARNESS_FAILURE\n'
  elif grep -Eiq '(^|[^[:alnum:]_-])(category|Category|分类)[[:space:]:=：]+(live-only)([^[:alnum:]_-]|$)|Live Pending|Blocks live[[:space:]:=：]+yes' "$blockers_file"; then
    printf 'LIVE_PROVIDER_FAILURE\n'
  else
    printf 'REVIEW_BLOCKER\n'
  fi
}

review_blockers_repairable() {
  local blockers_file="$1"
  if grep -Eiq '(^|[^[:alnum:]_-])(category|Category|分类)[[:space:]:=：]+(environment|human-input|needs-human|harness|live-only|环境|人工|用户)([^[:alnum:]_-]|$)|Live Pending' "$blockers_file"; then
    return 1
  fi
  return 0
}

run_review_gate_stage() {
  review_stage="review-${attempt_key}"
  review_file="${run_dir}/review-${attempt_key}.md"
  state_progress "$review_stage" "" "running" "running review gate attempt ${verify_attempt}" ""
  run_codex_stage_reuse "ephemeral" "$review_stage" "review gate" "read-only" "$review_file" ".harness/prompts/review-feature.md" || blocked_exit "$blocked_category" "$blocked_reason"
  cp "$review_file" "${run_dir}/review.md"

  review_gate_log="${run_dir}/review-gate-${attempt_key}.log"
  review_pending_file="${review_file%.md}.pending"
  review_blockers_file="${review_file%.md}.blockers"
  if FEATURE="$feature" HARNESS_WORKSPACE_DIR="$workspace_dir" HARNESS_LIVE="$live_mode" ./scripts/check-review-blockers.sh "$review_file" > "$review_gate_log" 2>&1; then
    review_message="review=${review_file}"
    if [[ -s "$review_pending_file" ]]; then
      review_message="${review_message}; pending=${review_pending_file}"
    fi
    state_stage "$review_stage" "review gate" "DONE" "$review_message" "" "" "ephemeral"
    state_progress "$review_stage" "" "done" "review gate passed" ""
    return 0
  fi

  gate_category="$(review_blocker_category "$review_blockers_file")"
  if ! review_blockers_repairable "$review_blockers_file"; then
    blocked_exit "$gate_category" "review gate found non-workspace blocker; see ${review_blockers_file}"
  fi
  if [[ "$repair_count" -ge "$max_repairs" ]]; then
    blocked_exit "REVIEW_BLOCKER" "review gate failed after ${repair_count} repairs"
  fi
  repair_count=$((repair_count + 1))
  run_codex_stage_reuse "ephemeral" "repair-review-e${current_epoch}-${repair_count}" "repair review ${repair_count}" "workspace-write" "${run_dir}/repair-review-e${current_epoch}-${repair_count}.md" ".harness/prompts/repair-review-findings.md" "$attempt_key" || blocked_exit "$blocked_category" "$blocked_reason"
  verify_attempt=$((verify_attempt + 1))
  return 1
}

run_live_verify_stage() {
  if [[ "$live_mode" != "1" ]]; then
    state_stage "live-verify-e${current_epoch}" "live verify" "SKIPPED" "live mode disabled" "" "" "rerun"
    state_progress "live-verify-e${current_epoch}" "" "skipped" "live verify skipped" "live mode disabled"
    return 0
  fi

  latest_live_log="${run_dir}/live-${attempt_key}.log"
  state_meta --latestLiveLog "$latest_live_log"
  state_stage "live-verify-${attempt_key}" "live verify" "RUNNING" "" "" "" "rerun"
  state_progress "live-verify-${attempt_key}" "" "running" "running live verify attempt ${verify_attempt}" ""
  if FEATURE="$feature" HARNESS_WORKSPACE_DIR="$workspace_dir" HARNESS_LIVE_OPENAI=1 IMAGE_PROVIDER=openai make verify-live > "$latest_live_log" 2>&1; then
    state_stage "live-verify-${attempt_key}" "live verify" "DONE" "log=${latest_live_log}" "" "" "rerun"
    state_progress "live-verify-${attempt_key}" "" "done" "live verify passed" ""
    return 0
  fi

  IFS='|' read -r live_category live_retryable live_reason < <(classify_failure "$latest_live_log")
  if [[ "$live_retryable" != "true" ]]; then
    blocked_exit "$live_category" "$live_reason"
  fi
  if [[ "$repair_count" -ge "$max_repairs" ]]; then
    blocked_exit "LIVE_PROVIDER_FAILURE" "live verify failed after ${repair_count} repairs"
  fi
  repair_count=$((repair_count + 1))
  run_codex_stage_reuse "ephemeral" "fix-live-e${current_epoch}-${repair_count}" "fix live ${repair_count}" "workspace-write" "${run_dir}/fix-live-e${current_epoch}-${repair_count}.md" ".harness/prompts/fix-live-verification.md" "$attempt_key" || blocked_exit "$blocked_category" "$blocked_reason"
  verify_attempt=$((verify_attempt + 1))
  return 1
}

ensure_tasks_yaml() {
  if [[ -f "$tasks_yaml" ]]; then
    return 0
  fi
  blocked_exit "HARNESS_FAILURE" "implementation plan did not create ${tasks_yaml}"
}

register_tasks() {
  while IFS='|' read -r task_id task_title task_type task_scope; do
    [[ -n "$task_id" ]] || continue
    if stage_exists "task-${task_id}"; then
      continue
    fi
    state_stage "task-${task_id}" "task ${task_id}: ${task_title}" "PENDING" "scope=${task_scope}" "" "$task_id" "durable"
  done < "${run_dir}/tasks.tsv"
  render_stage_boundary
}

run_light_check_stage() {
  local log_file="${run_dir}/light-check.log"
  state_stage "light-check" "lightweight workspace check" "RUNNING" "log=${log_file}" "" "" "rerun"
  state_progress "light-check" "" "running" "running lightweight workspace check" ""
  render_stage_boundary
  if FEATURE="$feature" HARNESS_WORKSPACE_DIR="$workspace_dir" ./scripts/harness-light-check.sh > "$log_file" 2>&1; then
    state_stage "light-check" "lightweight workspace check" "DONE" "log=${log_file}" "" "" "rerun"
    state_progress "light-check" "" "done" "lightweight workspace check passed" ""
    render_stage_boundary
    return 0
  fi

  IFS='|' read -r blocked_category _ blocked_reason < <(classify_failure "$log_file")
  state_stage "light-check" "lightweight workspace check" "FAILED" "$blocked_reason" "$blocked_category" "" "rerun"
  return 1
}

run_dependency_stage() {
  local log_file="${run_dir}/install-deps.log"
  state_stage "install-deps" "install workspace dependencies" "RUNNING" "log=${log_file}" "" "" "rerun"
  state_progress "install-deps" "" "running" "installing workspace dependencies" ""
  render_stage_boundary
  if FEATURE="$feature" HARNESS_WORKSPACE_DIR="$workspace_dir" ./scripts/install-workspace-deps.sh > "$log_file" 2>&1; then
    state_stage "install-deps" "install workspace dependencies" "DONE" "log=${log_file}" "" "" "rerun"
    state_progress "install-deps" "" "done" "workspace dependencies ready" ""
    render_stage_boundary
    return 0
  fi

  IFS='|' read -r blocked_category _ blocked_reason < <(classify_failure "$log_file")
  state_stage "install-deps" "install workspace dependencies" "FAILED" "$blocked_reason" "$blocked_category" "" "rerun"
  return 1
}

run_light_check_loop() {
  local light_attempt=0

  while true; do
    if run_light_check_stage; then
      return 0
    fi

    if [[ "$blocked_category" == "ENVIRONMENT_FAILURE" || "$blocked_category" == "HARNESS_FAILURE" || "$blocked_category" == "NEEDS_HUMAN_INPUT" ]]; then
      return 1
    fi

    if [[ "$repair_count" -ge "$max_repairs" ]]; then
      blocked_reason="lightweight check failed after ${repair_count} repairs: ${blocked_reason}"
      return 1
    fi

    repair_count=$((repair_count + 1))
    run_codex_stage_reuse "ephemeral" "fix-light-e${current_epoch}-${repair_count}" "fix lightweight check ${repair_count}" "workspace-write" "${run_dir}/fix-light-e${current_epoch}-${repair_count}.md" ".harness/prompts/fix-light-check.md" "$light_attempt" || return 1
    light_attempt=$((light_attempt + 1))
  done
}

run_task_with_recovery() {
  local task_id="$1"
  local task_title="$2"
  local task_type="$3"
  local task_scope="$4"
  local recoveries=0
  local stage_name="task-${task_id}"
  local output="${run_dir}/tasks/${task_id}.md"

  if [[ -s "$output" ]]; then
    state_stage "$stage_name" "task ${task_id}: ${task_title}" "DONE" "output=$output" "" "$task_id" "durable"
    echo "[harness] task ${task_id} durable output exists; resume using ${output}"
    render_stage_boundary
    return 0
  fi

  while true; do
    if run_codex_stage_reuse "durable" "$stage_name" "task ${task_id}: ${task_title}" "workspace-write" "$output" ".harness/prompts/implement-task.md" "" "$task_id" "$task_title" "$task_type" "$task_scope"; then
      return 0
    fi

    if [[ "$blocked_category" != "STAGE_IDLE_TIMEOUT" && "$blocked_category" != "AGENT_STALLED" && "$blocked_category" != "STAGE_WALL_TIMEOUT" ]]; then
      return 1
    fi

    if [[ "$recoveries" -ge "$max_task_recoveries" ]]; then
      return 1
    fi

    recoveries=$((recoveries + 1))
    run_codex_stage "recover-${task_id}-${recoveries}" "recover task ${task_id} ${recoveries}" "workspace-write" "${run_dir}/tasks/${task_id}.recover-${recoveries}.md" ".harness/prompts/recover-task.md" "" "$task_id" "$task_title" "$task_type" "$task_scope" || return 1
    state_stage "$stage_name" "task ${task_id}: ${task_title}" "DONE" "recovered by recover-${task_id}-${recoveries}" "" "$task_id" "durable"
    return 0
  done
}

echo "[harness] Feature: ${feature}"
echo "[harness] Model: ${model}"
echo "[harness] Run dir: ${run_dir}"
echo "[harness] Workspace dir: ${workspace_dir}"
echo "[harness] Live mode: ${live_mode}"
echo "[harness] Resume: $([[ "$fresh_mode" == "1" ]] && printf 'fresh' || printf 'enabled')"
echo "[harness] Max repairs: ${max_repairs}; max task recoveries: ${max_task_recoveries}"
echo "[harness] Output mode: ${output_mode}"

state_stage "preflight" "preflight" "RUNNING" "" "" "" "rerun"
if FEATURE="$feature" HARNESS_WORKSPACE_DIR="$workspace_dir" HARNESS_LIVE="$live_mode" ./scripts/harness-preflight.sh > "${run_dir}/preflight.log" 2>&1; then
  state_resolve_blocked "preflight passed"
  refresh_epoch
  state_stage "preflight" "preflight" "DONE" "log=${run_dir}/preflight.log" "" "" "rerun"
else
  cat "${run_dir}/preflight.log" >&2
  blocked_exit "ENVIRONMENT_FAILURE" "preflight failed"
fi

if [[ "$live_mode" == "1" ]]; then
  state_stage "live-env" "live env" "RUNNING" "" "" "" "rerun"
  if HARNESS_LIVE_OPENAI=1 IMAGE_PROVIDER="${IMAGE_PROVIDER:-openai}" ./scripts/load-live-env.sh > "${run_dir}/live-env.log" 2>&1; then
    cat "${run_dir}/live-env.log"
    state_resolve_blocked "live env validation passed"
    refresh_epoch
    state_stage "live-env" "live env" "DONE" "log=${run_dir}/live-env.log" "" "" "rerun"
  else
    cat "${run_dir}/live-env.log" >&2
    blocked_exit "NEEDS_HUMAN_INPUT" "live env validation failed"
  fi
else
  state_stage "live-env" "live env" "SKIPPED" "live mode disabled" "" "" "rerun"
fi

if [[ ! -f "docs/product/${feature}.md" ]]; then
  blocked_exit "NEEDS_HUMAN_INPUT" "missing PRD docs/product/${feature}.md"
fi

if [[ ! -f "docs/architecture/${feature}.md" ]]; then
  case "$architecture_mode" in
    require)
      blocked_exit "NEEDS_HUMAN_INPUT" "missing required architecture docs/architecture/${feature}.md"
      ;;
    generate|prompt)
      run_codex_stage "generate-architecture" "architecture" "workspace-write" "${run_dir}/generate-architecture.md" ".harness/prompts/generate-architecture.md" || blocked_exit "$blocked_category" "$blocked_reason"
      ;;
    *)
      blocked_exit "HARNESS_FAILURE" "invalid HARNESS_ARCHITECTURE_MODE=${architecture_mode}"
      ;;
  esac
else
  state_stage "architecture" "architecture" "DONE" "using docs/architecture/${feature}.md" "" "" "durable"
fi

[[ -f "docs/architecture/${feature}.md" ]] || blocked_exit "HARNESS_FAILURE" "architecture generation did not create docs/architecture/${feature}.md"

if [[ ! -f "docs/acceptance/${feature}.yaml" ]]; then
  run_codex_stage "generate-acceptance" "acceptance" "workspace-write" "${run_dir}/generate-acceptance.md" ".harness/prompts/generate-acceptance.md" || blocked_exit "$blocked_category" "$blocked_reason"
else
  state_stage "acceptance" "acceptance" "DONE" "using docs/acceptance/${feature}.yaml" "" "" "durable"
fi

[[ -f "docs/acceptance/${feature}.yaml" ]] || blocked_exit "HARNESS_FAILURE" "acceptance generation did not create docs/acceptance/${feature}.yaml"

if [[ -f "$tasks_yaml" ]] && node ./scripts/harness-tasks.mjs "$tasks_yaml" > "${run_dir}/tasks.tsv"; then
  state_stage "implementation-plan" "implementation plan" "DONE" "using existing ${tasks_yaml}" "" "" "durable"
else
  run_codex_stage_reuse "durable" "implementation-plan" "implementation plan" "workspace-write" "${run_dir}/implementation-plan.md" ".harness/prompts/implementation-plan.md" || blocked_exit "$blocked_category" "$blocked_reason"
fi
ensure_tasks_yaml
node ./scripts/harness-tasks.mjs "$tasks_yaml" > "${run_dir}/tasks.tsv" || blocked_exit "HARNESS_FAILURE" "invalid ${tasks_yaml}"
register_tasks

FEATURE="$feature" HARNESS_WORKSPACE_DIR="$workspace_dir" ./scripts/check-protected-paths.sh snapshot

while IFS='|' read -r task_id task_title task_type task_scope; do
  [[ -n "$task_id" ]] || continue
  run_task_with_recovery "$task_id" "$task_title" "$task_type" "$task_scope" || blocked_exit "$blocked_category" "$blocked_reason"
done < "${run_dir}/tasks.tsv"

repair_count=0
run_light_check_loop || blocked_exit "$blocked_category" "$blocked_reason"
run_dependency_stage || blocked_exit "$blocked_category" "$blocked_reason"

verify_attempt=0

while true; do
  refresh_epoch
  attempt_key="e${current_epoch}-${verify_attempt}"
  verify_stage="verify-${attempt_key}"
  state_stage "$verify_stage" "verify attempt ${verify_attempt}" "RUNNING" "" "" "" "rerun"
  state_progress "$verify_stage" "" "running" "running stable verify attempt ${verify_attempt}" ""
  latest_verify_log="${run_dir}/verify-${attempt_key}.log"
  protected_log="${run_dir}/protected-${attempt_key}.log"
  state_meta --latestVerifyLog "$latest_verify_log"
  verify_ok=1

  if ! HARNESS_STRICT=1 FEATURE="$feature" HARNESS_WORKSPACE_DIR="$workspace_dir" ./scripts/check-protected-paths.sh verify > "$protected_log" 2>&1; then
    verify_ok=0
    {
      echo "[verify] Protected Harness files changed."
      echo "See ${protected_log} and ${run_dir}/protected-paths.diff."
    } > "$latest_verify_log"
  elif ! HARNESS_STRICT=1 FEATURE="$feature" HARNESS_WORKSPACE_DIR="$workspace_dir" make verify > "$latest_verify_log" 2>&1; then
    verify_ok=0
  fi

  if [[ "$verify_ok" == "1" ]]; then
    state_stage "$verify_stage" "verify attempt ${verify_attempt}" "DONE" "log=${latest_verify_log}" "" "" "rerun"
    state_progress "$verify_stage" "" "done" "stable verify passed attempt ${verify_attempt}" ""

    if [[ "$live_mode" == "1" ]]; then
      run_live_verify_stage || continue
      run_review_gate_stage || continue
    else
      run_review_gate_stage || continue
      run_live_verify_stage || continue
    fi

    refresh_epoch
    run_delivery_stage || blocked_exit "$blocked_category" "$blocked_reason"
    state_progress "delivery-e${current_epoch}" "" "done" "delivery complete" ""
    state_stage "done-e${current_epoch}" "done" "DONE" "delivery_json=${run_dir}/delivery.json; delivery_md=${run_dir}/delivery.md" "" "" "ephemeral"
    state_meta --status "done" --currentStage "done-e${current_epoch}" --currentPid "" --currentPidStage ""
    render_status
    echo "[harness] Done: ${run_dir}/delivery.json"
    echo "[harness] Delivery report: ${run_dir}/delivery.md"
    exit 0
  fi

  IFS='|' read -r failure_category failure_retryable failure_reason < <(classify_failure "$latest_verify_log")
  state_stage "$verify_stage" "verify attempt ${verify_attempt}" "FAILED" "$failure_reason" "$failure_category" "" "rerun"
  state_progress "$verify_stage" "" "failed" "stable verify failed attempt ${verify_attempt}" "$failure_reason"

  if [[ "$failure_retryable" != "true" ]]; then
    blocked_exit "$failure_category" "$failure_reason"
  fi

  if [[ "$repair_count" -ge "$max_repairs" ]]; then
    blocked_exit "$failure_category" "verify failed after ${repair_count} repairs: ${failure_reason}"
  fi

  repair_count=$((repair_count + 1))
  run_codex_stage_reuse "ephemeral" "fix-e${current_epoch}-${repair_count}" "fix verification ${repair_count}" "workspace-write" "${run_dir}/fix-e${current_epoch}-${repair_count}.md" ".harness/prompts/fix-verification.md" "$attempt_key" || blocked_exit "$blocked_category" "$blocked_reason"
  verify_attempt=$((verify_attempt + 1))
done
