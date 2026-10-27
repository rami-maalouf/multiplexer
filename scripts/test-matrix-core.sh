#!/usr/bin/env bash
# runs matrix-core's tests on an ios simulator against the practice account.
# MATRIX_TEST_FILL=24 also sends 24 numbered messages to the test room (testFillTheTestRoom).
# the password comes from the mac's keychain (service multiplexer-test-account)
# and reaches the test as an environment variable; it is never printed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
user="${MATRIX_TEST_USER:-@rami-m-test:matrix.org}"
simulator="${SIMULATOR:-iPhone 17 Pro}"

password="$(security find-generic-password -s multiplexer-test-account -a "$user" -w)"

# xcodebuild passes TEST_RUNNER_-prefixed variables to the test process without the prefix.
# without -collect-test-diagnostics never, a failed test waits up to 10 minutes for simctl diagnose.
cd "$root/matrix-core"
TEST_RUNNER_MATRIX_TEST_USER="$user" \
TEST_RUNNER_MATRIX_TEST_PASSWORD="$password" \
TEST_RUNNER_MATRIX_TEST_HOMESERVER="${MATRIX_TEST_HOMESERVER:-matrix.org}" \
TEST_RUNNER_MATRIX_TEST_FILL="${MATRIX_TEST_FILL:-}" \
  xcodebuild test -scheme MatrixCore -destination "platform=iOS Simulator,name=$simulator" \
  -collect-test-diagnostics never "$@"
