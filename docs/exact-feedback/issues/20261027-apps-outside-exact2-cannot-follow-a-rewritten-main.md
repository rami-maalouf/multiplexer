# An app that uses exact2 by path has no safe way to follow a rewritten `main`

**Status:** Open
**Systems:** `exact.mjs update`, exact2's history, apps outside the repo
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

On 2026-10-27, exact2's `main` history was rewritten twice (a transcript purged on
purpose). Each time, `git pull --ff-only` in the exact2 checkout that the app uses failed:
local `main` and `origin/main` had diverged (the second time, 183 local commits and 209
remote ones). A check of commit subjects showed 177 of the 183 on the remote under new
hashes; the other 6 were the purged transcript and two housekeeping commits. The fix was
a backup branch, then `git reset --hard origin/main`. Cost: about 8 minutes each time.

## What would help

`bun exact.mjs update` (or its help) detecting a rewritten history and saying "back up,
then reset", or a stable tag that apps outside the repo can follow.

## Evidence

From the app's diary entry for the second update. Local backup branches:
`backup/main-before-2026-10-27-rewrite` and `backup/main-before-2026-10-27-rewrite-2`.
