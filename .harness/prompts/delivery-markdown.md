# Delivery Markdown Report

Generate the final human-readable delivery report for feature `{{FEATURE}}`.
The business implementation directory is `{{WORKSPACE}}/`.

Read:

- `.harness/runs/{{FEATURE}}/delivery.json`
- `AGENTS.md`
- `.harness/runs/{{FEATURE}}/status.md`

Output rules:

- Output Markdown only.
- Use Chinese.
- Base the report on `.harness/runs/{{FEATURE}}/delivery.json`; do not invent facts not present in that JSON.
- Do not output "I cannot write files", "the environment is read-only", or similar environment disclaimers.
- Do not output full API keys, tokens, secrets, secret prefixes, or secret suffixes. Use only `present`, `missing`, or `invalid format`.

Required sections:

- Feature name
- Requirement ids implemented
- Changed files
- Commands run
- Verification status
- Live pending items
- Evidence files
- Screenshot files
- Known risks or unresolved blockers
- Recommended next Harness improvements
