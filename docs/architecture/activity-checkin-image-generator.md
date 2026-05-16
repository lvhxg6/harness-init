# AI 活动打卡图片生成工具技术架构

Feature: `activity-checkin-image-generator`

## 1. 技术目标

本功能交付一个移动端优先的 H5 生图工具：用户可选择上传现场照片或不上传照片，选择颜色、元素、图片比例和补充描述后，由后端统一调用图片生成 provider，一次返回 3 张真实照片风格候选图，并支持放大预览、单张下载和“再来一组”。

验收重点：

- 前端不能直接接触图片生成 API Key。
- 后端必须在调用外部生图接口前完成参数校验和 IP 每日次数限制。
- 后端必须根据是否上传图片选择文生图或图生图。
- 每次成功生成固定返回 3 张图片。
- mock 验证不依赖外部网络，live 验证使用真实 OpenAI-compatible Image API。
- API 测试必须通过真实 HTTP 接口；E2E 必须驱动真实浏览器并保存截图。

所有业务实现文件必须放在 `workspace/` 下：

- 后端：`workspace/backend/`
- 前端：`workspace/frontend/`
- API、E2E、fixtures：`workspace/tests/`

不得在仓库根目录新建 `backend/`、`frontend/` 或 `tests/`。

## 2. 技术选型

### 2.1 前端

- 框架：React + TypeScript + Vite。
- 样式：普通 CSS 或 CSS Modules，移动端优先，不引入重型 UI 框架。
- 运行端口：`FRONTEND_PORT`，默认 `5173`。
- 页面职责：
  - 图片选择和本地预览。
  - 颜色、元素、比例、补充描述输入。
  - 生成按钮 loading 和防重复提交。
  - 3 张结果图展示、点击放大、下载。
  - “再来一组”沿用当前表单重新请求。

### 2.2 后端

- 框架：Node.js + TypeScript + Express。
- 文件上传：`multer` 或等价 multipart 中间件，上传文件仅在请求生命周期和 provider 调用中使用，不做用户历史保存。
- 图片基础校验：校验 MIME、扩展名和文件大小；如需读取原图比例，使用轻量图片尺寸解析库。
- Provider 抽象：
  - `mock` provider：稳定验证默认使用，生成或返回确定性的本地测试图片。
  - `openai` provider：live 验证使用 OpenAI-compatible Image API。
- 运行端口：`PORT`，默认 `3001`。
- 健康检查：`GET /api/health`。

### 2.3 外部服务

第三方参考文档位于 `docs/references/activity-checkin-image-generator/image2.md`，它是外部图片 API 接入的来源事实。

第一版使用 OpenAI-compatible Image API：

- Base URL：live 环境通过 `OPENAI_IMAGE_BASE_URL` 配置。接 ZenMux 时取 `https://zenmux.ai/api/v1`。
- Model：live 环境通过 `OPENAI_IMAGE_MODEL` 配置。接 ZenMux 时取 `openai/gpt-image-2`。
- 鉴权：`Authorization: Bearer $OPENAI_API_KEY`。
- 文生图 endpoint：`POST /images/generations`。
- 图生图 endpoint：`POST /images/edits`。
- 返回解析：读取 `data[*].b64_json`，base64 解码后落成本地图片文件，再通过后端静态 URL 返回给前端。

不使用参考文档中实测不支持的参数：

- 不传 `input_fidelity`。
- 不传 `background=transparent`。
- 不依赖 `response_format=url`。
- 第一版不使用 `stream` 和 `partial_images`。

### 2.4 测试工具

- 后端：TypeScript typecheck + Vitest 单元测试。
- API：Playwright API 测试，调用真实 HTTP 服务。
- 前端：TypeScript typecheck + Vite build。
- E2E：Playwright browser 测试，保存真实页面截图到 `.harness/runs/activity-checkin-image-generator/screenshots/`。
- 总验证入口：`HARNESS_STRICT=1 FEATURE=activity-checkin-image-generator make verify`。
- live 验证入口：`./.harness/run-feature.sh activity-checkin-image-generator --live` 或 `FEATURE=activity-checkin-image-generator make verify-live`。

