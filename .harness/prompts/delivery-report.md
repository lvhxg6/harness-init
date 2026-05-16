# Delivery JSON Report

Generate the final machine-readable delivery report for feature `{{FEATURE}}`.
The business implementation directory is `{{WORKSPACE}}/`.

Read:

- `AGENTS.md`
- `docs/product/{{FEATURE}}.md`
- `docs/acceptance/{{FEATURE}}.yaml`
- `docs/architecture/{{FEATURE}}.md`
- `docs/references/{{FEATURE}}/`, if present
- `docs/quality/scorecard.md`
- `.harness/runs/{{FEATURE}}/`
- `.harness/schemas/delivery-report.schema.json`

Output rules:

- Output only a single JSON object.
- Do not wrap the JSON in Markdown fences.
- Do not include any prose before or after the JSON.
- The JSON must satisfy `.harness/schemas/delivery-report.schema.json`.
- Use Chinese strings where explanatory text is needed.
- Do not output "I cannot write files", "the environment is read-only", or similar environment disclaimers.
- Do not output full API keys, tokens, secrets, secret prefixes, or secret suffixes. Use only `present`, `missing`, or `invalid format`.

Field rules:

- `feature`: exactly `{{FEATURE}}`.
- `verification_status`: `passed`, `failed`, or `blocked`.
- `stable_status`: `passed`, `failed`, `blocked`, or `skipped`.
- `review_status`: `passed`, `blocked`, or `passed_with_live_pending`.
- `live_status`: `not_run`, `passed`, `failed`, or `blocked`.
- `live_pending`: list live-only pending items, or `[]`.
- `implemented_requirements`: list implemented requirement ids from acceptance criteria.
- `changed_files`: include only source, test, prompt, script, schema, or documentation files intentionally changed for delivery.
- `changed_files` must not include runtime artifacts such as `dist/`, `coverage/`, `node_modules/`, logs, screenshots, generated image outputs, `.DS_Store`, or run cache files.
- `commands_run`: include Harness-owned commands proven by logs, such as `make verify` or `make verify-live`.
- `evidence`: include verification logs, review reports, pending files, status files, or other run evidence paths.
- `screenshots`: include screenshot evidence paths only.
- `risks`: include known risks, or `[]`.
- `human_review_needed`: include items requiring human review, or `[]`.
- `recommended_next_harness_improvements`: include concrete Harness follow-ups, or `[]`.
