# Codex Harness Architecture

## 1. Codex Role

Codex is the execution agent in this Harness.

It is responsible for:

- Reading PRD, acceptance criteria, architecture docs, and project rules.
- Producing an implementation plan when needed.
- Editing source code and tests.
- Running deterministic project commands.
- Reading verification logs and repairing failures.
- Reading E2E screenshots when browser behavior fails.
- Producing review notes and delivery reports.

Codex is not responsible for owning the lifecycle policy. Retry limits,
verification entry points, report locations, and escalation rules belong to the
Harness layer.

## 2. Harness Role

The Harness is the control system around Codex.

It is responsible for:

- Defining where requirements live.
- Requiring feature-specific technical architecture.
- Generating acceptance criteria from the PRD when missing.
- Defining where acceptance criteria live.
- Defining the single verification command.
- Calling Codex non-interactively.
- Keeping dependency installation, service startup, API tests, E2E tests, and
  live checks outside individual Codex implementation tasks.
- Capturing logs, screenshots, and evidence.
- Feeding failed verification logs back to Codex.
- Feeding screenshot evidence back to Codex.
- Feeding live dependency failures back to Codex when live mode is enabled.
- Tracking state, checkpoints, dynamic tasks, and progress.
- Resuming completed stages instead of restarting from zero.
- Stopping after a bounded number of repair attempts.
- Producing a durable delivery artifact.

## 3. Lifecycle

```text
PRD
  -> optional docs/references/{feature}/ for third-party API details
  -> preflight
  -> live env validation when --live is enabled
  -> prompt for feature architecture
  -> use user-provided architecture or generate architecture
  -> generate acceptance
  -> implementation plan and .harness/runs/{feature}/tasks.yaml
  -> .harness/run-feature.sh
  -> codex exec implements dynamic tasks with lightweight checks only
  -> lightweight workspace structure and test-entry contract check
  -> install workspace dependencies once from the outer Harness process
  -> HARNESS_STRICT=1 FEATURE={feature} make verify
  -> failed logs and screenshots feed back to codex exec
  -> optional live verify and live E2E when --live is enabled
  -> review
  -> delivery report
```

Every run writes state to `.harness/runs/{feature}/state.json`,
`.harness/runs/{feature}/progress.json`, `.harness/runs/{feature}/tasks.yaml`,
`.harness/runs/{feature}/timeline.jsonl`, and
`.harness/runs/{feature}/status.md`. `scripts/harness-status.sh {feature}` reads
these files and prints the full step table, current task, elapsed time, latest
logs, screenshots, and blocked reason without mutating run state. Use
`scripts/harness-status.sh {feature} --reconcile` only when stale PID
reconciliation is intentionally requested.

The runner defaults to compact output: full progress is printed at stage
boundaries, while long-running stages print heartbeat lines with current stage,
duration, idle time, changed file count, PID, and output path. Set
`HARNESS_OUTPUT=full` to print the full status table during heartbeats.

## 3.1 Resume and Recovery

The default `.harness/run-feature.sh {feature}` command is a resume command.
It keeps `.harness/runs/{feature}/` and `workspace/`, reconciles state on
startup, and continues from durable checkpoints. Use `--fresh` only when the
feature run and workspace should be discarded and rebuilt from zero.

On startup, the Harness checks the recorded `currentPid`. If the state says a
stage is `RUNNING` but the PID no longer exists, the stage is marked
`INTERRUPTED`, the PID fields are cleared, and a timeline event is appended.
The next run then continues from files and completed stages instead of treating
the dead process as active.

Blocked runs are recoverable. If a previous run stopped with
`NEEDS_HUMAN_INPUT`, `ENVIRONMENT_FAILURE`, or another blocking category, the
blocked report and logs remain as historical evidence. After the user fixes the
condition and the next run passes the relevant preflight or live-env checks, the
Harness clears the active blocked state, records `resume-after-blocked`, and
continues. Old failure files are not deleted; they are treated as superseded
history and no longer define the current state.

Resume is epoch based. Each successful blocked recovery increments `runEpoch`.
Durable implementation outputs can be reused across epochs, but judgment
outputs are regenerated in the current epoch. Review, repair-review,
live-verify, delivery, and blocked-report stages must not reuse old epoch files
as current decisions. Current verification artifacts include the epoch in the
filename, for example `verify-e1-0.log`, `review-e1-0.md`, and
`review-gate-e1-0.log`.

Delivery produces two artifacts. `delivery.json` is the machine-readable source
of truth and must pass `.harness/schemas/delivery-report.schema.json`.
`delivery.md` is the human-readable report generated from the validated JSON.

Task-level recovery is conservative. A task is skipped only when the task stage
is `DONE` and its task output file exists. If a task was interrupted after
writing partial workspace files, the Harness runs that task again and instructs
Codex to read existing files first, then incrementally complete or repair the
task without deleting unrelated work.

The Harness also enforces a test-entry contract during lightweight checks. If a
workspace module exposes a test command that verification will execute, the
module must contain matching test assets. For example, a Node backend with
`npm test` must contain backend `*.test.*` or `*.spec.*` files under
`workspace/backend/`; API and E2E specs under `workspace/tests/` are separate
layers and do not satisfy that backend entry.

## 3.2 Architecture Modes

When `docs/architecture/{feature}.md` is missing, `.harness/run-feature.sh`
supports:

- `HARNESS_ARCHITECTURE_MODE=prompt`: ask whether to stop for a user-provided
  architecture or generate one from the PRD. This is the default.
