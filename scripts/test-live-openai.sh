#!/usr/bin/env bash
set -euo pipefail

feature="${FEATURE:-manual}"
workspace_dir="${HARNESS_WORKSPACE_DIR:-workspace}"
run_dir=".harness/runs/${feature}"
mkdir -p "$run_dir"

source ./scripts/load-live-env.sh

live_log="$run_dir/live-openai.log"
live_result="$run_dir/live-openai-result.json"

echo "[live-openai] Running live provider smoke and E2E tests" | tee "$live_log"
trap 'FEATURE="$feature" ./scripts/stop-test-env.sh' EXIT
FEATURE="$feature" HARNESS_STRICT=1 IMAGE_PROVIDER=openai ./scripts/start-test-env.sh | tee -a "$live_log"

node --input-type=module <<'NODE'
import { writeFile } from 'node:fs/promises';

const base = process.env.API_BASE_URL || `http://127.0.0.1:${process.env.PORT || 3001}`;
const feature = process.env.FEATURE || 'manual';
const resultPath = `.harness/runs/${feature}/live-openai-result.json`;
const form = new FormData();
form.append('colors', 'yellow');
form.append('elements', 'scenery');
form.append('aspectRatio', '4:3');
form.append('extraPrompt', '真实手机照片风格，简单烟雾测试');

const response = await fetch(`${base}/api/images/generate`, {
  method: 'POST',
  body: form,
  headers: {
    'X-Forwarded-For': `live-smoke-${Date.now()}`
  }
});

const body = await response.json();
if (!response.ok || body.code !== 0 || !Array.isArray(body.data?.images) || body.data.images.length !== 3) {
  console.error(JSON.stringify(body, null, 2));
  process.exit(1);
}

for (const image of body.data.images) {
  const url = image.url.startsWith('http') ? image.url : `${base}${image.url}`;
  const imageResponse = await fetch(url);
  if (!imageResponse.ok) {
    console.error(`[live-openai] generated image URL is not reachable: ${url}`);
    process.exit(1);
  }
}

await writeFile(resultPath, JSON.stringify({
  code: body.code,
  message: body.message,
  remainingGenerations: body.data.remainingGenerations,
  imageCount: body.data.images.length,
  imageUrls: body.data.images.map((image) => image.url),
  model: process.env.OPENAI_IMAGE_MODEL,
  baseUrl: process.env.OPENAI_IMAGE_BASE_URL,
  apiKey: 'present',
}, null, 2));
console.log('[live-openai] OK: received 3 generated images');
NODE

if [[ -f "${workspace_dir}/tests/api/live-openai.spec.ts" ]]; then
  API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:${PORT:-3001}}" \
  FEATURE="$feature" \
  npx playwright test "${workspace_dir}/tests/api/live-openai.spec.ts" --project=api --reporter=line | tee -a "$live_log"
else
  echo "[live-openai] SKIP: no ${workspace_dir}/tests/api/live-openai.spec.ts" | tee -a "$live_log"
fi

if [[ ! -f "${workspace_dir}/tests/e2e/live-openai.spec.ts" ]]; then
  echo "[live-openai] Missing ${workspace_dir}/tests/e2e/live-openai.spec.ts" | tee -a "$live_log" >&2
  exit 1
fi

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:${PORT:-3001}}" \
E2E_BASE_URL="${E2E_BASE_URL:-http://127.0.0.1:${FRONTEND_PORT:-5173}}" \
FEATURE="$feature" \
npx playwright test "${workspace_dir}/tests/e2e/live-openai.spec.ts" --project=e2e --reporter=line | tee -a "$live_log"

if [[ ! -f "$run_dir/screenshots/live-results.png" ]]; then
  echo "[live-openai] Missing live screenshot: $run_dir/screenshots/live-results.png" | tee -a "$live_log" >&2
  exit 1
fi

echo "[live-openai] Live 验证完成：$live_result" | tee -a "$live_log"
