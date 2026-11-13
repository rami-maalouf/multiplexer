# A screenshot drive is silent during native rebuild stages

## What happened

A signed-out screenshot drive announced a native rebuild and its log path, then gave no terminal progress for several minutes. The log showed completed Swift package builds while the command was still pending. Adding a new, not-yet-imported Contract component during that baseline build caused the completed drive to stop with `ios build is stale`. Retrying selected the fast plan path and reached the screen.

The invalidation after an edit is understandable; the missing stage progress made it harder to judge when the build would finish. About three minutes of delay, including a retry. A later comment edit during verification also invalidated the run; that was an authoring mistake and is not a separate defect.

## What would help

Report the current build stage periodically in the command output, and consider refreshing the plan automatically before a drive when only Contract content changed during the native build.

## Evidence

Observed on 2026-11-12 with upstream checkout `8536d208c40f97be3f132ea266d5029e2e3c10ba`. The baseline retry captured the signed-out form and correctly refused a missing help target. No account was used.

## More evidence (2026-11-13)

At `6f4917bda`, a fresh native build seeded the registry cache but still recompiled the framework and module code for several minutes, with long quiet intervals between phase boundaries. Periodic phase progress would distinguish compilation from a stall.
