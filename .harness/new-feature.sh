#!/usr/bin/env bash
set -euo pipefail

feature="${1:-}"
if [[ -z "$feature" ]]; then
  echo "Usage: ./.haniers/new-feature.sh <feature-name>" >&2
  exit 2
fi

path="docs/product/${feature}.md"
if [[ -f "$path" ]]; then
  echo "PRD already exists: $path"
  exit 0
fi

cat > "$path" <<EOF
# ${feature}

## Background

Describe why this feature is needed.

## Users

Describe who uses this feature.

## Requirements

1. Describe the first requirement.
2. Describe the second requirement.

## UI Flow

Describe pages, buttons, forms, states, and navigation.

## Backend/API Behavior

Describe APIs, data persistence, validation, permissions, and error handling.

## Out of Scope

Describe what this feature does not include.
EOF

echo "Created $path"

