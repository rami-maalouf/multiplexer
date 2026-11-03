# exact update re-adds a gitignore line that hides the diary

**Status:** Open
**Systems:** exact.mjs update, diary
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-31

## What happens

`docs/diary.md` says `.exact/` is gitignored. This app keeps its diary in git on purpose
(the diary is shared with its owner and reviewed with the code), with its own exception:

```
/.exact/*
!/.exact/diary/
```

`bun exact.mjs update` appended `/.exact/` after those lines. That line ignores the whole
folder, so git cannot re-include the diary: a new diary file is ignored
(`git check-ignore -v .exact/diary/x.md` names the new line). Removing the line does not
last, because each `update` appends it again. Cost: about 10 minutes.

The workaround that survives `update`: keep its line, and re-include after it.

```
/.exact/
!/.exact/
/.exact/*
!/.exact/diary/
```

## What would help

`update` not appending `/.exact/` when the file already ignores `/.exact/*` (the app's own
lines say what it wants), or `update` saying that it changed `.gitignore` and why.

## Evidence

Seen on 2026-10-31, updating an app from exact2 `cee509ac82` to `1bc4c36cb7`.

## Pull request (2026-11-02)

https://github.com/ccheever/exact2/pull/1344 (fixes it): `exact update` takes `/.exact/*` as the diary rule and no longer appends `/.exact/`.
