# 修复 Live 验证失败

你是 Codex，正在修复 Harness live 验证失败。输出必须使用中文。

Feature: `{{FEATURE}}`
Attempt: `{{ATTEMPT}}`
Failure log: `.harness/runs/{{FEATURE}}/live-{{ATTEMPT}}.log`
Workspace: `{{WORKSPACE}}`

请阅读：

- `AGENTS.md`
- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/architecture/testing.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在
- `.harness/runs/{{FEATURE}}/live-{{ATTEMPT}}.log`
- `.harness/runs/{{FEATURE}}/live-openai.log`
- `.harness/runs/{{FEATURE}}/live-openai-result.json`
- `.harness/runs/{{FEATURE}}/screenshots/`

任务：

1. 定位 live 验证失败根因。
2. 修复 `{{WORKSPACE}}/` 下的业务实现、provider 集成、配置读取、接口适配、前端展示或 E2E 测试。
3. 不要修改 `.harness/`、`scripts/`、`AGENTS.md` 和全局架构规则文件。
4. 不要把完整 API Key 写入代码、文档、日志或报告；只能使用环境变量。
5. 如果失败来自第三方 API 参数、模型名、Base URL 或返回结构，优先以 `docs/references/{{FEATURE}}/` 中的资料为准。
6. 如果失败来自 Playwright，必须打开真实页面、执行真实交互，并用 `page.screenshot()` 生成真实截图。
7. 运行最窄相关静态检查、单元测试或 build；不要启动长驻 dev server。完整 live verify 由外层 Harness 执行。

中文报告：失败原因、修改内容、运行过的局部命令、剩余风险。
