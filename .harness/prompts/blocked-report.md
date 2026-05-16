# 生成阻断报告

你是 Codex，正在为未通过 Harness 闭环的功能生成阻断报告。

Feature: `{{FEATURE}}`
Workspace: `{{WORKSPACE}}`

请阅读：

- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在
- `.harness/runs/{{FEATURE}}/`

任务：

直接输出阻断报告正文。外层 Harness 会把你的输出写入
`.harness/runs/{{FEATURE}}/blocked-report.md`，你不需要也不能自己写文件。

必须说明：

- 当前停在什么阶段。
- 失败分类：`AGENT_STALLED`、`STAGE_IDLE_TIMEOUT`、`STAGE_WALL_TIMEOUT`、`ENVIRONMENT_FAILURE`、`VERIFY_FAILURE`、`REVIEW_BLOCKER`、`LIVE_PROVIDER_FAILURE`、`HARNESS_FAILURE`、`BUSINESS_FAILURE` 或 `NEEDS_HUMAN_INPUT`。
- 哪些验证或 review 问题仍未解决。
- 如果开启 live 模式，说明最新 live 验证日志和仍未解决的问题。
- 最后一次 fix 后是否已经执行 final verify。
- 哪些文件和日志最值得查看。
- Harness 下次是否可以 resume，以及应该从哪个阶段或 task 继续。
- 如果需要人工介入，明确列出需要用户提供什么。
- 建议 Harness 自动恢复策略，而不是要求用户手动拆命令跑完整流程。

不要输出“我无法写文件”“当前环境是只读”之类的说明；只输出报告正文。
不要输出任何 API Key、Token、Secret 的完整值、前缀或后缀；只能写 present/missing/invalid format。
不要把“请用户手动执行一堆验证命令”作为主要解决方案；诊断命令只能作为参考。
输出必须是中文。
