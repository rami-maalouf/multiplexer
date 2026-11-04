surfaces: ios
task: validate row-drag cancellation with native input

### Rough
- Mixing a manually launched agent socket session with `exact agent ios` changed the scratch data directory. The second launch displayed Sign In. Its multi-leg drag landed in a TextField, so neither reversal nor button-return is valid proof. The app's `SessionStore.prepare` missing-store path clears its saved session and queues server sign-out. Preserve the launch and driver logs; do not treat a signed-out screen as independent server logout proof.

### Lean in
- Native device pans plus read-only navigation/layout queries separate a row activation from horizontal overflow.
- The candidate keeps real reply and edge-back gestures working in the exercised chat.

### Needed
- one continuous authenticated driver session for the remaining native multi-leg reversal and button-return controls

### Checkpoints
- baseline: app `a09a33d`, isolated framework `ed43ad09a0` plus candidate patch sha256 `e796f50be2acd78b54a63d9855b6db8dd54c7c07075f775aadee2a03d0639266`; generated app dependency paths point to `exact2-navigation` only for this build.
- actual Simulator video: `/tmp/mx-row-native-after.mov`; state/layout evidence: `.exact/row-native/`.
- native left/right pans `(310,370)->(90,370)` and inverse, 1400 ms, stay at `/` with idle navigation.
- native vertical pan `(310,370)->(310,150)`, 1400 ms, stays home and scrolls 208.67 pt, x range/offset zero.
- native row tap opens the two-person chat. Bubble pan `(100,610)->(260,610)`, 500 ms, opens Reply; Cancel Reply was tapped without sending text.
- native edge pan `(2,400)->(342,400)`, 400 ms, with keyboard visible returns to the inbox. The immediate state sample is still in transition; `/tmp/mx-row-edge-home.png` shows the completed return. This one pass does not close intermittent Back-layout corruption.
- invalid controls: `.exact/row-native/reversal-button.log` records a TextField hit on Sign In. Its screenshot and home navigation state do not establish row cancellation.
- cleanup: restored manual launch reports session.userId empty; `/tmp/mx-row-signed-out.png` shows Sign In. A separate short-lived test-account inspection login was logged out. No older device was removed; its list is not identity-based proof of the original app session's server logout. Recording and both probe runs stopped; size large and appearance light restored; only MX settings shut down; owned auth marker checked before releasing the lock.
- remaining: native reversal returning inside, slight-movement tap, button drag-out/back, then final scoped commit. Cache owns the next slot; no reacquisition before explicit handoff.
- feedback stays local.

- off-simulator preparation: `remaining.sh` passes `zsh -n`, uses `--storage row-native-124`, and keeps login, all remaining controls and native sign-out in one driver launch. Any cleanup retry must retain that store. The prior manual state reports storage unavailable with no named scratch store; this explains the launch mismatch but does not identify the prior server device or prove its logout. Cache retains the next runtime slot.

### Final named-store controls
- first attempt signed in but reversal failed before any touch reached the app window; preserved `remaining.log`. Retried with the same `--storage row-native-124`, adding settle and omitting redundant list positioning. No candidate source changed.
- `remaining-retry.log`: row reversal landed NodeView, 81 moves, net zero, navigation next=1 and only home (zero pushes). Subsequent 2 pt movement landed the same row, six moves, next=2 and one room entry (one push).
- native MenuButton out 130 pt/back 130 pt, 64 moves, net zero opened its menu. Reversal and small-movement pictures are display captures; button-return is app fallback, no material claim. All three inspected.
- sign-out confirmation initially refused while the alert moved. Same named-store cleanup with settle succeeded; `cleanup-final.log` records native alert action and session.userId empty. Final sign-in screenshot inspected (app fallback). No exact server device ID was captured, so no server absence claim.
- restored large/light, shut down MX settings, checked own auth marker and removed only its lock. No core lock held.
- framework commit `7529006ab992ff021f790291fedd05b189250e81`; final diff SHA-256 equals tested `e796f50be2acd78b54a63d9855b6db8dd54c7c07075f775aadee2a03d0639266`. Host result remains 77 passed, six skipped, zero failed.
- intermittent Back layout and dynamic header tint remain separate/open.
