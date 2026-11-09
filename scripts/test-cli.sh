#!/usr/bin/env bash
# verify deterministic contracts, then serialize both live suites against the test accounts.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
bun test scripts/cli-test-policy.test.ts
swift test --package-path cli
swift build --package-path cli -c release
exec "$root/scripts/mx-lock.sh" matrixcore cli-suite -- bun "$root/scripts/test-cli-suite.ts"