## 3. 运行时架构

```text
Mobile H5 client
  -> POST /api/images/generate multipart/form-data
  -> Express route validation
  -> IP daily rate limiter
  -> prompt builder + size resolver
  -> image provider interface
       -> mock provider, or
       -> OpenAI-compatible /images/generations or /images/edits
  -> generated image storage
  -> JSON response with 3 image URLs and remaining count
```

关键模块建议：

- `workspace/backend/src/server.ts`：创建 Express app、健康检查、静态图片访问、API route。
- `workspace/backend/src/routes/images.ts`：`POST /api/images/generate`。
- `workspace/backend/src/domain/validation.ts`：颜色、元素、比例、描述长度、上传文件校验。
- `workspace/backend/src/domain/rateLimit.ts`：按 IP + 自然日计数。
- `workspace/backend/src/domain/promptBuilder.ts`：把用户选择转成稳定提示词。
- `workspace/backend/src/domain/size.ts`：把比例映射成外部 API `size`。
- `workspace/backend/src/providers/imageProvider.ts`：provider 接口。
- `workspace/backend/src/providers/mockImageProvider.ts`：mock 生成。
- `workspace/backend/src/providers/openAiImageProvider.ts`：OpenAI-compatible 调用。
- `workspace/frontend/src/`：移动 H5 页面、组件和 API client。
- `workspace/tests/api/`：Playwright API specs。
- `workspace/tests/e2e/`：Playwright browser specs。
- `workspace/tests/fixtures/`：上传图片 fixtures。

## 4. API 设计

### 4.1 健康检查

```http
GET /api/health
```

成功响应：

```json
{
  "code": 0,
  "message": "ok"
}
```

### 4.2 生成图片

```http
POST /api/images/generate
Content-Type: multipart/form-data
```

请求字段：

| 字段 | 必填 | 类型 | 说明 |
| --- | --- | --- | --- |
| `image` | 否 | file | JPG、PNG、WebP；上传则进入图生图模式 |
| `colors` | 是 | string 或 repeated field | `yellow`、`blue`、`pink`，至少 1 个 |
| `elements` | 是 | string 或 repeated field | `person`、`building`、`scenery`，至少 1 个 |
| `extraPrompt` | 否 | string | 最多 200 字 |
| `aspectRatio` | 否 | string | `follow_original`、`1:1`、`4:3`、`3:4`、`16:9`、`9:16` |

`colors` 和 `elements` 的 multipart 解析规则：

- 前端多选时优先使用 repeated fields，例如多个 `colors` 字段。
- API 也兼容单字段逗号分隔值，便于脚本烟测，例如 `colors=yellow,blue`。
- 服务端统一归一化为数组并去重。

