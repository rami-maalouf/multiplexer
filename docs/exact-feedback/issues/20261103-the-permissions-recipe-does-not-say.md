# the permissions recipe does not say that a refused request runs no then

**Status:** Open
**Systems:** permissions recipe, mutations
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app records a voice message. Its composer moves through steps of its own state
(`"opening"` while `getUserMedia(audio=true)` asks for the microphone, then `"recording"`), and
the request's `then` action moves it on, as the permissions recipe shows (`mutation located as
shape GeolocationPosition then arrived`, with `case none` in `arrived`). A drive that denied the
permission (`--permission microphone=prompt`, then `tap @<ticket> deny`) left the composer in
`"opening"` for good: the agent's note said "mutation micOpened's reply was refused:
media-capture.getUserMedia: NotAllowedError; its slot keeps what it had and its `then` does not
run". The `case none` branch that was meant to show the "turn it on in Settings" alert never ran.

The rule is in the error-alert recipe ("`then` does not run for a request that brought no
answer"), but not in the permissions recipe, where a refused request is the main failure, and
not in the recorder sample (its `then arm` has a `case none` that a refusal never reaches; the
sample is safe only because it reads `pending(opened)`, not a state of its own).

The fix in the app: a derive of the step's `failure(...)` and a task on it
(`task endFailedRecording when voiceFailed key=recording`, `after(1, recordingFailed)`), which
shows the alert and resets the step.

Cost: one drive and about 10 minutes to redesign the steps.

## What would help

One line in the permissions recipe, at "Recover": a refused request (`NotAllowedError`) runs no
`then`; read `failure(x)` (its `code`) where the app waits on the request, as `error-alert`
says. The recorder sample's `case none` could say the same.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` (iOS simulator, `@exact/media-capture`'s
`getUserMedia` under the agent, the permission denied by its ticket).

## Pull request (2026-11-03)

https://github.com/ccheever/exact2/pull/1363 (fixes it): the recipe's "Recover" step says that a refused request fails and runs no `then`, and names `failed(...)`. The recorder sample is not changed.
