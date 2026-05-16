# 第三方接口参考资料

当某个功能依赖第三方 API、SDK 或外部平台时，把资料放在：

```text
docs/references/{feature}/
```

推荐文件：

- `overview.md`：接口用途、鉴权方式、Base URL、模型或版本。
- `curl.md`：可执行或接近真实的 curl 示例。
- `request-response.md`：请求字段、响应字段、错误结构。
- `limits.md`：限流、超时、重试、费用或安全约束。

Harness 会在生成架构、验收标准、实施计划、代码实现、review、修复和交付报告时读取该目录。
不要在这里写真实 API Key；Key 只能放在 `.harness/env/.env.live` 或当前 shell 环境变量中。
