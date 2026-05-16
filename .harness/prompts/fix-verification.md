# 修复验证失败

你是 Codex，正在修复 Harness 验证失败。

Feature: `{{FEATURE}}`
Attempt: `{{ATTEMPT}}`
Failure log: `.harness/runs/{{FEATURE}}/verify-{{ATTEMPT}}.log`
Workspace: `{{WORKSPACE}}`

请阅读：

- `AGENTS.md`
- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在
- `.harness/runs/{{FEATURE}}/verify-{{ATTEMPT}}.log`
- `.harness/runs/{{FEATURE}}/protected-{{ATTEMPT}}.log`
- `.harness/runs/{{FEATURE}}/protected-paths.diff`
- `.harness/runs/{{FEATURE}}/screenshots/`

任务：

1. 定位失败根因。
2. 修复 `{{WORKSPACE}}/` 下的业务实现或测试，不要修改 `.harness/`、`scripts/`、`AGENTS.md` 和全局架构规则文件。
   如果失败原因是 protected paths 被修改，需要把这些文件恢复到 Harness 既定规则，而不是继续修改验证框架。
3. 如果失败来自 API 测试，必须保证测试走真实 HTTP API。
4. 如果失败来自 E2E 或截图，必须保证 Playwright 打开真实页面并用 `page.screenshot()` 截图。
5. 如果失败来自第三方 API 适配，但当前是 mock 验证，仍要保证 live provider 的真实调用代码不退化为 stub。
6. 禁止安装依赖、联网安装浏览器或启动长驻 dev server。不要运行 `npm install`、`npm ci`、`pnpm install`、`yarn install`、`npx playwright install`、`./scripts/start-test-env.sh`、`npm run dev` 或需要持续监听端口的命令。
7. 如果依赖已由 Harness 安装完成，可以运行最窄相关的静态检查、单元测试和 build；完整 verify 由外层 Harness 执行。
8. 中文报告：失败原因、修改内容、运行过的命令、剩余风险。
