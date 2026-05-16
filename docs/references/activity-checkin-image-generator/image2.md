# ZenMux OpenAI Image 协议接入说明：文生图与修图

本文档整理 ZenMux 的 OpenAI Image 协议接入方式，覆盖文生图、基于原图编辑、请求 URL、鉴权方式、参数说明、实测结论和可直接复用的代码示例。

目标是让其他 AI 或工程师读取本文后，可以直接写出可运行的调用程序。

## 1. 接入结论

推荐使用 ZenMux 的 OpenAI Compatible Image API：

```text
Base URL: https://zenmux.ai/api/v1
Model: openai/gpt-image-2
```

已实测通过的能力：

| 能力 | Endpoint | 结果 |
| --- | --- | --- |
| 文生图 | `POST /images/generations` | 成功 |
| 基于原图编辑/修图 | `POST /images/edits` | 成功 |
| 16:9 输出 | `size=1536x864` | 成功，实际输出 1536x864 |
| 9:16 输出 | `size=864x1536` | 成功，实际输出 864x1536 |
| `quality=low` | 低质量/低成本 | 成功 |
| `quality=medium` | 中质量 | 成功 |
| `quality=high` | 高质量 | 成功，但耗时和 token 明显增加 |
| `output_format=png` | PNG 输出 | 成功 |
| `output_format=jpeg` + `output_compression=70` | JPEG 压缩输出 | 成功 |

实测不支持或不建议直接使用：

| 参数 | 实测结果 |
| --- | --- |
| `input_fidelity=low/high` | `openai/gpt-image-2` 返回不支持 |
| `background=transparent` | `openai/gpt-image-2` 返回不支持透明背景 |
| `response_format=url` | 当前 GPT image 模型通常返回 `b64_json`，不要依赖 URL 返回 |

## 2. Key 与鉴权

ZenMux 使用 Bearer Token 鉴权：

```http
Authorization: Bearer $ZENMUX_API_KEY
```

不要把 API Key 硬编码到代码仓库里。建议通过环境变量传入：

```bash
export ZENMUX_API_KEY="你的 ZenMux API Key"
```

代码中读取：

```python
import os

api_key = os.environ["ZENMUX_API_KEY"]
```

如果余额不足，接口会返回类似：

```json
{
  "error": {
    "code": "402",
    "type": "reject_no_credit",
    "message": "Credit required. To prevent abuse, a positive balance is required for this model."
  }
}
```

如果 Key 无权限或无效，接口会返回类似：

```json
{
  "error": {
    "code": "403",
    "type": "access_denied",
    "message": "You have no permission to access this resource"
  }
}
```

## 3. 文生图接口

### 3.1 URL

```text
POST https://zenmux.ai/api/v1/images/generations
```

### 3.2 Header

```http
Content-Type: application/json
Authorization: Bearer $ZENMUX_API_KEY
```

### 3.3 请求体示例

```json
{
  "model": "openai/gpt-image-2",
  "prompt": "A clean product-style image of a small blue ceramic cup on a white desk, soft daylight, realistic.",
  "n": 1,
  "size": "1536x864",
  "quality": "low",
  "output_format": "png"
}
```

### 3.4 最小 curl 示例

```bash
curl https://zenmux.ai/api/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ZENMUX_API_KEY" \
  -d '{
    "model": "openai/gpt-image-2",
    "prompt": "A clean product photo of a blue ceramic cup on a white desk.",
    "n": 1,
    "size": "1536x864",
    "quality": "low",
    "output_format": "png"
  }'
```

返回的图片在：

```json
data[0].b64_json
```

需要把 base64 解码成图片文件。

## 4. 修图/编辑接口

编辑模式用于“原图 + 描述 -> 新图”。例如：上传一张参考图，然后要求模型把它改成 app icon、海报、产品图等。

### 4.1 URL

```text
POST https://zenmux.ai/api/v1/images/edits
```

### 4.2 Header

本地上传图片时使用 multipart：

```http
Content-Type: multipart/form-data
Authorization: Bearer $ZENMUX_API_KEY
```

### 4.3 multipart 请求字段

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `model` | 是 | 建议使用 `openai/gpt-image-2` |
| `prompt` | 是 | 修图说明 |
| `image[]` | 是 | 输入原图，可传一张或多张 |
| `n` | 否 | 生成数量，通常传 `1` |
| `size` | 否 | 输出尺寸 |
| `quality` | 否 | `low` / `medium` / `high` / `auto` |
| `output_format` | 否 | `png` / `jpeg` / `webp` |
| `output_compression` | 否 | 仅 `jpeg` / `webp` 有意义 |

### 4.4 最小 curl 示例

