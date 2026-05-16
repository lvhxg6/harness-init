# 修复轻量检查失败

你是 Codex，正在修复 Harness 的轻量工作区检查失败。输出必须使用中文。

Feature: `{{FEATURE}}`
Attempt: `{{ATTEMPT}}`
Failure log: `.harness/runs/{{FEATURE}}/light-check.log`
Workspace: `{{WORKSPACE}}`

请阅读：

- `AGENTS.md`
- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在
- `.harness/runs/{{FEATURE}}/light-check.log`

任务：

1. 根据 `light-check.log` 定位 JSON、Shell 或 JavaScript 语法/结构问题。
2. 只修复 `{{WORKSPACE}}/` 下的业务代码、测试或 fixtures。
3. 不要修改 `.harness/`、`scripts/`、`AGENTS.md` 和全局架构规则文件。
4. 禁止安装依赖、联网、启动服务或运行依赖完整安装的验证命令。
5. 禁止运行：`npm install`、`npm ci`、`pnpm install`、`yarn install`、`mvn dependency:*`、`npm run build`、`npm run test`、`npm test`、`npm run typecheck`、`npm run lint`、`npx playwright install`、`npm run dev`、`./scripts/start-test-env.sh`，以及任何长驻监听端口的命令。
6. 允许运行的轻量检查仅限：读取文件、搜索文件、解析 JSON/YAML、`node --check` 检查已有 `.js/.mjs/.cjs` 文件、`bash -n` 检查 shell 脚本。

最终输出必须包含：失败原因、修改内容、运行过的轻量命令、剩余风险。
