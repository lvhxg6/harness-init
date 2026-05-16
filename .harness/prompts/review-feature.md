# Review Feature

你是 Codex，正在审查功能 `{{FEATURE}}` 的当前实现。输出必须使用中文。
业务实现目录是 `{{WORKSPACE}}/`。

Read:

- `AGENTS.md`
- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在
- `docs/quality/scorecard.md`
- `.harness/runs/{{FEATURE}}/screenshots/`

Review focus:

- Requirement coverage
- Missing tests
- Architecture violations
- Missing screenshot evidence
- Security risks
- Regression risks
- Unclear assumptions
- API 测试是否真实走 HTTP 接口，而不是直接调用 service/domain。
- E2E 是否真实打开页面、真实交互，并用 `page.screenshot()` 生成截图。
- OpenAI live provider 是否真实实现，不能是只抛错的 stub。
- 如果存在第三方 API 参考资料，实现是否与 `docs/references/{{FEATURE}}/` 一致。
- 业务实现阶段是否修改了受保护的 Harness 文件。
- 业务代码、测试、fixtures 是否全部位于 `{{WORKSPACE}}/`，不能散落在根目录 `backend/`、`frontend/`、`tests/`。

先输出 findings，按严重程度排序。严重程度必须使用 `High`、`Medium`、`Low`
之一，方便 Harness 识别阻断问题。如果没有 High/Medium 问题，明确写：

`No blocking findings.`

如果发现 High 或 Medium，必须保留这些英文严重程度标记。
