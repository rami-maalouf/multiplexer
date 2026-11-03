# A drive says the app hung up with exit code 0 when it crashed

**Status:** Open
**Systems:** agent driver
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

On the iOS Simulator, an app crashed at launch with `EXC_BAD_ACCESS` (a segmentation fault in a
third-party library, on another thread). The drive stopped at its second step:

```
op 2/16 `clock data`: the app hung up (exit code 0)
```

Nothing said it crashed, and "exit code 0" reads as a clean exit. The simulator's system log
held nothing useful. Only the next drive's `logs` printed it:

```
crash report: ~/Library/Logs/DiagnosticReports/<app>-2026-11-03-175643.ips (2026-11-03 17:56:43.00 -0500)
  EXC_BAD_ACCESS (SIGSEGV), Segmentation fault: 11; thread 31 crashed:
   0 …
```

Cost: about 10 minutes and three drives.

## What would help

- The refusal saying "the app crashed (SIGSEGV, thread 31)" and naming the crash report, as the
  next drive's `logs` does; or no exit code when the host has none to tell.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