- `HARNESS_ARCHITECTURE_MODE=require`: fail fast and wait for the user to add
  the architecture document.
- `HARNESS_ARCHITECTURE_MODE=generate`: generate the architecture document from
  the PRD without asking.

In non-interactive execution, `prompt` behaves like `generate` so automation can
continue.

## 3.3 Live Mode

`.harness/run-feature.sh {feature} --live` runs the same closed loop as the
default command, but adds real dependency verification after strict verification
and before the final review gate.

Live mode does this before implementation starts:

- Loads `.harness/env/.env.live` when present.
- Requires `OPENAI_API_KEY` for OpenAI image features.
- Sets `HARNESS_LIVE_OPENAI=1` and `IMAGE_PROVIDER=openai`.
- Writes only masked environment diagnostics to `.harness/runs/{feature}/live-env.log`.

Live mode does this before delivery:

- Runs `FEATURE={feature} make verify-live`.
- Stores output in `.harness/runs/{feature}/live-{attempt}.log`.
- Feeds live failures to Codex through `.harness/prompts/fix-live-verification.md`.
- Continues the bounded repair loop until live verification passes or attempts
  are exhausted.
- Runs review after live verification so live-only evidence is judged from
  completed live logs and screenshots, not from future expected artifacts.

If strict verification fails, live verification is skipped and the status file
records the skip reason. If live verification passes, review runs against both
stable and live evidence.

Review is mode-aware. In the default stable/mock run, review may record
live-only evidence as pending, but it must not block stable delivery for missing
real provider screenshots or live logs. In `--live` mode, those same pending
items become live blockers until real API, live log, and live screenshot
evidence exists. Provider implementations that are still stubs are not
live-only; they are workspace-fixable stable blockers.

## 3.4 Failure Categories

Harness failures are routed by category:

- `AGENT_STALLED`: Codex is not making effective progress.
- `STAGE_IDLE_TIMEOUT`: a stage had no file, progress, or log activity for the idle threshold.
- `STAGE_WALL_TIMEOUT`: a stage exceeded the broad wall-clock safety limit.
- `VERIFY_FAILURE`: stable verification failed in workspace code or tests.
- `REVIEW_BLOCKER`: review gate found blocking findings.
- `LIVE_PROVIDER_FAILURE`: live API, provider credentials, quota, model, or live E2E failed.
- `BUSINESS_FAILURE`: behavior still does not satisfy PRD or acceptance.
- `NEEDS_HUMAN_INPUT`: required input, secret, account state, or product decision is missing.
- `ENVIRONMENT_FAILURE`: missing commands, port permissions, dependency/runtime
  issues, dependency registry/network failures, or local browser/runtime
  problems.
- `HARNESS_FAILURE`: protected Harness paths or Harness scripts failed.

Verify, review, live, idle, and stalled categories can enter recovery or repair
loops when retryable. Environment, Harness, and human-input failures block with a
report.

Review blockers are repaired only when they are `workspace-fixable`. Live-only
findings route to live verification or `LIVE_PROVIDER_FAILURE`, environment
findings route to `ENVIRONMENT_FAILURE`, human-input findings route to
`NEEDS_HUMAN_INPUT`, and Harness findings route to `HARNESS_FAILURE`.

Missing tests or screenshots, empty test suites such as `No test files found`,
type failures, build failures, API assertion failures, and E2E assertion
failures are `VERIFY_FAILURE` cases. They are retryable because Codex can repair
business code or tests under `workspace/`. Dependency registry/network failures
and missing local commands remain `ENVIRONMENT_FAILURE` and block for user or
environment action.

## 3.5 Third-Party References

Optional external API documentation belongs in:

```text
docs/references/{feature}/
```

Prompts must read this directory when it exists. These references are used for
architecture choices, acceptance criteria, provider implementation, live
verification, review, repair, and delivery reporting.

## 4. Boundaries

Codex can decide implementation details inside the constraints of the PRD,
acceptance criteria, and architecture docs.

Business implementation must stay under `workspace/`. The Harness frame,
product input, generated specifications, references, logs, and evidence stay
outside `workspace/`.

Implementation tasks may not run dependency installation or full verification.
They can only perform lightweight local checks such as package JSON parsing,
`node --check` for existing JavaScript files, and `bash -n` for shell scripts.
The Harness owns the unified dependency stage and blocks immediately when npm or
other dependency registries are unreachable.

The Harness must decide:

- Which commands count as verification.
- How many repair attempts are allowed.
- Where logs and reports are stored.
- Which modules are in scope.
- Which screenshots are required as E2E evidence.
- When a task is blocked and needs human review.
- How failures are classified and whether Codex should repair or block.

Status output must distinguish active and historical blockers. Historical
blocked reports and old `BLOCKED` rows stay in the run directory as evidence,
but they do not define current state after a successful resume.

## 5. Extension Points

- Replace `scripts/test-backend.sh` with Maven or Gradle module tests.
- Replace `scripts/test-api.sh` with Playwright API, RestAssured, Karate, or
  Newman.
- Replace `scripts/test-frontend.sh` with React build, lint, and typecheck.
- Replace `scripts/test-e2e.sh` with Playwright browser tests.
- Store E2E screenshots under `.harness/runs/{feature}/screenshots/`.
- Store third-party API references under `docs/references/{feature}/`.
- Extend `.harness/prompts/` for planning, debugging, release, migration, and
  review workflows.
- Add MCP servers when Codex needs structured access to GitHub, databases,
  browser automation, logs, or design documents.
