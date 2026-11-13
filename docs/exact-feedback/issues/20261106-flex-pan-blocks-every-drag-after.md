# Scrolling and swipes freeze after a Home-indicator return

**Status:** Open
**Systems:** Apple host (iOS)
**Severity:** P1
**Author:** Auto (Composer), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-06

Local state: the flex-pan release workaround was reverted. A later idle-state probe
isolated `TimerScrollTouch`. The lifecycle fix passes native regression and simulator
checks; rebuilt physical acceptance remains pending.
Upstream repair: [expo/exact#494](https://github.com/expo/exact/pull/494), based on
`c419ce55c9`. All six framework checks, 19 native timer tests and tvOS compile pass.

## Corrected diagnosis, 2026-11-13

The earlier `.changed` snapshots below were taken during touch delivery, before all
recognizers had processed the end event. They do not prove that a flex pan stayed active.
On integration `8536d208c40f97be3f132ea266d5029e2e3c10ba`, two Home-indicator returns
froze the same mounted list. Finger scrolling confirmed both directions were blocked.
Hardware Home returns at 8 and 30 seconds did not reproduce it.

An idle-state debugger inspection found both glass flex pans `.possible` with zero
touches. The list pan was `.failed`, while `TimerScrollTouch` was still `.possible`
with zero touches. Changing only that observer to `.failed` immediately restored
scrolling on the same list, without navigation, restart or remount.

`TimerScrollTouch.finish` removes its final tracked contact but never assigns a
terminal recognizer state. Both `touchesEnded` and `touchesCancelled` take this path.
The observer must fail after the final contact so UIKit can reset the touch sequence.
It must continue observing while another contact remains and never prevent other
recognizers. The final UIKit regression fails without the state transition and
passes with it: 18 timer tests pass on the repaired version. Simulator inbox returns
at 8/8/30 seconds, chat scrolling, row actions and interactive back pass. The simulator
automation did not trigger the same system Home gesture, so physical rebuilt acceptance
is still required. Fix: `6f4917bdab8b5392a78c2e4e6b6d8d3b28e9317c`.

The older evidence and unsuccessful workaround below are retained as history, not
as the current diagnosis. No private diagnostic log or account content is attached.

## Follow-up: responsiveness does not establish smoothness

After installing the repair, numeric physical-phone diagnostics show the observer
ending and the list moving after Home returns. The owner nevertheless reports jerky
scrolling in both lists and transcripts. An external automated inbox profile measured
frame hitches; timer-state updates scan presenter views during scroll events, but
automation adds accessibility work and causal attribution remains open. Manual
profiling did not produce a usable scrolling baseline. A movement boolean cannot
validate smoothness; native timing coverage should accompany return-gesture checks.
No further runtime change is justified by these observations alone.
The owner later reported smooth scrolling on the same installed build. The comparison
install had failed, so no code change explains that improvement; attribution remains open.

## What happens

After the app returns from the background on a physical iPhone, vertical scrolling, row
swipes and the interactive back swipe all stop working; taps still work. Switching tab or
screen remounts the tree and recovers. Simulator returns never reproduced it.

A host log written to `Library/Caches/scroll-return.log` on a freeze showed, after the
finger lifted, `_UIFlexInteractionPanGestureRecognizer` on the Exact window still in
`state=2` (`.changed`), with `delegate=_UIFlexInteraction`. Later dead drags also left
`_UIParallaxTransitionPanGestureRecognizer` in `.changed`. List pans stayed
`enabled=true` / `pan=0`; the freeze was other recognizers waiting on the stuck one.

Cost: prior diagnostic work plus about 20 minutes to pull and read the phone log once a
freeze was captured.

## What would help

- On `didBecomeActive`, and when a drag ends with no scroll motion while a recognizer is
  still began/changed, force-end those recognizers (toggling `isEnabled` cancels them).
- A durable fix: liquid-glass `_UIFlexInteraction` must not leave its pan in `.changed`
  across suspension or after a cancelled touch; Exact's glass surfaces should not attach a
  flex pan that outranks scroll and interactive-back without ending cleanly.
- Keep (or thin) the scroll-return file log until phones stop freezing.

## Evidence

Physical iPhone, app with Exact integration at `584858860a` (scroll-return file log).
Freeze after return=2; first five ≥30pt drags `moved=false` with
`_UIFlexInteractionPanGestureRecognizer[state=2 … view=ExactWindow]`; `stuck` lines for
the transcript and the inbox list; drags 7–8 moved once the flex pan was gone.
Tried locally: Exact `e2b58b6992` toggled `isEnabled` on began/changed recognizers on return
and after a dead drag. On the phone that did not stop the freeze (returns often logged
`recognizers-released=0`; the freeze remained). Reverted as `4251663c25`. The diagnostic file
log stays.
