# 生成功能技术架构

你是 Codex，正在为这个仓库的 Harness 工作流准备功能技术架构文档。输出文档默认中文。

Feature: `{{FEATURE}}`
Workspace: `{{WORKSPACE}}`

Input:

- `docs/product/{{FEATURE}}.md`
- `docs/architecture/_feature-template.md`
- `docs/architecture/system.md`
- `docs/architecture/testing.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在；其中是第三方 API 文档、curl 示例、参数说明或错误码参考
- `AGENTS.md`

任务：

Create `docs/architecture/{{FEATURE}}.md`.

This file is the feature-specific technical architecture. It must turn the PRD
into concrete implementation choices, runtime shape, API design, verification
strategy, and environment requirements.

Rules:

- Do not implement code in this step.
- Choose a pragmatic first-version architecture.
- Keep the architecture specific enough that Codex can implement from it.
- Include backend/API test requirements.
- Include Playwright E2E and screenshot requirements.
- Include mock/live dependency strategy when external services are involved.
- State clearly that business implementation files must live under
  `{{WORKSPACE}}/`, for example `{{WORKSPACE}}/backend`,
  `{{WORKSPACE}}/frontend`, and `{{WORKSPACE}}/tests`.
- If third-party references exist under `docs/references/{{FEATURE}}/`, use them
  as the source of truth for API shape, authentication, request parameters, and
  response parsing.
- If the PRD leaves a decision open, make a conservative choice and list it
  under assumptions.

写入文件后，用中文报告主要技术选型和假设。
