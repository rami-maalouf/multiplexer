# affected reports a javascript type error when cargo is unavailable

**Status:** Open
**Systems:** affected-suite lookup
**Severity:** P3
**Date:** 2026-11-07

## What happened

Running `bun scripts/affected.mjs` in a shell without cargo on its path failed at `cargoMetadata` with `TypeError: null is not an object (evaluating 'r.stderr.trim')`. Adding the installed rust toolchain to the path made the lookup succeed.

Cost: about one minute. The executable lookup failure was hidden by dereferencing the absent subprocess stderr.

## What would help

Report the subprocess launch error and name cargo as the unavailable executable before reading its output.

## Evidence

Seen at framework commit `eddc967dc3`, pinned Bun 1.4.2, macOS. No product change was necessary to complete the lookup.
