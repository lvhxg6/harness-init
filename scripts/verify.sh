#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  ./scripts/stop-test-env.sh
}
trap cleanup EXIT

./scripts/bootstrap.sh
./scripts/install-workspace-deps.sh
./scripts/start-test-env.sh
./scripts/test-backend.sh
./scripts/test-api.sh
./scripts/test-frontend.sh
./scripts/test-e2e.sh
./scripts/check-architecture-alignment.sh
./scripts/collect-evidence.sh

echo "[verify] OK"