```bash
curl https://zenmux.ai/api/v1/images/edits \
  -H "Authorization: Bearer $ZENMUX_API_KEY" \
  -F "model=openai/gpt-image-2" \
  -F "prompt=Turn this reference image into a polished app icon." \
  -F "image[]=@reference.png" \
  -F "n=1" \
  -F "size=1024x1024" \
  -F "quality=medium" \
  -F "output_format=png"
```

返回的图片同样在：

```json
data[0].b64_json
```

## 5. 参数说明

### 5.1 `model`

推荐：

```text
openai/gpt-image-2
```

说明：

- ZenMux 文档示例中有时写 `gpt-image-2`，但实测 `openai/gpt-image-2` 可用。
- 项目中建议统一使用 `openai/gpt-image-2`，避免和其他供应商模型重名。

### 5.2 `prompt`

文本提示词。文生图时描述要生成的图片；修图时描述基于原图要如何变化。

示例：

```text
A clean product photo of a blue ceramic cup on a white desk, soft daylight, realistic.
```

编辑模式示例：

```text
Turn this reference image into a polished enamel pin while preserving the red circle and blue checkerboard motif.
```

### 5.3 `n`

生成图片数量。

推荐：

```json
"n": 1
```

说明：

- 文档写可在一定范围内生成多张。
- 实际项目建议先用 `1`，减少成本和失败面。

### 5.4 `size`

输出图片尺寸。

实测成功：

```text
1024x1024
1536x864
864x1536
```

文档说明：

- 对 `gpt-image-2`，支持 `WIDTHxHEIGHT` 格式。
- 宽和高都必须能被 16 整除。
- 宽高比必须在 `1:3` 到 `3:1` 之间。
- 高于 `2560x1440` 属于实验能力。
- 最大分辨率文档写到 `3840x2160`，但实际还受模型当前像素和边长限制。

常用尺寸建议：

| 场景 | size |
| --- | --- |
| 方图 | `1024x1024` |
| 横图 16:9 | `1536x864` |
| 竖图 9:16 | `864x1536` |
| 横版更接近官方常见尺寸 | `1536x1024` |
| 竖版更接近官方常见尺寸 | `1024x1536` |

### 5.5 `quality`

图片质量。

可选值：

```text
low
medium
high
auto
```

实测结果：

| quality | 实测情况 | 建议 |
| --- | --- | --- |
| `low` | 成功，速度较快，token 少 | 草稿、预览、低成本批量生成 |
| `medium` | 成功，耗时和 token 增加 | 正式图的默认选择 |
| `high` | 成功，但耗时明显更长 | 只用于最终高质量出图 |
| `auto` | 文档支持，未重点实测 | 不确定成本时不建议默认用 |

实测 token 和耗时参考：

| 参数 | 尺寸 | output image tokens | 耗时 |
| --- | --- | --- | --- |
| `quality=low` | `1536x864` | 120 | 约 24 秒 |
| `quality=medium` | `1024x1024` | 1756 | 约 74 秒 |
| `quality=high` | `1024x1024` | 7024 | 约 200 秒 |

### 5.6 `output_format`

输出格式。

可选值：

```text
png
jpeg
webp
```

建议：

| 场景 | 推荐 |
| --- | --- |
| 需要无损或后续编辑 | `png` |
| 需要小文件、网页展示 | `jpeg` |
| 需要小文件且支持现代浏览器 | `webp` |

实测：

- `png` 成功。
- `jpeg` 成功。
- `webp` 文档支持，本轮未重点实测。

### 5.7 `output_compression`

压缩质量，范围通常是 `0-100`。

仅在：

```text
output_format=jpeg
output_format=webp
```

时有意义。

实测成功：

```json
{
  "output_format": "jpeg",
  "output_compression": 70
}
```

### 5.8 `background`

背景行为。

文档列出的可选值：

```text
transparent
opaque
auto
```

实测结果：

- `background=transparent` 对 `openai/gpt-image-2` 返回不支持。
- 返回错误：`Transparent background is not supported for this model.`

建议：

- 当前不要依赖透明背景。
- 需要透明图时，可以先生成普通图，再用其他抠图/去背景流程处理。

### 5.9 `input_fidelity`

文档在编辑接口中列出：

```text
high
low
```

但实测：

```text
The model 'gpt-image-2' does not support the 'input_fidelity' parameter.
```

建议：

- 当前不要给 `openai/gpt-image-2` 传 `input_fidelity`。
- 如果未来换模型，再单独验证。

### 5.10 `moderation`

内容审核级别。

文档列出：

```text
low
auto
```

本轮未重点实测。一般建议不传，使用默认值。

