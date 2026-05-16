# 交付报告

为功能 `{{FEATURE}}` 生成最终交付报告。内容说明使用中文。
业务实现目录是 `{{WORKSPACE}}/`。

Read:

- `AGENTS.md`
- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在
- `docs/quality/scorecard.md`
- `.harness/runs/{{FEATURE}}/`

包含：

- Feature name
- Requirement ids implemented
- Changed files
- Commands run
- Verification status
- Live verification status, including whether `make verify-live` ran and which log proves it
- Evidence files
- Screenshot files
- Known risks
- Recommended next Harness improvements

不要输出任何 API Key、Token、Secret 的完整值、前缀或后缀；只能写 present/missing/invalid format。
