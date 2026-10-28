#!/usr/bin/env bash
# runs matrix-core's tests on an ios simulator as a test user (default @test1 on our server).
# MATRIX_TEST_FILL=24 also sends 24 numbered messages to the test room (testFillTheTestRoom).
# the password comes from the mac's keychain (service multiplexer-test-account)
# and reaches the test as an environment variable; it is never printed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# the test users on our own server; never @rami (AGENTS.md, the safety rule).
user="${MATRIX_TEST_USER:-@test1:ramimaalouf.com}"
homeserver="${MATRIX_TEST_HOMESERVER:-${user#*:}}"
simulator="${SIMULATOR:-iPhone 17 Pro}"

password="$(security find-generic-password -s multiplexer-test-account -a "$user" -w)"
# a second person, for the tests that need one (unread counts): @test2 beside @test1.
user2="${MATRIX_TEST_USER2:-@test2:${user#*:}}"
password2="$(security find-generic-password -s multiplexer-test-account -a "$user2" -w 2>/dev/null || true)"

# xcodebuild passes TEST_RUNNER_-prefixed variables to the test process without the prefix.
# without -collect-test-diagnostics never, a failed test waits up to 10 minutes for simctl diagnose.
cd "$root/matrix-core"
TEST_RUNNER_MATRIX_TEST_USER="$user" \
TEST_RUNNER_MATRIX_TEST_PASSWORD="$password" \
TEST_RUNNER_MATRIX_TEST_HOMESERVER="$homeserver" \
TEST_RUNNER_MATRIX_TEST_USER2="$user2" \
TEST_RUNNER_MATRIX_TEST_PASSWORD2="$password2" \
TEST_RUNNER_MATRIX_TEST_FILL="${MATRIX_TEST_FILL:-}" \
  xcodebuild test -scheme MatrixCore -destination "platform=iOS Simulator,name=$simulator" \
  -collect-test-diagnostics never "$@"