成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "remainingGenerations": 9,
    "images": [
      {
        "id": "image-1",
        "url": "/generated-images/image-1.png"
      }
    ]
  }
}
```

成功响应必须返回 3 个 `images` 项。`url` 可以是相对 URL，API 和 E2E 测试按后端 base URL 访问验证。

错误响应统一格式：

```json
{
  "code": "VALIDATION_ERROR",
  "message": "请选择至少一种颜色"
}
```

错误码建议：

- `UNSUPPORTED_IMAGE_TYPE`：图片格式不支持。
- `IMAGE_TOO_LARGE`：图片过大。
- `COLOR_REQUIRED`：未选择颜色。
- `ELEMENT_REQUIRED`：未选择元素。
- `EXTRA_PROMPT_TOO_LONG`：补充描述超过 200 字。
- `INVALID_ASPECT_RATIO`：比例非法。
- `RATE_LIMIT_EXCEEDED`：今日生成次数已用完。
- `PROVIDER_TIMEOUT`：外部生成超时。
- `PROVIDER_CONTENT_BLOCKED`：内容安全拦截。
- `PROVIDER_ERROR`：外部生成失败。

HTTP 状态建议：

- 参数错误：`400`。
- 超限：`429`。
- provider 超时：`504`。
- provider 其他失败：`502`。
- 成功：`200`。

## 5. 生成策略

### 5.1 模式选择

- 有上传图片：调用 `/images/edits`，multipart 字段为 `model`、`prompt`、`image[]`、`n`、`size`、`quality`、`output_format`。
- 无上传图片：调用 `/images/generations`，JSON 字段为 `model`、`prompt`、`n`、`size`、`quality`、`output_format`。

参考文档建议项目中 `n=1` 可降低失败面。因此第一版后端对一次用户生成请求执行 3 次 provider 调用，每次 `n=1`，聚合成 3 张候选图。业务上这仍计为 1 次生成。mock provider 也按同样契约返回 3 张。

### 5.2 尺寸映射

默认输出 `output_format=png`、`quality=medium`。测试和 mock 不依赖真实成本。

比例到 `size` 的映射：

| 选择 | size |
| --- | --- |
| `1:1` | `1024x1024` |
| `4:3` | `1536x1152` |
| `3:4` | `1152x1536` |
| `16:9` | `1536x864` |
| `9:16` | `864x1536` |
| `follow_original` | 根据上传图片宽高比选取最接近的上述尺寸 |

无上传图片且未传 `aspectRatio` 时默认 `4:3`。有上传图片且未传 `aspectRatio` 时默认 `follow_original`。

### 5.3 Prompt 结构

服务端统一构造英文 prompt，避免直接把前端字段裸传给模型。结构包括：

- 场景基调：真实手机照片、自然光、适合跑步活动打卡、非海报、非插画。
- 无上传图片时：明确北京奥林匹克森林公园场景。
- 有上传图片时：尽量保留原图主要场景、构图、光线、透视和真实感。
- 颜色约束：所有选中色彩必须自然出现，可放在衣服、帽子、鞋、背包、运动装备、路牌、花朵等位置，避免突兀大色块。
- 元素约束：所有选中元素必须出现。
- 人物约束：不换脸、不改变身份；原图有人时不新增重复主体人物；原图无人且选择人时可加入自然的跑者、路人或活动参与者。
- 建筑约束：符合现场环境，避免摩天楼、城堡、科幻建筑。
- 风景约束：树木、湖面、步道、草地、天空、自然光线，不把原图改成完全不同地点。
- 负面约束：不要 AI 合成感、卡通、动漫、插画、海报风、水印、乱码文字、拼接痕迹、畸形人物、多余肢体、不合理透视。
- 用户补充描述：追加在受控段落中，最多 200 字。

第一版不做人脸识别或人物检测。关于“原图是否已有真人”的处理通过 prompt 约束实现，不在后端做视觉判断。

## 6. 数据和状态

### 6.1 生成图片存储

- provider 返回 `b64_json` 后，后端解码写入本地运行目录。
- 默认目录：`workspace/backend/.data/generated-images/`。
- 对外访问路径：`/generated-images/{imageId}.png`。
- 文件名使用随机 ID 或时间戳 + 随机后缀，不包含用户输入。
- 第一版不提供历史列表、不提供收藏、不做长期持久化。

### 6.2 上传文件处理

- 最大上传大小第一版设为 10 MB。
- 允许 MIME：`image/jpeg`、`image/png`、`image/webp`。
- 上传文件不返回给其他用户，不写入公开目录。
- provider 调用完成后可删除临时上传文件；测试 fixture 保存在 `workspace/tests/fixtures/`。

### 6.3 IP 限制

- 维度：IP + 自然日。
- 限制：每个 IP 每日最多 10 次生成，每次最多返回 3 张图。
- IP 解析顺序：`X-Forwarded-For` 第一个 IP，其次 `req.ip`。
- 调用 provider 前检查剩余次数，超限直接返回 `429 RATE_LIMIT_EXCEEDED`，不得调用 provider。
- 生成失败是否扣减：
  - 参数校验失败、超限、provider 未发起时不扣减。
  - provider 请求已经发起后，即使超时或外部失败，按 PRD 技术验收视为可扣减。
- 第一版使用进程内 Map 存储计数，服务重启后重置；这是无登录、无数据库第一版的保守实现。

## 7. Mock 和 Live 策略

### 7.1 Stable mock

默认 `IMAGE_PROVIDER=mock`。mock provider 必须：

- 不访问网络。
- 对同一请求返回结构稳定的 3 张图片。
- 生成真实 PNG 文件并返回可访问 URL，不能只返回占位 JSON。
- 图片内容至少能让 E2E 页面展示、放大和下载；可包含简单色块或文字，但测试不得把 mock 内容当成真实 AI 质量验收。

### 7.2 Live OpenAI-compatible

live 使用 `IMAGE_PROVIDER=openai`，并读取：

- `OPENAI_API_KEY`：必填，只能来自 shell 环境或 `.harness/env/.env.live`。
- `OPENAI_IMAGE_BASE_URL`：默认可为官方 OpenAI；接 ZenMux 时设为 `https://zenmux.ai/api/v1`。
- `OPENAI_IMAGE_MODEL`：接 ZenMux 时设为 `openai/gpt-image-2`。

