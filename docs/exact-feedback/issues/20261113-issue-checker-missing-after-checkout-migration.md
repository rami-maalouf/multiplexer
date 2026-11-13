# The older feedback workflow names a tool the current checkout no longer ships

**Status:** Open
**Systems:** Documentation and tooling
**Severity:** P3
**Author:** Codex, from an external app feedback log
**Date:** 2026-11-13

The external app's feedback instructions still name `scripts/issue.mjs new` and
`scripts/issue.mjs check`. The current framework checkout has neither that file
nor a replacement script with `issue` in its name. Running the documented check
fails with `Module not found`. About one minute was spent checking the checkout.

The existing finding was updated and its metadata and links were checked manually.
A migration note for apps retaining the older issue workflow would explain which
parts remain supported. Seen at framework commit `6f4917bdab8b5392a78c2e4e6b6d8d3b28e9317c`.
