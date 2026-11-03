# Adding a package to an app has no app verb and writes an absolute path

**Status:** Open
**Systems:** exact add, packages
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

`docs/reference.md` ("Notifications") says the app depends on the package through `exact add
notifications` (or a `file:` line). In the app's folder:

- `bun exact.mjs add notifications` printed the app's verbs, which have no `add`;
- the framework's `bun <exact2>/scripts/exact.mjs add notifications` said "name the app (exact add
  geolocation <app>), or run bun exact.mjs add in it", though the app's `exact.mjs` has no `add`;
- `bun <exact2>/scripts/exact.mjs add notifications .` worked, and wrote
  `"@exact/notifications": "file:/Users/…/exact2/packages/notifications"`: an absolute path, where the
  app's other packages are `file:../../../exact/exact2/packages/…`. A checkout on another machine
  would not find it. I made it relative by hand and ran `bun install`.

Cost: about 4 minutes.

## What would help

- `add` among the verbs of the app's `exact.mjs`, as the second message says.
- The package's path written relative, as `exact new` writes the others.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.
