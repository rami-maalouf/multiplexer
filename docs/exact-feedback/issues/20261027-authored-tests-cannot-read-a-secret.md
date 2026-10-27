# An authored test cannot read a secret, so `verify` never reaches the screens behind a sign-in

**Status:** Open
**Systems:** authored tests (`app.test.contract`), `verify`, agent
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

The app signs in to a real server with a password, through a native library (not
`fetch`, so a fake server cannot stand in). The password cannot be in
`app.test.contract`, which is in git. The test grammar (`docs/contract-grammar.md`,
"Authored tests") has no step that reads a value from the environment or the Keychain.
So every authored test stays on the sign-in screen, and `verify ios` checks only that
screen.

The chat list behind the sign-in drew each row's time over the chat's name at the
largest text size. `verify ios` said "nothing spills". Only a drive at the simulator's
own largest size (`xcrun simctl ui <udid> content_size
accessibility-extra-extra-extra-large`) found it.

Workaround: drives that type the password from a shell variable
(`pw="$(security find-generic-password …)"`, then `"type password $pw"`). The drive masks
the field, but `state` does not (`20261027-agent-state-prints-a-password.md`).

## What would help

A test step that types a named secret from the environment, masked in every report and
log, for example `type "password" env "APP_TEST_PASSWORD"`. A test whose variable is not
set would be skipped and say why. `verify` would then check the screens behind the
sign-in, in both schemes and at every text size.