live provider 必须：

- 使用 Bearer Token 鉴权。
- 文生图发送 JSON。
- 图生图发送 multipart，图片字段名使用参考文档中的 `image[]`。
- 超时时间不低于 300 秒，避免高质量生成误判为失败。
- 只在日志和报告中输出 Key 状态为 `present`、`missing` 或 `invalid format`，不得输出 Key 任意片段。

## 8. 验证策略

### 8.1 后端检查

后端应提供 `workspace/backend/package.json`，至少包含：

- `typecheck`：TypeScript 类型检查。
- `test`：Vitest 后端单元测试。
- `dev`：供 Harness 启动 `GET /api/health` 和业务 API。

后端单元测试覆盖：

- 颜色、元素、比例、描述长度校验。
- multipart 字段归一化，包含 repeated field 和逗号分隔。
- prompt builder 包含颜色、元素、真实性和北京奥森约束。
- size resolver 映射和 `follow_original` 兜底。
- IP 限流计数、超限、自然日切换。
- provider 错误映射到业务错误码。

### 8.2 API 测试

API specs 放在 `workspace/tests/api/`，必须调用真实 HTTP 地址 `API_BASE_URL`，不得直接调用 service/domain 函数。

至少覆盖：

- `REQ-GEN-001` 无上传图片，选择颜色/元素/比例后返回 3 张图片 URL。
- `REQ-GEN-002` 上传 JPG/PNG/WebP fixture 后走图生图路径并返回 3 张图片 URL。
- `REQ-GEN-003` 未选颜色返回 `400 COLOR_REQUIRED`。
- `REQ-GEN-004` 未选元素返回 `400 ELEMENT_REQUIRED`。
- `REQ-GEN-005` 补充描述超过 200 字返回 `400 EXTRA_PROMPT_TOO_LONG`。
- `REQ-GEN-006` 不支持的上传格式返回 `400 UNSUPPORTED_IMAGE_TYPE`。
- `REQ-GEN-007` 同一 IP 第 11 次生成返回 `429 RATE_LIMIT_EXCEEDED`，且不调用 provider。
- `REQ-GEN-008` provider 失败时返回明确错误，且响应不包含密钥。
- `REQ-GEN-009` 返回的 3 个图片 URL 都可被 HTTP GET 成功访问。

测试名称必须包含相关 requirement id。

### 8.3 前端检查

前端应提供 `workspace/frontend/package.json`，至少包含：

- `typecheck`
- `build`
- `dev`

前端实现检查重点：

- 移动端宽度下无横向溢出。
- 颜色和元素支持多选。
- 上传图片后展示本地预览。
- 生成中禁用提交按钮，避免重复提交。
- 错误提示适合移动端展示。
- 结果区固定展示 3 张候选图。
- 放大预览和下载控件可访问。

