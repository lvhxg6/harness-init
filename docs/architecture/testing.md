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

This runs mock verification first, then live API and live E2E verification, then
review. If live verification fails, the Harness feeds the live log back to Codex
and continues the same bounded repair loop. Review runs after live verification
so it can judge actual live logs and screenshots.

Without `--live`, the same entry command runs stable/mock verification only.
Review may record missing real API logs, live screenshots, or live E2E evidence
as live pending items. Those pending items do not fail stable delivery, but they
remain blockers for a later `--live` run.

Progress is observable through:

```bash
./scripts/harness-status.sh {feature}
tail -f .harness/runs/{feature}/timeline.jsonl
```

`harness-status.sh` is read-only by default. It prints the latest rendered
status without reconciling PIDs or changing `state.json`. Use the explicit form
only when a stale PID should be reconciled:

```bash
./scripts/harness-status.sh {feature} --reconcile
```

To stop the active child process recorded in Harness state:

```bash
./.harness/stop-feature.sh {feature}
```

The default terminal output is compact. Use `HARNESS_OUTPUT=full` when debugging
and a full table is needed during heartbeats.

## Resume Behavior

Rerunning `.harness/run-feature.sh {feature}` without `--fresh` resumes the
existing run. The Harness keeps run logs, generated prompts, screenshots,
blocked reports, and workspace files, then reconciles `state.json` against the
recorded PID and durable output files.

If the recorded Codex child process no longer exists, the active stage is
marked `INTERRUPTED` and the PID is cleared. If the user has fixed a blocked
condition, a successful preflight or live environment validation clears the
active blocked fields while preserving the previous reason as history.

Historical failure documents are useful evidence and should not be manually
deleted during normal resume. Current status is determined by `state.json`,
latest active logs, and timeline events; old `verify-*.log`, `live-*.log`,
`review-*.md`, and `blocked-report*.md` files are retained for diagnosis and
delivery context.

`status.md` separates active blockers from historical blockers. A historical
`BLOCKED` row means the run previously stopped there; it is not the current
blocker unless the top-level status is still `blocked`.

Resume uses a run epoch to decide whether an artifact can participate in the
current flow. Durable implementation artifacts such as `tasks.yaml` and
`tasks/*.md` may be reused. Judgment artifacts such as review, review-gate,
repair-review, blocked-report, and delivery outputs are regenerated after a
blocked resume. Current verify/review/live files include the epoch in their
names, such as `verify-e1-0.log` and `review-e1-0.md`, so old findings remain
available without driving the current gate.

Delivery has a split contract: `delivery.json` is strict machine-readable JSON
validated against `.harness/schemas/delivery-report.schema.json`, while
`delivery.md` is the human-readable Chinese report generated from that JSON.

Use `--fresh` only when the feature should restart from zero. It removes the
feature run directory and workspace, so previous logs and partial business
files are intentionally discarded.

Live 验证的密钥配置推荐放在本地文件：

```text
.harness/env/.env.live
```

可从 `.harness/env/.env.live.example` 复制。该文件必须只保存在本机，不得提交、
不得写入 PRD、架构文档、acceptance、review 或 delivery。Harness 只允许输出
`present`、`missing` 或 `invalid format`，不能输出 Key 的前缀或后缀。

## Test Layers

- Lightweight task checks: JSON parsing, `node --check` for existing
  JavaScript, `bash -n` for shell scripts, and the test-entry contract check.
  These run before dependency installation and cannot use network access.
- Backend tests: service, domain, DAO, integration checks.
- API tests: externally visible HTTP behavior and contract checks.
- Frontend tests: typecheck, lint, component or build checks.
- E2E tests: browser-level user workflows.
- Screenshot evidence: Playwright screenshots at important UI checkpoints.

## Test Entry Contract

Harness uses an entry-implies-assets rule. A project is not required to have
backend unit tests just because it has a backend, but if the implementation
creates a test entry that Harness will execute, it must also create matching
test files for that entry.

Examples:

- Node/Vitest or Jest: if `workspace/backend/package.json` has `scripts.test`,
  backend tests must exist under `workspace/backend/` as `*.test.*` or
  `*.spec.*`.
- Maven/Gradle: if backend JVM tests are executed, test files must exist under
  `workspace/backend/src/test/`.
- pytest: if a pytest entry is configured, Python tests must exist as
  `test_*.py` or `*_test.py`.
- Go: if Harness executes `go test`, Go tests must exist as `*_test.go`.

API tests under `workspace/tests/api/` and E2E tests under
`workspace/tests/e2e/` are separate layers. They do not satisfy a backend test
entry such as `npm test`.

The contract is checked by `scripts/check-test-contract.sh`, which is called by
`scripts/harness-light-check.sh` before dependency installation and full
verification. Missing test assets are treated as retryable verification work so
Codex can repair `workspace/`.

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

## Review Gate Modes

Review findings are structured with severity, category, and whether they block
stable or live mode. The gate blocks stable/mock runs only for findings that
explicitly block stable, plus legacy unstructured High/Medium findings for
backward compatibility.

Live-only findings include missing real provider logs, missing live screenshots,
or skipped live E2E evidence. They are pending in stable/mock mode and blocking
in `--live` mode. Workspace-fixable findings include missing provider
implementation, missing backend/API/E2E tests, non-HTTP API tests, fake
screenshots, PRD mismatches, or architecture violations.

Review repair stages only receive workspace-fixable blockers. Environment,
human-input, Harness, and live-only blockers are routed to the matching Harness
failure category instead of spending repair attempts on files Codex cannot fix
inside `workspace/`.

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
