# 恢复停滞任务

你是 Codex，正在恢复一个 Harness 任务。上一个 Codex 子进程在该任务中长时间没有有效进展，Harness 已保留当前半成品。

Feature: `{{FEATURE}}`
Workspace: `{{WORKSPACE}}`
Task ID: `{{TASK_ID}}`
Task Title: `{{TASK_TITLE}}`
Task Type: `{{TASK_TYPE}}`
Task Scope: `{{TASK_SCOPE}}`

请阅读：

- `AGENTS.md`
- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在
- `.harness/runs/{{FEATURE}}/implementation-plan.md`
- `.harness/runs/{{FEATURE}}/tasks.yaml`
- `.harness/runs/{{FEATURE}}/progress.json`
- `.harness/runs/{{FEATURE}}/tasks/` 下当前任务相关输出，如果存在

任务：

1. 判断当前任务已经完成了什么，还缺什么。
2. 在不推翻已有正确实现的前提下继续完成当前任务。
3. 只修改 `{{WORKSPACE}}/` 下与 Task Scope 相关的业务文件、测试和 fixtures。
4. 不要修改 `.harness/`、`scripts/`、`AGENTS.md` 和全局架构规则文件。
5. 继续维护 `.harness/runs/{{FEATURE}}/progress.json`。
6. 当前恢复阶段只负责继续落库和轻量自检。禁止安装依赖、联网、启动服务或运行依赖完整安装的验证命令。
7. 禁止运行：`npm install`、`npm ci`、`pnpm install`、`yarn install`、`mvn dependency:*`、`npm run build`、`npm run test`、`npm test`、`npm run typecheck`、`npm run lint`、`npx playwright install`、`npm run dev`、`./scripts/start-test-env.sh`，以及任何长驻监听端口的命令。
8. 允许运行的轻量检查仅限：读取文件、搜索文件、解析 JSON/YAML、`node --check` 检查已有 `.js/.mjs/.cjs` 文件、`bash -n` 检查 shell 脚本。依赖安装、构建、单元测试、接口测试、E2E 和 live 验证由 Harness 后续统一阶段执行。

最终输出必须包含：恢复判断、补充修改、运行过的轻量命令、未运行的依赖/构建/测试说明、剩余风险。
