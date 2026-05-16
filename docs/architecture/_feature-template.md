# Feature Technical Architecture Template

Use this template for `docs/architecture/{feature}.md`.

## 1. Technical Goal

Describe what the feature must technically deliver and how it will be verified.

## 2. Technology Choices

Record concrete choices for:

- Frontend framework and language.
- Backend framework and language.
- Storage, cache, queues, or external services.
- Test tools.
- Build and run commands.

## 3. Runtime Architecture

Business implementation must live under `workspace/`:

- Backend: `workspace/backend/`
- Frontend: `workspace/frontend/`
- Tests and fixtures: `workspace/tests/`

Describe how user requests move through the system.

```text
Client
  -> Backend/API
  -> Domain/service logic
  -> External dependencies
  -> Response
```

## 4. API Design

List endpoints, request fields, response fields, and error cases.

## 5. Data and State

Describe persistence, temporary files, rate limits, sessions, or in-memory state.

## 6. Verification Strategy

Define required checks:

- Backend checks.
- API tests.
- Frontend checks.
- Playwright E2E tests.
- Required screenshots.

## 7. Environment

List required environment variables, ports, local services, and mock/live modes.

## 8. Constraints and Non-Goals

Record what the first version will not include.
