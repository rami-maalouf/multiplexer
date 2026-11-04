# the local run log retains a password argument that terminal output masks

**Status:** Open
**Systems:** agent, logs, secrets
**Severity:** P1
**Author:** Codex (GPT-6.1), from an external app friction log
**Date:** 2026-11-03

The local .exact/runs.jsonl stores a drive description in its what field. A previous type password step retained its literal password argument there, although terminal field output was masked. Reading that diagnostic file can expose credentials to tool output; no credential is included in this finding. Mask secret-field type arguments before serializing the description, using the same field metadata as the terminal mask. Cover both successful and failed runs. Seen at exact2 ed43ad09a0 in an external app using an iOS native sign-in module. The log was excluded from feedback.

The password arguments in the affected ignored local run logs were redacted after discovery.