### 8.4 Playwright E2E

E2E specs 放在 `workspace/tests/e2e/`，必须驱动真实浏览器页面并使用 `page.screenshot()`。

至少覆盖：

- `REQ-E2E-001` 初始移动页面加载，截图：`initial-mobile.png`。
- `REQ-E2E-002` 不上传图片，选择黄色、蓝色、风景、建筑、`4:3` 和补充描述，生成 3 张图，截图：`text-to-image-results.png`。
- `REQ-E2E-003` 上传 fixture 图片后出现预览并生成 3 张图，截图：`image-to-image-results.png`。
- `REQ-E2E-004` 点击结果图打开放大预览，截图：`preview-modal.png`。
- `REQ-E2E-005` 下载按钮可见且指向当前图片 URL，截图：`download-control.png`。
- `REQ-E2E-006` 点击“再来一组”重新生成并更新结果。
- `REQ-E2E-007` 模拟超限 IP 后页面显示“今日生成次数已用完”，截图：`rate-limit.png`。

截图目录必须是：

```text
.harness/runs/activity-checkin-image-generator/screenshots/
```

live E2E 还必须提供 `workspace/tests/e2e/live-openai.spec.ts`，并在真实 provider 返回结果后保存：

```text
.harness/runs/activity-checkin-image-generator/screenshots/live-results.png
```

## 9. 环境变量和运行要求

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `PORT` | `3001` | 后端端口 |
| `FRONTEND_PORT` | `5173` | 前端端口 |
| `IMAGE_PROVIDER` | `mock` | `mock` 或 `openai` |
| `OPENAI_API_KEY` | 无 | live provider 必填，只能来自环境变量或 `.harness/env/.env.live` |
| `OPENAI_IMAGE_BASE_URL` | `https://api.openai.com/v1` | OpenAI-compatible base URL；ZenMux 为 `https://zenmux.ai/api/v1` |
| `OPENAI_IMAGE_MODEL` | `gpt-image-2` | ZenMux 推荐 `openai/gpt-image-2` |
| `GENERATED_IMAGE_DIR` | `workspace/backend/.data/generated-images` | 生成图片运行时目录 |
| `MAX_UPLOAD_BYTES` | `10485760` | 默认 10 MB |
| `DAILY_GENERATION_LIMIT` | `10` | IP 每日生成次数 |

密钥处理约束：

- 不得把真实 API Key 写入 PRD、架构文档、acceptance、delivery、日志或前端代码。
- 前端请求只打后端 API，不读取任何 provider Key。
- 后端日志不得打印 Authorization header 或 Key 片段。

## 10. 约束和非目标

第一版不包含：

- 登录、用户中心、支付、收藏、分享、后台管理。
- 长期生成历史记录。
- 复杂手工 mask 编辑。
- 数据库、Redis、队列或分布式限流。
- 对上传图片做真人检测、人脸识别或身份判断。
- 自动评价生成图片是否真的满足全部颜色和元素；第一版通过 prompt 和人工验收约束。
- 透明背景、流式生成、部分图片预览。

## 11. 假设

- PRD 未指定技术栈，第一版选择 Node/TypeScript 全栈以降低 Harness 接入和 Playwright 测试成本。
- PRD 要求每次返回 3 张图；第三方参考建议 `n=1` 更稳，因此后端以 3 次 `n=1` provider 调用聚合为 3 张。
- IP 限制第一版使用进程内 Map；若后续部署多实例或要求跨重启保留计数，需要引入 Redis 或数据库。
- `follow_original` 不直接输出任意原图尺寸，而是映射到最接近的受支持尺寸，确保宽高是 16 的倍数且比例在模型支持范围内。
- 上传图是否已有真人不做算法检测，统一通过 prompt 要求模型保留现有人物并避免新增重复主体人物。
- mock provider 只验证接口、状态和 UI 流程，不验证真实图片质量；真实图片质量由 live 验证和人工验收确认。
