surfaces: ios
agent: Codex gpt-6-astra
task: diagnose and fix scrolling and swipes freezing after a foreground return

### Rough
- The existing scroll-return diagnostic sampled recognizers during touch delivery, so a `.changed` entry was not proof that a recognizer stayed active after delivery. It also detailed only eight drags per return. About 30 minutes reviewing logs and source; a paused, idle-state debugger inspection was needed. Post-delivery state and touch counts would have prevented the misleading inference.
- A timer touch observer never finished its recognizer state when its last touch ended or was cancelled. A physical Home-indicator swipe reproduced a frozen list twice; ending only the observer in the live process restored scrolling without navigation. About an hour of source and device investigation. Observer lifecycle coverage is needed alongside timer-admission policy tests.

- The older feedback workflow names `scripts/issue.mjs`, which the current checkout no longer ships (`Module not found`). About one minute checking for a replacement. The finding format and index links were checked manually; a migration note would help.

### Lean in
- The existing numeric scroll log distinguished hardware Home returns that worked from Home-indicator gesture returns that froze, without recording message content.

### Needed
- touch lifecycle: provided, final-contact termination repaired in the native observer

### Checkpoints
- physical reproduction: frozen in both directions after a Home-indicator swipe; finger confirmation agreed
- causal probe: one observer moved to failed, same mounted list scrolled again
- native regression: baseline 17 passed / 1 failed; repaired 18 passed / 0 failed
- iOS build: smooth after freeing local build-cache space
- driving the app: 14 native tests pass; simulator inbox/chat returns, row actions and back swipe pass
- physical rebuilt verification: pending; phone no longer available
- test cleanup: signed out; owned simulator shut down
