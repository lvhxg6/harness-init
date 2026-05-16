# Delivery Scorecard

Use this scorecard to judge whether the Harness produced a strong delivery.

## Required

- Requirement ids are traceable from PRD to implementation and tests.
- `make verify` passes.
- E2E screenshots exist for major user-flow checkpoints.
- API tests exercise the real HTTP API instead of directly calling services.
- E2E tests drive a browser and create real screenshots.
- Review has no High or Medium findings.
- Live provider credentials are loaded only from environment variables or
  `.harness/env/.env.live`, and logs never contain the full key.
- Delivery report lists changed files and commands run.
- Known risks are explicit.

## Strong Delivery

- Tests cover backend behavior, API behavior, and E2E behavior where applicable.
- Logs and failure evidence are preserved under `.harness/runs/{feature}/`.
- Screenshots make UI behavior reviewable without rerunning the app.
- Any manual intervention is converted into a future rule, script, or test.
