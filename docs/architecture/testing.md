# Testing Strategy

## Verification Entry

All feature work must end with stable verification:

```bash
HARNESS_STRICT=1 FEATURE={feature} make verify
```

Harness runs start with preflight:

```bash
FEATURE={feature} ./scripts/harness-preflight.sh
```

Preflight checks required commands and repository boundaries. `rg` is optional;
when missing, Harness checks must use `grep` fallback instead of failing.

Before starting local services, `.harness/run-feature.sh` runs a dedicated
dependency stage through `scripts/install-workspace-deps.sh`. This happens once
after all implementation tasks are written and after lightweight structure
checks pass. Individual Codex task stages must not run dependency installation.

Live OpenAI smoke tests can be run directly:

```bash
HARNESS_LIVE_OPENAI=1 IMAGE_PROVIDER=openai FEATURE={feature} make verify-live
```

For the full closed loop, prefer:

```bash
./.harness/run-feature.sh {feature} --live
```

This runs mock verification first, then review, then live API and live E2E
verification. If live verification fails, the Harness feeds the live log back to
Codex and continues the same bounded repair loop.

Progress is observable through:

```bash
./scripts/harness-status.sh {feature}
tail -f .harness/runs/{feature}/timeline.jsonl
```

To stop the active child process recorded in Harness state:

```bash
./.harness/stop-feature.sh {feature}
```

The default terminal output is compact. Use `HARNESS_OUTPUT=full` when debugging
and a full table is needed during heartbeats.

Live 验证的密钥配置推荐放在本地文件：

```text
.harness/env/.env.live
```

可从 `.harness/env/.env.live.example` 复制。该文件必须只保存在本机，不得提交、
不得写入 PRD、架构文档、acceptance、review 或 delivery。Harness 只允许输出
`present`、`missing` 或 `invalid format`，不能输出 Key 的前缀或后缀。

## Test Layers

- Lightweight task checks: JSON parsing, `node --check` for existing
  JavaScript, and `bash -n` for shell scripts. These run before dependency
  installation and cannot use network access.
- Backend tests: service, domain, DAO, integration checks.
- API tests: externally visible HTTP behavior and contract checks.
- Frontend tests: typecheck, lint, component or build checks.
- E2E tests: browser-level user workflows.
- Screenshot evidence: Playwright screenshots at important UI checkpoints.

## Strict Harness Mode

`HARNESS_STRICT=1` is used by `.harness/run-feature.sh`.

Strict mode requires:

- `workspace/backend/package.json` or `workspace/backend/pom.xml`
- `workspace/frontend/package.json`
- API specs under `workspace/tests/api/`
- E2E specs under `workspace/tests/e2e/`
- At least one PNG screenshot under `.harness/runs/{feature}/screenshots/`
- API tests must call the real HTTP API.
- E2E tests must drive a real browser page and use `page.screenshot()`.

Regular `make verify` remains useful for checking the skeleton before a feature
exists, and may skip missing modules.

## Empty Project Behavior

This skeleton treats missing `workspace/backend`, `workspace/frontend`, and
`workspace/tests` modules as skipped checks outside strict mode.
When real modules are added, replace skip behavior in `scripts/*.sh` with actual
commands.

## PRD-Only Input

The user provides only `docs/product/{feature}.md`.

If the feature architecture is missing, the Harness asks whether to use a
user-provided architecture or generate one from the PRD. The Harness then
generates `docs/acceptance/{feature}.yaml` before implementation. That YAML
becomes the machine-verifiable contract used to create backend, API, frontend,
and E2E tests.

## Third-Party API References

If a feature depends on an external API, place optional reference material under:

```text
docs/references/{feature}/
```

These files can include curl examples, request/response schemas, model names,
Base URLs, SDK notes, rate limits, and known errors. They must not include real
API Keys.

## Workspace Test Layout

Business tests and fixtures must stay under:

```text
workspace/tests/api/
workspace/tests/e2e/
workspace/tests/fixtures/
```

Root-level `tests/` is not used by the Harness.

## Screenshot Evidence

Playwright E2E tests must write screenshots to:

```text
.harness/runs/{feature}/screenshots/
```

Recommended checkpoints:

- Initial mobile page loaded.
- Form filled with selected colors, elements, ratio, and extra prompt.
- Generation result with three images.
- Enlarged image preview.
- Download control visible.
- IP limit error, when covered by a test.
