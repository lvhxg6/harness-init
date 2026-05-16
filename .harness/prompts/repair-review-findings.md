# 修复 Review 阻断问题

你是 Codex，正在修复 Harness review gate 发现的阻断问题。

Feature: `{{FEATURE}}`
Attempt: `{{ATTEMPT}}`
Review 文件：`.harness/runs/{{FEATURE}}/review-{{ATTEMPT}}.md`
Workspace: `{{WORKSPACE}}`

请阅读：

- `AGENTS.md`
- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在
- `.harness/runs/{{FEATURE}}/verify-{{ATTEMPT}}.log`
- `.harness/runs/{{FEATURE}}/review-{{ATTEMPT}}.md`
- `.harness/runs/{{FEATURE}}/screenshots/`

任务：

1. 修复 review 中所有 High 和 Medium 问题。
2. 只修复 `{{WORKSPACE}}/` 下的业务代码和业务测试；不要修改 `.harness/`、`scripts/`、`AGENTS.md` 和全局架构规则文件，除非明确处于 Harness 维护任务。
3. 对 E2E 问题，必须使用真实 Playwright 页面操作和 `page.screenshot()`，不能写入占位 PNG。
4. 对 API 问题，必须通过 HTTP 调用真实接口，不能直接调用 service/domain 函数冒充接口测试。
5. 对 OpenAI live provider 问题，必须实现真实 provider；默认验证仍可使用 mock provider。
6. 对第三方 API 适配问题，必须优先以 `docs/references/{{FEATURE}}/` 中的资料为准。
7. 修复后运行最窄相关静态检查、单元测试或 build；不要启动长驻 dev server。完整验证由外层 Harness 执行。

最终输出中文说明：修复了哪些阻断项、修改了哪些文件、仍有哪些风险。
