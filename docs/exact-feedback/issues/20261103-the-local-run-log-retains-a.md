# the local run log retains a password argument that terminal output masks

**Status:** Open

Additional evidence (2026-11-04): an authenticated drive used a separate native driver to fill
the secure field from stdin, then resumed the Exact drive after sign-in. This kept the secret
out of Exact's persisted command arguments, but required coordinating two drivers. A dedicated
secret-input channel would remove that workaround.
**Systems:** agent, logs, secrets
**Severity:** P1
**Author:** Codex (GPT-6.1), from an external app friction log
**Date:** 2026-11-03

The local .exact/runs.jsonl stores a drive description in its what field. A previous type password step retained its literal password argument there, although terminal field output was masked. Reading that diagnostic file can expose credentials to tool output; no credential is included in this finding. Mask secret-field type arguments before serializing the description, using the same field metadata as the terminal mask. Cover both successful and failed runs. Seen at exact2 ed43ad09a0 in an external app using an iOS native sign-in module. The log was excluded from feedback.

The password arguments in the affected ignored local run logs were redacted after discovery.

Additional evidence (2026-11-07, exact2 `91d7b12620`): two sign-in drives on iOS with a masked password field. The terminal output showed `•••`; `.exact/runs.jsonl` held the password once for each drive and was redacted by hand after each one.
