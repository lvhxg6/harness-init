# 实施计划

你是 Codex，正在为这个仓库的 Harness 工作流规划功能实现。输出必须使用中文。

Feature: `{{FEATURE}}`
Workspace: `{{WORKSPACE}}`

Read:

- `AGENTS.md`
- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/references/{{FEATURE}}/`，如果该目录存在
- `docs/architecture/system.md`
- `docs/architecture/testing.md`

任务：

Create an implementation plan for the feature. Do not edit business source code
in this step.

You must create both files:

- `.harness/runs/{{FEATURE}}/implementation-plan.md`
- `.harness/runs/{{FEATURE}}/tasks.yaml`

The Markdown plan must include:

- Implementation tasks to run.
- Business files to create or modify.
- Backend unit/domain/integration tests to create when backend verification will
  run a backend test entry such as `npm test`, `mvn test`, `pytest`, or
  `go test`.
- API tests to create when APIs are involved.
- Playwright E2E tests to create when UI workflows are involved.
- Required screenshots and their target paths.
- Live dependency verification plan when external services are involved.
- Verification commands.
- Risks or assumptions.

The `tasks.yaml` file is the machine-readable task contract used by Harness.
It must use this shape:

```yaml
tasks:
  - id: "short-id-without-spaces"
    title: "中文任务名"
    type: "implementation"
    scope:
      - "{{WORKSPACE}}/some-path"
    success:
      - "可验证的完成标准"
    verify:
      - "可选的局部验证命令"
```

Task rules:

- Keep the tasks generic and based on the PRD/architecture. Do not assume every
  feature has backend, frontend, API tests, or E2E tests.
- Split large work into small tasks by module, service, UI area, test layer, or
  integration boundary.
- Use the test-entry contract: if a task creates or keeps a backend test entry
  that the Harness will execute, the plan must include a task that creates the
  matching backend test files in the backend project itself. Examples:
  `{{WORKSPACE}}/backend/**/*.test.ts` for Vitest/Jest,
  `{{WORKSPACE}}/backend/src/test/` for Maven/Gradle,
  `{{WORKSPACE}}/backend/test_*.py` or `*_test.py` for pytest, and
  `{{WORKSPACE}}/backend/**/*_test.go` for Go.
- API tests under `{{WORKSPACE}}/tests/api/` and E2E tests under
  `{{WORKSPACE}}/tests/e2e/` do not satisfy a backend unit test entry such as
  `npm test`; plan backend tests separately when that entry exists.
- Every task id must be stable, lowercase, and must not contain spaces.
- Every task must write business code, tests, or fixtures only under
  `{{WORKSPACE}}/`.
- Do not plan root-level `backend/`, `frontend/`, or `tests/` directories.
- Include test/E2E/live tasks only when they are required by the PRD or
  architecture.

最终输出会保存为 `.harness/runs/{{FEATURE}}/implementation-plan.md`。
