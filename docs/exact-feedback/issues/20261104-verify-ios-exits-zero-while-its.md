# verify ios exits zero while its report says there are problems

**Status:** Open
**Systems:** verify,agent
**Severity:** P3
**Author:** Codex gpt-6.1-sol, from Rami Maalouf's app friction log
**Date:** 2026-11-04

## what happens

An app's `verify ios` run reported "tests: 8 passed, 0 failed", followed by one fixed-size
symbol and one deliberate native refusal in an error-state test. Its final line was
"verify: 2 problems (2 findings; the tests passed) in 83.8 s". The command exited zero.
A caller checking the process status alone can therefore report successful verification
while the human-readable report says the app still has problems.

The issues in the app were corrected and verification was run again. About 3 minutes.

## what would help

A nonzero exit when the final report counts problems, or a documented structured result
with a separate clean flag that callers can use as a gate.

## evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, on an iOS 26.5 simulator. The run output was
redirected to a log; the shell command's returned exit code was zero.