### 5.11 `stream` 与 `partial_images`

文档说明支持流式生成和部分图片事件：

```json
{
  "stream": true,
  "partial_images": 1
}
```

说明：

- `partial_images` 取值通常为 `0` 到 `3`。
- 适合需要实时预览生成进度的产品。
- 本轮重点验证的是非流式调用，生产接入建议先用非流式，稳定后再做流式。

### 5.12 `user`

代表终端用户的唯一标识，可用于监控和滥用检测。

示例：

```json
{
  "user": "user_12345"
}
```

可选，建议在多用户 SaaS 中传入业务侧用户 ID。

## 6. Python requests 示例

下面示例不依赖 OpenAI SDK，直接通过 HTTP 调用，适合任何后端项目参考。

### 6.1 文生图

```python
import base64
import os
import requests

BASE_URL = "https://zenmux.ai/api/v1"
API_KEY = os.environ["ZENMUX_API_KEY"]
MODEL = "openai/gpt-image-2"

payload = {
    "model": MODEL,
    "prompt": "A clean product photo of a blue ceramic cup on a white desk.",
    "n": 1,
    "size": "1536x864",
    "quality": "low",
    "output_format": "png",
}

resp = requests.post(
    f"{BASE_URL}/images/generations",
    headers={
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    },
    json=payload,
    timeout=300,
)
resp.raise_for_status()

data = resp.json()
image_base64 = data["data"][0]["b64_json"]
image_bytes = base64.b64decode(image_base64)

with open("text_to_image.png", "wb") as f:
    f.write(image_bytes)

print("saved text_to_image.png")
print("usage:", data.get("usage"))
```

### 6.2 修图/编辑

```python
import base64
import os
import requests

BASE_URL = "https://zenmux.ai/api/v1"
API_KEY = os.environ["ZENMUX_API_KEY"]
MODEL = "openai/gpt-image-2"

with open("reference.png", "rb") as image_file:
    resp = requests.post(
        f"{BASE_URL}/images/edits",
        headers={
            "Authorization": f"Bearer {API_KEY}",
        },
        data={
            "model": MODEL,
            "prompt": "Turn this reference image into a polished app icon.",
            "n": "1",
            "size": "1024x1024",
            "quality": "medium",
            "output_format": "png",
        },
        files={
            "image[]": ("reference.png", image_file, "image/png"),
        },
        timeout=300,
    )

resp.raise_for_status()

data = resp.json()
image_base64 = data["data"][0]["b64_json"]
image_bytes = base64.b64decode(image_base64)

with open("edited.png", "wb") as f:
    f.write(image_bytes)

print("saved edited.png")
print("usage:", data.get("usage"))
```

## 7. Python OpenAI SDK 示例

如果项目已经使用 OpenAI SDK，可以这样接入。

安装：

```bash
pip install openai
```

### 7.1 文生图

```python
import base64
import os
from openai import OpenAI

client = OpenAI(
    base_url="https://zenmux.ai/api/v1",
    api_key=os.environ["ZENMUX_API_KEY"],
)

img = client.images.generate(
    model="openai/gpt-image-2",
    prompt="A clean product photo of a blue ceramic cup on a white desk.",
    n=1,
    size="1536x864",
    quality="low",
    output_format="png",
)

image_bytes = base64.b64decode(img.data[0].b64_json)

with open("text_to_image.png", "wb") as f:
    f.write(image_bytes)
```

### 7.2 修图/编辑

```python
import base64
import os
from openai import OpenAI

client = OpenAI(
    base_url="https://zenmux.ai/api/v1",
    api_key=os.environ["ZENMUX_API_KEY"],
)

result = client.images.edit(
    model="openai/gpt-image-2",
    image=[open("reference.png", "rb")],
    prompt="Turn this reference image into a polished app icon.",
    n=1,
    size="1024x1024",
    quality="medium",
    output_format="png",
)

image_bytes = base64.b64decode(result.data[0].b64_json)

with open("edited.png", "wb") as f:
    f.write(image_bytes)
```

注意：不同版本的 OpenAI SDK 对图片参数的类型声明可能不完全一致。如果 SDK 报参数类型错误，优先使用上一节的 `requests` 直连方式。

## 8. Node.js fetch 示例

### 8.1 文生图

```js
import fs from "node:fs/promises";

const BASE_URL = "https://zenmux.ai/api/v1";
const API_KEY = process.env.ZENMUX_API_KEY;
const MODEL = "openai/gpt-image-2";

const resp = await fetch(`${BASE_URL}/images/generations`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${API_KEY}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    model: MODEL,
    prompt: "A clean product photo of a blue ceramic cup on a white desk.",
    n: 1,
    size: "1536x864",
    quality: "low",
    output_format: "png",
  }),
});

if (!resp.ok) {
  throw new Error(await resp.text());
}

const data = await resp.json();
const imageBuffer = Buffer.from(data.data[0].b64_json, "base64");
await fs.writeFile("text_to_image.png", imageBuffer);
```

