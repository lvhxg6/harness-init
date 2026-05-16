# 实现任务

你是 Codex，正在 Harness 工作流中实现一个被拆分后的任务。输出必须使用中文。

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
- `docs/architecture/system.md`
- `docs/architecture/testing.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在
- `.harness/runs/{{FEATURE}}/implementation-plan.md`
- `.harness/runs/{{FEATURE}}/tasks.yaml`

任务：

1. 只完成当前 Task ID 对应的工作，不要顺手重构其他任务范围。
2. 所有业务代码、测试和 fixtures 必须写入 `{{WORKSPACE}}/`。
3. 优先只修改 Task Scope 中列出的路径；如果必须修改其他 `{{WORKSPACE}}/` 子路径，需要在最终报告说明原因。
4. 不要修改 `.harness/`、`scripts/`、`AGENTS.md` 和全局架构规则文件。
5. API 测试必须通过 HTTP 调用真实接口，不能直接调用 service/domain 函数冒充接口测试。
6. E2E 必须打开真实页面、执行真实交互，并通过 `page.screenshot()` 保存截图到 `.harness/runs/{{FEATURE}}/screenshots/`。
7. 如果存在第三方 API 参考资料，provider、鉴权、参数和返回解析必须以 `docs/references/{{FEATURE}}/` 为准。
8. 当前 Task 阶段只负责落库和轻量自检。禁止安装依赖、联网、启动服务或运行依赖完整安装的验证命令。
9. 禁止运行：`npm install`、`npm ci`、`pnpm install`、`yarn install`、`mvn dependency:*`、`npm run build`、`npm run test`、`npm test`、`npm run typecheck`、`npm run lint`、`npx playwright install`、`npm run dev`、`./scripts/start-test-env.sh`，以及任何长驻监听端口的命令。
10. 允许运行的轻量检查仅限：读取文件、搜索文件、解析 JSON/YAML、`node --check` 检查已有 `.js/.mjs/.cjs` 文件、`bash -n` 检查 shell 脚本。依赖安装、构建、单元测试、接口测试、E2E 和 live 验证由 Harness 后续统一阶段执行。
11. 在执行过程中维护 `.harness/runs/{{FEATURE}}/progress.json`，格式如下：

```json
{
  "feature": "{{FEATURE}}",
  "stage": "task",
  "task_id": "{{TASK_ID}}",
  "status": "running",
  "completed_items": [],
  "current_item": "正在处理的事项",
  "next_item": "下一步",
  "last_update": "ISO-8601 时间"
}
```

最终输出必须包含：当前任务完成情况、修改文件、运行过的轻量命令、未运行的依赖/构建/测试说明、剩余风险。
