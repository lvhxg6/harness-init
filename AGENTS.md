# Codex Harness Guide

This repository is organized for Codex-driven Harness Engineering.

## Codex Role

Codex is the execution agent. It reads the task context, plans scoped changes,
edits files, runs commands, fixes verification failures, and produces a delivery
report.

Codex is not the workflow engine. The workflow is controlled by repository
scripts under `.harness/` and `scripts/`.

During dynamic task implementation, Codex only writes business files and runs
lightweight checks. It must not install dependencies, start services, run
network commands, or execute full build/test/E2E commands. Dependency install,
service startup, API tests, Playwright E2E, screenshots, live checks, and repair
loops are owned by the Harness runner.

## Workspace Boundary

`workspace/` is the only business implementation area. Generated backend,
frontend, API tests, E2E tests, fixtures, and other feature code must live under:

```text
workspace/backend/
workspace/frontend/
workspace/tests/
```

The Harness frame lives outside `workspace/`: `.harness/`, `scripts/`,
`AGENTS.md`, `Makefile`, root test tooling, and shared architecture docs.
Product input documents and references also stay outside `workspace/` under
`docs/product/` and `docs/references/`.

Do not create root-level `backend/`, `frontend/`, or `tests/` directories during
feature implementation.

## Language

文档、review、delivery、blocked report 和面向用户的总结默认使用中文。
代码命名、接口字段、测试名、环境变量可以保持英文。

## Secret Handling

- API Key、Token、Base URL 等敏感或环境相关配置只能来自环境变量或
  `.harness/env/.env.live`。
- 不要把完整 Key 写入 PRD、架构文档、acceptance、review、delivery、日志或前端代码。
- 日志和报告中不能展示 Key 的前缀或后缀，只能展示 `present`、`missing`
  或 `invalid format`。

## Required Read Order

Before implementing a feature, read:

1. `docs/product/{feature}.md`
2. `docs/acceptance/{feature}.yaml`
3. `docs/architecture/{feature}.md`
4. `docs/architecture/system.md`
5. `docs/architecture/testing.md`
6. This `AGENTS.md`

The user only needs to provide `docs/product/{feature}.md`. If
`docs/architecture/{feature}.md` is missing, the Harness asks whether to wait
for a user-provided architecture or generate one from the PRD. If acceptance
criteria are missing, the Harness asks Codex to generate
`docs/acceptance/{feature}.yaml` from the PRD and architecture.

If the feature depends on third-party APIs, the user can optionally provide
reference material under `docs/references/{feature}/`. These files are treated
as implementation source material for architecture, acceptance, provider code,
tests, review, and repair. Never place real secrets in reference documents.

If acceptance criteria are ambiguous, write concrete assumptions into the
acceptance file and delivery report. Do not silently invent product behavior.

## Definition of Done

A feature is complete only when:

- The implementation matches the PRD and acceptance criteria.
- Backend checks pass.
- API tests pass.
- Frontend checks pass.
- Playwright E2E tests pass.
- E2E screenshots are captured under `.harness/runs/{feature}/screenshots/`.
- `HARNESS_STRICT=1 FEATURE={feature} make verify` passes.
- If live mode is requested, `FEATURE={feature} make verify-live` also passes
  inside `.harness/run-feature.sh`.
- A delivery report is written under `.harness/runs/{feature}/`.

## Development Rules

- Keep changes scoped to the requested feature.
- Put all business code, tests, and fixtures under `workspace/`.
- Do not modify unrelated modules.
- Do not modify `.harness/`, `scripts/`, `AGENTS.md`, or global architecture
  rules during feature implementation unless the task is explicitly a Harness
  maintenance task.
- Preserve existing behavior unless the PRD explicitly changes it.
- Add or update tests for every implemented requirement id.
- API and E2E test names must include related requirement ids.
- E2E tests must capture screenshots at major user-flow checkpoints.
- API tests must call the real HTTP API. Do not call service/domain functions as
  a substitute for API tests.
- E2E tests must drive a real browser page with Playwright and use
  `page.screenshot()`. Do not synthesize or copy placeholder PNG files.
- Prefer deterministic scripts over manual steps.
- If verification fails, inspect logs, fix the root cause, and rerun the relevant
  checks before rerunning the full verification.
- During a Harness task stage, do not run `npm install`, `npm ci`,
  `pnpm install`, `yarn install`, `npm run build`, `npm test`,
  `npm run typecheck`, `npm run lint`, `npx playwright install`, `npm run dev`,
  or long-running service commands. The task stage may run only lightweight
  syntax/structure checks such as `node --check` for existing JS files and
  `bash -n` for shell scripts.

## Harness Commands

Default closed loop with mock/stable verification:

```bash
./.harness/run-feature.sh {feature}
```

Real dependency closed loop with live verification:

```bash
./.harness/run-feature.sh {feature} --live
```

`--live` validates `.harness/env/.env.live` or shell environment first, then runs
architecture generation, acceptance generation, dynamic task implementation,
strict verify, review gate, live API smoke test, live Playwright E2E, and repair
loops.

To discard prior run state and business output for a feature:

```bash
./.harness/run-feature.sh {feature} --fresh
```

To stop the currently recorded Harness child process:

```bash
./.harness/stop-feature.sh {feature}
```

The runner prints compact progress by default. Set `HARNESS_OUTPUT=full` when a
full status table is needed after every heartbeat.

## Harness Progress and Failures

Feature runs write progress to:

```text
.harness/runs/{feature}/state.json
.harness/runs/{feature}/checkpoint.json
.harness/runs/{feature}/progress.json
.harness/runs/{feature}/tasks.yaml
.harness/runs/{feature}/timeline.jsonl
.harness/runs/{feature}/status.md
```

Use `./scripts/harness-status.sh {feature}` to inspect the current or latest run.

Harness failures are classified as:

- `AGENT_STALLED`: Codex appears alive but is not making effective progress.
- `STAGE_IDLE_TIMEOUT`: a stage had no file, progress, or log activity for the idle threshold.
- `STAGE_WALL_TIMEOUT`: a stage exceeded the broad wall-clock safety limit.
- `VERIFY_FAILURE`: stable verification failed; Codex may repair `workspace/`.
- `REVIEW_BLOCKER`: review gate found High/Medium issues; Codex may repair `workspace/`.
- `LIVE_PROVIDER_FAILURE`: live dependency verification failed or provider credentials/model/quota failed.
- `BUSINESS_FAILURE`: product behavior is still not aligned with requirements.
- `NEEDS_HUMAN_INPUT`: required PRD, architecture choice, secret, account, quota, or decision is missing.
- `ENVIRONMENT_FAILURE`: local tools, ports, permissions, or runtime dependencies are missing.
- `HARNESS_FAILURE`: `.harness/`, `scripts/`, protected paths, or Harness checks failed.

Codex must not try to fix `ENVIRONMENT_FAILURE`, `HARNESS_FAILURE`, or
`NEEDS_HUMAN_INPUT` by changing business code. Those require Harness maintenance,
environment changes, or user-provided information.

## Final Response Requirements

Final responses must include:

- Feature name
- Requirement ids implemented
- Changed files
- Commands run
- Verification status
- Known risks or unresolved blockers