### 8.2 修图/编辑

Node 18+ 的 `fetch` 支持 `FormData`。文件上传可用 `Blob`：

```js
import fs from "node:fs/promises";

const BASE_URL = "https://zenmux.ai/api/v1";
const API_KEY = process.env.ZENMUX_API_KEY;
const MODEL = "openai/gpt-image-2";

const imageBytes = await fs.readFile("reference.png");
const form = new FormData();

form.append("model", MODEL);
form.append("prompt", "Turn this reference image into a polished app icon.");
form.append("n", "1");
form.append("size", "1024x1024");
form.append("quality", "medium");
form.append("output_format", "png");
form.append("image[]", new Blob([imageBytes], { type: "image/png" }), "reference.png");

const resp = await fetch(`${BASE_URL}/images/edits`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${API_KEY}`,
  },
  body: form,
});

if (!resp.ok) {
  throw new Error(await resp.text());
}

const data = await resp.json();
const imageBuffer = Buffer.from(data.data[0].b64_json, "base64");
await fs.writeFile("edited.png", imageBuffer);
```

## 9. 推荐项目封装方式

建议在项目中封装两个函数：

```text
generateImage(prompt, options)
editImage(referenceImagePath, prompt, options)
```

推荐默认参数：

```json
{
  "model": "openai/gpt-image-2",
  "n": 1,
  "size": "1024x1024",
  "quality": "medium",
  "output_format": "png"
}
```

低成本预览参数：

```json
{
  "size": "1024x1024",
  "quality": "low",
  "output_format": "jpeg",
  "output_compression": 75
}
```

最终高质量出图参数：

```json
{
  "size": "1536x864",
  "quality": "high",
  "output_format": "png"
}
```

## 10. 错误处理建议

调用时至少处理以下状态：

| HTTP 状态 | 常见含义 | 处理方式 |
| --- | --- | --- |
| `200` | 成功 | 解码 `data[0].b64_json` |
| `400` | 参数错误 | 打印 ZenMux 返回的 `error.message`，检查参数是否被模型支持 |
| `402` | 余额不足 | 提醒充值或切换可用 Key |
| `403` | Key 无效或无权限 | 检查 API Key、模型权限、是否过期 |
| `429` | 限流 | 重试、退避、降低并发 |
| `5xx` | 服务端或上游错误 | 退避重试，并记录请求参数 |

错误响应通常类似：

```json
{
  "error": {
    "code": "400",
    "type": "invalid_params",
    "message": "Transparent background is not supported for this model."
  }
}
```

## 11. 本次实测记录

本机已生成参数验证脚本和测试结果：

```text
/Users/liubu/zenmux-image-test/test_zenmux_params.py
/Users/liubu/zenmux-image-test/outputs/params/
```

关键实测输出：

| 文件 | 参数 |
| --- | --- |
| `generate_16_9_low_png.png` | `size=1536x864`, `quality=low`, `output_format=png` |
| `generate_9_16_low_png.png` | `size=864x1536`, `quality=low`, `output_format=png` |
| `generate_medium_jpeg_compression.jpeg` | `size=1024x1024`, `quality=medium`, `output_format=jpeg`, `output_compression=70` |
| `edit_medium_quality_png.png` | 编辑模式，`size=1024x1024`, `quality=medium`, `output_format=png` |
| `generate_high_quality_png.png` | `size=1024x1024`, `quality=high`, `output_format=png` |

## 12. 最小可用参数清单

如果只想快速接入，文生图使用：

```json
{
  "model": "openai/gpt-image-2",
  "prompt": "你的图片描述",
  "n": 1,
  "size": "1024x1024",
  "quality": "medium",
  "output_format": "png"
}
```

修图使用 multipart：

```text
model=openai/gpt-image-2
prompt=你的修图描述
image[]=@reference.png
n=1
size=1024x1024
quality=medium
output_format=png
```

然后从响应中读取：

```text
data[0].b64_json
```

并 base64 解码保存成图片文件。

## 13. 参考文档

- ZenMux OpenAI Image 协议指南：`https://zenmux.ai/docs/zh/guide/advanced/openai-image-generation.html`
- Create image API：`https://zenmux.ai/docs/zh/api/openai/generate-an-image.html`
- Create image edit API：`https://zenmux.ai/docs/zh/api/openai/create-image-edit.html`
