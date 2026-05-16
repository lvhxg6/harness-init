#!/usr/bin/env bash
set -euo pipefail

log_file="${1:-}"
if [[ -z "$log_file" || ! -f "$log_file" ]]; then
  echo '{"category":"HARNESS_FAILURE","retryable":false,"reason":"missing verification log"}'
  exit 0
fi

content="$(cat "$log_file")"
category="VERIFY_FAILURE"
retryable="true"
reason="verification failed"

case "$content" in
  *"STAGE_IDLE_TIMEOUT"*|*"idle timeout"*|*"no effective progress"*)
    category="STAGE_IDLE_TIMEOUT"
    retryable="true"
    reason="stage made no effective progress"
    ;;
  *"STAGE_WALL_TIMEOUT"*|*"wall timeout"*)
    category="STAGE_WALL_TIMEOUT"
    retryable="true"
    reason="stage exceeded wall timeout"
    ;;
  *"AGENT_STALLED"*|*"agent stalled"*)
    category="AGENT_STALLED"
    retryable="true"
    reason="Codex agent stalled"
    ;;
  *"401"*|*"403"*|*"Unauthorized"*|*"invalid_api_key"*|*"insufficient_quota"*|*"model_not_found"*)
    category="LIVE_PROVIDER_FAILURE"
    retryable="false"
    reason="live provider authentication, quota, or model failure"
    ;;
  *"command not found"*|*"Cannot find module"*|*"npx: command not found"*|*"Executable doesn't exist"*|*"browserType.launch"*)
    category="ENVIRONMENT_FAILURE"
    retryable="false"
    reason="environment dependency missing"
    ;;
  *"ENOTFOUND"*|*"EAI_AGAIN"*|*"ECONNRESET"*|*"ECONNREFUSED"*|*"ETIMEDOUT"*|*"network timeout"*|*"getaddrinfo"*|*"registry.npmjs.org"*|*"npm ERR! network"*)
    category="ENVIRONMENT_FAILURE"
    retryable="false"
    reason="dependency registry or network is unreachable"
    ;;
  *"listen EPERM"*|*"EADDRINUSE"*|*"operation not permitted"*)
    category="ENVIRONMENT_FAILURE"
    retryable="false"
    reason="local service could not start"
    ;;
  *"Protected Harness files changed"*|*"protected-paths"*"changed"*)
    category="HARNESS_FAILURE"
    retryable="false"
    reason="protected Harness files changed"
    ;;
  *"scripts/"*"syntax error"*|*"bad substitution"*|*"unbound variable"*)
    category="HARNESS_FAILURE"
    retryable="false"
    reason="Harness script failed"
    ;;
esac

if [[ "$content" == *"rg: command not found"* ]]; then
  category="HARNESS_FAILURE"
  retryable="false"
  reason="Harness search fallback missing for rg"
fi

json_reason="${reason//\\/\\\\}"
json_reason="${json_reason//\"/\\\"}"
printf '{"category":"%s","retryable":%s,"reason":"%s"}\n' "$category" "$retryable" "$json_reason"
