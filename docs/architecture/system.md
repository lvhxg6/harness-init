# System Architecture

This document is the top-level architecture map for Codex.

## Current State

The repository separates the Harness frame from generated business code.
Generated backend, frontend, infrastructure, and test modules must live under
`workspace/`.

## Intended Harness Shape

- Codex acts as the implementation and repair agent.
- `.harness/run-feature.sh` controls the feature lifecycle.
- `make verify` is the single source of truth for completion.
- `docs/product/` contains product requirements.
- `docs/architecture/{feature}.md` contains feature-specific technical architecture.
- `docs/acceptance/` contains machine-verifiable acceptance criteria.
- `docs/references/{feature}/` contains optional third-party API references.
- `workspace/` contains generated business implementation and tests.
- `scripts/` contains deterministic commands that Codex can run.

## Feature Architecture Handling

Every feature run must have:

```text
docs/product/{feature}.md
docs/architecture/{feature}.md
docs/acceptance/{feature}.yaml
docs/references/{feature}/
workspace/
```

If `docs/architecture/{feature}.md` is missing, the Harness prompts the user to
either provide it or let Codex generate it from the PRD. In non-interactive
execution, the Harness may generate it automatically unless configured to
require a user-provided architecture.

The Harness generates `docs/acceptance/{feature}.yaml` from the PRD and feature
architecture when acceptance is missing.

## Module Boundaries

Record service boundaries here once `workspace/backend` and
`workspace/frontend` modules are introduced.
