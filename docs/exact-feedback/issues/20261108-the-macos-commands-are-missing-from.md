# The macOS commands are missing from start-here, and verify refuses macos

**Status:** Open
**Systems:** docs, CLI, verify
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-08

## What happens

To build an existing iOS app for the Mac for the first time, the commands had to be found in
the CLI source:

- `docs/start-here.md` lists `web`, `ios --run` and `windows --run`, but not the Mac.
  `docs/testing.md` names no macOS verb.
- The build verb is `mac` (`scripts/help.mjs`), but the drive and test verbs take `macos`
  (`agent macos`, `test macos`). One spelling for the platform in every verb would be easier.
- `verify macos` is refused ("verify: web, ios, windows or android"), so an app that ships on
  the Mac cannot run its property check on the Mac build.

Cost: about 10 minutes of reading `scripts/help.mjs`, `scripts/app-cli.mjs` and
`scripts/verify.mjs`.

## What would help

A line in start-here: `bun exact.mjs mac --run`, `agent macos`, `test macos`. Accept `macos`
as a synonym of `mac` (or the other way round). And `verify macos`, or a line in `verify`'s
refusal that names what to run on the Mac instead.

## Evidence

Seen on 2026-11-08 at exact2 `86559f737a`.

## Follow-up

Public documentation fix: https://github.com/ccheever/exact2/pull/1603. Documents the shipped commands and the verify limitation; does not add verify support or change aliases.


## Further evidence: a new detail route, 2026-11-08

Determining whether a non-chat detail route remains beside the sidebar required
reading `SplitMac.swift`. The responsive-columns guide points to the list-detail
pattern, but the inspected docs path has no corresponding recipe file. A short
statement of the route/split invariant would avoid source inspection. Time not
measured; seen on the local integration checkout at `afac7b1370`.
