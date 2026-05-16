#!/usr/bin/env bash
set -euo pipefail

env_file=".harness/env/.env.live"

load_env_file() {
  local file="$1"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == *"="* ]] || continue

    local key="${line%%=*}"
    local value="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"

    case "$key" in
      HARNESS_LIVE_OPENAI|IMAGE_PROVIDER|OPENAI_API_KEY|OPENAI_IMAGE_MODEL|OPENAI_IMAGE_BASE_URL|PORT|FRONTEND_PORT|API_BASE_URL|E2E_BASE_URL)
        if [[ -z "${!key:-}" ]]; then
          export "$key=$value"
        fi
        ;;
    esac
  done < "$file"
}

if [[ -f "$env_file" ]]; then
  load_env_file "$env_file"
else
  echo "[live-env] 未找到 ${env_file}；将仅使用当前 shell 环境变量"
fi

export HARNESS_LIVE_OPENAI="${HARNESS_LIVE_OPENAI:-0}"
export IMAGE_PROVIDER="${IMAGE_PROVIDER:-openai}"

if [[ -z "${OPENAI_IMAGE_BASE_URL:-}" ]]; then
  export OPENAI_IMAGE_BASE_URL="https://api.openai.com/v1"
  openai_image_base_url_status="default"
else
  openai_image_base_url_status="present"
fi

if [[ -z "${OPENAI_IMAGE_MODEL:-}" ]]; then
  export OPENAI_IMAGE_MODEL="gpt-image-2"
  openai_image_model_status="default"
else
  openai_image_model_status="present"
fi

if [[ "$HARNESS_LIVE_OPENAI" != "1" ]]; then
  echo "[live-env] HARNESS_LIVE_OPENAI 不是 1，live 验证不会执行真实生图" >&2
  exit 2
fi

if [[ "$IMAGE_PROVIDER" != "openai" ]]; then
  echo "[live-env] IMAGE_PROVIDER 必须为 openai，当前为 $IMAGE_PROVIDER" >&2
  exit 2
fi

if [[ -z "${OPENAI_API_KEY:-}" || "$OPENAI_API_KEY" == "replace-with-your-key" ]]; then
  cat >&2 <<'MSG'
[live-env] 缺少 OPENAI_API_KEY。
请复制 `.harness/env/.env.live.example` 为 `.harness/env/.env.live`，填入真实 Key；
或通过命令行环境变量传入 OPENAI_API_KEY。
MSG
  exit 2
fi

echo "[live-env] Live 配置已加载："
echo "[live-env] IMAGE_PROVIDER=$IMAGE_PROVIDER"
echo "[live-env] OPENAI_IMAGE_MODEL=$openai_image_model_status"
echo "[live-env] OPENAI_IMAGE_BASE_URL=$openai_image_base_url_status"
echo "[live-env] OPENAI_API_KEY=present"
