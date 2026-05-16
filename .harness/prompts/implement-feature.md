# 实现功能

你是 Codex，正在这个仓库的 Harness 工作流中实现功能。

Feature: `{{FEATURE}}`
Workspace: `{{WORKSPACE}}`

请阅读：

- `AGENTS.md`
- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/architecture/system.md`
- `docs/architecture/testing.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在；第三方 API 集成必须以这里的资料为准
- `.harness/runs/{{FEATURE}}/implementation-plan.md`

任务：

1. 理解 PRD、acceptance 和技术架构。
2. 实现满足需求的最小范围代码，所有业务代码、测试和 fixtures 必须写入 `{{WORKSPACE}}/`。
3. 添加或更新后端测试、真实 HTTP API 测试和真实 Playwright E2E 测试。
4. E2E 必须打开真实页面、执行真实交互，并通过 `page.screenshot()` 保存截图到 `.harness/runs/{{FEATURE}}/screenshots/`。
5. API 测试必须通过 HTTP 调用真实接口，不能直接调用 service/domain 函数冒充接口测试。
6. 默认使用 mock provider 做稳定自动化验证；如果有 live provider 需求，必须真实实现 provider，并通过环境变量开关真实调用外部服务。
7. 不要修改 `.harness/`、`scripts/`、`AGENTS.md` 和全局架构规则文件；这些文件由 Harness 维护任务负责。
8. 可以运行局部静态检查、单元测试和 build；不要启动长驻 dev server，不要运行 `./scripts/start-test-env.sh`、`npm run dev` 或需要持续监听端口的命令。完整 HTTP/API/E2E 验证由外层 Harness 执行。
9. 如果 `docs/references/{{FEATURE}}/` 存在，必须按其中资料实现第三方 API 的鉴权、请求参数、返回解析和错误处理。
10. 不要创建或使用根目录 `backend/`、`frontend/`、`tests/`；对应目录必须是 `{{WORKSPACE}}/backend`、`{{WORKSPACE}}/frontend`、`{{WORKSPACE}}/tests`。
11. 必须遵守 `docs/architecture/{{FEATURE}}.md` 中的技术栈和运行时选择；如果确实无法遵守，写入 `.harness/runs/{{FEATURE}}/architecture-deviations.md` 并说明原因。

最终输出必须使用中文，包含：修改文件、运行过的局部命令、未解决风险。
