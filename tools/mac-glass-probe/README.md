# intermittent macOS glass crash probe

An account-free reduction of a chat composer's glass controls. On macOS 27.0.1
(26A434), `test macos` crashed with SIGTRAP in one of two consecutive runs. The
first run also reported `draft is "hello", expected ""`; the next run passed.
Manual `agent macos --chrome platform` drives passed. This is intermittent, not
a deterministic regression test. No stack was captured for the reduced crash,
so a shared root cause with the full app remains unproved.

The full app repeatedly traps after Send; a debugger previously stopped in
`NSGlassEffectContainerView.layout()` from AppKit's display cycle. Removing the
send exit animation there did not prevent the trap. No causal fix is claimed.
The smaller control retains nested glass, group spacing, tint and overlapping
entry/exit animations. No SDK, network, account or native module is needed.

Framework: `a53615adc4` (a stdio-only fix over upstream `73bee05917`).
Initial simpler manual probes also passed on `86559f737a`.

Use `bun <exact-checkout>/scripts/exact.mjs new <scratch-dir>`, copy these three
app files over its placeholders, then run from the scratch directory:

```sh
bun exact.mjs test macos
bun exact.mjs agent macos --size 900x700 --chrome platform \
  "clock 300" "type composer hello" "clock +100" "tap send" \
  "clock +40" "clock +300" "state"
```

Observed failing output:

```text
replace the animated glass send control: line 7: draft is "hello", expected ""
replace the animated glass send control: line 7: the app exited (killed by SIGTRAP)
test "replace the animated glass send control": FAIL
0 passed, 1 failed
```

Next: capture a debugger stack from the reduction and compare with the full
app's AppKit glass stack. Preserve both failed and passing runs when testing.
