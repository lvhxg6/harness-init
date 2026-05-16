# 生成验收标准

你是 Codex，正在为这个仓库的 Harness 工作流准备功能验收标准。说明文字默认中文。

Feature: `{{FEATURE}}`
Workspace: `{{WORKSPACE}}`

Input:

- `docs/product/{{FEATURE}}.md`
- `docs/architecture/{{FEATURE}}.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在；其中是第三方 API 文档、curl 示例、参数说明或错误码参考
- `AGENTS.md`
- `docs/architecture/system.md`
- `docs/architecture/testing.md`

任务：

Create `docs/acceptance/{{FEATURE}}.yaml`.

The acceptance file is the machine-verifiable contract for implementation and
testing. It must translate the PRD into concrete requirement ids and checks.

Required YAML shape:

```yaml
feature: "{{FEATURE}}"
source_prd: "docs/product/{{FEATURE}}.md"
requirements:
  - id: "REQ-{{FEATURE}}-001"
    title: ""
    description: ""
    priority: "must"
    backend:
      required: false
      checks: []
    frontend:
      required: false
      checks: []
    e2e:
      required: false
      flows: []
    data:
      fixtures: []
    assumptions: []
```

Rules:

- Preserve the PRD intent.
- Do not invent large product behavior beyond the PRD.
- If the PRD is ambiguous, write explicit assumptions under each requirement.
- Include backend checks only when the PRD implies backend behavior.
- Include frontend checks only when the PRD implies UI behavior.
- Include E2E flows for user-visible workflows.
- Include screenshot checkpoints for important E2E states.
- Place any test or fixture paths under `{{WORKSPACE}}/tests`, not root `tests/`.
- If external API references exist under `docs/references/{{FEATURE}}/`, include
  acceptance criteria for both mock verification and live dependency smoke
  verification.
- Use stable requirement ids.
- Do not implement code in this step.

写入 YAML 后，用中文报告生成的 requirement ids 和最重要的假设。
